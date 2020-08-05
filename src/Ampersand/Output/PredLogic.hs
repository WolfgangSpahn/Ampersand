{-# LANGUAGE OverloadedStrings #-}
module Ampersand.Output.PredLogic
         ( showPredLogic
         ) where

import           Ampersand.ADL1
import           Ampersand.Basics hiding (toList)
import           Ampersand.Classes
import qualified RIO.NonEmpty as NE
import qualified RIO.List as L
import qualified RIO.List.Partial as P  -- TODO Use NonEmpty 
-- import qualified RIO.Map as M
import qualified RIO.Set as Set
import qualified RIO.Text as T
import           Text.Pandoc.Builder

data PredLogic = 
    Forall (NE.NonEmpty Var) PredLogic
  | Exists (NE.NonEmpty Var) PredLogic
  | Implies PredLogic PredLogic
  | Equiv PredLogic PredLogic
  | Conj [PredLogic]
  | Disj [PredLogic]
  | Not PredLogic
  | Kleene0 PredLogic
  | Kleene1 PredLogic
  | R PredLogic Relation PredLogic
  -- ^ R _ a r b is represented as a r b 
  --  but if isIdent r then it is represented as a = b
  | Constant Text
  -- ^ A constant. e.g.: "Churchill", 1
  | Variable Var
  -- ^ A variable. e.g.: x
  | Vee Var Var
  -- ^ The complete relation. e.g.: a Vee b (which is always true)
  | Function PredLogic Relation
  -- ^ Function a f is represented in text as f(a)
  | Dom PredLogic Var
  -- ^ Dom expr (a,_) is represented as a ∈ dom(expr) 
  | Cod PredLogic Var
    deriving Eq

type VarSet = Set.Set Var
data Var = Var Integer A_Concept
   deriving (Eq,Ord,Show)

showPredLogic :: Lang -> Expression -> Inlines
showPredLogic lang expr = text $ predLshow lang varMap (predNormalize predL)
 where
   (predL,varSet) = toPredLogic expr
   -- For printing a variable we use varMap
   -- A variable is represented by the first character of its concept name, followed by a number of primes to distinguish from similar variables.
   varMap :: Var -> Text
   varMap (Var n c) = vChar c<>(T.pack . replicate (length vars-1)) '\''
     where
       vars = Set.filter (\(Var i c')->i<=n && vChar c==vChar c') varSet
       vChar = T.toLower . T.take 1 . name

-- predLshow exists for the purpose of translating a predicate logic expression to natural language.
-- example:  'predLshow l e' translates expression 'e'
-- into a string that contains a natural language representation of 'e'.
predLshow :: Lang -> (Var->Text) -> PredLogic -> Text
predLshow lang vMap predlogic = charshow 0 predlogic
  where
     -- shorthand for easy localizing    
   l :: LocalizedStr -> Text
   l = localize lang
   listVars :: Text -> NE.NonEmpty Var -> Text
   listVars sep vars = T.intercalate sep . NE.toList . fmap vMap $ vars

   wrap :: Integer -> Integer -> Text -> Text
   wrap i j txt = if i<=j then txt else "("<>txt<>")"
   charshow :: Integer -> PredLogic -> Text
   charshow i predexpr
    = case predexpr of
       Forall vars restr      -> wrap i 1 (             l (NL "Voor alle ", EN "For all ") 
                                           <> listVars (l (NL ", ", EN ", ")) vars <> ": "
                                           <> charshow 1 restr)
       Exists vars restr      -> wrap i 1 (             l (NL "Er is een ", EN "There exists ")
                                           <> listVars (l (NL ", ", EN ", ")) vars <> ": "
                                           <> charshow 1 restr)
       Implies ante cons      -> wrap i 2 (implies (charshow 2 ante) (charshow 2 cons))
                                 where implies :: Text -> Text -> Text
                                       implies a b =
                                          l (NL "Als ",EN "If " )<>a<>l (NL" dan ",EN " then ")<>b
       Equiv lhs rhs          -> wrap i 2 (charshow 2 lhs<>(l (NL " is equivalent met ",EN " is equivalent to "))<>charshow 2 rhs)
       Disj rs                -> if null rs
                                      then mempty
                                      else wrap i 3 (T.intercalate (l (NL " of ",EN " or ")) (map (charshow 3) rs))
       Conj rs                -> if null rs
                                      then mempty
                                      else wrap i 4 (T.intercalate (l (NL " en ",EN " and ")) (map (charshow 4) rs))
       Dom pexpr var          -> vMap var<>" ∈ dom(" <>charshow 8 pexpr<>")"
       Cod pexpr var          -> vMap var<>" ∈ cod(" <>charshow 8 pexpr<>")"
       R pexpr rel pexpr'  
         | isIdent (EDcD rel) -> wrap i 5 (charshow 5 pexpr) <> " = " <> wrap i 5 (charshow 5 pexpr')
         | otherwise          -> if T.null (prL<>prM<>prR)
                                 then d<>" "<>name rel<>" "<>c
                                 else prL<>d<>prM<>c<>prR
                                 where d = wrap i 5 (charshow 5 pexpr)
                                       c = wrap i 5 (charshow 5 pexpr')
                                       prL = decprL rel
                                       prM = decprM rel
                                       prR = decprR rel
       Constant txt           -> txt
       Variable v             -> vMap v
       Vee v w                -> wrap i 5 (vMap v) <> " V " <> wrap i 5 (vMap w)
       Function pexpr rel     -> name rel<>"("<>charshow 1 pexpr<>")"
       Kleene0 rs             -> wrap i 6 (charshow 6 rs<>"*")
       Kleene1 rs             -> wrap i 7 (charshow 7 rs<>"+")
       Not rs                 -> wrap i 8 (l (NL " niet ",EN " not ")<>charshow 8 rs)

predNormalize :: PredLogic -> PredLogic
predNormalize predlogic = predlogic  --TODO: Fix normalization of PredLogic

-- The function 'toPredLogic' translates an expression to predicate logic for two purposes:
-- The first purpose is that it is a step towards generating natural language.
-- The second purpose is to generate predicate logic text, which serves a larger audience than relation algebra.
toPredLogic :: Expression -> (PredLogic,VarSet)
toPredLogic expr
 = case (source expr, target expr) of
        (ONE, ONE) -> propagate Set.empty expr (oneVar,oneVar)
        (_  , ONE) -> (Forall (oneVar :| []) predL, vSet)
                      where
                        (predL, vSet) = propagate vM expr (var,oneVar)
                        var = mkVar Set.empty (source expr)        :: Var
                        vM  = addVar (addVar Set.empty oneVar) var :: VarSet
        (ONE, _)   -> (Forall (var :| []) predL, vSet)
                      where
                        (predL, vSet) = propagate vM expr (oneVar,var)
                        var = mkVar Set.empty (target expr)        :: Var
                        vM  = addVar (addVar Set.empty oneVar) var :: VarSet
        (_  , _)   -> (Forall vars predL, vSet)
                      where
                        (predL, vSet) = propagate vM expr (s,t)
                        s   = mkVar Set.empty (source expr)        :: Var
                        ss  = addVar Set.empty s                   :: VarSet
                        t   = mkVar ss (target expr)               :: Var
                        Just vars = NE.nonEmpty [s,t]
                        vM  = addVar ss t                          :: VarSet
  where
   oneVar :: Var
   oneVar = Var 0 ONE
   addVar :: VarSet -> Var -> VarSet
   addVar varSet v = Set.insert v varSet

   mkVar :: VarSet -> A_Concept -> Var
   mkVar varSet c
    = if Set.null varSet then Var 1 c else
      Var (P.maximum (Set.map (\(Var i _)->i) varSet) + 1) c

   -- propagate calls mkVar to generate fresh variables throughout the recursive tree.
   -- For that purpose, it yield not only the answer (of type: PredLogic),
   -- but also the set of variables (of type: VarSet) generated in the process.
   -- precondition: propagate varSet _ (a,b)  ==> {a,b} Set.isSubsetOf varSet
   propagate :: VarSet -> Expression -> (Var,Var) -> (PredLogic, VarSet)
   propagate varSet (EEqu (l,r)) (a,b)  = (Equiv l' r', set_l `Set.union` set_r)
                                  where (l',set_l) = propagate varSet l (a,b)
                                        (r',set_r) = propagate varSet r (a,b)
   propagate varSet (EInc (l,r)) (a,b)  = (Implies l' r', set_l `Set.union` set_r)
                                  where (l',set_l) = propagate varSet l (a,b)
                                        (r',set_r) = propagate varSet r (a,b)
   propagate varSet e@EIsc{}     (a,b)  = (Conj (map fst ps) , Set.unions (map snd ps))
                                  where ps = [propagate varSet e' (a,b) | e'<-NE.toList (exprIsc2list e)]
   propagate varSet e@EUni{}     (a,b)  = (Disj (map fst ps) , Set.unions (map snd ps))
                                  where ps = [propagate varSet e' (a,b) | e'<-NE.toList (exprUni2list e)]
   propagate varSet (EDif (l,r)) (a,b)  = (Conj [l', Not r'] , set_l `Set.union` set_r)
                                  where (l',set_l) = propagate varSet l (a,b)
                                        (r',set_r) = propagate varSet r (a,b)
   propagate varSet (ELrs (l,r)) (a,b)  = (Forall (c :| []) (Implies l' r') , set_l `Set.union` set_r)
                                  where c          = mkVar varSet (target l)
                                        eVars      = addVar varSet c
                                        (l',set_l) = propagate eVars r (b,c)
                                        (r',set_r) = propagate eVars l (a,c)
   propagate varSet (ERrs (l,r)) (a,b)  = (Forall (c :| []) (Implies l' r') , set_l `Set.union` set_r)
                                  where c          = mkVar varSet (source l)
                                        eVars      = addVar varSet c
                                        (l',set_l) = propagate eVars l (c,a)
                                        (r',set_r) = propagate eVars r (c,b)
   propagate varSet (EDia (l,r)) (a,b)  = (Forall (c :| []) (Equiv l' r') , set_l `Set.union` set_r)
                                  where c          = mkVar varSet (target l)
                                        eVars      = addVar varSet c
                                        (l',set_l) = propagate eVars r (b,c)
                                        (r',set_r) = propagate eVars l (a,c)
   propagate varSet e@ECps{}     (a,b)  = (Exists polVs (Conj predLs), varSet')
                                  where (polVs, predLs, varSet') = fencePoles varSet (exprCps2list e) (a,b)
   propagate varSet e@ERad{}     (a,b)  = (Forall polVs (Disj predLs), varSet')
                                  where (polVs, predLs, varSet') = fencePoles varSet (exprRad2list e) (a,b)
   propagate _      (EPrd (l,r)) (a,b)  = (Conj [Dom l a, Cod r b], Set.empty)
   propagate varSet (EKl0 e)     (a,b)  = (Kleene0 predL, vSet)
                                   where
                                     (predL, vSet) = propagate varSet e (a,b)
   propagate varSet (EKl1 e)     (a,b)  = (Kleene1 predL, vSet)
                                   where
                                     (predL, vSet) = propagate varSet e (a,b)
   propagate varSet (ECpl e)     (a,b)  = (Not predL, vSet)
                                   where
                                     (predL, vSet) = propagate varSet e (a,b)
   propagate varSet (EBrk e)     (a,b)  = propagate varSet e (a,b)
   propagate varSet (EFlp e)     (a,b)  = propagate varSet e (b,a)
   propagate _      (EDcD dcl)   (a,b)  = (R (Variable a) dcl (Variable b), Set.fromList [a,b])
   propagate _      (EDcI _)     (a,b)  = (Equiv (Variable a) (Variable b), Set.fromList [a,b])
   propagate _      (EEps _ _)   (a,b)  = (Equiv (Variable a) (Variable b), Set.fromList [a,b])
   propagate _      (EDcV _)     (a,b)  = (Vee a b, Set.fromList [a,b])
   propagate _      (EMp1 pAV _) _      = (Constant (T.pack (show pAV)), Set.empty)

   fencePoles :: VarSet -> NonEmpty Expression -> (Var,Var) -> (NonEmpty Var, [PredLogic], VarSet)
   fencePoles varSet fences (a,b) = (polVs, predLs, varSet'')
     where
      poles = (map source . NE.tail) fences  :: [A_Concept]   -- the "in between concepts"
      Just polVs = NE.nonEmpty vars
      (varSet',vars)                        -- (VarSet,[Var])
       = foldr g (varSet,[]) poles
         where g c (vSet,vs) = let v = mkVar vSet c in (addVar vSet v, vs<>[v])
      predLs :: [PredLogic]
      (predLs, varSet'')
       = ( [ l' ]<>fmap fst midFences<>[ r' ], set_l `Set.union` Set.unions (map snd midFences) `Set.union` set_r )
         where
           (l',set_l) = propagate varSet' (NE.head fences) (a, P.head vars)
           midFences  = [ propagate varSet' ex (sVar, tVar) | (ex, sVar, tVar)<-L.zip3 (NE.tail fences) vars (P.tail vars) ]
           (r',set_r) = propagate varSet' (NE.last fences) (P.last vars, b)