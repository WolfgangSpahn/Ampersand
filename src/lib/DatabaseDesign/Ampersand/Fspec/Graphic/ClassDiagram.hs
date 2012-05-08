{-# OPTIONS_GHC -Wall #-}
--TODO -> clean and stuff. Among which moving classdiagram2dot to Graphviz library implementation (see Classes/Graphics.hs).
--        I only helped it on its feet and I have put in the fSpec, now it generates stuff. I like stuff :)

module DatabaseDesign.Ampersand.Fspec.Graphic.ClassDiagram
         (ClassDiag(..), Class(..), Attribute(..), Association(..), Aggregation(..), Generalization(..), Deleting(..), Method(..),
          Multiplicities(..), MinValue(..), MaxValue(..),
          clAnalysis, plugs2classdiagram, cdAnalysis, classdiagram2dot)
where
   import Data.List
   import DatabaseDesign.Ampersand.Basics
   import DatabaseDesign.Ampersand.Classes
   import DatabaseDesign.Ampersand.ADL1  hiding (Association,Box)
   import DatabaseDesign.Ampersand.Fspec.Plug
   import DatabaseDesign.Ampersand.Misc
   import DatabaseDesign.Ampersand.Fspec.Fspec
   import Data.String
   import Data.GraphViz.Types.Canonical hiding (attrs)
   import Data.GraphViz.Attributes.Complete hiding (Attribute)
   import Data.GraphViz.Attributes hiding (Attribute)
   
   fatal :: Int -> String -> a
   fatal = fatalMsg "Fspec.Graphic.ClassDiagram"

   class CdNode a where
    nodes :: a->[String]


   instance CdNode ClassDiag where
    nodes (OOclassdiagram cs as rs gs _) = nub (concat (map nodes cs++map nodes as++map nodes rs++map nodes gs))

   instance CdNode Class where
    nodes (OOClass c _ _) = [c]
   instance CdNode a => CdNode [a] where
    nodes = concatMap nodes

   instance CdNode Attribute where
    nodes (OOAttr _ t _) = [t]

   instance CdNode Method where
    nodes _ = []

   instance CdNode Association where
    nodes (OOAssoc s _ _ t _ _) = [s,t]

   instance CdNode Aggregation where
    nodes (OOAggr _ s t) = [s,t]

   instance CdNode Generalization where
    nodes (OOGener g ss) = g:ss

-- The following function, clAnalysis, makes a classification diagram.
-- It focuses on generalizations and specializations.
   clAnalysis :: Fspc -> Options -> Maybe ClassDiag
   clAnalysis fSpec _ = if null classes' then Nothing else Just (OOclassdiagram classes' [] [] geners' ("classification"++name fSpec, concs fSpec))
    where
-- The following code was inspired on ADL2Plug
-- The first step is to determine which entities to generate.
-- All concepts and relations mentioned in exclusions are excluded from the process.
       rels       = [ERel (makeRelation rel) | rel@Sgn{} <- declarations fSpec, decusr rel, not (isIdent rel)]
       relsAtts   = [r | e<-rels, r<-[e, flp e], isUni r]
       cpts       = nub [ c
                        | gs<-fsisa fSpec
                        , let c=fst gs -- select only those generalisations whose specific concept is part of the themes to be printed.
                        , null (themes fSpec) || c `elem` (concs [mors pat | pat<-patterns fSpec, name pat `elem` themes fSpec ] `uni`  -- restrict to those themes that must be printed.
                                                           concs [mors (fpProc prc) | prc<-vprocesses fSpec, name prc `elem` themes fSpec ])
                        , (not.null) [ r | r<-relsAtts, source r==c ] ||  -- c is either a concept that has attributes or
                               null  [ r | r<-relsAtts, target r==c ]     --      it does not occur as an attribute.
                        ]
       geners'    = nub [ OOGener (name c) (map (name.snd) gs)
                        | gs<-eqCl fst (fsisa fSpec)
                        , let c=fst (head gs), c `elem` cpts -- select only those generalisations whose specific concept is part of the themes to be printed.
                        ]
       classes'   = [ OOClass (name c) (attrs c) []
                    | c<-cpts]
       attrs c    = [ OOAttr (fldname fld) (if isPropty fld then "Bool" else  name (target (fldexpr fld))) (fldnull fld)
                    | plug<-lookup' c, fld<-tail (tblfields plug), not (inKernel fld), source (fldexpr fld)==c]
                    where inKernel fld = null([Uni,Inj,Sur]>-multiplicities (fldexpr fld)) && not (isPropty fld)
       lookup' c = [p |InternalPlug p@(TblSQL{})<-plugInfos fSpec , (c',_)<-cLkpTbl p, c'==c]
       isPropty fld = null([Sym,Asy]>-multiplicities (fldexpr fld))
        
