{-# OPTIONS_GHC -Wall #-}
module Prototype.ConnectToDataBase (connectToDataBase) 
  where
   import Data.List
   import ADL
   import Options
   import Languages
   import ShowADL(showADLcode)
   import Rendering.AdlExplanation (explain,ExplainOutputFormat(..),format)
   import NormalForms (conjNF)
   import Prototype.RelBinGenBasics(phpShow,pDebug)
   import Version (versionbanner)
   import Data.Fspec
   import Prototype.Code

   connectToDataBase :: Fspc -> Options -> String
   connectToDataBase fSpec flags 
    = (intercalate "\n  " 
      ([ "<?php // generated with "++versionbanner
       , "require \"dbsettings.php\";"
       , ""
       , "function display($tbl,$col,$id){"
       , "   return firstRow(firstCol(DB_doquer(\"SELECT DISTINCT `\".$col.\"` FROM `\".$tbl.\"` WHERE `i`='\".addslashes($id).\"'\")));"
       , "}"
       , ""
       , "function stripslashes_deep(&$value) "
       , "{ $value = is_array($value) ? "
       , "           array_map('stripslashes_deep', $value) : "
       , "           stripslashes($value); "
       , "    return $value; "
       , "} "
       , "if((function_exists(\"get_magic_quotes_gpc\") && get_magic_quotes_gpc()) "
       , "    || (ini_get('magic_quotes_sybase') && (strtolower(ini_get('magic_quotes_sybase'))!=\"off\")) ){ "
       , "    stripslashes_deep($_GET); "
       , "    stripslashes_deep($_POST); "
       , "    stripslashes_deep($_REQUEST); "
       , "    stripslashes_deep($_COOKIE); "
       , "} "
       , "$DB_slct = mysql_select_db('"++dbName flags++"',$DB_link);"
       , "function firstRow($rows){ return $rows[0]; }"
       , "function firstCol($rows){ foreach ($rows as $i=>&$v) $v=$v[0]; return $rows; }"
       , "function DB_debug($txt,$lvl=0){"
       , "  global $DB_debug;"
       , "  if($lvl<=$DB_debug) {"
       , "    echo \"<i title=\\\"debug level $lvl\\\">$txt</i>\\n<P />\\n\";"
       , "    return true;"
       , "  }else return false;"
       , "}"
       , ""
       , "$DB_errs = array();"
       {- -- code below (or something similar) will be generated by headers
       , "function addLookup(&$var,$val){"
       , "  if(!isset($var)) $var=array();"
       , "  $var[]=$val;"
       , "}"
       , "function addLookups(&$var,$vals){"
       , "  if(!isset($var)) $var=array();"
       , "  foreach($vals as $val) $var[]=$val;"
       , "}"
       , "function DB_doquer_lookups($quer,$debug=5){"
       , "  $r=DB_doquer($quer,$debug);"
       , "  $lookup=array();"
       , "  foreach($r as $v){"
       , "    addLookup($lookup[$v[0]],$v[1]);"
       , "  }"
       , "  return $lookup;"
       , "}"
       -}
       , ""
       , "// wrapper function for MySQL"
       , "function DB_doquer($quer,$debug=5)"
       , "{"
       , "  global $DB_link,$DB_errs;"
       , "  DB_debug($quer,$debug);"
       , "  $result=mysql_query($quer,$DB_link);"
       , "  if(!$result){"
       , "    DB_debug('Error '.($ernr=mysql_errno($DB_link)).' in query \"'.$quer.'\": '.mysql_error(),2);"
       , "    $DB_errs[]='Error '.($ernr=mysql_errno($DB_link)).' in query \"'.$quer.'\"';"
       , "    return false;"
       , "  }"
       , "  if($result===true) return true; // succes.. but no contents.."
       , "  $rows=Array();"
       , "  while (($row = @mysql_fetch_array($result))!==false) {"
       , "    $rows[]=$row;"
       , "    unset($row);"
       , "  }"
       , "  return $rows;"
       , "}"
       , "function DB_plainquer($quer,&$errno,$debug=5)"
       , "{"
       , "  global $DB_link,$DB_errs,$DB_lastquer;"
       , "  $DB_lastquer=$quer;"
       , "  DB_debug($quer,$debug);"
       , "  $result=mysql_query($quer,$DB_link);"
       , "  if(!$result){"
       , "    $errno=mysql_errno($DB_link);"
       , "    return false;"
       , "  }else{"
       , "    if(($p=stripos($quer,'INSERT'))!==false"
       , "       && (($q=stripos($quer,'UPDATE'))==false || $p<$q)"
       , "       && (($q=stripos($quer,'DELETE'))==false || $p<$q)"
       , "      )"
       , "    {"
       , "      return mysql_insert_id();"
       , "    } else return mysql_affected_rows();"
       , "  }"
       , "}"
       , ""
       ] ++ (ruleFunctions flags fSpec)
       ++
       [ ""
       , "if($DB_debug>=3){"
       ] ++
          [ "  checkRule"++show (runum r)++"();"
          | r<-rules fSpec ] ++
       [ "}"
       ]
      )) ++ "\n?>"
   
   
   
   ruleFunctions :: Options -> Fspc -> [String]
   ruleFunctions flags fSpec
    = showCodeHeaders 
       ([ (code rule')
        | rule<-rules fSpec, rule'<-[(conjNF . Cpx . normExpr) rule]
        ])
      ++
      [ "\n  function checkRule"++show (runum rule)++"(){\n    "++
           (if isFalse rule'
            then "// "++(langwords!!2)++": "++showADLcode fSpec rule++"\n     "
            else "// "++(langwords!!3)++" ("++showADLcode fSpec rule++")\n    "++
                 concat [ "//            rule':: "++(showADLcode fSpec rule') ++"\n    " | pDebug] ++
                   showCode 4 (code rule')
                 ++
                 "if(count($v)) {\n    "++
                 "  DB_debug("++dbError rule++",3);\n    "++
                 "  return false;\n    }"
           ) ++ "return true;\n  }"
         | rule<-rules fSpec, rule'<-[(conjNF . Cpx . normExpr) rule]]
      where
       code :: Expression (Relation Concept) -> [Statement]
       code r = case (getCodeFor fSpec [] [codeVariableForBinary "v" r]) of
                 Nothing -> error "!Fatal (module ConnectToDataBase 144): No codes returned"
                 Just x  -> x
       dbError rule
        = phpShow((langwords!!0)++" ("++show (source rule)++" ")++".$v[0][0]."++phpShow(","++show (target rule)++" ")++".$v[0][1]."++
          phpShow(")\n"++(langwords!!1)++": \""++format PlainText (explain fSpec flags rule)++"\"<BR>")++"" 
       langwords :: [String]
       langwords
        = case language flags of
           Dutch   -> ["Overtreding","reden","Tautologie","Overtredingen horen niet voor te komen in"]
           English -> ["Violation", "reason","Tautology","No violations should occur in"]
