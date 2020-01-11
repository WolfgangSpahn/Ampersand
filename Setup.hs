{-# OPTIONS_GHC -Wall #-}
module Main 
where
import qualified Codec.Compression.GZip as GZip  --TODO replace by Codec.Archive.Zip from package zip-archive. This reduces the amount of packages. (We now use two for zipping/unzipping)
import           Control.Exception
import qualified Data.ByteString.Lazy.Char8 as BLC
import           RIO.Char
import qualified RIO.List as L
import           RIO.Time
import           Distribution.Simple
import           Distribution.Simple.LocalBuildInfo
import           Distribution.Simple.Setup
import           Distribution.PackageDescription
import           Distribution.Pretty (prettyShow)
import           System.Directory
import           System.Environment (getEnvironment)
import           System.Exit
import           System.FilePath
import           System.IO(withFile,IOMode(ReadMode),hGetContents)
import           System.Process(readProcessWithExitCode)

main :: IO ()
main = defaultMainWithHooks (simpleUserHooks { buildHook = generateBuildInfoHook } )

-- Before each build, generate a BuildInfo_Generated module that exports the project version from cabal,
-- the current revision number and the build time.
--
-- Note that in order for this Setup.hs to be used by cabal, the build-type should be Custom.

generateBuildInfoHook :: PackageDescription -> LocalBuildInfo -> UserHooks -> BuildFlags -> IO ()
generateBuildInfoHook pd  lbi uh bf =
 do { let cabalVersionStr = prettyShow . pkgVersion . package $ pd

    ; gitInfoStr <- getGitInfoStr
    ; clockTime <- getCurrentTime >>= utcToLocalZonedTime
    ; let buildTimeStr = formatTime defaultTimeLocale "%d-%b-%y %H:%M:%S %Z" clockTime
    ; writeFile (pathFromModuleName buildInfoModuleName) $
        buildInfoModule cabalVersionStr gitInfoStr buildTimeStr

    ; generateStaticFileModule

    ; putStrLn ""
    ; (buildHook simpleUserHooks) pd lbi uh bf -- start the build
    }

buildInfoModuleName :: String
buildInfoModuleName = "Ampersand.Basics.BuildInfo_Generated"

buildInfoModule :: String -> String -> String -> String
buildInfoModule cabalVersion gitInfo time = unlines
  [ "module "++buildInfoModuleName++"("
  -- Workaround: break pragma start { - #, since it upsets Eclipse :-(
  , ""
  , "-- This module is generated automatically by Setup.hs before building. Do not edit!"
  , ""
  , "      cabalVersionStr"
  , "    , gitInfoStr"
  , "    , buildTimeStr"
  , "    ) where"
  , "import Ampersand.Basics.Prelude"
  , ""
  , "{-"++"# NOINLINE cabalVersionStr #-}" -- disable inlining to prevent recompilation of dependent modules on each build
  , "cabalVersionStr :: String"
  , "cabalVersionStr = \"" ++ cabalVersion ++ "\""
  , ""
  , "{-"++"# NOINLINE gitInfoStr #-}"
  , "gitInfoStr :: String"
  , "gitInfoStr = \"" ++ gitInfo ++ "\""
  , ""
  , "{-"++"# NOINLINE buildTimeStr #-}"
  , "buildTimeStr :: String"
  , "buildTimeStr = \"" ++ time ++ "\""
  , ""
  ]

getGitInfoStr :: IO String
getGitInfoStr = getInfoStr `catch` warnGracefully
  where 
   getInfoStr = do
     eSHA <- readProcessEither "git" ["rev-parse", "--short", "HEAD"] ""
     eBranch <- readProcessEither "git" ["rev-parse", "--abbrev-ref", "HEAD"] ""
     (exitCode, _, _) <- readProcessWithExitCode "git" ["diff", "--quiet"] ""
     let isDirty = exitCode /= ExitSuccess -- exit code signals whether branch is dirty
     case (eSHA, eBranch) of
       (Right sha, Right branch) ->
           return $ gitInfoStr sha branch isDirty
       _ -> do 
           -- ci/cd will create some custom environment variables.
           -- This is required in case of usage of cabal 2.4 or greater.
           -- (See https://github.com/haskell/cabal/issues/5934 for 
           -- the discussion)
           env <- getEnvironment
           case ( lookup "GIT_SHA" env
                , lookup "GIT_Branch" env
                ) of
             (Just sha, Just branch) ->
               return $ gitInfoStr branch sha False
             _ -> do
               mapM_ print $ lefts [eSHA, eBranch] -- errors during git execution
               warnNoCommitInfo
           
   warnGracefully err = do
     print (err :: IOException)
     warnNoCommitInfo
   gitInfoStr sha branch isDirty =
      strip branch ++ ":" ++ strip sha ++ (if isDirty then "*" else "")   
   strip str = reverse . dropWhile isSpace . reverse $ str

   readProcessEither :: String -> [String] -> String -> IO (Either String String)
   readProcessEither cmd args stdinStr = do
     (exitCode,stdoutStr,stderrStr) <- readProcessWithExitCode cmd args stdinStr
     case exitCode of
       ExitSuccess   -> return $ Right stdoutStr
       ExitFailure _ -> return $ Left stderrStr

warnNoCommitInfo :: IO String
warnNoCommitInfo = do
  putStrLn ""
  putStrLn ""
  putStrLn "WARNING: Execution of 'git' command failed."
  putStrLn "BuildInfo_Generated.hs will not contain revision information, and"
  putStrLn "   therefore neither will fatal error messages."
  putStrLn "   Please check your installation."
  return "no git info"

{- For each file in the directory ampersand/static, we generate a StaticFile value,
   which contains the information necessary for Ampersand to create the file at run-time.

   To prevent compiling the generated module (which can get rather big) on each build, we compare the contents
   the file we are about to generate with the contents of the already generated file and only write if there is a difference.
   This complicates the build process, but seems the only way to handle large amounts of diverse static
   files, until Cabal's data-files mechanism is updated to allow fully recursive patterns.

   TODO: creating the entire file may be somewhat time-consuming, if this is a problem on slower machines, we may want to cache the
         timestamps+names in a file and only generate when there is a change. (using the timestamps from the previously
         generated module file is not an option, as a Haskell read on that file is extremely slow)
-}

staticFileModuleName :: String
staticFileModuleName = "Ampersand.Prototype.StaticFiles_Generated"

generateStaticFileModule :: IO ()
generateStaticFileModule =
 do { previousModuleContents <- getPreviousStaticFileModuleContents sfModulePath
    ; currentModuleContents <- readAllStaticFiles

    -- simply compare file contents to see if we need to write (to prevent re-compilation)
    ; if previousModuleContents == currentModuleContents
      then
        putStrLn $ "Static files unchanged, no need to update "++sfModulePath
      else
       do { putStrLn $ "Static files have changed, updating "++sfModulePath
          ; writeFile sfModulePath currentModuleContents
          }
    }
 where sfModulePath = pathFromModuleName staticFileModuleName

getPreviousStaticFileModuleContents :: String -> IO String
getPreviousStaticFileModuleContents sfModulePath =
  (withFile sfModulePath ReadMode $ \h ->
   do { str <- hGetContents h
      --; putStrLn $ "reading old file"
      ; length str `seq` return () -- lazy IO is :-(
      --; putStrLn $ "Done"
      ; return str
      }) `catch` \err ->  -- old generated module exists, but we can't read the file or read the contents
   do { putStrLn $ "\n\n\nWarning: Cannot read previously generated " ++ sfModulePath ++ ":\n" ++
                   show (err :: SomeException) ++ "\nThis warning should disappear the next time you build Ampersand. If the error persists, please report this as a bug.\n"
      ; return []
      }

-- Collect all files required to be inside the ampersand.exe 
readAllStaticFiles :: IO String
readAllStaticFiles =
  do { pandocTemplatesFiles <- readStaticFiles PandocTemplates  "outputTemplates" "." -- templates for several PANDOC output types
     ; formalAmpersandFiles <- readStaticFiles FormalAmpersand  "AmpersandData/FormalAmpersand" "."  --meta information about Ampersand
     ; systemContextFiles   <- readStaticFiles PrototypeContext    "AmpersandData/PrototypeContext" "."  --Special system context for Ampersand
     ; return $ mkStaticFileModule $ pandocTemplatesFiles ++ formalAmpersandFiles ++ systemContextFiles
     }

readStaticFiles :: FileKind -> FilePath -> FilePath -> IO [String]
readStaticFiles fkind base fileOrDirPth =
  do { let path = combine base fileOrDirPth
     ; isDir <- doesDirectoryExist path
     ; if isDir then
        do { fOrDs <- getProperDirectoryContents path
           ; fmap concat $ mapM (\fOrD -> readStaticFiles fkind base (combine fileOrDirPth fOrD)) fOrDs
           }
       else
        do { timeStamp <- getModificationTime path
           ; fileContents <- BLC.readFile path
           ; return [ "SF "++show fkind++" "++show fileOrDirPth++" "++utcToEpochTime timeStamp ++
                             " {-"++show timeStamp++" -} (BLC.unpack$ GZip.decompress "++show (GZip.compress fileContents)++")"
                    ]
           }
     }
  where utcToEpochTime :: UTCTime -> String
        utcToEpochTime utcTime = formatTime defaultTimeLocale "%s" utcTime

data FileKind = PandocTemplates | FormalAmpersand | PrototypeContext deriving (Show, Eq)

mkStaticFileModule :: [String] -> String
mkStaticFileModule sfDeclStrs =
  unlines staticFileModuleHeader ++
  "  [ " ++ L.intercalate "\n  , " sfDeclStrs ++ "\n" ++
  "  ]\n"

staticFileModuleHeader :: [String]
staticFileModuleHeader =
  [ "{-# LANGUAGE OverloadedStrings #-}"
  , "module "++staticFileModuleName
  , "   ( StaticFile(..),FileKind(..)"
  , "   , allStaticFiles, getStaticFileContent"
  , "   )"
  , "where"
  , "import Ampersand.Basics"
  , "import qualified Data.ByteString.Lazy.Char8 as BLC"
  , "import qualified Codec.Compression.GZip as GZip"
  , "import System.FilePath"
  , ""
  , "data FileKind = PandocTemplates | FormalAmpersand | PrototypeContext deriving (Show, Eq)"
  , "data StaticFile = SF { fileKind      :: FileKind"
  , "                     , filePath      :: FilePath -- relative path, including extension"
  , "                     , timeStamp     :: Integer  -- unix epoch time"
  , "                     , contentString :: String"
  , "                     }"
  , ""
  , "getStaticFileContent :: FileKind -> FilePath -> Maybe String"
  , "getStaticFileContent fk fp ="
  , "     case filter isRightFile allStaticFiles of"
  , "        [x] -> Just (contentString x)"
  , "        _   -> Nothing"
  , "  where"
  , "    isRightFile :: StaticFile -> Bool"
  , "    isRightFile (SF fKind path _ _ ) = fKind == fk && equalFilePath path (\".\" </> fp)"
  , ""
  , "{-"++"# NOINLINE allStaticFiles #-}" -- Workaround: break pragma start { - #, since it upsets Eclipse :-(
  , "allStaticFiles :: [StaticFile]"
  , "allStaticFiles ="
  ]

getProperDirectoryContents :: FilePath -> IO [String]
getProperDirectoryContents pth = fmap (filter (`notElem` [".","..",".svn"])) $ getDirectoryContents pth

pathFromModuleName :: String -> String
pathFromModuleName m = "src/" ++ [if c == '.' then '/' else c | c <- m] ++ ".hs"
