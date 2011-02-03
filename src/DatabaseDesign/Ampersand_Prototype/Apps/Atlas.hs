{-# OPTIONS_GHC -Wall -XFlexibleInstances #-}  
--running PHP in IIS on the php.exe of XAMPP requires setting "cgi.force_redirect = 0" in the php.ini
--in IIS you can enable windows authentication
--
--like Installer.php, only assuming that the DATABASE already exists behind the ODBC connection and the namespace doesn't
--TODO -> check namespaces a.k.a. contexts in the Atlas context (Meterkast)
--this connection should be the same as the one in dbsettings.php
--thus:
-- 1) CREATE TABLES (sqlplugs fspec)
-- 2) INSERT INTO TABLES (tblcontents sqlplug)
module DatabaseDesign.Ampersand_Prototype.Apps.Atlas 
   (fillAtlas)
where
import DatabaseDesign.Ampersand
import Database.HDBC.ODBC 
import Database.HDBC
import Data.List  (intercalate)
------
runMany :: (IConnection conn) => conn -> [String] -> IO Integer
runMany _ [] = return 1
runMany conn (x:xs)  = 
   do _ <- run conn x []
      runMany conn xs

placeholders :: [a] -> String
placeholders [] = []
placeholders (_:[]) = "?"
placeholders (_:xs) = "?," ++ placeholders xs

inserts :: (IConnection conn) => conn -> [PlugSQL] -> IO Integer
inserts _ [] = return 1
inserts conn (tbl:tbls) = 
   do stmt<- prepare conn
             ("INSERT INTO "++name tbl++"("++intercalate "," ["`"++fldname f++"` "|f<-tblfields tbl]++")"
                                ++" VALUES ("++placeholders(tblfields tbl)++")")
      executeMany stmt (map (map toSql) (tblcontents tbl))
      inserts conn tbls

creates :: (IConnection conn) => conn -> [PlugSQL] -> IO Integer
creates _ [] = return 1
creates conn (tbl:tbls) = 
   do _ <- run conn stmt []
      creates conn tbls
   where stmt = ("CREATE TABLE "++name tbl
               ++"("++intercalate "," 
                      ([createfld f|f<-tblfields tbl]
                     ++[" UNIQUE KEY (`"++fldname key++"`)"
                       | key <- tblfields tbl, flduniq key, not (fldnull key)]
                     ++[" UNIQUE INDEX (`"++fldname kernelfld++"`)" 
                       | kernelfld <- tblfields tbl, flduniq kernelfld, fldnull kernelfld])
               ++") TYPE=InnoDB DEFAULT CHARACTER SET latin1 COLLATE latin1_bin ")
         createfld fld = "`"++fldname fld++"` " ++ showSQL (fldtype fld) ++ autoIncr fld ++ nul fld
         nul fld = if fldnull fld then "" else " NOT NULL"
         autoIncr fld = if fldauto fld then " AUTO_INCREMENT" else ""
            


----------------------

--Atlas requires an ODBC data source named "atlas" representing the db of an Atlas.adl prototype
--hdbc and hdbc-odbc must be installed (from hackage)
fillAtlas :: Fspc -> Options -> IO()
fillAtlas fSpec flags = 
 if genGraphics flags 
 then do verboseLn flags "Generating pictures for atlas..."
         sequence_ [writePicture flags pict | pict <- picturesForAtlas flags fSpec]
 else do initDatabase flags fSpec
-- Van Han aan Gerard: 
-- Hieronder vind je de code om het plaatje als imagemap te genereren. Dat is nu dus geregeld.
-- Vervolgens moet je er nog voor zorgen dat de imagemap op de juiste manier wordt gebruikt. Daarvoor
-- moet je de gegenereerde php oppoetsen. Ik heb daar geen verstand van. Bas overigens wel, maar jij wellicht ook. 
-- enige informatie hierover staat op http://www.wellho.net/resources/ex.php4?item=h112/imap.php
-- Het enige dat vervolgens geregeld moet worden is dat in DOT de nodes /edges moeten worden voorzien van de juiste URL attribuut. 
-- Dat kan voor jou niet moeilijk zijn. Als je dat regelt, dan vallen alle stukjes op z'n plaats. Succ6! 
--GMI:
--Dank Han!
--TODO -> "include (str_replace('png','map', $v0));" op een nette manier laten genereren op juiste plekken in .php zonder gebruik van str_replace natuurlijk.
--TODO -> .map files zijn nog vrij leeg (geen areas, slechts header/footer)
initDatabase :: Options -> Fspc -> IO() 
initDatabase flags fSpec = 
                 do verboseLn flags "Populating atlas for ..."
                   --connect through ODBC data source "atlas"
                    conn<-connectODBC "DSN=atlas"
                    --TODO handle connection errors
                    --REMARK -> expecting new namespace, thus drop not needed: x <- runMany conn ["DROP TABLE "++name p| InternalPlug p<-plugInfos fSpec]
                    _ <- creates conn [p|InternalPlug p<-plugInfos fSpec]
                    --insert population of this Ampersand script of this user
                    _ <- inserts conn [p|InternalPlug p<-plugInfos fSpec]
                    --end connection
                    commit conn
                    disconnect conn
   where
    pictures = picturesForAtlas flags fSpec

picturesForAtlas :: Options -> Fspc -> [Picture]
picturesForAtlas flags fSpec
   = [makePicture flags fSpec p | p <- patterns fSpec] ++
     [makePicture flags fSpec userRule | userRule <- rules fSpec++signals fSpec, r_usr userRule]++
     [makePicture flags fSpec cpt | cpt <- (concs fSpec)]

----------------------------------------------------

