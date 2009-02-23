{-# OPTIONS_GHC -Wall #-}
{-# OPTIONS -XTypeSynonymInstances #-}

module Adl.Concept where
   import Adl.Prop
   import CommonClasses --(Identified(name,typ)
                        --, ABoolAlg(glb,lub,order)
                        --, Explained(explain)
                        --, 
                        --, Morphics(anything)
                        --)
   import Collection ((>-))
   import Typology
   
   type Concepts = [Concept]
   data Concept
      = C   { cptnm :: String    -- ^The name of this Concept
            , cptgE :: GenR 
            , cptos :: [String]  -- ^Atoms
            }  -- ^C nm gE cs represents the set of instances cs by name nm.
      | S  -- ^The universal Singleton: 'I'['Anything'] = 'V'['Anything']
      | Anything -- ^Really Anything!
      | NOthing  -- ^Nothing at all
            
   instance Typologic Concept


   type Sign = (Concept,Concept) 
   type GenR = Concept->Concept->Bool

-- \***********************************************************************
-- \*** Eigenschappen met betrekking tot: Concept                       ***
-- \***********************************************************************
   instance Eq Concept where
    C a _ _ == C b _ _ = a==b
    S == S = True
    Anything == Anything = True
    NOthing == NOthing = True
    _ == _ = False
   instance Show Concept where
    showsPrec _ c = showString (name c)
   instance Identified Concept where
    name (C {cptnm = nm}) = nm
    name S = "ONE"
    name Anything   = "Anything"
    name NOthing    = "NOthing"
    typ _ = "Concept_"
   instance Association Concept where
    source c = c
    target c = c
   instance Ord Concept where
    NOthing <= _  = False
    _ <= NOthing  = True
    Anything <= _ = True
    _ <= Anything = False
    a@(C _ gE _) <= b = a `gE` b
    a <= b = a==b

   one :: Concept
   one = C "ONE" (error "!Bug in module ADLdef: Illegal reference to gE in ONE. Please program the right gE into ONE.")
                 (error "!Fatal (module ADLdef): Illegal reference to content of the universal singleton.")


   instance ABoolAlg Concept where
    glb a b | b <= a = b
            | a <= b = a
            | otherwise = error ("(module Concept) Fatal: (C) glb undefined: a="++show a++", b="++show b)
    lub a b | a <= b = b
            | b <= a = a
            | otherwise = error ("(module Concept) Fatal: (C) lub undefined: a="++show a++", b="++show b)

   cptC :: String -> GenR -> [String] -> Concept
   cptC nm gE os = C{ cptnm=nm, cptgE = gE, cptos = os}  -- constructor
   cptS :: Concept
   cptS = S                    -- constructor
   cptAnything :: Concept
   cptAnything = Anything      -- constructor
   cptNothing :: Concept
   cptNothing = NOthing        -- constructor
   cptnew :: String -> Concept
   cptnew nm = C{ cptnm=nm, cptgE = (==), cptos = []}

   class Association a where
     source, target :: a -> Concept
     sign           :: a -> Sign
     sign x = (source x,target x) 

   instance Association Sign where
     source (src, _ ) = src
     target (_ , tgt) = tgt
     
    
   class Association a => Morphic a where
    multiplicities :: a -> [Prop]
--    multiplicities _ = []  --WAAROM? Stef, dit stond er eerst, maar ik geloof niet dat dat goed is. zelfs niet als default regel. Toch?
    flp            :: a -> a
--    isIdent        :: a -> Bool  -- > tells whether the argument is equivalent to I
    isProp         :: a -> Bool  -- > tells whether the argument is a property
    isNot          :: a -> Bool  -- > tells whether the argument is equivalent to I-
    isMph          :: a -> Bool
    isTrue         :: a -> Bool  -- > tells whether the argument is equivalent to V
    isFalse        :: a -> Bool  -- > tells whether the argument is equivalent to V-
    isSignal       :: a -> Bool  -- > tells whether the argument refers to a signal
    singleton      :: a -> Bool  -- > tells whether V=I
    singleton e     = isProp e && isTrue e
    equiv          :: a -> a -> Bool
    equiv m m' = source m==source m'&&target m==target m' || source m==target m'&&target m==source m'
    typeUniq :: a -> Bool -- this says whether the type of 'a' and all of its constituent parts is defined (i.e. not "Anything")
    isFunction :: a -> Bool     
    isFunction m   = null ([Uni,Tot]>-multiplicities m)
    isFlpFunction :: a -> Bool
    isFlpFunction m = null ([Sur,Inj]>-multiplicities m)


   isSingleton :: Concept -> Bool
   isSingleton s = s == S
   
   instance Conceptual Concept where
    conts (C {cptos = os}) = os
    conts (S)        = error ("(module CC_aux) Fatal: ONE has exactly one atom, but that atom may not be referred to")
    conts Anything   = error ("(module CC_aux) Fatal: Anything is Everything...")
    conts NOthing    = error ("(module CC_aux) Fatal: NOthing is not very much...")

   instance Morphics Concept where
    anything c = c == Anything
   