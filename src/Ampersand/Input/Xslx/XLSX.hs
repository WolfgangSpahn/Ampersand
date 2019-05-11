{-# LANGUAGE OverloadedStrings, DuplicateRecordFields,OverloadedLabels #-}
module Ampersand.Input.Xslx.XLSX 
  (parseXlsxFile)
where
import           Ampersand.ADL1
import           Ampersand.Basics
import           Ampersand.Input.ADL1.CtxError
import           Ampersand.Misc
import           Ampersand.Prototype.StaticFiles_Generated (getStaticFileContent, FileKind)
import           Codec.Xlsx
import           Control.Lens
import qualified Data.List as L
import qualified Data.ByteString.Lazy as BL
import           Data.Char
import qualified Data.Map as M 
import           Data.Maybe
import           Data.String
import qualified Data.Text as T
import           Data.Tuple

parseXlsxFile :: Options 
              -> Maybe FileKind
              -> FilePath -> IO (Guarded [P_Population])
parseXlsxFile opts mFk file =
  do bytestr <- 
        case mFk of
          Just fileKind 
             -> case getStaticFileContent fileKind file of
                      Just cont -> return $ fromString cont
                      Nothing -> fatal ("Statically included "++ show fileKind++ " files. \n  Cannot find `"++file++"`.")
          Nothing
             -> BL.readFile file
     return . xlsx2pContext . toXlsx $ bytestr
 where
  xlsx2pContext :: Xlsx -> Guarded [P_Population]
  xlsx2pContext xlsx = Checked pop []
    where 
      pop = concatMap (toPops opts file)
          . concatMap theSheetCellsForTable 
          $ (xlsx ^. xlSheets)

data SheetCellsForTable 
       = Mapping{ theSheetName :: String
                , theCellMap   :: CellMap
                , headerRowNrs :: [Int]
                , popRowNrs    :: [Int]
                , colNrs       :: [Int]
                , debugInfo :: [String]
                }
instance Show SheetCellsForTable where  --for debugging only
  show x 
   = unlines $
      [ "Sheet       : "++theSheetName x
      , "headerRowNrs: "++show (headerRowNrs x)
      , "popRowNrs   : "++show (popRowNrs x)
      , "colNrs      : "++show (colNrs x)
      ] ++ debugInfo x 
toPops :: Options -> FilePath -> SheetCellsForTable -> [P_Population]
toPops opts file x = map popForColumn (colNrs x)
  where
    popForColumn :: Int -> P_Population
    popForColumn i =
      if i  == sourceCol  
      then  P_CptPopu { pos = popOrigin
                      , p_cnme = sourceConceptName 
                      , p_popas = concat [ case value(row,i) of
                                             Nothing -> []
                                             Just cv -> cellToAtomValues mSourceConceptDelimiter cv popOrigin
                                         | row <- popRowNrs x
                                         ] 
                      }
      else  P_RelPopu { pos = popOrigin
                      , p_src = src
                      , p_tgt = trg
                      , p_nmdr = PNamedRel popOrigin relName Nothing -- The P-to-A converter must assign the type.
                      , p_popps = thePairs
                      }
     where                             
       src, trg :: Maybe String
       (src,trg) = case mTargetConceptName of
                  Just tCptName -> (if isFlipped' then swap else id) (Just sourceConceptName, Just tCptName)
                  Nothing -> (Nothing,Nothing)
          
       popOrigin :: Origin
       popOrigin = originOfCell (relNamesRow, targetCol)
       conceptNamesRow = head . tail $ headerRowNrs x
       relNamesRow     = head $ headerRowNrs x
       sourceCol       = head $ colNrs x
       targetCol       = i 
       sourceConceptName :: String
       mSourceConceptDelimiter :: Maybe Char
       (sourceConceptName, mSourceConceptDelimiter)
          = case value (conceptNamesRow,sourceCol) of
                Just (CellText t) -> 
                   fromMaybe (fatal "No valid source conceptname found. This should have been checked before")
                             (conceptNameWithOptionalDelimiter . trim $ t)
                _ -> fatal "No valid source conceptname found. This should have been checked before"
       mTargetConceptName :: Maybe String
       mTargetConceptDelimiter :: Maybe Char
       (mTargetConceptName, mTargetConceptDelimiter)
          = case value (conceptNamesRow,targetCol) of
                Just (CellText t) -> let (nm,mDel) 
                                           = fromMaybe
                                                (fatal "No valid source conceptname found. This should have been checked before")
                                                (conceptNameWithOptionalDelimiter . trim $ t)
                                     in (Just nm, mDel)
                _ -> (Nothing, Nothing)
       relName :: String
       isFlipped' :: Bool
       (relName,isFlipped') 
          = case value (relNamesRow,targetCol) of
                Just (CellText t) -> 
                    let str = T.unpack . trim $ t
                    in if last str == '~'
                       then (init str, True )
                       else (     str, False)
                _ -> fatal ("No valid relation name found. This should have been checked before" ++show (relNamesRow,targetCol))
       thePairs :: [PAtomPair]
       thePairs =  concat . mapMaybe pairsAtRow . popRowNrs $ x
       pairsAtRow :: Int -> Maybe [PAtomPair]
       pairsAtRow r = case (value (r,sourceCol)
                          ,value (r,targetCol)
                          ) of
                       (Just s,Just t) -> Just $ 
                                            (if isFlipped' then map flp else id)
                                                [mkPair origTrg s' t'
                                                | s' <- cellToAtomValues mSourceConceptDelimiter s origSrc
                                                , t' <- cellToAtomValues mTargetConceptDelimiter t origTrg
                                                ]
                       _               -> Nothing
            where origSrc = XLSXLoc file (theSheetName x) (r,sourceCol)
                  origTrg = XLSXLoc file (theSheetName x) (r,targetCol)
       cellToAtomValues :: Maybe Char -> CellValue -> Origin -> [PAtomValue]  -- The value in a cell can contain the delimeter of the row
       cellToAtomValues mDelimiter cv orig
         = case cv of
             CellText t   -> map (XlsxString orig . T.unpack) 
                           . filter (not . T.null)
                           . unDelimit mDelimiter 
                           . handleSpaces $ t
             CellDouble d -> [XlsxDouble orig d]
             CellBool b -> [ComnBool orig b] 
             CellRich ts -> map (XlsxString orig . T.unpack) 
                          . filter (not . T.null)
                          . unDelimit mDelimiter 
                          . handleSpaces . T.concat . map _richTextRunText $ ts
             CellError e -> fatal . L.intercalate "\n  " $
                                    [ "Error reading cell at:"
                                    , show orig
                                    , show e]
       unDelimit :: Maybe Char -> T.Text -> [T.Text]
       unDelimit mDelimiter xs = 
         case mDelimiter of
           Nothing -> [xs]
           (Just delimiter) -> map trim $ T.split (== delimiter) xs
       handleSpaces = if trimXLSXCells opts then trim else id     
    originOfCell :: (Int,Int) -- (row number,col number)
                 -> Origin
    originOfCell (r,c) 
      = XLSXLoc file (theSheetName x) (r,c) 

    value :: (Int,Int) -> Maybe CellValue
    value k = theCellMap x ^? ix k . cellValue . _Just


theSheetCellsForTable :: (T.Text,Worksheet) -> [SheetCellsForTable]
theSheetCellsForTable (sheetName,ws) 
  =  catMaybes [theMapping i | i <- [0..length tableStarters - 1]]
  where
    tableStarters :: [(Int,Int)]
    tableStarters = filter isStartOfTable $ M.keys (ws  ^. wsCells)  
      where isStartOfTable :: (Int,Int) -> Bool
            isStartOfTable (rowNr,colNr)
              | colNr /= 1 = False
              | rowNr == 1 = isBracketed (rowNr,colNr) 
              | otherwise  =           isBracketed  (rowNr     ,colNr)  
                             && (not . isBracketed) (rowNr - 1, colNr)             
              
    value :: (Int,Int) -> Maybe CellValue
    value k = (ws  ^. wsCells) ^? ix k . cellValue . _Just
    isBracketed :: (Int,Int) -> Bool
    isBracketed k = 
       case value k of
         Just (CellText t) -> (not . T.null ) trimmed && T.head trimmed == '[' && T.last trimmed == ']'
               where trimmed = trim t
         _                 -> False      
    theMapping :: Int -> Maybe SheetCellsForTable
    theMapping indexInTableStarters 
     | length okHeaderRows /= nrOfHeaderRows = Nothing  -- Because there are not enough header rows
     | otherwise
     =  Just Mapping { theSheetName = T.unpack sheetName
                     , theCellMap   = ws  ^. wsCells
                     , headerRowNrs = okHeaderRows
                     , popRowNrs    = populationRows
                     , colNrs       = theCols
                     , debugInfo = [ "indexInTableStarters"++": "++show indexInTableStarters
                                   , "maxRowOfWorksheet"++": "++show maxRowOfWorksheet
                                   , "maxColOfWorksheet"++": "++show maxColOfWorksheet
                                   , "startOfTable     "++": "++show startOfTable
                                   , "firstPopRowNr    "++": "++show firstPopRowNr
                                   , "lastPopRowNr     "++": "++show lastPopRowNr
                                   , "[(row,isProperRow)] "++": "++concatMap show [(r,isProperRow r) | r<- [firstPopRowNr..lastPopRowNr]]
                                   , "theCols          "++": "++show theCols
                                   ] 
                     }
     where
       startOfTable = tableStarters !! indexInTableStarters 
       firstHeaderRowNr = fst startOfTable
       firstColumNr = snd startOfTable
       relationNameRowNr = firstHeaderRowNr
       conceptNameRowNr  = firstHeaderRowNr+1
       nrOfHeaderRows = 2
       maxRowOfWorksheet = maximum (map fst (M.keys (ws  ^. wsCells)))
       maxColOfWorksheet = maximum (map snd (M.keys (ws  ^. wsCells)))
       firstPopRowNr = firstHeaderRowNr + nrOfHeaderRows
       lastPopRowNr = ((map fst tableStarters++[maxRowOfWorksheet+1])!!(indexInTableStarters+1))-1
       okHeaderRows = filter isProperRow [firstHeaderRowNr,firstHeaderRowNr+nrOfHeaderRows-1]
       populationRows = filter isProperRow [firstPopRowNr..lastPopRowNr]
       isProperRow :: Int -> Bool
       isProperRow rowNr
          | rowNr == relationNameRowNr = True -- The first row was recognized as tableStarter
          | rowNr == conceptNameRowNr  = isProperConceptName(rowNr,firstColumNr)
          | otherwise                  = notEmpty (rowNr,firstColumNr)
       notEmpty k
          = case value k of
            Just (CellText t)   -> (not . T.null . trim) t
            Just (CellDouble _) -> True
            Just (CellBool _)   -> True
            Just (CellRich _)   -> True
            Just (CellError e)  -> fatal $ "Error reading cell "++show e
            Nothing -> False
       theCols = filter isProperCol [1..maxColOfWorksheet]
       isProperCol :: Int -> Bool
       isProperCol colNr
          | colNr == 1 = isProperConceptName (conceptNameRowNr,colNr)
          | otherwise  = isProperConceptName (conceptNameRowNr,colNr) && isProperRelName(relationNameRowNr,colNr)
       isProperConceptName k 
         = case value k of
            Just (CellText t) -> isJust . conceptNameWithOptionalDelimiter . trim $ t
            _ -> False
       isProperRelName k 
         = case value k of
            Just (CellText t) -> (not . T.null . trim) t -- && (isLower . T.head . trim) t
            _ -> False
               
conceptNameWithOptionalDelimiter :: T.Text -> Maybe ( String     {- Conceptname -} 
                                                    , Maybe Char {- Delimiter   -}
                                             )
-- Cases:  1) "[" ++ Conceptname ++ delimiter ++ "]"
--         2) Conceptname
--         3) none of above
--  Where Conceptname is any string starting with an uppercase character
conceptNameWithOptionalDelimiter t
  | T.null t = Nothing
  | T.head t == '[' && T.last t == ']'
             = let mid = (T.reverse . T.tail . T.reverse . T.tail) t
                   (nm,d) = (T.init mid, T.last mid)
               in if isDelimiter d && isConceptName nm
                  then Just (T.unpack nm , Just d)
                  else Nothing
  | otherwise = if isConceptName t
                then Just (T.unpack t, Nothing)
                else Nothing
           
isDelimiter :: Char -> Bool
isDelimiter = isPunctuation
isConceptName :: T.Text -> Bool
isConceptName t = case T.uncons t of
                    Nothing  -> False
                    (Just (h,_)) -> isUpper h

-- | trim is used to remove leading and trailing spaces
trim :: T.Text -> T.Text
trim = T.reverse . trim' . T.reverse . trim'
  where 
    trim' :: T.Text -> T.Text
    trim' t = case uncons t of
               Just (' ',t') -> trim' t'
               _  -> t 