-- The following function, plugs2classdiagram, is useful to make a technical data model.
-- It draws on the plugs, which are meant to implement database tables for OLTP purposes.
-- Plugs come in three flavours: TblSQL, which is an entity (class),
--                               BinSQL, which is a relation between entities, and
--                               ScalarSQL, which represents scalars.
   plugs2classdiagram :: Fspc -> Options -> ClassDiag
   plugs2classdiagram fSpec _ = OOclassdiagram classes' assocs' aggrs' geners' (name fSpec, concs fSpec)
    where
-- The condition for becoming a class is in the function isClass. Does this correspond with the distinction TblSQL and BinSQL?
       isClass  :: PlugSQL -> Bool
       isClass  p = (not.null) [fld |fld<-tblfields p, flduniq fld] &&      -- an assocciation does not have fields that are flduniq
                    (not.null) [fld |fld<-tblfields p, not (flduniq fld)]   -- a scalar has only fields that are flduniq
       classes'   = [ OOClass (name (concept plug)) [ OOAttr a atype fNull | (a,atype,fNull)<-attrs plug] [] -- drop the I field.
                    | InternalPlug plug <- plugInfos fSpec, isClass plug
                    , not (null (attrs plug))
                    ]
       assocs'    = [ OOAssoc (nm source s) (mults $ EFlp rel) "" (nm target t) (mults rel) relname
                    | InternalPlug plug@(BinSQL{}) <-plugInfos fSpec
                    , let rel=mLkp plug
                    , not ((isSignal.head.mors) rel)
                    , let relname=case rel of
                           ERel r -> name r
                           EFlp (ERel r) -> name r
                           _ -> fatal 109 (show rel ++ " has no name.")
                    , let (s,t)=columns plug
                    ]
                    where
                     mults r = let minVal = if isTot r then MinOne else MinZero
                                   maxVal = if isInj r then MaxOne else MaxMany
                               in  Mult minVal maxVal 
                     nm f = name.concept.lookup'.f.fldexpr
       aggrs'     = []
       geners'    = []
       -- The attributes are shown without the key-attributes. Hence the first attribute (key of this concept) and
       -- the keys of its subtypes (filtered by 'inKernel') are not shown.
       attrs plug = [ if isPropty fld
                      then (fldname fld, "Bool",                      False      )
                      else (fldname fld, name (target (fldexpr fld)), fldnull fld)
                    | fld<-tail (tblfields plug), not (inKernel fld)]
                    where isPropty fld = null([Sym,Asy]>-multiplicities (fldexpr fld))
                    -- TODO: (SJ) I'm not sure if inKernel is correct. Check with Bas.
                          inKernel fld = null([Uni,Inj,Sur]>-multiplicities (fldexpr fld)) && not (isPropty fld)
       lookup' c = if null ps
                   then fatal 112 $ "erroneous lookup for concept "++name c++" in plug list"
                   else head ps
                   where ps = [p |InternalPlug p<-plugInfos fSpec, case p of ScalarSQL{} -> c==cLkp p; _ -> c `elem` [c' |(c',_)<-cLkpTbl p, c'==c]]

-- The following function, cdAnalysis, generates a conceptual data model.
-- It creates a class diagram in which generalizations and specializations remain distinct entities.
-- This yields more classes than plugs2classdiagram does, as plugs contain their specialized concepts.
-- Properties and identities are not shown.
   cdAnalysis :: Fspc -> Options -> ClassDiag
   cdAnalysis fSpec _ = OOclassdiagram classes' assocs' aggrs' geners' (name fSpec, concs fSpec)
    where
       classes'   = let cls=eqClass (==) assRels in
                    if length cls /= length assRels
                    then fatal 125 (show [map show cl | cl<-cls, length cl>1])
                    else [ OOClass (name c) (attrs cl) []
                         | cl<-eqCl source attRels, let c=source (head cl)
                         , c `elem` (map source assRels `uni` map target assRels)]
       assocs'    = [ OOAssoc (name (source r)) (mults $ EFlp r) "" (name (target r)) (mults r) ((name.head.morlist) r)
                    | r<-assRels]
                    where
                     mults r = let minVal = if isTot r then MinOne else MinZero
                                   maxVal = if isInj r then MaxOne else MaxMany
                               in  Mult minVal maxVal 
       aggrs'     = []
       geners'    = []
