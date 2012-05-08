{-# OPTIONS_GHC -Wall #-}
module DatabaseDesign.Ampersand.Basics.Version (ampersandVersionStr, ampersandVersionWithoutBuildTimeStr, fatalMsg) where

import DatabaseDesign.Ampersand.Basics.BuildInfo_Generated

fatalMsg :: String -> Int -> String -> a
fatalMsg haskellModuleName lineNr msg
 = error ("!fatal error "++show lineNr++" (module "++haskellModuleName++", "++ampersandVersionWithoutBuildTimeStr++")\n  "++msg)

ampersandVersionStr :: String
ampersandVersionStr = ampersandVersionWithoutBuildTimeStr ++", build time: "++buildTimeStr

ampersandVersionWithoutBuildTimeStr :: String
ampersandVersionWithoutBuildTimeStr = "Ampersand v"++cabalVersionStr++"."++svnRevisionStr
{- 
   #1.#2.#3.#4 : #1 major version; #2 student release version; #3 production fix version (normally 0 ); 
   #4 SVN revision number: 
      - may be a range separated by ':' if the working copy contains mixed revisions (e.g. "163:165")
      - ends with an 'M' if the working copy was modified (e.g. "163M")
      - for other (rare) values, see the output of the command 'svnversion --help' 
-}