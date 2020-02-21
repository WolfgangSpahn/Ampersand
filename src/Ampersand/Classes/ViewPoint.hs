{-# LANGUAGE OverloadedStrings #-}
module Ampersand.Classes.ViewPoint 
   (Language(..)) 
where
import           Ampersand.ADL1
import           Ampersand.Basics hiding (Ord(..),Identity)
import           Ampersand.Classes.Relational  (HasProps(properties))
import qualified RIO.List as L
import qualified RIO.NonEmpty as NE
import qualified RIO.Set as Set

-- Language exists because there are many data structures that behave like an ontology, such as Pattern, P_Context, and Rule.
-- These data structures are accessed by means of a common set of functions (e.g. rules, relations, etc.)

class Language a where
  relsDefdIn :: a -> Relations   -- ^ all relations that are declared in the scope of this viewpoint.
                                     --   These are user defined relations and all generated relarations,
                                     --   i.e. one relation for each GEN and one for each signal rule.
                                     --   Don't confuse relsDefdIn with bindedRelationsIn, which gives the relations that are
                                     --   used in a.)
  udefrules :: a -> Rules           -- ^ all user defined rules that are maintained within this viewpoint,
                                     --   which are not multiplicity- and not identity rules.
  multrules :: a -> Rules           -- ^ all multiplicityrules that are maintained within this viewpoint.
  multrules x   = Set.fromList $ 
                 [rulefromProp p d |d<-Set.elems $ relsDefdIn x, p<-Set.elems (properties d)]
  identityRules :: a -> Rules       -- all identity rules that are maintained within this viewpoint.
  identityRules x    = Set.unions . map rulesFromIdentity $ identities x
  allRules :: a -> Rules
  allRules x = udefrules x `Set.union` multrules x `Set.union` identityRules x
  identities :: a -> [IdentityDef]   -- ^ all keys that are defined in a
  viewDefs :: a -> [ViewDef]         -- ^ all views that are defined in a
  gens :: a -> [AClassify]               -- ^ all generalizations that are valid within this viewpoint
  patterns :: a -> [Pattern]         -- ^ all patterns that are used in this viewpoint

rulesFromIdentity :: IdentityDef -> Rules
rulesFromIdentity identity
 = Set.singleton . mkKeyRule $
       foldr (./\.) h t 
        .|-. EDcI (idCpt identity)
 {-    diamond e1 e2 = (flp e1 .\. e2) ./\. (e1 ./. flp e2)  -}
 where (h NE.:| t) = fmap (\expr-> expr .:. flp expr) 
                    . fmap (objExpression . segment) 
                    . identityAts $ identity
       meaningEN :: Text
       meaningEN = "Identity rule" <> ", following from identity "<>name identity
       meaningNL = "Identiteitsregel" <> ", volgend uit identiteit "<>name identity
       mkKeyRule expression =
         Ru { rrnm   = "identity_" <> name identity
            , formalExpression  = expression
            , rrfps  = origin identity     -- position in source file
            , rrmean = 
                [ Meaning $ Markup English (string2Blocks ReST meaningEN)
                , Meaning $ Markup Dutch (string2Blocks ReST meaningNL)
                ]
            , rrmsg  = []
            , rrviol = Nothing
            , rrdcl  = Nothing        -- This rule was not generated from a property of some relation.
            , rrpat  = idPat identity
            , r_usr  = Identity       -- This rule was not specified as a rule in the Ampersand script, but has been generated by a computer
            , isSignal  = False       -- This is not a signal rule
            }

instance (Eq a,Language a) => Language [a] where
  relsDefdIn  = Set.unions . map relsDefdIn 
  udefrules   = Set.unions . map udefrules 
  identities  =       concatMap identities
  viewDefs    =       concatMap viewDefs
  gens        = L.nub . concatMap gens
  patterns    =       concatMap patterns
instance (Eq a,Language a) => Language (Set.Set a) where
  relsDefdIn  = Set.unions . map relsDefdIn . Set.elems
  udefrules   = Set.unions . map udefrules  . Set.elems
  identities  = L.nub . concatMap identities  . Set.elems
  viewDefs    = L.nub . concatMap viewDefs    . Set.elems
  gens        = L.nub . concatMap gens        . Set.elems
  patterns    = L.nub . concatMap patterns    . Set.elems
  
instance Language A_Context where
  relsDefdIn context = uniteRels ( relsDefdIn (patterns context)
                                `Set.union` ctxds context)
     where
      -- relations with the same name, but different properties (decprps,pragma,etc.) may exist and need to be united
      -- decprps and decprps_calc are united, all others are taken from the head.
      uniteRels :: Relations -> Relations
      uniteRels ds = Set.fromList .
        map fun . eqClass (==) $ Set.elems ds
         where fun :: NE.NonEmpty Relation -> Relation
               fun rels = (NE.head rels) {decprps = Set.unions . fmap decprps $ rels
                                          ,decprps_calc = Nothing -- Calculation is only done in ADL2Fspc.
                                          }
  udefrules    context = (Set.unions . map udefrules $ ctxpats context) `Set.union` ctxrs context
  identities   context =       concatMap identities (ctxpats context) <> ctxks context
  viewDefs     context =       concatMap viewDefs   (ctxpats context) <> ctxvs context
  gens         context = L.nub $ concatMap gens       (ctxpats context) <> ctxgs context
  patterns             =       ctxpats

instance Language Pattern where
  relsDefdIn     = ptdcs
  udefrules      = ptrls   -- all user defined rules in this pattern
  identities     = ptids
  viewDefs       = ptvds
  gens           = ptgns
  patterns   pat = [pat]