-- The following code was inspired on ADL2Plug
-- The first step is to determine which entities to generate.
-- All concepts and relations mentioned in exclusions are excluded from the process.
       rels       = [ERel (makeRelation rel) | rel@Sgn{} <- declarations fSpec, decusr rel, not (isIdent rel)]
       relsLim    = [ERel (makeRelation rel)           -- The set of relations that is defined in patterns to be printed.
                    | rel@Sgn{} <- declarations fSpec
                    , null (themes fSpec) || decpat rel `elem` themes fSpec   -- restrict to those themes that must be printed.
                    , decusr rel, not (isIdent rel)]
-- In order to make classes, all relations that are univalent and injective are flipped
-- attRels contains all relations that occur as attributes in classes.
       attRels    = [r |r<-rels, isUni r, not (isInj r)]        ++[EFlp r |r<-rels, not (isUni r), isInj r] ++
                    [r |r<-rels, isUni r,      isInj r, isSur r]++[EFlp r |r<-rels,      isUni r , isInj r, not (isSur r)]
-- assRels contains all relations that do not occur as attributes in classes
       assRels    = [r |r<-relsLim, not (isUni r), not (isInj r)]
       attrs rs   = [ OOAttr ((name.head.morlist) r) (name (target r)) (not(isTot r))
                    | r<-rs, not (isPropty r)]
       isPropty r = null([Sym,Asy]>-multiplicities r)

   classdiagram2dot :: Options -> ClassDiag -> DotGraph String
   classdiagram2dot flags cd
    = DotGraph { strictGraph   = False
               , directedGraph = True
               , graphID       = Nothing
               , graphStatements = dotstmts
               }
        where
         dotstmts = DotStmts
           { attrStmts =  [ GraphAttrs [ RankDir FromLeft
                                       , bgColor White]
                          ]
                   --    ++ [NodeAttrs  [ ]]
                       ++ [EdgeAttrs  [ FontSize 11
                                      , MinLen 4
                          ]           ]
           , subGraphs = []
           , nodeStmts = allNodes (classes cd) (nodes cd >- nodes (classes cd))
           , edgeStmts = (map association2edge (assocs cd))  ++
                         (map aggregation2edge (aggrs cd))  ++
                         (concatMap generalization2edges (geners cd))
           }
        
        
          where
          allNodes :: [Class] -> [String] -> [DotNode String]
          allNodes cs others = 
             map class2node cs ++ 
             map nonClass2node others
          
          class2node :: Class -> DotNode String
          class2node cl = DotNode 
            { nodeID         = name cl
            , nodeAttributes = [ Shape PlainText
                               , Color [(X11Color Purple)]
                               , Label (HtmlLabel (HtmlTable htmlTable))
                               ]
            } where 
             htmlTable = HTable { tableFontAttrs = Nothing
                                , tableAttrs     = [ HtmlBGColor (X11Color White)
                                                   , HtmlColor (X11Color Black) -- the color used for all cellborders
                                                   , HtmlBorder 0  -- 0 = no border
                                                   , HtmlCellBorder 1  
                                                   , HtmlCellSpacing 0
                                                   ]
                                , tableRows      = [ HtmlRow -- Header row, containing the name of the class
                                                      [ HtmlLabelCell 
                                                            [ HtmlBGColor (X11Color Gray10)
                                                            , HtmlColor   (X11Color Black)
                                                            ]
                                                            (HtmlText [ HtmlFont [ HtmlColor   (X11Color White)
                                                                                 ]                                                            
                                                                                 [HtmlStr (fromString (name cl))]
                                                                      ]
                                                            )
                                                      ]
                                                   ]++ 
                                                   map attrib2row (clAtts cl) ++
                                                   map method2row (clMths cl) 
                                                   
                                                   
                                } 
                 where
                   attrib2row a = HtmlRow
                                    [ HtmlLabelCell [ HtmlAlign HLeft] 
                                         ( HtmlText [ HtmlStr (fromString (if attOptional a then "o " else "+ "))
                                                    , HtmlStr (fromString (name a))
                                                    , HtmlStr (fromString " : ")
                                                    , HtmlStr (fromString (attTyp a))
                                                    ]
                                         ) 
                                    ]
                   method2row m = HtmlRow
                                    [ HtmlLabelCell [ HtmlAlign HLeft] 
                                         ( HtmlText [ HtmlStr (fromString "+ ")
                                                    , HtmlStr (fromString (show m))
                                                    ]
                                         ) 
                                    ]
                    
          nonClass2node :: String -> DotNode String
          nonClass2node str = DotNode { nodeID = str
                                      , nodeAttributes = [ Shape Box3D
                                                         , Label (StrLabel (fromString str))
                                                         ]
                                      }
          
  -------------------------------
  --        ASSOCIATIONS:      --
  -------------------------------
          association2edge :: Association -> DotEdge String
          association2edge ass = 
             DotEdge { fromNode       = assSrc ass
                     , toNode         = assTrg ass
                     , edgeAttributes = [ ArrowHead (AType [(ArrMod OpenArrow BothSides, NoArrow)])  -- No arrowHead
                                        , ArrowTail (AType [(ArrMod OpenArrow BothSides, NoArrow)])  -- No arrowTail
                                        , HeadLabel (mult2Lable (assrhm ass))
                                        , TailLabel (mult2Lable (asslhm ass))
                                        , Label     (StrLabel (fromString (assrhr ass)))
                                        , LabelFloat True
                                        ]
                     }
              where
                 mult2Lable = StrLabel . fromString . mult2Str
                 mult2Str (Mult MinZero MaxOne)  = "[0..1]"
                 mult2Str (Mult MinZero MaxMany) = "[0..n]"
                 mult2Str (Mult MinOne  MaxOne)  = "[1..1]"
                 mult2Str (Mult MinOne  MaxMany) = "[1..n]"
                  
  -------------------------------
  --        AGGREGATIONS:      --
  -------------------------------
          aggregation2edge :: Aggregation -> DotEdge String
          aggregation2edge agg =
             DotEdge { fromNode       = aggSrc agg
                     , toNode         = aggTrg agg
                     , edgeAttributes = [ ArrowHead (AType [(ArrMod OpenArrow BothSides, NoArrow)])  -- No arrowHead
                                        , ArrowTail (AType [(ArrMod (case aggDel agg of 
                                                                      Open -> OpenArrow
                                                                      Close -> FilledArrow
                                                                    ) BothSides , Diamond)
                                                           ]) 
                                        ]
                     }
                 
 
 
  -------------------------------
  --        GENERALIZATIONS:   --       -- Ampersand statements such as "GEN Dolphin ISA Animal" are called generalization.
  --                           --       -- Generalizations are represented by a red arrow with a (larger) open triangle as arrowhead 
  -------------------------------
          generalization2edges :: Generalization -> [DotEdge String]
          generalization2edges ooGen = map (sub2edge (genGen ooGen)) (genSubs ooGen)
           where
             sub2edge g s = DotEdge
                              { fromNode = g
                              , toNode   = s
                              , edgeAttributes 
                                         = [ ArrowTail (AType [(ArrMod OpenArrow BothSides, NoArrow)])  -- No arrowTail
                                           , ArrowHead (AType [(ArrMod OpenArrow BothSides, Normal)])   -- Open normal arrowHead
                                           , ArrowSize  2.0
                                           ] ++
                                           ( if blackWhite flags
                                             then [Style [SItem Dashed []]]
                                             else [Color [X11Color Red]]
                                           )
                              }
             



