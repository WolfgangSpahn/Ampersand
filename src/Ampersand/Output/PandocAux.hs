{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
module Ampersand.Output.PandocAux
      ( writepandoc
      , chptTitle
      , count
      , showMath
      , latexEscShw
      , texOnlyMarginNote
      , newGlossaryEntry
      , commaPandocAnd
      , commaPandocOr
      , outputLang
      )
where
import           Ampersand.ADL1
import           Ampersand.Basics
import           Ampersand.Classes (isFunction)
import           Ampersand.FSpec
import           Ampersand.Misc.HasClasses
import           Ampersand.Prototype.StaticFiles_Generated
import           Conduit (liftIO, MonadIO)  
import qualified RIO.Text as T
import qualified RIO.ByteString.Lazy as BL
import qualified RIO.Text.Partial as Partial (replace)
import           System.Directory
import           System.FilePath
import           Text.Pandoc
import           Text.Pandoc.Builder
import           Text.Pandoc.PDF (makePDF)
import qualified Text.Pandoc.UTF8 as UTF8

-- | Default key-value pairs for use with the Pandoc template
defaultWriterVariables :: (HasDocumentOpts env) => env -> FSpec -> [(Text , Text)]
defaultWriterVariables env fSpec
  = [ ("title", (case (outputLang', view chaptersL env) of
                        (Dutch  , [Diagnosis]) -> "Diagnose van "
                        (English, [Diagnosis]) -> "Diagnosis of "
                        (Dutch  , _          ) -> "Functioneel Ontwerp van "
                        (English, _          ) -> "Functional Design of "
                )<>name fSpec)
    , ("fontsize", "12pt")   --can be overridden by geometry package (see below)
    , ("lang"    , case outputLang' of
                       Dutch   -> "nl-NL"
                       English -> "en-US")
    , ("papersize", "a4")
    , ("babel-lang", case outputLang' of
                       Dutch   -> "dutch"
                       English -> "english")
    , ("documentclass","report")
    ] <>
    [ ("toc" , "<<TheTableOfContentsShouldGoHere>>") | [Diagnosis] == (view chaptersL env)]<>
    [ ("header-includes", T.unlines
         [ "% ============Ampersand specific Begin================="
         , "% First a couple of LaTeX packages are included:"
         , ""
         , "% The glossaries package supports acronyms and multiple glossaries"
         , "\\usepackage[toc]{glossaries}    % Add the glossaries to the table of contents"
         , "\\makeglossaries"
         , ""
         , "% geometry provides a flexible and easy interface to page dimentions"
         , "\\usepackage[ top=1.5cm, bottom=1.5cm, outer=5cm, inner=2cm"
         , "            , heightrounded, footskip=.5cm"
         , "            , marginparwidth=2.5cm, marginparsep=0.5cm]{geometry}"
         , ""
         , "% breqn – Automatic line breaking of displayed equations"
         , "\\usepackage{breqn}"
         , ""
         , "% colonequals – Colon equals symbols"
         , "\\usepackage{colonequals}"
         , ""
         , "% caption – Customising captions in floating environments"
         , "\\usepackage{caption}"
         , "\\captionsetup{format=plain"
         , "              ,textfont=bf,labelfont=small"
         , "              ,labelsep=none"
         , "              ,labelformat=empty"
         , "              ,width=.85\\textwidth"
         , "              }"
         , ""
         , "% textcomp – LATEX support for the Text Companion fonts -- Disabled because obsolete."
         , "% \\usepackage{textcomp}"
         , ""
         , "% hypcap – Adjusting the anchors of captions"
         , "\\usepackage[all]{hypcap}"
         , ""
         , "% <Adaptation>: The LaTeX commands \\[ and \\], are redefined in the amsmath package, making sure that equations are"
         , "% not numbered. This is undesireable behaviour. this is fixed with the following hack, inspired on a note"
         , "% found at http://tex.stackexchange.com/questions/40492/what-are-the-differences-between-align-equation-and-displaymath"
         , "\\DeclareRobustCommand{\\[}{\\begin{equation}}"
         , "\\DeclareRobustCommand{\\]}{\\end{equation}}"
         , "% <End-adaptation>"
         , ""
         , ""
         , "% ============Ampersand specific End==================="
         ])
    | (view fspecFormatL env) `elem` [Fpdf,Flatex]
    ]
  where
   outputLang' :: Lang
   outputLang' = outputLang env fSpec

--DESCR -> functions to write the pandoc
writepandoc :: (HasDirOutput env, HasRootFile env, HasDocumentOpts env, HasLogFunc env) => 
      FSpec -> Pandoc -> RIO env ()
writepandoc fSpec thePandoc = do
  env <- ask
  logInfo $ "Generating "<>display (fSpecFormatString env) <>" to : "<>display (T.pack $ outputFile env)
  liftIO $ writepandoc' env fSpec thePandoc
 where
    fSpecFormatString :: (HasDocumentOpts env) => env -> Text 
    fSpecFormatString = T.toLower . T.drop 1 . tshow . view fspecFormatL

outputFile :: (HasDocumentOpts env, HasRootFile env, HasDirOutput env) => env -> FilePath
outputFile env = view dirOutputL env </> baseName env -<.> ext (view fspecFormatL env) 
       
ext :: FSpecFormat -> FilePath
ext format =
      case format of
        Fasciidoc     -> ".txt"
        Fcontext      -> ".context"
        Fdocbook      -> ".docbook"
        Fdocx         -> ".docx"
        Fhtml         -> ".html"
        Fpdf          -> ".pdf"
        Fman          -> ".man"
        Fmarkdown     -> ".md"
        Fmediawiki    -> ".mediawiki"
        Fopendocument -> ".odt"
        Forg          -> ".org"
        FPandoc       -> ".pandoc"
        Fplain        -> ".plain"
        Frst          -> ".rst"
        Frtf          -> ".rtf"
        Flatex        -> ".ltx"
        Ftexinfo      -> ".texinfo"
        Ftextile      -> ".textile"
                   
writepandoc' :: (HasDocumentOpts env, HasRootFile env, HasDirOutput env) => env -> FSpec -> Pandoc -> IO ()
writepandoc' env fSpec thePandoc = liftIO . runIOorExplode $ do
  case writer of 
     ByteStringWriter f -> do 
       res <- f writerOptions thePandoc -- >>= handleError
       let content :: LByteString
           content = res
       liftIO $ createDirectoryIfMissing True (takeDirectory (outputFile env))
       BL.writeFile (outputFile env) content
     TextWriter f -> case view fspecFormatL env of
        Fpdf -> do
           res <- makePDF "pdflatex" [] f writerOptions thePandoc -- >>= handleError)
           case res of
             Right pdf -> writeFnBinary (outputFile env) pdf
             Left err' -> liftIO . throwIO . PandocPDFError .
                               decodeUtf8 . BL.toStrict $ err'
        _     -> liftIO $ do
                output <- runIO (f writerOptions thePandoc) >>= handleError
                writeFileUtf8 (outputFile env) (output)
 where   
    writer :: PandocMonad m => Writer m
    writer = case lookup writerName writers of
                Nothing -> fatal $ "There is no such Pandoc writer: "<>writerName
                Just w -> w
    writerName =
      case view fspecFormatL env of
       Fpdf    -> "latex"
       Flatex  -> "latex"
       FPandoc -> "native"
       fmt     -> T.toLower . T.drop 1 . tshow $ fmt
    writeFnBinary :: MonadIO m => FilePath -> BL.ByteString -> m()
    writeFnBinary f bs = do
        liftIO $ createDirectoryIfMissing True (takeDirectory f)
        liftIO . BL.writeFile (UTF8.encodePath f) $ bs
    
    writerOptions :: WriterOptions
    writerOptions = def
                      { writerTableOfContents=True
                      , writerNumberSections=True
              --        , writerTemplate= template
              --        , writerVariables=defaultWriterVariables env fSpec
                      , writerHTMLMathMethod =MathML
                    --  , writerMediaBag=bag
                    --  , writerReferenceDocx=Just docxStyleUserPath
                    --  , writerVerbose=optVerbosity
                      }
      where 
 --       template :: IO (Either String (Template a))
 --       template  = compileTemplate "" $ substitute substMap <$> decodeUtf8 <$> getStaticFileContent PandocTemplates ("default."<>writerName)
        substitute :: [(Text,Text)] -> Text -> Text
        substitute subs tmpl = foldr replaceAll tmpl subs
        replaceAll :: (Text,Text) -> Text -> Text
        replaceAll (needle,replacement) = Partial.replace needle replacement
        substMap :: [(Text,Text)]
        -- The following substitutions are required to use the 
        -- templates from pandoc unchanged. Without them we get
        -- errors with LaTeX, and possibly other templates.
        substMap = 
            [ ("\r\n$if("   ,"$if("   )        
            , ("$endif$\r\n","$endif$")
            , ("\r\n$endif$","$endif$")
            ]

-----Linguistic goodies--------------------------------------

count :: Lang -> Int -> Text -> Text
count    lang    n      x
 = case (lang, n) of
      (Dutch  , 0) -> "geen "<>plural Dutch x
      (Dutch  , 1) -> "één "<>x
      (Dutch  , 2) -> "twee "<>plural Dutch x
      (Dutch  , 3) -> "drie "<>plural Dutch x
      (Dutch  , 4) -> "vier "<>plural Dutch x
      (Dutch  , 5) -> "vijf "<>plural Dutch x
      (Dutch  , 6) -> "zes "<>plural Dutch x
      (Dutch  , _) -> tshow n<>" "<>plural Dutch x
      (English, 0) -> "no "<>plural English x
      (English, 1) -> "one "<>x
      (English, 2) -> "two "<>plural English x
      (English, 3) -> "three "<>plural English x
      (English, 4) -> "four "<>plural English x
      (English, 5) -> "five "<>plural English x
      (English, 6) -> "six "<>plural English x
      (English, _) -> tshow n<>" "<>plural English x



chptTitle :: Lang -> Chapter -> Inlines
chptTitle lang cpt =
  case cpt of
    Intro                 -> text.l $ (NL "Inleiding", EN "Introduction")
    SharedLang            -> text.l $ (NL "Gemeenschappelijke taal", EN "Shared Language")
    Diagnosis             -> text.l $ (NL "Diagnose", EN "Diagnosis")
    ConceptualAnalysis    -> text.l $ (NL "Conceptuele Analyse", EN "Conceptual Analysis")
    DataAnalysis          -> text.l $ (NL "Gegevensstructuur", EN "Data structure")
 where 
     -- shorthand for easy localizing    
    l :: LocalizedStr -> Text
    l = localize lang
    



--DESCR -> pandoc print functions for Ampersand data structures
---------------------------------------
-- LaTeX math markup
---------------------------------------

class ShowMath a where
 showMath :: a -> Inlines

instance ShowMath Rule where
 showMath = showMath . formalExpression

instance ShowMath Expression where
 showMath = math . showExpr . insParentheses
   where  showExpr :: Expression -> Text
          showExpr (EEqu (l,r)) = showExpr l<>inMathEquals<>showExpr r
          showExpr (EInc (l,r)) = showExpr l<>inMathInclusion<>showExpr r
          showExpr (EIsc (l,r)) = showExpr l<>inMathIntersect<>showExpr r
          showExpr (EUni (l,r)) = showExpr l<>inMathUnion<>showExpr r
          showExpr (EDif (l,r)) = showExpr l<>inMathDifference <>showExpr r
          showExpr (ELrs (l,r)) = showExpr l<>inMathLeftResidu<>showExpr r
          showExpr (ERrs (l,r)) = showExpr l<>inMathRightResidu<>showExpr r
          showExpr (EDia (l,r)) = showExpr l<>inMathDiamond<>showExpr r
          showExpr (ECps (EEps i sgn,r)) | i==source sgn||i==target sgn = showExpr  r
                                         | otherwise                    = showExpr (ECps (EDcI i,r))
          showExpr (ECps (l,EEps i sgn)) | i==source sgn||i==target sgn = showExpr  l
                                         | otherwise                    = showExpr (ECps (l,EDcI i))
          showExpr (ECps (l,r)) = showExpr l<>inMathCompose<>showExpr r
          showExpr (ERad (l,r)) = showExpr l<>inMathRelativeAddition<>showExpr r
          showExpr (EPrd (l,r)) = showExpr l<>inMathCartesianProduct<>showExpr r
          showExpr (EKl0 e)     = showExpr (addParensToSuper e)<>inMathStar
          showExpr (EKl1 e)     = showExpr (addParensToSuper e)<>inMathPlus
          showExpr (EFlp e)     = showExpr (addParensToSuper e)<>inMathFlip
          showExpr (ECpl e)     = inMathOverline (showExpr e)
          showExpr (EBrk e)     = "("<>showExpr e<>")"
          showExpr (EDcD d)     = inMathText (name d)
          showExpr (EDcI c)     = "I_{ \\lbrack "<>inMathText (name c)<>" \\rbrack }"
          showExpr  EEps{}      = "" -- fatal "EEps may occur only in combination with composition (semicolon)."  -- SJ 2014-03-11: Are we sure about this? Let's see if it ever occurs...
          showExpr (EDcV sgn)   = "V_{ \\lbrack "<>inMathText (name (source sgn))<>"*"<>inMathText (name (target sgn))<>" \\rbrack }"
          showExpr (EMp1 val _) = atomVal2Math val --"\texttt{"<>show val<>"}"
          
atomVal2Math :: PAtomValue -> Text
atomVal2Math pav =
   case pav of
    PSingleton   _ s _ -> " \\texttt{"<>tshow s<>"}"
    ScriptString   _ s -> " \\texttt{"<>tshow s<>"}"
    XlsxString     _ s -> " \\texttt{"<>tshow s<>"}"
    ScriptInt      _ i -> tshow i
    ScriptFloat    _ d -> tshow d
    XlsxDouble     o d -> fatal ("We got a value "<>tshow d<>" from "<>tshow o<>", which has to be shown in an expression, however the technicaltype is not known.")
    ComnBool       _ b -> tshow b
    ScriptDate     _ x -> tshow x
    ScriptDateTime _ x -> tshow x

-- add extra parentheses to consecutive superscripts, since latex cannot handle these
-- (this is not implemented in insParentheses because it is a latex-specific issue)
addParensToSuper :: Expression -> Expression
addParensToSuper e@EKl0{} = EBrk e
addParensToSuper e@EKl1{} = EBrk e
addParensToSuper e@EFlp{} = EBrk e
addParensToSuper e        = e

instance ShowMath Relation where
 showMath decl = math . noBreaking $ 
        inMathText (name decl)<>" \\lbrack "
     <>(inMathText . name . source $ decl)<> (if isFunction (EDcD decl) then " \\mapsto " else "*")
     <>(inMathText . name . target $ decl)<>" \\rbrack "

noBreaking :: (IsString a, Semigroup a) => a -> a
noBreaking x = "{"<>x<>"}"
-- | latexEscShw escapes to LaTeX encoding. It is intended to be used in LaTeX text mode.
--   For more elaborate info on LaTeX encoding, consult the The Comprehensive LATEX Symbol List
--   on:    http://ftp.snt.utwente.nl/pub/software/tex/info/symbols/comprehensive/symbols-a4.pdf
latexEscShw :: Text -> Text
latexEscShw = id
{-# DEPRECATED latexEscShw "latexEscShw has become obsolete, because we now use Text, which is UTF8 compliant by itself." #-}

{- latexEscShw ""           = ""
latexEscShw ('\"':c:cs) | isAlphaNum c = "``"<>latexEscShw (c:cs)
                        | otherwise    = "''"<>latexEscShw (c:cs)
latexEscShw "\""        = "''"
latexEscShw (c:cs)      | isAlphaNum c && isAscii c = c:latexEscShw cs
                        | otherwise    = f c<>latexEscShw cs
 where
  f '"' = "\\textquotedbl "
  f '#' = "\\#"
  f '$' = "\\$"
  f '%' = "\\%"
  f '&' = "\\&"
  f '\\'= "\\textbackslash "
  f '^' = "\\^{}"
  f '_' = "\\_"
  f '{' = "\\{"
  f '|' = "\\textbar "
  f '}' = "\\}"
  f '~' = "\\~{}"
  f '¦' = "\\textbrokenbar "
  f '¨' = "\\textasciidieresis "
  f '¯' = "\\textasciimacron "
  f '´' = "\\textasciiacute "
  f '¢' = "\\textcent "
  f '£' = "\\textpound "
  f '¤' = "\\textcurrency "
  f '¥' = "\\textyen "
  f '€' = "\\texteuro "
  f '<' = "\\textless "
  f '>' = "\\textgreater "
  f '±' = "\\textpm "
  f '«' = "\\guillemotleft "
  f '»' = "\\guillemotright "
  f '×' = "\\texttimes "
  f '÷' = "\\textdiv "
  f '§' = "\\S "
  f '©' = "\\textcopyright "
  f '¬' = "\\textlnot "
  f '®' = "\\textregistered "
  f '°' = "\\textdegree "
  f 'µ' = "\\textmu "
  f '¶' = "\\P "
  f '·' = "\\textperiodcentered "
  f '¼' = "\\textonequarter "
  f '½' = "\\textonehalf "
  f '¾' = "\\textthreequarters "
  f '¹' = "\\textonesuperior "
  f '²' = "\\texttwosuperior "
  f '³' = "\\textthreesuperior "
  f '∞' = "\\hbipropto "
  f 'ä' = "\\\"{a}"        --  umlaut or dieresis
  f 'Ä' = "\\\"{A}"        --  umlaut or dieresis
  f 'â' = "\\^{a}"         --  circumflex
  f 'Â' = "\\^{A}"         --  circumflex
  f 'à' = "\\`{a}"         --  grave accent
  f 'À' = "\\`{A}"         --  grave accent
  f 'á' = "\\'{a}"         --  acute accent
  f 'Á' = "\\'{A}"         --  acute accent
  f 'ã' = "\\~{a}"         --  tilde
  f 'Ã' = "\\~{A}"         --  tilde
  f 'å' = "\\aa "
--  f 'å' = "\\r{a}"       --  alternatively: ring over the letter
  f 'Å' = "\\AA "
--  f 'Å' = "\\r{A}"       --  alternatively: ring over the letter
  f 'ą' = "\\k{a}"         --  ogonek
  f 'Ą' = "\\k{A}"         --  ogonek
  f 'ª' = "\\textordfeminine "
  f 'æ' = "\\ae "
  f 'Æ' = "\\AE "
  f 'ç' = "\\c{c}"         --  cedilla
  f 'Ç' = "\\c{C}"         --  cedilla
  f 'Ð' = "\\DH "
  f 'ð' = "\\dh "
  f 'ë' = "\\\"{e}"        --  umlaut or dieresis
  f 'Ë' = "\\\"{E}"        --  umlaut or dieresis
  f 'ê' = "\\^{e}"         --  circumflex
  f 'Ê' = "\\^{E}"         --  circumflex
  f 'è' = "\\`{e}"         --  grave accent
  f 'È' = "\\`{E}"         --  grave accent
  f 'é' = "\\'{e}"         --  acute accent
  f 'É' = "\\'{E}"         --  acute accent
  f 'ï' = "\\\"{\\i}"      --  umlaut or dieresis
  f 'Ï' = "\\\"{I}"        --  umlaut or dieresis
  f 'î' = "\\^{\\i}"       --  circumflex
  f 'Î' = "\\^{I}"         --  circumflex
  f 'ì' = "\\`{\\i}"       --  grave accent
  f 'Ì' = "\\`{I}"         --  grave accent
  f 'í' = "\\'{\\i}"       --  acute accent
  f 'Í' = "\\'{I}"         --  acute accent
  f 'ł' = "\\l "           --  l with stroke
  f 'Ł' = "\\L "           --  l with stroke
  f 'n' = "\\~{n}"         --  tilde
  f 'Ñ' = "\\~{N}"         --  tilde
  f 'Ȯ' = "\\.{O}"         --  dot over the letter
  f 'ȯ' = "\\.{o}"         --  dot over the letter
  f 'ö' = "\\\"{o}"        --  umlaut or dieresis
  f 'Ö' = "\\\"{O}"        --  umlaut or dieresis
  f 'ô' = "\\^{o}"         --  circumflex
  f 'Ô' = "\\^{O}"         --  circumflex
  f 'ò' = "\\`{o}"         --  grave accent
  f 'Ò' = "\\`{O}"         --  grave accent
  f 'ó' = "\\'{o}"         --  acute accent
  f 'Ó' = "\\'{O}"         --  acute accent
  f 'õ' = "\\~{o}"         --  tilde
  f 'Õ' = "\\~{O}"         --  tilde
  f 'ō' = "\\={o}"         --  macron accent a bar over the letter)
  f 'Ō' = "\\={O}"         --  macron accent a bar over the letter)
  f 'ő' = "\\H{o}"         --  long Hungarian umlaut double acute)
  f 'Ő' = "\\H{O}"         --  long Hungarian umlaut double acute)
  f 'Ø' = "\\O "
  f 'ø' = "\\o "
  f 'º' = "\\textordmasculine "
  f 'ŏ' = "\\u{o}"         --  breve over the letter
  f 'Ŏ' = "\\u{O}"         --  breve over the letter
  f 'œ' = "\\oe "
  f 'Œ' = "\\OE "
  f 'š' = "\\v{s}"         --  caron/hacek "v") over the letter
  f 'Š' = "\\v{S}"         --  caron/hacek "v") over the letter
  f 'ß' = "\\ss "
  f 'Þ' = "\\TH "
  f 'þ' = "\\th "
  f '™' = "\\texttrademark "
  f 'ü' = "\\\"{u}"        --  umlaut or dieresis
  f 'Ü' = "\\\"{U}"        --  umlaut or dieresis
  f 'û' = "\\^{u}"         --  circumflex
  f 'Û' = "\\^{U}"         --  circumflex
  f 'ù' = "\\`{u}"         --  grave accent
  f 'Ù' = "\\`{U}"         --  grave accent
  f 'ú' = "\\'{u}"         --  acute accent
  f 'Ú' = "\\'{U}"         --  acute accent
  f 'ý' = "\\'{y}"         --  acute accent
  f 'Ý' = "\\'{Y}"         --  acute accent
  f _   = [c] -- let us think if this should be:    fatal ("Symbol "<>show x<>" (character "<>show (ord c)<>") is not supported")
 -}
