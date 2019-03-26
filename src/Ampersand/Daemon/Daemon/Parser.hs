{-# LANGUAGE TupleSections #-}
{-# OPTIONS_GHC -fno-warn-name-shadowing #-}
-- | Parses the output from GHCi
module Ampersand.Daemon.Daemon.Parser (
 --   parseShowModules
 -- , parseShowPaths
 -- , parseLoad
    parseProject
  , P_Context
) where


import           Ampersand.Basics
import           Ampersand.Core.ParseTree
import           Ampersand.Daemon.Daemon.Escape
import           Ampersand.Daemon.Daemon.Types
import           Ampersand.FSpec.ToFSpec.CreateFspec
import           Ampersand.Input.Parsing
import           Ampersand.Input.ADL1.CtxError
import           Ampersand.Misc
import           Data.Char
import           Data.List.Extra
import qualified Data.List.NonEmpty as NEL (toList)
import           Data.Tuple.Extra
import           System.FilePath
import           Text.Read

parseProject :: Options -> FilePath -> IO [Load]
parseProject opts rootAdl = do
    gPctx <- parseADL opts rootAdl 
    let gActx = pCtx2Fspec opts gPctx
    case gActx of
      Checked _ ws -> return . map warning2Load $ ws
      Errors  es   -> return . NEL.toList . fmap error2Load $ es
    
warning2Load :: Warning -> Load
warning2Load warn = Message
    {loadSeverity = Warning
    ,loadFile = file 
    ,loadFilePos = (line,col) 
    ,loadFilePosEnd = (line,col)
    ,loadMessage = showWarning warn
    }
  where (file, line, col) = (filenm warn, linenr warn, colnr warn)
        
error2Load :: CtxError -> Load
error2Load err = Message
    {loadSeverity = Error
    ,loadFile = file 
    ,loadFilePos = (line,col) 
    ,loadFilePosEnd = (line,col)
    ,loadMessage = lines $ showErr err
    }
  where (file, line, col) = (filenm err, linenr err, colnr err)

-- | Parse messages from show modules command. Given the parsed lines
--   return a list of (module name, file).
parseShowModules :: [String] -> [(String, FilePath)]
parseShowModules strs =
    -- we only return raw values, don't want any escape codes in there
    [ (takeWhile (not . isSpace) $ trimStart a, takeWhile (/= ',') b)
    | x <- map unescape strs
    , (a,'(':' ':b) <- [break (== '(') x]
    ]

-- | Parse messages from show paths command. Given the parsed lines
--   return (current working directory, module import search paths)
parseShowPaths :: [String] -> (FilePath, [FilePath])
parseShowPaths strs 
    | (_:x:_:is) <- map unescape strs = (trimStart x, map trimStart is)
    | otherwise = (".",[])

-- | Parse messages given on reload.
parseLoad :: [String] -> [Load]
-- nub, because cabal repl sometimes does two reloads at the start
parseLoad strs = nubOrd $ f ss
    where
        ss = map Esc strs
        f :: [Esc] -> [Load]

        -- [1 of 2] Compiling GHCi             ( GHCi.hs, interpreted )
        f (xs:rest)
            | Just xs <- stripPrefixE "[" xs
            = map (uncurry Loading) (parseShowModules [drop 11 $ dropWhile (/= ']') $ unescapeE xs]) ++
                f rest

        -- GHCi.hs:81:1: Warning: Defined but not used: `foo'
        f (x:xs)
            | not $ " " `isPrefixOfE` x
            , Just (file,rest) <- breakFileColon x
            , takeExtension file `elem` [".hs",".lhs",".hs-boot",".lhs-boot"]
                -- take position, including span if present
            , Just ((pos1, pos2), rest) <- parsePosition rest
            , (msg,las) <- span isMessageBody xs
            , rest <- trimStartE $ unwordsE $ rest : xs
            , sev <- if "warning:" `isPrefixOf` lower (unescapeE rest) then Warning else Error
            = Message sev file pos1 pos2 (map fromEsc $ x:msg) : f las

        -- <no location info>: can't find file: FILENAME
        f (x:xs)
            | Just file <- stripPrefixE "<no location info>: can't find file: " x
            = Message Error (unescapeE file) (0,0) (0,0) [fromEsc x] : f xs

        -- Module imports form a cycle:
        --   module `Module' (Module.hs) imports itself
        f (x:xs)
            | unescapeE x == "Module imports form a cycle:"
            , (xs,rest) <- span (isPrefixOfE " ") xs
            , let ms = [takeWhile (/= ')') x | x <- xs, '(':x <- [dropWhile (/= '(') $ unescapeE x]]
            = [Message Error m (0,0) (0,0) (map fromEsc $ x:xs) | m <- nubOrd ms] ++ f rest

        -- Loaded GHCi configuration from C:\Neil\ghcid\.ghci
        f (x:xs)
            | Just x <- stripPrefixE "Loaded GHCi configuration from " x
            = LoadConfig (unescapeE x) : f xs

        f (_:xs) = f xs
        f [] = []


-- 1:2:
-- 1:2-4:
-- (1,2)-(3,4):
parsePosition :: Esc -> Maybe (((Int, Int), (Int, Int)), Esc)
parsePosition x
    | Just (l1, x) <- digit x, Just x <- lit ":" x, Just (c1, x) <- digit x = case () of
        _ | Just x <- lit ":" x -> Just (((l1,c1),(l1,c1)), x)
            | Just x <- lit "-" x, Just (c2,x) <- digit x, Just x <- lit ":" x -> Just (((l1,c1),(l1,c2)), x)
            | otherwise -> Nothing
    | Just (p1, x) <- digits x, Just x <- lit "-" x, Just (p2, x) <- digits x, Just x <- lit ":" x = Just ((p1,p2),x)
    | otherwise = Nothing
    where
        lit = stripPrefixE

        digit x = (,b) <$> readMaybe (unescapeE a)
            where (a,b) = spanE isDigit x

        digits x =  do
            x <- lit "(" x
            (l,x) <- digit x
            x <- lit "," x
            (c,x) <- digit x
            x <- lit ")" x
            return ((l,c),x)


-- After the file location, message bodies are indented (perhaps prefixed by a line number)
isMessageBody :: Esc -> Bool
isMessageBody xs = isPrefixOfE " " xs || case stripInfixE "|" xs of
    Just (prefix, _) | all (\x -> isSpace x || isDigit x) $ unescapeE prefix -> True
    _ -> False

-- A filename, followed by a colon - be careful to handle Windows drive letters, see #61
breakFileColon :: Esc -> Maybe (FilePath, Esc)
breakFileColon xs = case stripInfixE ":" xs of
    Nothing -> Nothing
    Just (a,b)
        | [drive] <- unescapeE a, isLetter drive -> first ((++) [drive,':'] . unescapeE) <$> stripInfixE ":" b
        | otherwise -> Just (unescapeE a, b)