-------------- Class Diagrams ------------------
   data ClassDiag = OOclassdiagram {classes     :: [Class]            --
                                   ,assocs      :: [Association]      --
                                   ,aggrs       :: [Aggregation]      --
                                   ,geners      :: [Generalization]   --
                                   ,nameandcpts :: (String,[A_Concept])}
                            deriving Show
   instance Identified ClassDiag where
      name cd = n
        where (n,_) = nameandcpts cd
        
   data Class          = OOClass  { clNm        :: String      -- ^ name of the class
                                  , clAtts      :: [Attribute] -- ^ Attributes of the class
                                  , clMths      :: [Method]    -- ^ Methods of the class
                                  } deriving Show
   instance Identified Class where
      name = clNm
   data Attribute      = OOAttr   { attNm       :: String      -- ^ name of the attribute
                                  , attTyp      :: String      -- ^ type of the attribute (Concept name or built-in type)
                                  , attOptional :: Bool        -- ^ says whether the attribute is optional
                                  } deriving Show
   instance Identified Attribute where
      name = attNm
   data MinValue = MinZero | MinOne deriving (Show, Eq)
   
   data MaxValue = MaxOne | MaxMany deriving (Show, Eq)
   
   data Multiplicities = Mult MinValue MaxValue deriving Show
   
   data Association    = OOAssoc  { assSrc :: String           -- ^ source: the left hand side class
                                  , asslhm :: Multiplicities   -- ^ left hand side multiplicities
                                  , asslhr :: String           -- ^ left hand side role
                                  , assTrg :: String           -- ^ target: the right hand side class
                                  , assrhm :: Multiplicities   -- ^ right hand side multiplicities
                                  , assrhr :: String           -- ^ right hand side role
                                  }  deriving Show
   data Aggregation    = OOAggr   { aggDel :: Deleting         -- 
                                  , aggSrc :: String           --
                                  , aggTrg :: String           --
                                  } deriving (Show, Eq)
   data Generalization = OOGener  { genGen :: String             --
                                  , genSubs:: [String]           --
                                  } deriving (Show, Eq)



   data Deleting       = Open | Close                      --
                                    deriving (Show, Eq)
   data Method         = OOMethodC      String             -- name of this method, which creates a new object (producing a handle)
                                        [Attribute]        -- list of parameters: attribute names and types
                       | OOMethodR      String             -- name of this method, which yields the attribute values of an object (using a handle).
                                        [Attribute]        -- list of parameters: attribute names and types
                       | OOMethodS      String             -- name of this method, which selects an object using key attributes (producing a handle).
                                        [Attribute]        -- list of parameters: attribute names and types
                       | OOMethodU      String             -- name of this method, which updates an object (using a handle).
                                        [Attribute]        -- list of parameters: attribute names and types
                       | OOMethodD      String             -- name of this method, which deletes an object (using nothing but a handle).
                       | OOMethod       String             -- name of this method, which deletes an object (using nothing but a handle).
                                        [Attribute]        -- list of parameters: attribute names and types
                                        String             -- result: a type

   instance Show Method where
    showsPrec _ (OOMethodC nm cs)  = showString (nm++"("++intercalate "," [ n | OOAttr n _ _<-cs]++"):handle")
    showsPrec _ (OOMethodR nm as)  = showString (nm++"(handle):["++intercalate "," [ n | OOAttr n _ _<-as]++"]")
    showsPrec _ (OOMethodS nm ks)  = showString (nm++"("++intercalate "," [ n | OOAttr n _ _<-ks]++"):handle")
    showsPrec _ (OOMethodD nm)     = showString (nm++"(handle)")
    showsPrec _ (OOMethodU nm cs)  = showString (nm++"(handle,"++intercalate "," [ n | OOAttr n _ _<-cs]++")")
    showsPrec _ (OOMethod nm cs r) = showString (nm++"("++intercalate "," [ n | OOAttr n _ _<-cs]++"): "++r)

