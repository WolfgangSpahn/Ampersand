{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PackageImports #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE UndecidableInstances #-}
module Ampersand.Misc.Options
        ( App(..)
        , HasOptions(..)
        , HasProtoOpts(..)
        , HasEnvironment(..),EnvironmentOptions, getEnvironmentOptions
        , FSpecFormat(..)
        , getOptionsIO
        , showFormat
--        , usageInfo'
        , writeConfigFile
        )
where
import Ampersand.Basics
import RIO.Char
import qualified RIO.List as L
import Data.List.Split (splitOn)
import Data.Time.Clock
import Data.Time.LocalTime
import System.Console.GetOpt
import System.Directory
import System.Environment    (getArgs, getProgName,getEnvironment,getExecutablePath )
import System.FilePath
import "yaml-config" Data.Yaml.Config as YC 
import Ampersand.Misc.HasClasses

-- | This data constructor is able to hold all kind of information that is useful to
--   express what the user would like Ampersand to do.
data Options = Options { environment :: EnvironmentOptions 
                       , showVersion :: Bool
                       , preVersion :: String
                       , postVersion :: String  --built in to aid DOS scripting... 8-(( Bummer.
                       , showHelp :: Bool
                       , verbosity :: Verbosity
                       , allowInvariantViolations :: Bool
                       , validateSQL :: Bool
                       , genSampleConfigFile :: Bool -- generate a sample configuration file (yaml)
                       , genPrototype :: Bool
                       , dirPrototype :: Maybe FilePath  -- the directory to generate the prototype in.
                       , zwolleVersion :: String -- the version in github of the prototypeFramework. can be a tagname, a branchname or a SHA
                       , dirCustomizations :: [FilePath] -- the directory that is copied after generating the prototype
                       , runComposer :: Bool -- if True, runs Composer (php package manager) when generating prototype. Requires PHP and Composer on the machine. Added as switch to disable when building with Docker.
                       , genInterfaces :: Bool -- if True, generate interfaces
                       , runAsDaemon :: Bool -- run Ampersand as a daemon. (for use with the vscode extension)
                    --   , daemonConfig :: FilePath -- the path (relative from current directory OR absolute) and filename of a file that contains the root file(s) to be watched by the daemon.
                       , namespace :: String
                       , testRule :: Maybe String
                       , genFSpec :: Bool   -- if True, generate a functional design
                       , diag :: Bool   -- if True, generate a diagnosis only
                       , fspecFormat :: FSpecFormat -- the format of the generated (pandoc) document(s)
                       , proofs :: Bool
                       , haskell :: Bool   -- if True, generate the F-structure as a Haskell source file
                       , sqlDump :: Bool   -- if True, generate a dump of SQL statements (for debugging)
                       , dirOutput :: String -- the directory to generate the output in.
                       , outputfileAdl :: String -- the file to generate the output in.
                       , outputfileDataAnalysis :: String -- the file to generate the output in.
                       , blackWhite :: Bool   -- only use black/white in graphics
                       , noDiagnosis :: Bool   -- omit the diagnosis chapter from the functional design document.
                       , noGraphics :: Bool  -- Omit generation of graphics during generation of functional design document.
                       , diagnosisOnly :: Bool   -- give a diagnosis only (by omitting the rest of the functional design document)
                       , genLegalRefs :: Bool   -- Generate a table of legal references in Natural Language chapter
                       , genUML :: Bool   -- Generate a UML 2.0 data model
                       , genFPAExcel :: Bool   -- Generate an Excel workbook containing Function Point Analysis
                       , genPOPExcel :: Bool   -- Generate an .xmlx file containing the populations 
                       , language :: Maybe Lang  -- The language in which the user wants the documentation to be printed.
                       , dirExec :: String --the base for relative paths to input files
                    --   , progrName :: String --The name of the adl executable
                       , rootFile :: Maybe FilePath --the file with the Ampersand context
                       , genTime :: LocalTime
                       , export2adl :: Bool
                       , dataAnalysis :: Bool
                       , test :: Bool
                       , genMetaFile :: Bool  -- When set, output the meta-population as a file
                       , addSemanticMetamodel :: Bool -- When set, the user can use all artefacts defined in Formal Ampersand, without the need to specify them explicitly
                       , genRapPopulation :: Bool -- This switch is to tell Ampersand that the model is being used in RAP3 as student's model
                       , sqlBinTables :: Bool -- generate binary tables (no 'brede tabellen')
                       , defaultCrud :: (Bool,Bool,Bool,Bool) -- Default values for CRUD functionality in interfaces
                       , trimXLSXCells :: Bool -- Should leading and trailing spaces of text values in .XLSX files be ignored? 
                  --     , protoOpts :: ProtoOpts
                       }
data EnvironmentOptions = EnvironmentOptions
      { envArgs               :: [String]
      , envArgsCommandLine    :: [String]
      , envArgsFromConfigFile :: [String]
      , envProgName           :: String --The name of the adl executable
      , envExePath            :: FilePath
      , envLocalTime          :: LocalTime
      , envDirOutput          :: Maybe FilePath
      , envDirPrototype       :: Maybe FilePath
      , envDbName             :: Maybe String
      , envPreVersion         :: Maybe String
      , envPostVersion        :: Maybe String  
      } deriving Show
  
class HasOptions env where
  optionsL :: Lens' env Options
instance HasDirPrototype Options where
  dirPrototypeL = lens dirPrototype (\x y -> x { dirPrototype = y })

class HasEnvironment a where
  environmentL :: Lens' a EnvironmentOptions
instance HasEnvironment Options where
  environmentL = lens environment (\x y -> x { environment = y })
instance HasEnvironment App where
  environmentL = optionsL . environmentL

--instance HasRootFile Options where
--  rootFileL = lens rootFile (\x y -> x { rootFile = y })
instance HasOutputLanguage Options where
  languageL = lens language (\x y -> x { language = y })
instance HasOutputLanguage App where
  languageL = optionsL . languageL
instance HasRunComposer Options where
  skipComposerL = lens runComposer (\x y -> x { runComposer = y })
instance HasRunComposer App where
  skipComposerL = optionsL . skipComposerL
instance HasDirCustomizations Options where
  dirCustomizationsL = lens dirCustomizations (\x y -> x { dirCustomizations = y })
instance HasDirCustomizations App where
  dirCustomizationsL = optionsL . dirCustomizationsL
instance HasZwolleVersion Options where
  zwolleVersionL = lens zwolleVersion (\x y -> x { zwolleVersion = y })
instance HasZwolleVersion App where
  zwolleVersionL = optionsL . zwolleVersionL
class HasMetaOptions a where
  genMetaFileL :: Lens' a Bool
  addSemanticMetamodelL :: Lens' a Bool
instance HasMetaOptions Options where
  genMetaFileL = lens genMetaFile (\x y -> x { genMetaFile = y })
  addSemanticMetamodelL = lens addSemanticMetamodel (\x y -> x { addSemanticMetamodel = y })
class HasCommands a where
  genUMLL :: Lens' a Bool -- Generate a UML 2.0 data model
  genHaskellL :: Lens' a Bool -- if True, generate the F-structure as a Haskell source file
  sqlDumpL :: Lens' a Bool -- if True, generate a dump of SQL statements (for debugging)
  export2adlL :: Lens' a Bool 
  genFPAExcelL :: Lens' a Bool 
  genPOPExcelL :: Lens' a Bool 
  proofsL :: Lens' a Bool 
  validateSQLL :: Lens' a Bool 
  genPrototypeL :: Lens' a Bool 
  dataAnalysisL :: Lens' a Bool -- "export a data model as plain Ampersand script, for analysing Excel-data."
  showVersionL :: Lens' a Bool
  genSampleConfigFileL :: Lens' a Bool
  showHelpL :: Lens' a Bool
  runAsDaemonL :: Lens' a Bool
instance HasCommands Options where
  genPrototypeL = lens genPrototype (\x y -> x { genPrototype = y })
  dataAnalysisL = lens dataAnalysis (\x y -> x { dataAnalysis = y })
  genUMLL = lens genUML (\x y -> x { genUML = y })
  genHaskellL = lens haskell (\x y -> x { haskell = y })
  sqlDumpL = lens sqlDump (\x y -> x { sqlDump = y })
  export2adlL = lens export2adl (\x y -> x { export2adl = y })
  genFPAExcelL = lens genFPAExcel (\x y -> x { genFPAExcel = y })
  genPOPExcelL = lens genPOPExcel (\x y -> x { genPOPExcel = y })
  proofsL = lens proofs (\x y -> x { proofs = y })
  validateSQLL = lens validateSQL (\x y -> x { validateSQL = y })
  showVersionL = lens showVersion (\x y -> x { showVersion = y })
  genSampleConfigFileL = lens genSampleConfigFile (\x y -> x { genSampleConfigFile = y })
  showHelpL = lens showHelp (\x y -> x { showHelp = y })
  runAsDaemonL = lens runAsDaemon (\x y -> x { runAsDaemon = y })


instance HasCommands App where
  genPrototypeL = optionsL . genPrototypeL
  dataAnalysisL = optionsL . dataAnalysisL
  genUMLL = optionsL . genUMLL
  genHaskellL = optionsL . genHaskellL
  sqlDumpL = optionsL . sqlDumpL
  export2adlL = optionsL . export2adlL
  genFPAExcelL = optionsL . genFPAExcelL
  genPOPExcelL = optionsL . genPOPExcelL
  proofsL = optionsL . proofsL
  validateSQLL = optionsL . validateSQLL
  showVersionL = optionsL . showVersionL
  genSampleConfigFileL = optionsL . genSampleConfigFileL
  showHelpL = optionsL . showHelpL
  runAsDaemonL = optionsL . runAsDaemonL
instance HasMetaOptions App where
  genMetaFileL = optionsL . genMetaFileL
  addSemanticMetamodelL = optionsL . addSemanticMetamodelL
instance HasDirOutput Options where
  dirOutputL = lens dirOutput (\x y -> x { dirOutput = y })
instance HasDirOutput App where
  dirOutputL = optionsL . dirOutputL
instance HasBlackWhite Options where
  blackWhiteL = lens blackWhite (\x y -> x { blackWhite = y })
instance HasBlackWhite App where
  blackWhiteL = optionsL . blackWhiteL
--instance HasOutputFile Options where
--  outputfileAdlL = lens outputfileAdl (\x y -> x { outputfileAdl = y })
--  outputfileDataAnalysisL = lens outputfileDataAnalysis (\x y -> x { outputfileDataAnalysis = y })
--instance HasOutputFile App where
--  outputfileAdlL = optionsL . outputfileAdlL
--  outputfileDataAnalysisL = optionsL . outputfileDataAnalysisL
instance HasAllowInvariantViolations Options where
  allowInvariantViolationsL = lens allowInvariantViolations (\x y -> x { allowInvariantViolations = y })
instance HasAllowInvariantViolations App where
  allowInvariantViolationsL = optionsL . allowInvariantViolationsL
instance HasVersion Options where
  preVersionL = lens preVersion (\x y -> x { preVersion = y })
  postVersionL = lens postVersion (\x y -> x { postVersion = y })
instance HasVersion App where
  preVersionL = optionsL . preVersionL
  postVersionL = optionsL . postVersionL

dirPrototypeVarName :: String
dirPrototypeVarName = "CCdirPrototype"
dirOutputVarName :: String
dirOutputVarName = "CCdirOutput"
dbNameVarName :: String
dbNameVarName = "CCdbName"

getEnvironmentOptions :: IO EnvironmentOptions
getEnvironmentOptions = 
   do args     <- getArgs
      let (configSwitches,otherArgs) = L.partition isConfigSwitch args
      argsFromConfigFile <- readConfigFileArgs (mConfigFile configSwitches)
      progName <- getProgName
      execPth  <- getExecutablePath -- on some operating systems, `getExecutablePath` gives a relative path. That may lead to a runtime error.
      exePath  <- makeAbsolute execPth -- see https://github.com/haskell/cabal/issues/3512 for details
      localTime <- utcToLocalTime <$> getCurrentTimeZone <*> getCurrentTime
      env <- getEnvironment
      return EnvironmentOptions
        { envArgs               = args
        , envArgsCommandLine    = otherArgs
        , envArgsFromConfigFile = argsFromConfigFile
        , envProgName           = progName
        , envExePath            = exePath
        , envLocalTime          = localTime
        , envDirOutput          = L.lookup dirOutputVarName    env
        , envDirPrototype       = L.lookup dirPrototypeVarName env  
        , envDbName             = L.lookup dbNameVarName       env
        , envPreVersion         = L.lookup "CCPreVersion"      env
        , envPostVersion        = L.lookup "CCPostVersion"     env
        }
  where
    isConfigSwitch :: String -> Bool
    isConfigSwitch = L.isPrefixOf configSwitch
    configSwitch :: String
    configSwitch = "--config"    
    mConfigFile :: [String] -> Maybe FilePath
    mConfigFile switches = case mapMaybe (L.stripPrefix configSwitch) switches of
                    []  -> Nothing
                    ['=':x] -> Just x
                    [err]   -> exitWith . WrongArgumentsGiven $ ["No file specified in `"++configSwitch++err++"`"]
                    xs  -> exitWith . WrongArgumentsGiven $ "Too many config files specified: " : map ("   " ++) xs
    readConfigFileArgs :: Maybe FilePath -> IO [String]
    readConfigFileArgs mFp
     = case mFp of
         Nothing    -> -- If no config file is given, there might exist one with the same name
                       -- as the script name. If that is the case, we use that config file. 
                       do args     <- getArgs
                          let (_, xs, _) = getOpt Permute (map fst options) args
                          case xs of 
                            [script] -> do let yaml = script -<.> "yaml"
                                           exist <- doesFileExist yaml
                                           if exist then readConfigFile yaml else return []
                            _  -> return []
         Just fName -> readConfigFile fName
        where 
           readConfigFile yaml = do
              runSimpleApp $ sayLn $ "Reading config file: "++yaml
              config <- load yaml
              case keys config L.\\ ["switches"] of
                []  -> do let switches :: [String] = YC.lookupDefault "switches" [] config
                          case filter (not . isValidSwitch) switches of
                            []  -> return $ map ("--"++) switches
                            [x] -> configFail $ "Invalid switch: "++x
                            xs  -> configFail $ "Invalid switches: "++L.intercalate ", " xs
                           
                [x] -> configFail $ "Unknown key: "++show x 
                xs  -> configFail $ "Unknown keys: "++L.intercalate ", " (map show xs)
             where
              configFail :: String -> a
              configFail msg
                  = exitWith . WrongArgumentsGiven $
                     [ "Error in "++yaml++":"
                     , "  "++msg
                     ] 


getOptionsIO :: IO Options
getOptionsIO = 
   do envOpts <- getEnvironmentOptions
      return (getOptions' envOpts)

getOptions' :: EnvironmentOptions -> Options
getOptions' envOpts =  
   case errors of
     []  | allowInvariantViolations opts && validateSQL opts 
                     -> exitWith . WrongArgumentsGiven $ ["--ignore-invariant-violations and --validate must not be used at the same time."] --(Reason: see ticket #378))
         | otherwise -> opts
     _  -> exitWith . WrongArgumentsGiven $ errors ++ [usage]
         
 where
    opts :: Options
    -- Here we thread startOptions through all supplied option actions
    opts = L.foldl f startOptions actions
      where f a b = b a
    (actions, fNames, errors) = getOpt Permute (map fst options) $ envArgsFromConfigFile envOpts ++ envArgsCommandLine envOpts 
    fName = case fNames of
             []   -> Nothing
             [n]  -> if hasExtension n then Just n else Just $ addExtension n "adl"
             _    -> exitWith . WrongArgumentsGiven $ ("Too many files: "++ L.intercalate ", " fNames) : [usage]
    usage = "Type '"++envProgName envOpts++" --help' for usage info."
    startOptions :: Options
    startOptions =
               Options {environment      = envOpts
                      , genTime          = envLocalTime envOpts
                      , dirOutput        = fromMaybe "." $ envDirOutput envOpts
                      , outputfileAdl       = "Export.adl"
                      , outputfileDataAnalysis  = "DataModel.adl"
                      , dirPrototype     = Just (fromMaybe "." (envDirPrototype envOpts) </> (takeBaseName (fromMaybe "" fName)) <.> ".proto")
                      , zwolleVersion    = "v1.3.1"
                      , dirCustomizations = ["customizations"]
                      , runComposer      = True -- by default run Composer (php package manager) when deploying prototype for backward compatibility
                      , dirExec          = takeDirectory (envExePath envOpts)
                      , preVersion       = fromMaybe "" $ envPreVersion envOpts
                      , postVersion      = fromMaybe "" $ envPostVersion envOpts
                      , showVersion      = False
                      , showHelp         = False
                      , verbosity         = Silent
                      , allowInvariantViolations = False
                      , validateSQL      = False
                      , genSampleConfigFile = False
                      , genPrototype     = False
                      , genInterfaces    = False
                      , runAsDaemon      = False
                    --  , daemonConfig     = ".ampersand"
                      , namespace        = ""
                      , testRule         = Nothing
                      , genFSpec         = False
                      , diag             = False
                      , fspecFormat      = fatal ("Unknown fspec format. Currently supported formats are "++allFSpecFormats++".")
                      , proofs           = False
                      , haskell          = False
                      , sqlDump          = False
                      , blackWhite       = False
                      , noDiagnosis      = False
                      , noGraphics       = False
                      , diagnosisOnly    = False
                      , genLegalRefs     = False
                      , genUML           = False
                      , genFPAExcel      = False
                      , genPOPExcel      = False
                      , language         = Nothing
                   --   , progrName        = envProgName envOpts
                      , rootFile         = fName
                      , export2adl       = False
                      , dataAnalysis     = False
                      , test             = False
                      , genMetaFile      = False
                      , addSemanticMetamodel = False
                      , genRapPopulation = False
                      , sqlBinTables       = False
                      , defaultCrud      = (True,True,True,True) 
                      , trimXLSXCells    = True
                  --    , protoOpts        = defProtoOpts fName envOpts
                      }
writeConfigFile :: IO ()
writeConfigFile = do
    writeFile sampleConfigFileName (unlines sampleConfigFile)
    runSimpleApp $ sayLn (sampleConfigFileName++" written.")
    
sampleConfigFileName :: FilePath
sampleConfigFileName = "sampleconfig.yaml"
sampleConfigFile :: [String]
sampleConfigFile =
  [ " # Sample config file for Ampersand"
  , " # This file contains a list of all command line options that can be set using a config file"
  , " # It can be used by specifying:  ampersand.exe --config=myConfig.yaml myModel.adl"
  , " # remove the comment character (`#`) in front of the switches you want to activate."
  , " # Note: Make sure that the minus (`-`) characters are in exactly the same column. Yaml format is picky about that."
  , ""
  , "switches:"
  ]++concatMap (yamlItem . fst) options
  where
    yamlItem :: OptionDef -> [String]
    yamlItem (Option _ label kind info ) 
      = case label of
          [] -> fatal "label cannot be empty"
          h:_ -> if h `elem` validSwitches
                  then
                  [ "  ### "++info++":"
                  , "  # - "++h++case kind of
                                   NoArg _ -> "" 
                                   ReqArg _ str -> "="++str
                                   OptArg _ str -> "[="++str++"]"
                  , ""
                  ]
                  else []   
isValidSwitch :: String -> Bool
isValidSwitch str = 
  case mapMaybe (matches . fst) options of
    [Option _ _ kind _]
        -> case (dropWhile (/= '=') str, kind) of
             ([]    , NoArg  _  ) -> True 
             ([]    , OptArg _ _) -> True
             ('=':_ , OptArg _ _) -> True
             ('=':_ , ReqArg _ _) -> True
             _  -> False
    _  -> False
  where 
    matches :: OptionDef -> Maybe OptionDef
    matches x@(Option _ labels _ _) 
     = if takeWhile (/= '=') str `elem` labels L.\\ ["version","help","config","sampleConfigFile"]
       then Just x
       else Nothing
validSwitches :: [String]
validSwitches =  filter canBeYamlSwitch [h | Option _ (h:_) _ _ <- map fst options]
canBeYamlSwitch :: String -> Bool
canBeYamlSwitch str =
   takeWhile (/= '=') str `notElem` ["version","help","config","sampleConfigFile"]  
data DisplayMode = Public | Hidden deriving Eq

allFSpecFormats :: String   --TODO: Should be: allFSpecFormats :: [FSpecFormat]
allFSpecFormats = 
     "[" ++
     L.intercalate ", " ((L.sort . map showFormat) [minBound..]) ++
     "]"
showFormat :: FSpecFormat -> String
showFormat fmt = case show fmt of
                  _:h:t -> toUpper h : map toLower t
                  x     -> x 

type OptionDef = OptDescr (Options -> Options)
options :: [(OptionDef, DisplayMode) ]
options = [ (Option ['v']   ["version"]
               (NoArg (\opts -> opts{showVersion = True}))
               "show version and exit."
            , Public)
          , (Option ['h','?'] ["help"]
               (NoArg (\opts -> opts{showHelp = True}))
               "get (this) usage information. Add --verbose for more advanced options."
            , Public)
          , (Option ['V']   ["verbose"]
               (NoArg (\opts -> opts{ verbosity  = Loud}))
               "verbose output, to report which files Ampersand writes."
            , Public)
          , (Option []   ["sampleConfigFile"]
               (NoArg (\opts -> opts{genSampleConfigFile = True}))
               ("write a sample configuration file ("++sampleConfigFileName++"), to avoid retyping (and remembering) the command line options for ampersand.")
            , Public)
          , (Option []      ["config"]
               (ReqArg (\nm _ -> fatal ("config file ("++nm++")should not be treated as a regular option.")
                       ) "config.yaml")
               "config file (*.yaml) that contains the command line options of ampersand."
            , Public)
--          , (Option []      ["ignore-invariant-violations"]
--               (NoArg (\opts -> opts{allowInvariantViolations = True}))
--               "Allow to build a prototype, even if there are invariants that are being violated. (See https://github.com/AmpersandTarski/Ampersand/issues/728)"
--            , Hidden)
          , (Option []      ["validate"]
               (NoArg (\opts -> opts{validateSQL = True}))
               "Compare results of rule evaluation in Haskell and SQL, for testing expression semantics. This requires command line php with MySQL support."
            , Hidden)
          , (Option ['p']     ["proto"]
               (OptArg (\nm opts -> opts {dirPrototype = nm
                                         ,genPrototype = True}
                       ) "DIRECTORY")
               ("generate a functional prototype, so you can experiment with the information system specified in your script. This overrules environment variable "++ dirPrototypeVarName ++ ").")
            , Public)
          , (Option []     ["prototype-framework-version"]
               (ReqArg (\x opts -> opts {zwolleVersion = x}
                       ) "VERSION")
               ("tag, branch or SHA of the prototype framework on Github. (What purpose does this serve?)")
            , Hidden)
          , (Option []     ["customizations"]
               (ReqArg (\names opts -> opts {dirCustomizations = splitOn ";" names}
                       ) "DIRECTORY")
               "copy a directory into the generated prototype, overriding the default directory called 'customizations'."
            , Hidden)
--          , (Option []      ["skip-composer"]
--               (NoArg (\opts -> opts{runComposer = False}))
--               "skip installing php dependencies (using Composer) for prototype framework."
--            , Hidden)
  --        , (Option []        ["sql-bin-tables"]
  --             (NoArg (\opts -> opts{sqlBinTables = True}))
  --             "generate binary tables only in SQL database, for testing purposes."
  --          , Hidden)
--          , (Option ['x']     ["interfaces"]
--               (NoArg (\opts -> opts{genInterfaces  = True}))
--               "generate interfaces, which currently does not work."
--            , Hidden)
          -- , (Option []        ["daemon"]
          --      (OptArg (\fn opts -> opts{runAsDaemon = True
          --                               ,daemonConfig = fromMaybe (daemonConfig opts) fn
          --                               })"configfile")
          --      "Run ampersand as daemon, for use by the vscode ampersand-language-extention. An optional parameter may be specified to tell what config file is used. This defaults to `.ampersand`."
          --   , Public)
          , (Option ['e']     ["export"]
               (OptArg (\mbnm opts -> opts{export2adl = True
                                          ,outputfileAdl = fromMaybe (outputfileAdl opts) mbnm}) "file")
               "export as plain Ampersand script, for round-trip testing of the Ampersand compiler."
            , Public)
            , (Option ['D']        ["dataAnalysis"]
            (OptArg (\mbnm opts -> opts{dataAnalysis = True
                                       ,outputfileDataAnalysis = fromMaybe (outputfileDataAnalysis opts) mbnm}) "file")
            "export a data model as plain Ampersand script, for analysing Excel-data."
         , Public)
       , (Option ['o']     ["outputDir"]
               (ReqArg (\nm opts -> opts{dirOutput = nm}
                       ) "DIR")
               ("output directory (This overrules environment variable "++ dirOutputVarName ++ ").")
            , Public)
--          , (Option []      ["namespace"]
--               (ReqArg (\nm opts -> opts{namespace = nm}
--                       ) "NAMESPACE")
--               "prefix database identifiers with this namespace, to isolate namespaces within the same database."
--            , Hidden)
          , (Option ['f']   ["fspec"]
               (ReqArg (\w opts -> opts
                                { genFSpec=True
                                , fspecFormat= case map toUpper w of
                                    ('A': _ )             -> Fasciidoc
                                    ('C': _ )             -> Fcontext
                                    ('D':'O':'C':'B': _ ) -> Fdocbook
                                    ('D':'O':'C':'X': _ ) -> Fdocx
                                    ('H': _ )             -> Fhtml
                                    ('L': _ )             -> Flatex
                                    ('M':'A':'N': _ )     -> Fman
                                    ('M':'A': _ )         -> Fmarkdown
                                    ('M':'E': _ )         -> Fmediawiki
                                    ('O':'P': _ )         -> Fopendocument
                                    ('O':'R': _ )         -> Forg
                                    ('P':'A': _ )         -> FPandoc
                                    ('P':'D': _ )         -> Fpdf
                                    ('P':'L': _ )         -> Fplain
                                    ('R':'S': _ )         -> Frst
                                    ('R':'T': _ )         -> Frtf
                                    ('T':'E':'X':'I': _ ) -> Ftexinfo
                                    ('T':'E':'X':'T': _ ) -> Ftextile
                                    _                     -> fspecFormat opts}
                       ) "FORMAT")
               ("generate a functional design document in specified format (FORMAT="++allFSpecFormats++"), to kick-start your functional specification.")
            , Public)
          , (Option []        ["testRule"]
               (ReqArg (\ruleName opts -> opts{ testRule = Just ruleName }
                       ) "RULE")
               "Show contents and violations of specified rule, for testing a single rule in your Ampersand-script."
            , Hidden)
     --     , (Option []        ["css"]
     --          (ReqArg (\pth opts -> opts{ customCssFile = Just pth }) "file")
     --          "Custom.css file to customize the style of the prototype."
     --       , Public)
          , (Option []        ["proofs"]
               (NoArg (\opts -> opts{proofs = True}))
               "generate derivations, for testing the generation of rules."
            , Hidden)
          , (Option []        ["haskell"]
               (NoArg (\opts -> opts{haskell = True}))
               "generate internal data structure, written in Haskell (for debugging)."
            , Hidden)
          , (Option []        ["sqldump"]
               (NoArg (\opts -> opts{sqlDump = True}))
               "generate a dump of SQL queries (for debugging)."
            , Hidden)
          , (Option []        ["blackWhite"]
               (NoArg (\opts -> opts{blackWhite = True}))
               "avoid coloring conventions to facilitate readable pictures in black and white."
            , Hidden)
          , (Option []        ["noGraphics"]
               (NoArg (\opts -> opts{noGraphics = True}))
               "omit the generation of graphics during generation of the functional design document to speed up the compiler."
            , Public)
          , (Option []        ["noDiagnosis"]
               (NoArg (\opts -> opts{noDiagnosis = True}))
               "omit the diagnosis chapter from the functional design document."
            , Public)
          , (Option []        ["diagnosis"]
               (NoArg (\opts -> opts{diagnosisOnly = True}))
               "diagnose your Ampersand script (generates a document containing the diagnosis chapter only)."
            , Public)
          , (Option []        ["reference-table"]
               (NoArg (\opts -> opts{genLegalRefs = True}))
               "generate a table of references in the Natural Language chapter, for instance for legal traceability."
            , Public)
          , (Option []        ["uml"]
               (NoArg (\opts -> opts{genUML = True}))
               "Generate a data model in UML 2.0 style."
            , Hidden)
          , (Option []        ["fpa-excel"]
               (NoArg (\opts -> opts{genFPAExcel = True}))
               "Generate an Excel workbook (FPA_<filename>.xml)."
            , Hidden)
          , (Option []        ["pop-xlsx"]
               (NoArg (\opts -> opts{genPOPExcel = True}))
               "Generate an .xmlx file containing the populations of your script."
            , Hidden)
      --    , (Option []        ["language"]
      --         (ReqArg (\l opts-> opts{language = case map toUpper l of
      --                                                 "NL"  -> Just Dutch
      --                                                 "UK"  -> Just English
      --                                                 "US"  -> Just English
      --                                                 "EN"  -> Just English
      --                                                 _     -> Nothing}
      --                 ) "LANG")
      --         "Pick 'NL' for Dutch or 'EN' for English, as the language to be used in your output. Without this option, output is written in the language of your context."
      --      , Public)
          , (Option []        ["test"]
               (NoArg (\opts -> opts{test = True}))
               "Used for test purposes only."
            , Hidden)
          , (Option []        ["meta-file"]
               (NoArg (\opts -> opts{genMetaFile = True}))
               ("Generate an .adl file that contains the relations of formal-ampersand, "++
                "populated with the the meta-population of your own .adl model, in case you want a metamodel.")
            , Hidden)
          , (Option []        ["add-semantic-metamodel","meta-tables"]
               (NoArg (\opts -> opts{addSemanticMetamodel = True}))
               ("All relations, views, idents etc. from formal-ampersand will be available for "++
                "use in your model. These artefacts do not have to be declared explicitly in your own model.")
            , Hidden)
          , (Option []        ["gen-as-rap-model"]
               (NoArg (\opts -> opts{genRapPopulation = True}))
               "Generate populations for use in RAP3."
            , Hidden)
          , (Option []        ["crud-defaults"]
               (ReqArg (\crudString opts -> let c = 'c' `notElem` crudString
                                                r = 'r' `notElem` crudString
                                                u = 'u' `notElem` crudString
                                                d = 'd' `notElem` crudString
                                            in opts{defaultCrud = (c,r,u,d)}
                       ) "CRUD"
               )
               "Temporary switch to learn about the semantics of crud in interface expressions."
            , Hidden)
--          , (Option []        ["do-not-trim-cellvalues"]
--               (NoArg (\opts -> opts{trimXLSXCells = False}))
--               "Do not ignore leading and trailing spaces in .xlsx files that are INCLUDED in the script." -- :-)
--            , Hidden)
          ]

--usageInfo' :: (HasLogFunc env, HasEnvironment env) => env -> String
-- When the user asks --help, then the public options are listed. However, if also --verbose is requested, the hidden ones are listed too.
--usageInfo' opts =
--  infoHeader (envProgName (view environmentL opts)) ++"\n"++
--    (concat . L.sort . map publishOption) [od | (od,x) <- options, view verbosityL opts == Loud || x == Public] 

--infoHeader :: String -> String
--infoHeader progName = "\nUsage info:\n " ++ progName ++ " options file ...\n\nList of options:"


-- publishOption:: OptDescr a -> String
-- publishOption (Option shorts longs args expl) 
--   = unlines (
--     ( "  "++L.intercalate ", " ["--"++l | l <-longs] 
--       ++case args of
--          NoArg _      -> "" 
--          ReqArg _ str -> "="++str
--          OptArg _ str -> "[="++str++"]"
--       ++case L.intercalate ", " [ "-"++[c] | c <- shorts] of
--           []  -> []
--           xs  -> " ("++xs++")"
--     ): 
--      map (replicate 10 ' '++) (lines (limit 65 expl)))
--   where
--    limit :: Int -> String -> String
--    limit i = L.intercalate "\n" . map (singleLine i . words) . lines
--    singleLine :: Int -> [String] -> String 
--    singleLine i wrds = 
--      case fillUpto i "" wrds of
--        (str, []) -> str
--        (str, rest) -> str ++ "\n"++ singleLine i rest
--    fillUpto :: Int -> String -> [String] -> (String, [String])
--    fillUpto i "" (w:ws) = fillUpto i w ws
--    fillUpto _ str [] = (str, [])
--    fillUpto i str (w:ws) = let nstr = str++" "++w
--                            in if length nstr > i 
--                            then (str, w:ws)
--                            else fillUpto i nstr ws 

data App = App
  { options' :: !Options
  , appLogFunc :: !LogFunc
  }

instance HasDirPrototype App where
  dirPrototypeL = optionsL . dirPrototypeL
--instance HasRootFile App where
--  rootFileL = optionsL . rootFileL
instance HasOptions App where
  optionsL = lens options' (\env opts -> env{ options' = opts})
instance HasLogFunc App where
  logFuncL = lens appLogFunc (\x y -> x { appLogFunc = y })