--posixFilePath :: FilePath -> Text
-- tex uses posix file notation, however when on a windows machine, we have windows conventions for file paths...
-- To set the graphicspath, we want something like: \graphicspath{{"c:/data/Ampersand/output/"}}
--posixFilePath fp = "/"<>System.FilePath.Posix.addTrailingPathSeparator (System.FilePath.Posix.joinPath   (tail  (splitDirectories fp)))


---------------------------
--- Math related stuff ---
---------------------------
-- safe function to have plain text in a piece of Math
inMathText :: Text -> Text
inMathText s = latexEscShw s

inMathCartesianProduct :: Text
inMathCartesianProduct = "\\times "

inMathCompose :: Text
inMathCompose = ";"

inMathRelativeAddition :: Text
inMathRelativeAddition = "\\dagger "

inMathIntersect :: Text
inMathIntersect = "\\cap "

inMathUnion :: Text
inMathUnion = "\\cup "

inMathInclusion :: Text
inMathInclusion = "\\vdash "

inMathEquals :: Text
inMathEquals = "="

inMathStar :: Text
inMathStar = "^{*}"

inMathPlus :: Text
inMathPlus = "^{+}"

inMathDifference :: Text
inMathDifference = " - "

inMathLeftResidu :: Text
inMathLeftResidu = " / "

