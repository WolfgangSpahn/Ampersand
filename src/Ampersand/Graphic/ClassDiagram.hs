module Ampersand.Graphic.ClassDiagram
  ( ClassDiag (..),
    Class (..),
    CdAttribute (..),
    Association (..),
    Aggregation (..),
    Generalization (..),
    Deleting (..),
    Method (..),
    Multiplicities (..),
    MinValue (..),
    MaxValue (..),
  )
where

import Ampersand.ADL1
  ( AClassify,
    A_Concept,
    Relation,
  )
import Ampersand.Basics
import qualified RIO.Text as T

data ClassDiag = OOclassdiagram
  { cdName :: !Text,
    -- | name of a subgraph and a list of classes in that subgraph
    groups :: ![(Text, NonEmpty Class)],
    -- | list of classes that do not go in a subgraph
    classes :: ![Class],
    assocs :: ![Association], --
    aggrs :: ![Aggregation], --
    geners :: ![Generalization], --
    ooCpts :: ![A_Concept]
  }
  deriving (Show)

instance Named ClassDiag where
  name = cdName

data Class = OOClass
  { -- | name of the class
    clName :: Text,
    -- | Main concept of the class. (link tables do not have a main concept)
    clcpt :: Maybe A_Concept,
    -- | Attributes of the class
    clAtts :: [CdAttribute],
    -- | Methods of the class
    clMths :: [Method]
  }
  deriving (Show, Eq)

instance Named Class where
  name = clName

data CdAttribute = OOAttr
  { -- | name of the attribute
    attNm :: Text,
    -- | type of the attribute (Concept name or built-in type)
    attTyp :: Text,
    -- | says whether the attribute is optional
    attOptional :: Bool
  }
  deriving (Show, Eq)

instance Named CdAttribute where
  name = attNm

data MinValue = MinZero | MinOne deriving (Show, Eq)

data MaxValue = MaxOne | MaxMany deriving (Show, Eq)

data Multiplicities = Mult MinValue MaxValue deriving (Show)

data Association = OOAssoc
  { -- | source: the name of the source class
    assSrc :: Text,
    -- | the name of the attribute in the source class
    assSrcPort :: Text,
    -- | left hand side properties
    asslhm :: Multiplicities,
    -- | left hand side role
    asslhr :: Text,
    -- | target: the name of the target class
    assTgt :: Text,
    -- | right hand side properties
    assrhm :: Multiplicities,
    -- | right hand side role
    assrhr :: Text,
    -- | the relations that caused this association , if any.
    assmdcl :: Maybe Relation
  }
  deriving (Show)

data Aggregation = OOAggr
  { aggDel :: Deleting, --
    aggChild :: A_Concept, --
    aggParent :: A_Concept --
  }
  deriving (Show, Eq)

newtype Generalization = OOGener
  { genAgen :: AClassify --
  }
  deriving (Show)

data Deleting = Open | Close --
  deriving (Show, Eq)

data Method
  = OOMethodC
      Text -- name of this method, which creates a new object (producing a handle)
      [CdAttribute] -- list of parameters: attribute names and types
  | OOMethodR
      Text -- name of this method, which yields the attribute values of an object (using a handle).
      [CdAttribute] -- list of parameters: attribute names and types
  | OOMethodS
      Text -- name of this method, which selects an object using key attributes (producing a handle).
      [CdAttribute] -- list of parameters: attribute names and types
  | OOMethodU
      Text -- name of this method, which updates an object (using a handle).
      [CdAttribute] -- list of parameters: attribute names and types
  | OOMethodD Text -- name of this method, which deletes an object (using nothing but a handle).
  | OOMethod
      Text -- name of this method, which deletes an object (using nothing but a handle).
      [CdAttribute] -- list of parameters: attribute names and types
      Text -- result: a type
  deriving (Eq)

instance Show Method where
  show (OOMethodC nm cs) = T.unpack $ nm <> "(" <> T.intercalate "," [n | OOAttr n _ _ <- cs] <> "):handle"
  show (OOMethodR nm as) = T.unpack $ nm <> "(handle):[" <> T.intercalate "," [n | OOAttr n _ _ <- as] <> "]"
  show (OOMethodS nm ks) = T.unpack $ nm <> "(" <> T.intercalate "," [n | OOAttr n _ _ <- ks] <> "):handle"
  show (OOMethodD nm) = T.unpack $ nm <> "(handle)"
  show (OOMethodU nm cs) = T.unpack $ nm <> "(handle," <> T.intercalate "," [n | OOAttr n _ _ <- cs] <> ")"
  show (OOMethod nm cs r) = T.unpack $ nm <> "(" <> T.intercalate "," [n | OOAttr n _ _ <- cs] <> "): " <> r

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