--
--   testCD
--    = OOclassdiagram
--      [ OOClass "Plan" [ooAttr "afkomst" "Actor"] []
--      , OOClass "Formulier" [ooAttr "plan" "Plan",ooAttr "van" "Actor",ooAttr "aan" "Actor",ooAttr "sessie" "Sessie"] []
--      , OOClass "Dossier" [ooAttr "eigenaar" "Actor"] []
--      , OOClass "Gegeven" [ooAttr "type" "Gegevenstype",ooAttr "in" "Dossier",ooAttr "veldnaam" "Veldnaam",ooAttr "waarde" "Waarde"] []
--      , OOClass "Veld" [ooAttr "type" "Veldtype",ooAttr "waarde" "Waarde"] []
--      , OOClass "Veldtype" [ooAttr "veldnaam" "Veldnaam",ooAttr "formuliertype" "Plan",ooAttr "gegevenstype" "Gegevenstype"] []
--      , OOClass "Sessie" [ooAttr "dossier" "Dossier",ooAttr "uitgevoerd" "Actor"] []
--      ]
--      [ OOAssoc "Plan" "0..n" "" "Plan" "0..n" "stap"
--      , OOAssoc "Formulier" "0..n" "" "Actor" "0..n" "inzage"
--      , OOAssoc "Formulier" "0..n" "" "Formulier" "0..n" "in"
--      , OOAssoc "Formulier" "0..n" "" "Plan" "0..n" "stap"
--      , OOAssoc "Autorisatie" "0..n" "" "Actor" "0..n" "aan"
--      , OOAssoc "Gegeven" "0..n" "" "Formulier" "0..n" "op"
--      , OOAssoc "Gegeven" "0..n" "" "Actor" "0..n" "inzage"
--      , OOAssoc "Actor" "0..n" "" "Actor" "0..n" "gedeeld"
--      , OOAssoc "Formulier" "0..n" "" "Actor" "0..n" "inzagerecht"
--      , OOAssoc "Gegeven" "0..n" "" "Actor" "0..n" "inzagerecht"
--      , OOAssoc "Autorisatie" "0..n" "" "Gegeven" "0..n" "object"
--      , OOAssoc "Actie" "0..n" "" "Gegeven" "0..n" "object"
--      , OOAssoc "Autorisatie" "0..n" "" "Actie" "0..n" "op"
--      , OOAssoc "Autorisatie" "0..n" "" "Actor" "0..n" "door"
--      , OOAssoc "Actie" "0..n" "" "Actor" "0..n" "door"
--      , OOAssoc "Veld" "0..n" "" "Gegeven" "0..n" "bindt"
--      , OOAssoc "Sessie" "0..1" "" "Actor" "0..1" "actief"
--      , OOAssoc "Formulier" "0..n" "" "Actor" "0..n" "openstaand"
--      , OOAssoc "Gegeven" "0..n" "" "Actor" "0..n" "openstaand"
--      ]
--      [ OOAggr Close "Dossier" "Formulier"
--      , OOAggr Close "Formulier" "Veld"
--      ]
--      []
--      ("NoPat",[])
--      where ooAttr nm t = OOAttr nm t True