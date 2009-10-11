  {-# OPTIONS_GHC -Wall #-}
  module ADL2Fspec (makeFspec)
  where
   import Collection     ( Collection (rd,(>-)) )
   import Strings        (firstCaps)
   import Adl
   import Dataset
   import Auxiliaries    (naming, eqCl, eqClass, sort')
   import FspecDef
   import Languages
   import Options(Options(language))
   import NormalForms(disjNF)
   import Data.Plug
   import Char(toLower)
   import Rendering.ClassDiagram
--   import Rendering.AdlExplanation
 -- The story:
 -- A number of datasets for this context is identified.
 -- Every pattern is considered to be a theme and every object is treated as a separate object specification.
 -- Every dataset is discussed in precisely one theme
 -- Every theme will be explained in a chapter of its own.

   makeFspec :: Options -> Context -> Fspc
   makeFspec flags context =
      Fspc { fsfsid = makeFSid1 (name context)
            , datasets = datasets'
              -- serviceS contains the services defined in the ADL-script.
              -- services are meant to create user interfaces, programming interfaces and messaging interfaces.
              -- A generic user interface (the Monastir interface) is already available.
            , vplugs   = definedplugs
            , plugs    = allplugs++[conc2plug S]
            , gplugs   = makePlugs context
            , serviceS = attributes context
            , serviceG = serviceG'
            , services = [makeFservice context a | a <-attributes context]
            , vrules   = rules context
            , vrels    = declarations context
            , fsisa    = ctxisa context
            , vpatterns= patterns context
            , classdiagrams = [cdAnalysis context True pat | pat<-patterns context]
            , themes = themes'
            , violations = [(r,viol) |r<-rules context, viol<-ruleviols r]
            } where
        ruleviols (Ru{rrsrt=rtyp,rrant=ant,rrcon=con}) 
            | rtyp==Truth = contents$Cp con --everything not in con
            | rtyp==Implication = ant `contentsnotin` con 
            | rtyp==Equivalence = ant `contentsnotin` con ++ con `contentsnotin` ant 
            where
            contentsnotin x y = [p|p<-contents x, not$elem p (contents y)]
        ruleviols _ = [] 
        definedplugs = vsqlplugs ++ vphpplugs
        conc2plug :: Concept -> Plug
        conc2plug c = PlugSql {plname=name c, fields = [field (name c) (Tm (mIs c)) Nothing False True]}
        mor2plug :: Morphism -> Plug
        mor2plug  m'
         = if isInj && not isUni then mor2plug (flp m')
           else if isUni || isTot
           then PlugSql { plname = name m'
                        , fields = [field (name (source m')) (Tm (mIs (source m'))) Nothing False isUni
                                   ,field (name (target m')) (Tm m') Nothing (not isTot) isInj]}
           else if isInj || isSur then mor2plug (flp m')
           else PlugSql { plname = name m'
                        , fields = [field (name (source m')) (Fi {es=[Tm (mIs (source m')),F {es=[Tm m',flp (Tm m')]}]}
                                                           )      Nothing False False
                                   ,field (name (target m')) (Tm m') Nothing False False]}
           where
             mults = multiplicities m'
             isTot = Tot `elem` mults
             isUni = Uni `elem` mults
             isSur = Sur `elem` mults
             isInj = Inj `elem` mults

        allplugs = uniqueNames forbiddenNames
                    (definedplugs ++                  -- all plugs defined by the user
                     gPlugs       ++                  -- all plugs generated by the compiler
                     relPlugs                        -- all plugs for relations not touched by definedplugs and gplugs
                --     [conc2plug S]                    -- the universal singleton
                    )
          where
           gPlugs         = makePlugs context
           relPlugs       = map mor2plug (map makeMph (declarations context) >- (mors definedplugs++mors gPlugs))
           forbiddenNames = map name definedplugs

        uniqueNames :: [String]->[Plug]->[Plug]
        -- MySQL is case insensitive! (hence the lowerCase)
        uniqueNames given plgs = naming (\x y->x{plname=y}) -- renaming function for plugs
                                        (map ((.) lowerCase) -- functions that name a plug (lowercase!)
                                             (name:n1:n2:[(\x->lowerCase(name x ++ show n))
                                                         |n<-[(1::Integer)..]])
                                        )
                                        (map lowerCase given) -- the plug-names taken
                                        (map uniqueFields plgs)
          where n1 p = name p ++ plsource p
                n2 p = name p ++ pltarget p
                plsource p = name (source (fldexpr (head (fields (p)))))
                pltarget p = name (target (fldexpr (last (fields (p)))))
                uniqueFields plug = plug{fields = naming (\x y->x{fldname=y}) -- renaming function for fields
                                                  (map ((.) lowerCase) -- lowercase-yielding
                                                       (fldname:[(\x->fldname x ++ show n)
                                                                |n<-[(1::Integer)..]])
                                                  )
                                                  [] -- no field-names are taken
                                                  (fields plug)
                                        }
        vsqlplugs = map makeSqlPlug (ctxsql context)
        vphpplugs = map makePhpPlug (ctxphp context)
        -- services (type ObjectDef) can be generated from a basic ontology. That is: they can be derived from a set
        -- of relations together with multiplicity constraints. That is what serviceG does.
        -- This is meant to help a developer to build his own list of services, by providing a set of services that works.
        -- The developer will want to assign his own labels and maybe add or rearrange attributes.
        -- This is easier than to invent a set of services from scratch.
        -- At a later stage, serviceG will be used to generate semantic error messages. The idea is to compare a service 
        -- definition from the ADL-script with the generated service definition and to signal missing items.
        -- Rule: a service must be large enough to allow the required transactions to take place within that service.
        -- TODO: afdwingen dat attributen van elk object unieke namen krijgen.
        serviceG'
         = concat
           [ [ Obj { objnm   = name c
                   , objpos  = Nowhere
                   , objctx  = Tm $ I [c] c c True -- was: Tm $ V [cptS,c] (cptS,c)
                   , objats  = [ recur [] mph | mph<-relsFrom c]++
                                [ Obj { objnm =  name (srrel s)
                                      , objpos = Nowhere
                                      , objctx = disjNF (notCp (if source s==c then normExpr (srsig s) else flp (normExpr (srsig s))))
                                      , objats = []
                                      , objstrs = [] -- [["DISPLAYTEXT", if null (srxpl s) then (lang lng .assemble.normRule) (srsig s) else srxpl s]]
                                      }
                                | s<-signals context, source s==c || target s==c ]
                   , objstrs = []
                   }]
             ++let ats = [ Obj { objnm  = composedname mph
                               , objpos = Nowhere
                               , objctx = Tm (preventAmbig mph)
                               , objats = []
                               , objstrs= [] -- [["DISPLAYTEXT", name mph++" "++name (target mph)]]++props (multiplicities mph)
                               }
                           | mph<-relsFrom c, not (isSignal mph), Tot `elem` multiplicities mph]
               in [ Obj { objnm  = plural (language flags) (name c)
                        , objpos = Nowhere
                        , objctx = Tm $ I [S] S S True
                        , objats = [ Obj { objnm  = plural (language flags) (name c)
                                         , objpos = Nowhere
                                         , objctx = Tm $ V [S,c] (S,c)
                                         , objats = ( Obj { objnm = "nr"
                                                          , objpos = Nowhere
                                                          , objctx = Tm $ I [c] c c True
                                                          , objats = []
                                                          , objstrs= []
                                                          }): ats
                                         , objstrs= []
                                         }
                                   ]
                        , objstrs = []
                        }
                        | not (null ats)
                  ]
           | c<-concs context ]
           where
           composedname mph | inline mph = name mph++name (target mph)
                            | otherwise  = name (target mph) ++ "_of_" ++ name mph
           preventAmbig mp@(Mph{mphats=[]}) =  
              if (length [d|d@(Sgn {})<-declarations context, name mp==name d]) > 1
              then if mphyin mp 
                   then mp{mphats=[source mp,target mp]} 
                   else  mp{mphats=[target mp,source mp]}
              else mp 
           preventAmbig mp = mp
           relsFrom c = [Mph (name d) Nowhere [] (source d,target d) True d| d@(Sgn {})<-declarations context, source d == c]++
                        [flp (Mph (name d) Nowhere [] (source d,target d) True d)| d@(Sgn {})<-declarations context, target d == c]
           --TODO -> Explain all expressions (recursive) in the generated services
           --explained :: ObjectDef -> ObjectDef
           --explained obj@(Obj{objstrs=xs,objctx=e}) = obj{objstrs=["EXPLANATION: ", explain e]:xs} 
           recur :: [Morphism] -> Morphism -> ObjectDef
  -- WAAROM: Han, als de "shadow m" warning  (hieronder in recur) storend is, kan die dan in de module Adl opgelost worden?
           recur ms m
            = Obj { objnm   = composedname m
                  , objpos  = Nowhere
                  , objctx  = Tm (preventAmbig m)
                  , objats  = (map head.eqCl objnm)
                                [ recur (ms++[mph]) mph
                                | mph<-relsFrom (target m), not (isSignal mph)
                                , Tot `elem` multiplicities mph, not (isProperty mph)
                                , not (mph `elem` ms)]
                  , objstrs = [] -- [["DISPLAYTEXT", name m++" "++name (target m)]]++props (multiplicities m)
                  }
 
{- alleen nodig voor DISPLAYTEXT; herzien i.c.m. interface
           props ps = [if Sym `elem` ps && Asy `elem` ps then ["PROPERTY"] else
                       if Tot `elem` ps && Uni `elem` ps then ["ATTRIBUTE"] else
                       if Tot `elem` ps                  then ["NONEMPTY LIST"] else
                       if                  Uni `elem` ps then ["OPTIONAL FIELD"] else
                                                              ["LIST"]
                      ]
-}
{- A dataset combines all functions that share the same source.
   This is used for function point analysis (in which data sets are counted).
   It can also be used in code generate towards SQL, allowing the code generator to
   implement relations wider than 2, for likely (but yet to be proven) reasons of efficiency.
   Datasets are constructed from the basic ontology (i.e. the set of relations with their multiplicities.)
-}
        datasets'  = makeDatasets context
        --TODO -> assign themerules to themes and remove them from the Anything theme
        themes' = FTheme{tconcept=Anything,tfunctions=[],trules=themerules}
                  :(map maketheme$orderby [(wsopertheme oper, oper)
                                          |oper<-themeoperations, wsopertheme oper /= Nothing])
        --TODO -> by default CRUD operations of datasets, possibly overruled by SQL or PHP plugs
        themeoperations = datasetoperations++phpoperations++sqloperations
        phpoperations =[makeDSOperation$makePhpPlug phpplug | phpplug<-(ctxphp context)]
        sqloperations =[oper|obj<-ctxsql context, oper<-makeDSOperations (ctxks context) obj]
        datasetoperations = [oper|obj<-datasets', oper<-makeDSOperations (ctxks context) obj, objtheme obj /=S]
        --query copied from FSpec.hs revision 174
        themerules = [r|p<-patterns context, r<-declaredRules p++signals p, null (cpu r)]
        maketheme (Just c,fs) = FTheme{tconcept=c,tfunctions=fs,trules=[]}
        maketheme _ = error $ "Error in ADL2Fspec.hs module ADL2Fspec function makeFspec.maketheme: "
                           ++ "The theme must involve a concept."
        orderby :: (Eq a) => [(a,b)] ->  [(a,[b])]
        orderby xs =  [(x,[y|(x',y)<-xs,x==x']) |x<-rd [dx|(dx,_)<-xs] ]

{- makePlugs computes a set of SQL plugs to obtain wide tables with minimal redundancy.
   First, we determine classes of concepts that are related by bijective relations.   Code:   eqClass bi (concs context)
   Secondly, we choose one concept as the kernel of that plug. Code:   c = minimum [g|g<-concs context,g<=head cl]
   Thirdly, we need all univalent relations that depart from this class to be the attributes. Code:   dss cl
   Then, all these morphisms are made into fields. Code:   uniqueNames [mph2fld m | m<- mIs c: dss cs ]
   Now we have plugs. However, some are redundant. If there is a surjective relation from the kernel of plug p
   to the kernel of plug p' and there are no univalent relations departing from p',
   then plug p can serve as kernel for plug p'. Hence p' is redundant and can be removed. It is absorbed by p.
   So, we sort the plugs on length, the longest first. Code:   sort' ((0-).length.fields)
   Finally, we filter out all shorter plugs that can be represented by longer ones. Code: absorb
-}
   makePlugs :: Context -> [Plug]
   makePlugs context
    = (absorb . sort' ((0-).length.fields))
       [ PlugSql { fields = uniqueNames [mph2fld m | m<- mIs c: dss cl ]
                 , plname = name c
                 }
       | cl<-eqClass bi (concs context), c<-[minimum [g|g<-concs context,g<=head cl]] ]
      where
       mph2fld m = Fld { fldname = name m
                       , fldexpr = Tm m
                       , fldtype = if isSQLId then SQLId else SQLVarchar 255
                       , fldnull = not (Tot `elem` multiplicities m)          -- can there be empty field-values? 
                       , flduniq = Inj `elem` multiplicities m                -- are all field-values unique?
                       , fldauto = isSQLId }  -- is the field auto increment?
                   where isSQLId = isIdent m && null (contents (source m))
       c `bi` c' = not (null [mph| mph<-declarations context, isFunction mph, isFunction (flp mph)
                                 , source mph<=c && target mph<=c'  ||  source mph<=c' && target mph<=c])
{- The attributes of a plug are determined by the univalent relations that depart from the kernel. -}
       dss cl = [     makeMph d | d<-declarations context, Uni `elem` multiplicities      d , source d `elem` cl]++
                [flp (makeMph d)| d<-declarations context, Uni `elem` multiplicities (flp d), target d `elem` cl]

{- The names of all fields in a plug must be unique. This is done by adding numbers sequentially to double names only. -}
       uniqueNames flds = [if length cl==1 then f else f{ fldname = fldname f++show i }| cl<-eqCl fldname flds, (i,f)<-zip [0::Int ..] cl]

{- Absorb
If a concept is represented by plug p, and there is a surjective path between concept c' and c, then c' can be represented in the same table.
Hence, we do not need a separate plug for c' and it will be skipped.
-}
       absorb []     = []
       absorb (p:ps) = p: absorb [p'| p'<-ps, kernel p' `notElem` [target m| f<-fields p, Tm m<-[fldexpr f], Sur `elem` multiplicities m]]

       kernel :: Plug -> Concept -- determines the core concept of p. The plug serves as concept table for (kernel p).
       kernel p@(PlugSql{}) = source (fldexpr (head (fields p)))
       kernel _ = error("Fatal error in module ADL2Fspec, function \"kernel\"")


   makeSqlPlug :: ObjectDef -> Plug
   makeSqlPlug plug = PlugSql{fields=makeFields plug,plname=name plug}
      where
      makeFields :: ObjectDef -> [SqlField]
      makeFields obj =
        [Fld{fldname=name att
            ,fldexpr=objctx att
            ,fldtype=sqltp att
            ,fldnull= nul att
            ,flduniq= uniq att
            ,fldauto= att `elem` autoFields
            }
        | att<-objats obj
        ]
        where nul  att = not (Tot `elem` multiplicities (objctx att))
              uniq att = if null [0::Int|a' <- objats obj
                                 ,Uni `notElem` multiplicities (disjNF$F[flp$objctx att,objctx a'])]
                         then True else False
              autoFields = take 1 [a'| a'<-objats obj
                                     , sqltp a'==SQLId, not $ nul a'
                                     , uniq a', isIdent $ objctx a' ]
      sqltp :: ObjectDef -> SqlType
      sqltp obj = head $ [makeSqltype sqltp' | strs<-objstrs obj,('S':'Q':'L':'T':'Y':'P':'E':'=':sqltp')<-strs]
                         ++[SQLVarchar 255]
      makeSqltype :: String -> SqlType
      makeSqltype str = case str of
          ('V':'a':'r':'c':'h':'a':'r':_) -> SQLVarchar 255 --TODO number
          ('P':'a':'s':'s':_) -> SQLPass
          ('C':'h':'a':'r':_) -> SQLChar 255 --TODO number
          ('B':'l':'o':'b':_) -> SQLBlob
          ('S':'i':'n':'g':'l':'e':_) -> SQLSingle
          ('D':'o':'u':'b':'l':'e':_) -> SQLDouble
          ('u':'I':'n':'t':_) -> SQLuInt 4 --TODO number
          ('s':'I':'n':'t':_) -> SQLsInt 4 --TODO number
          ('I':'d':_) -> SQLId 
          ('B':'o':'o':'l':_) -> SQLBool
          _ -> SQLVarchar 255 --TODO number

   makePhpPlug :: ObjectDef -> Plug
   makePhpPlug plug = PlugPhp{args=makeArgs,returns=makeReturns,function=PhpAction{action=makeActiontype,on=[]}
                             ,phpfile="phpPlugs.inc.php",plname=name plug}
      where
      makeActiontype = head $ [case str of {"SELECT"->Read;
                                            "CREATE"->Create;
                                            "UPDATE"->Update;
                                            "DELETE"->Delete;
                                            _ -> error $ "Choose from ACTION=[SELECT|CREATE|UPDATE|DELETE].\n"  
                                                         ++ show (objpos plug)
                                           }
                     | strs<-objstrs plug,'A':'C':'T':'I':'O':'N':'=':str<-strs]
                     ++ [error $ "Specify ACTION=[SELECT|CREATE|UPDATE|DELETE] on phpplug.\n"  ++ show (objpos plug)]
      makeReturns = head $ [PhpReturn {retval=PhpObject{objectdf=oa,phptype=makePhptype oa}}
                           | oa<-objats plug, strs<-objstrs oa,"PHPRETURN"<-strs]
                           ++ [PhpReturn {retval=PhpNull}]
      makeArgs = [(i,PhpObject{objectdf=oa,phptype=makePhptype oa})
                 | (i,oa)<-zip [1..] (objats plug), strs<-(objstrs oa), elem "PHPARG" strs]
   makePhptype :: ObjectDef -> PhpType
   makePhptype objat = head $ [case str of {"String"->PhpString;
                                            "Int"->PhpInt;
                                            "Float"->PhpFloat;
                                            "Array"->PhpArray;
                                            _ -> error $ "Choose from PHPTYPE=[String|Int|Float|Array].\n"  
                                                        ++ show (objpos objat)
                                           }
                     | strs<-objstrs objat,'P':'H':'P':'T':'Y':'P':'E':'=':str<-strs]
                     ++ [error $ "Specify PHPTYPE=[String|Int|Float|Array] on PHPARG or PHPRETURN.\n"
                                 ++ show (objpos objat)]

   --DESCR -> Use for plugs that describe a single operation like PHP plugs
   makeDSOperation :: Plug -> WSOperation
   makeDSOperation PlugSql{} = error $ "Error in ADL2Fspec.hs module ADL2Fspec function makeDSOperation: "
                                    ++ "SQL plugs do not describe a single operation."
   makeDSOperation p@PlugPhp{} = 
       let nullval val = case val of
                         PhpNull    -> True
                         PhpObject{}-> False
           towsaction x = case x of {Create->WSCreate;Read->WSRead;Update->WSUpdate;Delete->WSDelete}
       in WSOper{wsaction=towsaction$action$function p
                 ,wsmsgin=[objectdf arg|(_,arg)<-args p,nullval$arg]
                 ,wsmsgout=[objectdf$retval$returns p|nullval$retval$returns p]
                 }
   --DESCR -> Use for objectdefs that describe all four CRUD operations like SQL plugs
   makeDSOperations :: [KeyDef] -> ObjectDef -> [WSOperation]
   makeDSOperations kds obj = 
       [WSOper{wsaction=WSCreate,wsmsgin=[obj],wsmsgout=[]}
       ,WSOper{wsaction=WSUpdate,wsmsgin=[obj],wsmsgout=[]}
       ,WSOper{wsaction=WSDelete,wsmsgin=[obj],wsmsgout=[]}]
     ++(if null keydefs then [readby []] else map readby keydefs)
       where
       keydefs = [kdats kd|kd<-kds,objtheme obj==keytheme kd]
       readby keyobj = WSOper{wsaction=WSRead,wsmsgin=keyobj,wsmsgout=[obj]}
   wsopertheme :: WSOperation -> Maybe Concept
   wsopertheme oper = 
      let msgthemes = map objtheme (wsmsgin oper++wsmsgout oper)
      in if samethemes msgthemes then Just$head msgthemes else Nothing
   
   --REMARK -> called samethemes because only used in this context
   samethemes :: (Eq a) => [a] -> Bool
   samethemes [] = False
   samethemes (_:[]) = True
   samethemes (c:c':cs) = if c==c' then samethemes (c':cs) else False

   --DESCR -> returns the concept on which the objectdef acts 
   objtheme :: ObjectDef -> Concept
   objtheme obj = case source$objctx obj of
      S -> let objattheme = [objtheme objat|objat<-objats obj]
           in if (not.null) objattheme then head objattheme
              else S
      c -> c

   --DESCR -> returns the concept on which the keydef is defined 
   keytheme :: KeyDef -> Concept
   keytheme kd = source$kdctx kd

   makeFservice :: Context -> ObjectDef -> Fservice
   makeFservice _ obj
    = Fservice{
        objectdef = obj  -- the object from which the service is drawn
      }

   makeFSid1 :: String -> FSid
   makeFSid1 s = FS_id (firstCaps s)  -- We willen geen spaties in de naamgeveing.

   lowerCase :: String->String
   lowerCase = map toLower -- from Char

--   fst3 :: (a,b,c) -> a
--   fst3 (a,_,_) = a
--   snd3 :: (a,b,c) -> b
--   snd3 (_,b,_) = b


