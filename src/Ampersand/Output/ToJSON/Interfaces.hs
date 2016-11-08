{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE MultiParamTypeClasses #-} 
{-# LANGUAGE FlexibleInstances #-} 
module Ampersand.Output.ToJSON.Interfaces 
   (Interfaces)
where
import Ampersand.Output.ToJSON.JSONutils 
import Ampersand.Core.AbstractSyntaxTree 
import Ampersand.FSpec.ToFSpec.NormalForms
import Ampersand.FSpec.ToFSpec.Calc
import Ampersand.FSpec.ShowADL

data Interfaces = Interfaces [JSONInterface] deriving (Generic, Show)
data JSONInterface = JSONInterface
  { ifcJSONinterfaceRoles     :: [String]
  , ifcJSONboxClass           :: Maybe String
  , ifcJSONifcObject          :: JSONObjectDef
  } deriving (Generic, Show)
data JSONObjectDef = JSONObjectDef
  { ifcJSONid                 :: String
  , ifcJSONlabel              :: String
  , ifcJSONviewId             :: Maybe String
  , ifcJSONNormalizationSteps :: [String] -- Not used in frontend. Just informative for analisys
  , ifcJSONrelation           :: Maybe String
  , ifcJSONrelationIsFlipped  :: Maybe Bool
  , ifcJSONcrud               :: JSONCruds
  , ifcJSONexpr               :: JSONexpr
  , ifcJSONsubinterfaces      :: Maybe JSONSubInterface
  } deriving (Generic, Show)
data JSONSubInterface = JSONSubInterface
  { subJSONboxClass           :: Maybe String
  , subJSONifcObjects         :: Maybe [JSONObjectDef]
  , subJSONrefSubInterfaceId  :: Maybe String
  , subJSONrefIsLinTo         :: Maybe Bool
  } deriving (Generic, Show)
data JSONCruds = JSONCruds
  { crudJSONread              :: Bool
  , crudJSONcreate            :: Bool
  , crudJSONupdate            :: Bool
  , crudJSONdelete            :: Bool
  } deriving (Generic, Show)
data JSONexpr = JSONexpr
  { exprJSONsrcConceptId      :: String
  , exprJSONtgtConceptId      :: String
  , exprJSONisUni             :: Bool
  , exprJSONisTot             :: Bool
  , exprJSONisIdent           :: Bool
  , exprJSONquery             :: String
  } deriving (Generic, Show)

instance ToJSON JSONSubInterface where
  toJSON = amp2Jason
instance ToJSON Interfaces where
  toJSON = amp2Jason
instance ToJSON JSONInterface where
  toJSON = amp2Jason
instance ToJSON JSONObjectDef where
  toJSON = amp2Jason
instance ToJSON JSONCruds where
  toJSON = amp2Jason
instance ToJSON JSONexpr where
  toJSON = amp2Jason
  
instance JSON MultiFSpecs Interfaces where
 fromAmpersand multi _ = Interfaces (map (fromAmpersand multi) (interfaceS fSpec ++ interfaceG fSpec))
   where fSpec = userFSpec multi

instance JSON SubInterface JSONSubInterface where
 fromAmpersand multi si = 
   case si of 
     Box{} -> JSONSubInterface
       { subJSONboxClass           = siMClass si
       , subJSONifcObjects         = Just . map (fromAmpersand multi) . siObjs $ si
       , subJSONrefSubInterfaceId  = Nothing
       , subJSONrefIsLinTo         = Nothing
       }
     InterfaceRef{} -> JSONSubInterface
       { subJSONboxClass           = Nothing
       , subJSONifcObjects         = Nothing
       , subJSONrefSubInterfaceId  = Just . escapeIdentifier . siIfcId $ si
       , subJSONrefIsLinTo         = Just . siIsLink $ si
       }
 
instance JSON Interface JSONInterface where
 fromAmpersand multi interface = JSONInterface
  { ifcJSONinterfaceRoles     = map name . ifcRoles $ interface
  , ifcJSONboxClass           = Nothing -- todo, fill with box class of toplevel ifc box
  , ifcJSONifcObject          = fromAmpersand multi (ifcObj interface)
  }

instance JSON Cruds JSONCruds where
 fromAmpersand _ crud = JSONCruds
  { crudJSONread              = crudR crud
  , crudJSONcreate            = crudC crud
  , crudJSONupdate            = crudU crud
  , crudJSONdelete            = crudD crud
  }
  
instance JSON ObjectDef JSONexpr where
 fromAmpersand multi object = JSONexpr
  { exprJSONsrcConceptId      = escapeIdentifier . name $ srcConcept
  , exprJSONtgtConceptId      = escapeIdentifier . name $ tgtConcept
  , exprJSONisUni             = isUni normalizedInterfaceExp
  , exprJSONisTot             = isTot normalizedInterfaceExp
  , exprJSONisIdent           = isIdent normalizedInterfaceExp
  , exprJSONquery             = query
  }
  where
    opts = getOpts fSpec
    fSpec = userFSpec multi
    query = broadQueryWithPlaceholder fSpec object{objctx=normalizedInterfaceExp}
    normalizedInterfaceExp = conjNF opts $ objctx object
    (srcConcept, tgtConcept) =
      case getExpressionRelation normalizedInterfaceExp of
        Just (src, _ , tgt, _) ->
          (src, tgt)
        Nothing -> (source normalizedInterfaceExp, target normalizedInterfaceExp) -- fall back to typechecker type
 
instance JSON ObjectDef JSONObjectDef where
 fromAmpersand multi object' = JSONObjectDef
  { ifcJSONid                 = escapeIdentifier . name $ object
  , ifcJSONlabel              = name object
  , ifcJSONviewId             = fmap name viewToUse
  , ifcJSONNormalizationSteps = showPrf showADL.cfProof opts.objctx $ object 
  , ifcJSONrelation           = fmap (showDcl True . fst) mEditableDecl
  , ifcJSONrelationIsFlipped  = fmap            snd  mEditableDecl
  , ifcJSONcrud               = fromAmpersand multi (objcrud object)
  , ifcJSONexpr               = fromAmpersand multi object
  , ifcJSONsubinterfaces      = fmap (fromAmpersand multi) (objmsub object)
  }
  where
    opts = getOpts fSpec
    fSpec = userFSpec multi
    viewToUse = case objmView object of
                 Just nm -> Just $ lookupView fSpec nm
                 Nothing -> getDefaultViewForConcept fSpec tgtConcept
    normalizedInterfaceExp = conjNF opts $ objctx object
    (tgtConcept, mEditableDecl) =
      case getExpressionRelation normalizedInterfaceExp of
        Just (_ , decl, tgt, isFlipped) ->
          (tgt, Just (decl, isFlipped))
        Nothing -> (target normalizedInterfaceExp, Nothing) -- fall back to typechecker type
    

    object :: ObjectDef
    object = case substitution of
               Nothing           -> object'
               Just (expr,cruds) -> object'{ objctx  = expr
                                           , objcrud = cruds
                                           }
    -- In case of reference to an INTERFACE, not used as a LINKTO, the
    -- expression and cruds are replaced. This is introduce with the
    -- refactoring of the frontend interfaces in oct/nov 2016. 
    substitution :: Maybe (Expression, Cruds)
    substitution =
       case objmsub object' of
         Just InterfaceRef{ siIsLink=False
                          , siIfcId=interfaceId} 
           -> let ifc = ifcObj (lookupInterface interfaceId)
              in Just (conjNF opts (objctx object' .:. objctx ifc), objcrud ifc)
         _ -> Nothing
    lookupInterface :: String -> Interface
    lookupInterface nm = 
        case [ ifc | ifc <- (interfaceS fSpec ++ interfaceG fSpec), name ifc == nm ] of
          [ifc] -> ifc
          _     -> fatal 124 "Interface lookup returned zero or more than one result"

      