{-# OPTIONS_GHC -Wall #-}
{-# LANGUAGE Rank2Types, KindSignatures, GeneralizedNewtypeDeriving #-}
module DatabaseDesign.Ampersand_Prototype.CodeAuxiliaries
       (Named(..),atleastOne,reName,nameFresh,noCollide,mapExpression, mapRelation, mapDeclaration, mapSign) 
where
 import Data.Char
 import DatabaseDesign.Ampersand_Prototype.CoreImporter
 data (Eq a) => Named a = Named { nName :: String, nObject :: a} deriving (Eq)
 instance (Show a,Eq a)=> Show (Named a) where
   show a = "$"++(nName a)++(show (nObject a))

 reName :: (Eq a) => String->Named a -> Named a
 reName s o = Named s (nObject o)
 
 nameFresh :: (Eq a, Eq a1) => [Named a] -> String -> a1 -> Named a1
 nameFresh vars nm obj
   = Named realname obj
     where  realname = noCollide (map nName vars) nm

 -- | make sure a function returns at least one item (run-time check) or give a debug error
 atleastOne :: forall t. [Char] -> [t] -> [t]
 atleastOne errormsg [] = error errormsg
 atleastOne _ (a:as) = a:as

 -- | changes its second argument by appending a digit, such that it does not occur in its first argument 
 noCollide :: [String] -- ^ forbidden names
           -> String -- ^ preferred name
           -> String -- ^ a unique name (does not occur in forbidden names)
 noCollide names nm | nm `elem` names = noCollide names (namepart (reverse nm) ++ changeNr (numberpart (reverse nm)))
                    | otherwise = nm
  where
    namepart str   = reverse (dropWhile isDigit str)
    numberpart str = reverse (takeWhile isDigit str)
    changeNr x     = int2string (string2int x+1)
    --  changeNr x = show (read x +1)
    string2int :: String -> Int
    string2int  = enc.reverse
     where enc "" = 0
           enc (c:cs) = digitToInt c + 10* enc cs
    int2string :: Int -> String
    int2string 0 = "0"
    int2string n = if n `div` 10 == 0 then [intToDigit (n `rem` 10) |n>0] else int2string (n `div` 10)++[intToDigit (n `rem` 10)]

 mapRelation :: (A_Concept->A_Concept) -> Relation -> Relation
 mapRelation f r
       = case r of
           Rel{} -> r{ relsgn = mapSign f (relsgn r)
                     , reldcl = mapDeclaration f (reldcl r)
                     }
           I  {} -> r{ rel1typ = f (rel1typ r) }
           V  {} -> r{ reltyp  = reltyp r }
           Mp1{} -> r{ rel1typ = f (rel1typ r) }

 mapExpression :: (Relation->Relation) -> Expression -> Expression
 mapExpression f (Eequ (l,r)) = Eequ (mapExpression f l,mapExpression f r) -- ^ equivalence             =
 mapExpression f (Eimp (l,r)) = Eimp (mapExpression f l,mapExpression f r) -- ^ implication             |-
 mapExpression f (Eisc es)    = Eisc (map (mapExpression f) es)            -- ^ intersection            /\
 mapExpression f (Euni es)    = Euni (map (mapExpression f) es)            -- ^ union                   \/
 mapExpression f (Edif (l,r)) = Edif (mapExpression f l,mapExpression f r) -- ^ difference              -
 mapExpression f (Elrs (l,r)) = Elrs (mapExpression f l,mapExpression f r) -- ^ left residual           /
 mapExpression f (Errs (l,r)) = Errs (mapExpression f l,mapExpression f r) -- ^ right residual          \
 mapExpression f (Ecps es)    = Ecps (map (mapExpression f) es)            -- ^ composition             ;
 mapExpression f (Erad es)    = Erad (map (mapExpression f) es)            -- ^ relative addition       !
 mapExpression f (Ekl0 e)     = Ekl0 (mapExpression f e)                   -- ^ Rfx.Trn closure         *
 mapExpression f (Ekl1 e)     = Ekl1 (mapExpression f e)                   -- ^ Transitive closure      +
 mapExpression f (Eflp e)     = Eflp (mapExpression f e)                   -- ^ Conversion              ~
 mapExpression f (Ecpl e)     = Ecpl (mapExpression f e)                   -- ^ OBSOLETE.. remove later
 mapExpression f (Ebrk e)     =     mapExpression f e                    -- ^ bracketed expression ( remove brackets )
 mapExpression f (Etyp e _)   =     mapExpression f e                    -- ^ remove type cast, as the type might change as a result of applying f to elements of e.
 mapExpression f (Erel rel)   = Erel (f rel)                               -- ^ simple relation

 mapDeclaration :: (A_Concept->A_Concept) -> Declaration -> Declaration
 mapDeclaration f d@Sgn{}
          = d{ decsgn = mapSign f (decsgn r) }
 mapDeclaration f d@Vs{}
          = d{ decsgn = mapSign f (decsgn r) }
 mapDeclaration f d
          = d{ detyp = f (detyp d) }

 mapSign :: (A_Concept->A_Concept) -> Sign -> Sign
 mapSign f (Sign s t) = Sign (f s) (f t)
