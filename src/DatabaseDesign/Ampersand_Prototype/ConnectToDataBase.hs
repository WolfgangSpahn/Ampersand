{-# OPTIONS_GHC -Wall #-}
module DatabaseDesign.Ampersand_Prototype.ConnectToDataBase
 (connectToDataBase) 
where
 import Data.List
 import DatabaseDesign.Ampersand_Prototype.CoreImporter
 import DatabaseDesign.Ampersand_Prototype.Code
 import DatabaseDesign.Ampersand_Prototype.RelBinGenBasics(phpIdentifier,phpShow,pDebug)
 import DatabaseDesign.Ampersand_Prototype.RelBinGenSQL    (InPlug(..),showsql,SqlSelect(..))
 import DatabaseDesign.Ampersand_Prototype.Version 

 fatal :: Int -> String -> a
 fatal = fatalMsg "ConnectToDataBase"

 connectToDataBase :: Fspc -> Options -> String
 connectToDataBase fSpec flags 
    = (intercalate "\n  " 
      ([ "<?php // generated with "++prototypeVersionStr
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
       ] 
       ++ (ruleFunctions flags fSpec)
       ++
       [ ""
       , "//if($DB_debug>=3){"
       , "function checkRules(){"
       , "  return" 
             ++(intercalate " &" --REMARK -> bitwise AND to get all violations on all rules 
                [ " "++phpIdentifier("checkRule"++name r)++"()" | r<-invariants fSpec ])
             ++ ";"
       , "}"
       ]
      )) ++ "\n?>"
   
   
 ruleFunctions :: Options -> Fspc -> [String]
 ruleFunctions flags fSpec
    = showCodeHeaders 
       ([ (code rule')
        | rule<-invariants fSpec, rule'<-[(conjNF . ECpl . rrexp {- . normExpr -}) rule]
        ])
      ++ 
      [ "\n  function " ++ phpIdentifier("checkRule"++name rule)++"(){\n    "++
           (if isFalse rule'
            then "// "++(langwords!!2)++": "++ showADL rule'++"\n     "
            else "// "++(langwords!!3)++" ("++ showADL rule'++")\n    "++
                 concat [ "//            rule':: "++showADL rule' ++"\n    " | pDebug] ++
                   "\n    $v = DB_doquer_lookups('"++ showsql(SqlSel2(selectbinary fSpec rule'))++"');\n"
                   -- ++ showCode 4 (code rule')
                 ++
                 "if(count($v)) {\n    "++
                 "  foreach($v as $viol){\n" ++
                 "     if (count($viol)==1){$vs=$viol[0];$vt=$viol[0];}\n" ++ --an homogeneous violation
                 "     else                {$vs=$viol[0];$vt=$viol[1];}\n" ++
                 "  DB_debug("++dbError rule++",3);\n"++
                 "  }\n" ++
                 "  return false;\n    }"
           )
           ++ "return true;\n  }"
         | rule<-invariants fSpec, rule'<-[(conjNF . ECpl . rrexp {- . normExpr -}) rule]]
      where
       code :: Expression -> [Statement]
       code r = case (getCodeFor fSpec [] [codeVariableForBinary "v" r]) of
                 Nothing -> fatal 139 "No codes returned"
                 Just x  -> x
       dbError rule
        = phpShow((langwords!!0)++" ("++show (source rule)++" ")++".$vs."++phpShow(","++show (target rule)++" ")++".$vt."++
          phpShow(")\n"++(langwords!!1)++": \""++head ([aMarkup2String  (meaning (language flags) rule)]++[""])++"\"<BR>")++"" 
       langwords :: [String]
       langwords
        = case language flags of
           Dutch   -> ["Overtreding","reden","Tautologie","Overtredingen horen niet voor te komen in"]
           English -> ["Violation", "reason","Tautology","No violations should occur in"]