inMathRightResidu :: Text
inMathRightResidu = " \\backslash "

inMathDiamond :: Text
inMathDiamond = " \\Diamond "

inMathFlip :: Text
inMathFlip = "^{\\smallsmile}"

inMathOverline :: Text -> Text
inMathOverline x = " \\overline{"<>x<>"} "

newGlossaryEntry :: Text -> Text -> Inlines
newGlossaryEntry nm cnt =
  rawInline "latex"
    ("\\newglossaryentry{"<>escapeNonAlphaNum nm <>"}\n"<>
     "     { name={"<>latexEscShw nm <>"}\n"<>
     "     , description={"<>latexEscShw cnt<>"}}\n")

texOnlyMarginNote :: Text -> Text
texOnlyMarginNote mgn = 
   "\\marginpar{\\begin{minipage}[t]{3cm}{\\noindent\\small\\em "<>mgn<>"}\\end{minipage}}"


commaPandocAnd :: Lang -> [Inlines] -> Inlines
commaPandocAnd Dutch = commaNLPandoc "en"
commaPandocAnd English = commaEngPandoc "and"
commaPandocOr :: Lang -> [Inlines] -> Inlines
commaPandocOr Dutch = commaNLPandoc "of"
commaPandocOr English = commaEngPandoc "or"

commaEngPandoc :: Inlines -> [Inlines] -> Inlines
commaEngPandoc s [a,b,c] = a <> ", " <> b <> ", " <> s <> space <> c
commaEngPandoc s [a,b]   = a <> space <> s <> space <> b
commaEngPandoc _   [a]   = a
commaEngPandoc s (a:as)  = a <> ", " <> commaEngPandoc s as
commaEngPandoc _   []    = mempty

commaNLPandoc :: Inlines -> [Inlines] -> Inlines
commaNLPandoc s [a,b]  = a <> space <> s <> space <> b
commaNLPandoc  _  [a]  = a
commaNLPandoc s (a:as) = a <> ", " <> commaNLPandoc s as
commaNLPandoc  _  []   = mempty
   
outputLang :: (HasOutputLanguage env) => env -> FSpec -> Lang
outputLang env fSpec = fromMaybe (defOutputLang fSpec) $ view languageL env

