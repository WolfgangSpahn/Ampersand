{-# OPTIONS_GHC -Wall #-}
module Prototype.ContextGen where
  import ADL
  import Data.List
  import Data.Fspec
  import Version (versionbanner)
   
  contextGen :: Fspc -> String
  contextGen fspc = "<?php\n  " ++ intercalate "\n  "
     (
        [ "// "++name fspc++".php"
        , "// Generated with "++ versionbanner
        , "// Prototype interface design by Milan van Bruggen and Sebastiaan J.C. Joosten"
        , ""
        , ""
        , "error_reporting(E_ALL); "
        , "ini_set(\"display_errors\", 1);"
        , ""
        , "$content = $_REQUEST['content'];"
        , "$ctxenv = array(" ++ 
           (if name fspc=="Atlas" then "'User'=>$_REQUEST['User'], 'Script'=>$_REQUEST['Script']" else [])
           ++ ");"
        , "include \"$content.php\"; "
        , ""
        , "?>"])
