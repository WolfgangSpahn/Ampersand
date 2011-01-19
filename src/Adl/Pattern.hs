{-# OPTIONS_GHC -Wall #-}
module ADL.Pattern (Pattern(..),Patterns)
where
   import ADL.KeyDef                   (KeyDefs)
   import ADL.Rule                     (Rules)
   import ADL.Gen                      (Gens)
   import ADL.Concept                  (Concept,Sign)
   import ADL.MorphismAndDeclaration   (Declaration,Relation,Identified(..))
   import ADL.ConceptDef               (ConceptDefs)
   import ADL.Explanation              (PExplanations)
   import ADL.Expression               (PExpression)
   
   type Patterns  = [Pattern]
   data Pattern
      = Pat { ptnm  :: String        -- ^ Name of this pattern
            , ptrls :: Rules (Relation Concept) -- ^ The rules declared in this pattern
            , ptgns :: Gens Concept  -- ^ The generalizations defined in this pattern
            , ptdcs :: [Declaration Concept] -- ^ The declarations declared in this pattern
            , ptcds :: ConceptDefs   -- ^ The concept definitions defined in this pattern
            , ptkds :: KeyDefs       -- ^ The key definitions defined in this pattern
            , ptxps :: PExplanations -- ^ The explanations of elements defined in this pattern
            , testexpr :: [PExpression (Relation Concept) (Maybe Sign)]
            , inftestexpr :: [PExpression (Declaration Concept) Sign]
            }   --deriving (Show) -- voor debugging

-- \***********************************************************************
-- \*** Eigenschappen met betrekking tot: Pattern                       ***
{- \**** (Eq dient alleen diagnostische doeleinden)    ********************

   instance Eq Pattern where
    p==p' = ptnm     p == ptnm  p'
       --   && ptrls p == ptrls p'
            && ptgns p == ptgns p'
       --   && ptdcs p == ptdcs p'
            && ptcds p == ptcds p'
            && ptkds p == ptkds p'
-}

--   instance Show Pattern
   instance Identified Pattern where
    name pat = ptnm pat

