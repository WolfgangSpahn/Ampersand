{-# LANGUAGE FlexibleInstances #-}
module Ampersand.Misc.HasClasses

where
import Ampersand.Basics
import RIO.FilePath
--import System.FilePath

class HasFSpecGenOpts a where
  fSpecGenOptsL :: Lens' a FSpecGenOpts
  sqlBinTablesL :: Lens' a Bool
  sqlBinTablesL = fSpecGenOptsL . (lens xsqlBinTables (\x y -> x { xsqlBinTables = y }))
  genInterfacesL :: Lens' a Bool -- 
  genInterfacesL = fSpecGenOptsL . (lens xgenInterfaces (\x y -> x { xgenInterfaces = y }))
  namespaceL :: Lens' a String -- prefix database identifiers with this namespace, to isolate namespaces within the same database.
  namespaceL = fSpecGenOptsL . (lens xnamespace (\x y -> x { xnamespace = y }))
  defaultCrudL :: Lens' a (Bool,Bool,Bool,Bool) -- Default values for CRUD functionality in interfaces
  defaultCrudL = fSpecGenOptsL . lens xdefaultCrud (\x y -> x { xdefaultCrud = y })
  trimXLSXCellsL :: Lens' a Bool
  trimXLSXCellsL = fSpecGenOptsL . lens xtrimXLSXCells (\x y -> x { xtrimXLSXCells = y })
instance HasFSpecGenOpts FSpecGenOpts where
  fSpecGenOptsL = id
  {-# INLINE fSpecGenOptsL #-}

instance HasFSpecGenOpts DevOutputOpts where
  fSpecGenOptsL = lens x8fSpecGenOpts (\x y -> x { x8fSpecGenOpts = y })
instance HasFSpecGenOpts ValidateOpts where
  fSpecGenOptsL = protoOptsL . fSpecGenOptsL
instance HasFSpecGenOpts UmlOpts where
  fSpecGenOptsL = lens x7fSpecGenOpts (\x y -> x { x7fSpecGenOpts = y })
instance HasFSpecGenOpts ProofOpts where
  fSpecGenOptsL = lens x6fSpecGenOpts (\x y -> x { x6fSpecGenOpts = y })
instance HasFSpecGenOpts PopulationOpts where
  fSpecGenOptsL = lens x5fSpecGenOpts (\x y -> x { x5fSpecGenOpts = y })
instance HasFSpecGenOpts InputOutputOpts where
  fSpecGenOptsL = lens x4fSpecGenOpts (\x y -> x { x4fSpecGenOpts = y })
instance HasFSpecGenOpts DocOpts where
  fSpecGenOptsL = lens x3fSpecGenOpts (\x y -> x { x3fSpecGenOpts = y })
instance HasFSpecGenOpts DaemonOpts where
  fSpecGenOptsL = lens x2fSpecGenOpts (\x y -> x { x2fSpecGenOpts = y })
instance HasFSpecGenOpts ProtoOpts where
  fSpecGenOptsL = lens x1fSpecGenOpts (\x y -> x { x1fSpecGenOpts = y })
class HasDirPrototype a where
  dirPrototypeL :: Lens' a (Maybe FilePath)
  getTemplateDir :: Named b => b -> a -> String
  getTemplateDir fSpec x = 
    getDirPrototype fSpec x </> "templates"
  getAppDir :: Named b => b -> a -> String
  getAppDir fSpec x =
    getDirPrototype fSpec x </> "public" </> "app" </> "project"
  getGenericsDir :: Named b => b -> a -> String
  getGenericsDir fSpec x = 
    getDirPrototype fSpec x </> "generics" 
  getDirPrototype :: Named b => b -> a -> FilePath
  getDirPrototype fSpec x =
    (case view dirPrototypeL x of
       Nothing -> name fSpec
       Just nm -> nm )
instance HasDirPrototype ProtoOpts where
  dirPrototypeL = lens xdirPrototype (\x y -> x { xdirPrototype = y })

class HasAllowInvariantViolations a where
  allowInvariantViolationsL :: Lens' a Bool
instance HasAllowInvariantViolations ProtoOpts where
  allowInvariantViolationsL = lens xallowInvariantViolations (\x y -> x { xallowInvariantViolations = y })

class HasRootFile a where
  rootFileL :: Lens' a FilePath
  baseName :: a -> String
  baseName = takeBaseName . view rootFileL
  dirSource :: a -> FilePath -- the directory of the script that is being compiled
  dirSource = takeDirectory . view rootFileL
instance HasRootFile ProtoOpts where
  rootFileL = fSpecGenOptsL . rootFileL
instance HasRootFile FSpecGenOpts where
  rootFileL = --Note: This instance definition is different, because
              --      we need a construction that in case of the deamon
              --      command, the root wil actually be read from a
              --      config file.  
     lens (\x -> fromMaybe
                    (fatal "The rootfile must be set before it is read!")
                    (xrootFile x)
          )
          (\x y -> x { xrootFile = Just y })
instance HasRootFile DocOpts where
  rootFileL = fSpecGenOptsL . rootFileL
instance HasRootFile InputOutputOpts where
  rootFileL = fSpecGenOptsL . rootFileL
instance HasRootFile PopulationOpts where
  rootFileL = fSpecGenOptsL . rootFileL
instance HasRootFile ProofOpts where
  rootFileL = fSpecGenOptsL . rootFileL
instance HasRootFile UmlOpts where
  rootFileL = fSpecGenOptsL . rootFileL
instance HasRootFile ValidateOpts where
  rootFileL = fSpecGenOptsL . rootFileL
instance HasRootFile DevOutputOpts where
  rootFileL = fSpecGenOptsL . rootFileL
class HasOutputLanguage a where
  languageL :: Lens' a (Maybe Lang)  -- The language in which the user wants the documentation to be printed.
instance HasOutputLanguage ProtoOpts where
  languageL = lens x1OutputLanguage (\x y -> x { x1OutputLanguage = y })
instance HasOutputLanguage DaemonOpts where
  languageL = lens x2OutputLanguage (\x y -> x { x2OutputLanguage = y })
instance HasOutputLanguage DocOpts where
  languageL = lens x3OutputLanguage (\x y -> x { x3OutputLanguage = y })
instance HasOutputLanguage UmlOpts where
  languageL = lens x4OutputLanguage (\x y -> x { x4OutputLanguage = y })

class HasRunComposer a where
  skipComposerL :: Lens' a Bool -- if True, runs Composer (php package manager) when generating prototype. Requires PHP and Composer on the machine. Added as switch to disable when building with Docker.
instance HasRunComposer ProtoOpts where
  skipComposerL = lens xskipComposer (\x y -> x { xskipComposer = y })


class HasDirCustomizations a where
  dirCustomizationsL :: Lens' a [FilePath] -- the directories that are copied after generating the prototype
instance HasDirCustomizations ProtoOpts where
  dirCustomizationsL = lens xdirCustomizations (\x y -> x { xdirCustomizations = y })

class HasZwolleVersion a where
  zwolleVersionL :: Lens' a String -- the version in github of the prototypeFramework. can be a tagname, a branchname or a SHA
instance HasZwolleVersion ProtoOpts where
  zwolleVersionL = lens xzwolleVersion (\x y -> x { xzwolleVersion = y })

class HasDirOutput a where
  dirOutputL :: Lens' a String -- the directory to generate the output in.

class HasOutputLanguage a => HasDocumentOpts a where
  documentOptsL :: Lens' a DocOpts
  chaptersL :: Lens' a [Chapter]
  chaptersL = documentOptsL . lens xchapters (\x y -> x { xchapters = y })
  fspecFormatL :: Lens' a FSpecFormat -- the format of the generated (pandoc) document(s)
  fspecFormatL = documentOptsL . lens xfspecFormat (\x y -> x { xfspecFormat = y })
  genLegalRefsL :: Lens' a Bool   -- Generate a table of legal references in Natural Language chapter
  genLegalRefsL = documentOptsL . lens xgenLegalRefs (\x y -> x { xgenLegalRefs = y })
  genGraphicsL :: Lens' a Bool -- Generate graphics during generation of functional design document.
  genGraphicsL = documentOptsL . lens xgenGraphics (\x y -> x { xgenGraphics = y })

instance HasDocumentOpts DocOpts where
  documentOptsL = id

class HasBlackWhite a where
  blackWhiteL :: Lens' a Bool    -- only use black/white in graphics
instance HasBlackWhite DocOpts where
  blackWhiteL = lens xblackWhite (\x y -> x { xblackWhite = y }) 

class HasOutputFile a where
  outputfileL :: Lens' a FilePath
instance HasOutputFile InputOutputOpts where
  outputfileL = lens x4outputFile (\x y -> x { x4outputFile = y })

class HasVersion a where
  preVersionL :: Lens' a String 
  postVersionL :: Lens' a String 

class HasProtoOpts env where
   protoOptsL :: Lens' env ProtoOpts
   dbNameL   :: Lens' env (Maybe String)
   sqlHostL  :: Lens' env String
   sqlLoginL :: Lens' env String
   sqlPwdL   :: Lens' env String
   forceReinstallFrameworkL :: Lens' env Bool
   dbNameL   = protoOptsL . lens xdbName (\x y -> x { xdbName = y })
   sqlHostL  = protoOptsL . lens xsqlHost (\x y -> x { xsqlHost = y })
   sqlLoginL = protoOptsL . lens xsqlLogin (\x y -> x { xsqlLogin = y })
   sqlPwdL   = protoOptsL . lens xsqlPwd (\x y -> x { xsqlPwd = y })
   forceReinstallFrameworkL
             = protoOptsL . lens xforceReinstallFramework (\x y -> x { xforceReinstallFramework = y })
instance HasProtoOpts ProtoOpts where
   protoOptsL = id
   {-# INLINE protoOptsL #-}
instance HasProtoOpts ValidateOpts where
   protoOptsL = lens protoOpts (\x y -> x { protoOpts = y }) 
class HasDevoutputOpts env where
   devoutputOptsL :: Lens' env DevOutputOpts
class HasInitOpts env where
   initOptsL :: Lens' env InitOpts
class HasProofOpts env where
   proofOptsL :: Lens' env ProofOpts
class HasPopulationOpts env where
   populationOptsL :: Lens' env PopulationOpts
class HasValidateOpts env where
   validateOptsL :: Lens' env ValidateOpts

-- | Options for @ampersand daemon@.
data DaemonOpts = DaemonOpts
  { x2OutputLanguage :: !(Maybe Lang)
  , xdaemonConfig :: !FilePath
  , x2fSpecGenOpts :: !FSpecGenOpts
   -- ^ The path (relative from current directory OR absolute) and filename of a file that contains the root file(s) to be watched by the daemon.
  }
class (HasFSpecGenOpts a) => HasDaemonOpts a where
  daemonOptsL :: Lens' a DaemonOpts
  daemonConfigL :: Lens' a FilePath
  daemonConfigL = daemonOptsL . (lens xdaemonConfig (\x y -> x { xdaemonConfig = y }))
instance HasDaemonOpts DaemonOpts where
  daemonOptsL = id
  {-# INLINE daemonOptsL #-}


data FSpecGenOpts = FSpecGenOpts
  { xrootFile :: !(Maybe FilePath)  --relative path. Must be set the first time it is read.
  , xsqlBinTables :: !Bool
  , xgenInterfaces :: !Bool -- 
  , xnamespace :: !String -- prefix database identifiers with this namespace, to isolate namespaces within the same database.
  , xdefaultCrud :: !(Bool,Bool,Bool,Bool)
  , xtrimXLSXCells :: !Bool
  -- ^ Should leading and trailing spaces of text values in .XLSX files be ignored? 
  } deriving Show

data FSpecFormat = 
         FPandoc
       | Fasciidoc
       | Fcontext
       | Fdocbook
       | Fdocx 
       | Fhtml
       | Fman
       | Fmarkdown
       | Fmediawiki
       | Fopendocument
       | Forg
       | Fpdf
       | Fplain
       | Frst
       | Frtf
       | Flatex
       | Ftexinfo
       | Ftextile
       deriving (Show, Eq, Enum, Bounded)

-- | Options for @ampersand export@.
data ExportOpts = ExportOpts
   { xexport2adl :: !FilePath  --relative path
   }
-- | Options for @ampersand dataAnalysis@ and @ampersand export@.
data InputOutputOpts = InputOutputOpts
   { x4fSpecGenOpts :: !FSpecGenOpts
   , x4outputFile :: !FilePath --relative path 
   }

-- | Options for @ampersand proto@.
data ProtoOpts = ProtoOpts
   { xdbName :: !(Maybe String)
   -- ^ Name of the database that is generated as part of the prototype
   , xsqlHost ::  !String
   -- ^ do database queries to the specified host
   , xsqlLogin :: !String
   -- ^ pass login name to the database server
   , xsqlPwd :: !String
   -- ^ pass password on to the database server
   , xforceReinstallFramework :: !Bool
   -- ^ when true, an existing prototype directory will be destroyed and re-installed
   , x1OutputLanguage :: !(Maybe Lang)
   , x1fSpecGenOpts :: !FSpecGenOpts
   , xskipComposer :: !Bool
   , xdirPrototype :: !(Maybe FilePath)
   , xdirCustomizations :: ![FilePath]
   , xzwolleVersion :: !String
   , xallowInvariantViolations :: !Bool
  } deriving Show

-- | Options for @ampersand documentation@.
data DocOpts = DocOpts
   { xblackWhite :: !Bool
   -- ^ avoid coloring conventions to facilitate readable pictures in black and white.
   , xchapters :: ![Chapter]
   -- ^ a list containing all chapters that are required to be in the generated documentation
   , xgenGraphics :: !Bool
   -- ^ enable/disable generation of graphics while generating documentation
   , xfspecFormat :: !FSpecFormat
   -- ^ the format of the documentation 
   , x3fSpecGenOpts :: !FSpecGenOpts
   -- ^ Options required to build the fSpec
   , x3OutputLanguage :: !(Maybe Lang)
   -- ^ Language of the output document
   , xgenLegalRefs :: !Bool
   -- ^ enable/disable generation of legal references in the documentation
   } deriving Show
-- | Options for @ampersand population@
data PopulationOpts = PopulationOpts
   { x5fSpecGenOpts :: !FSpecGenOpts
   -- ^ Options required to build the fSpec
   } deriving Show
-- | Options for @ampersand proofs@
data ProofOpts = ProofOpts
   { x6fSpecGenOpts :: !FSpecGenOpts
   -- ^ Options required to build the fSpec
   } deriving Show
-- | Options for @ampersand init@
data InitOpts = InitOpts
   deriving Show
-- | Options for @ampersand uml@
data UmlOpts = UmlOpts
   { x7fSpecGenOpts :: !FSpecGenOpts
   -- ^ Options required to build the fSpec
   , x4OutputLanguage :: !(Maybe Lang)
   -- ^ Language of the output document
   } deriving Show
-- | Options for @ampersand validate@
data ValidateOpts = ValidateOpts
   { protoOpts :: !ProtoOpts
   -- ^ Options required to build the fSpec
   --, x5OutputLanguage :: !(Maybe Lang)
   -- ^ Language of the output document
   } deriving Show
-- | Options for @ampersand devoutput@
data DevOutputOpts = DevOutputOpts
   { x8fSpecGenOpts :: !FSpecGenOpts
   -- ^ Options required to build the fSpec
   , x5outputFile :: !FilePath --relative path  
   } deriving Show
data TestOpts = TestOpts
   { rootTestDir :: !FilePath --relative path to directory containing test scripts
   } deriving Show
data Chapter = Intro
             | SharedLang
             | Diagnosis
             | ConceptualAnalysis
             | DataAnalysis
             deriving (Eq, Show, Enum, Bounded) 

