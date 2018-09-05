module Processing.Typecheck (
    typeOf,
    generateContextFromEquations,
    desugarTypes
) where

import Data.Bifunctor
import Data.Terms

import Debug.Trace

matchType :: MatchPattern -> TermType -> Context
matchType (MatchVar s) t = [(s, VarBind t)]
matchType (MatchRecord ps) (TypeRecord ts) =
    case sequence $ getRecordType ps ts of
        Nothing -> error "Invalid Record Match!"
        (Just mp) -> concat $ map (uncurry matchType) mp
matchType p t = error $ "Invalid Match: " ++ (show p) ++ " for type " ++ (show t)

generateContextFromEquations :: EqnContext -> TypeContext -> Context
generateContextFromEquations eqns tc = gcfe' [] eqns
    where
        dst = desugarTypes tc
        st = sugarTypes tc
        gcfe' :: Context -> EqnContext -> Context
        gcfe' ctx [] = ctx
        gcfe' ctx ((name, term):eqns) =
            let tt = getNameForType tc $ typeof ctx $ dst term
            in gcfe' (ctx ++ [(name, VarBind tt)]) eqns

mapTermTypes :: (TermType -> TermType) -> Term -> Term
mapTermTypes f t = mapTerm g t
    where g :: Term -> Term
          g (TermAbs i name ty t1) = TermAbs i name (f ty) t1
          g t = t

desugarTypes :: TypeContext -> Term -> Term
desugarTypes tc = mapTermTypes (getTypeForName tc)

sugarTypes :: TypeContext -> Term -> Term
sugarTypes tc = mapTermTypes (getNameForType tc)

desugarBindingType :: TypeContext -> Binding -> Binding
desugarBindingType tc (VarBind tt) = VarBind xs
    where xs = getTypeForName tc tt
desugarBindingType _ b = error $ "Can't get context type for " ++ (show b)

typeOf :: Context -> TypeContext -> Term -> TermType
typeOf ctx tc term = getNameForType tc $ typeof ctx' $ desugarTypes tc term
    where ctx' = map (second (desugarBindingType tc)) ctx

typeof :: Context -> Term -> TermType
typeof ctx term
    | TermTrue _ <- term
    = TypeBool
    
    | TermFalse _ <- term
    = TypeBool

    | TermNat _ _ <- term
    = TypeNat

    | TermString _ _ <- term
    = TypeString

    | TermSucc _ t1 <- term
    = if typeof ctx t1 == TypeNat then
        TypeNat
      else error "Subterm of succ must be type Nat"

    | TermPred _ t1 <- term
    = if typeof ctx t1 == TypeNat then
        TypeNat
      else error "Subterm of pred must be type Nat"
    
    | TermIsZero _ t1 <- term
    = if typeof ctx t1 == TypeNat then
        TypeBool
      else error "Subterm of iszero must be type Nat"

    | TermTup _ ts <- term
    = TypeTuple $ map (typeof ctx) ts

    | TermTupProjection _ t1 n <- term
    , (TypeTuple ts) <- typeof ctx t1
    = if n < 0 || n >= (fromIntegral $ length ts)
        then error "Tuple index out of bounds of the tuple"
        else ts !! (fromIntegral n)

    | TermIf _ t1 t2 t3 <- term
    = if typeof ctx t1 == TypeBool then
        let typeT2 = typeof ctx t2 in
            if typeof ctx t3 == typeT2 then
                typeT2
            else error "Branches of Conditional have different Types"
      else error "Guard of conditional not a boolean"

    | TermRecord _ ts <- term
    = TypeRecord $ map (second $ typeof ctx) ts

    | TermRecordProjection _ t1 l <- term
    , (TypeRecord ts) <- typeof ctx t1
    = case lookup l ts of
        Nothing -> error ("Label '" ++ l ++ "' is not a member of record")
        Just t -> t

    | TermLet _ p t1 t2 <- term
    = let ty1 = typeof ctx t1
          ctx' = matchType p ty1
      in typeof (ctx ++ ctx') t2

    | TermVar _ n <- term
    , (Just tv) <- getTypeFromContext ctx n
    = tv

    | TermAbs _ x ty1 t2 <- term
    = let ctx' = addBinding ctx x (VarBind (ty1))
          ty2  = typeof ctx' t2
      in TypeArrow ty1 ty2

    | TermApp _ t1 t2 <- term
    = let ty1 = typeof ctx t1
          ty2 = typeof ctx t2
      in case ty1 of
        (TypeArrow ty1' ty2') -> if ty2 == ty1'
            then ty2'
            else error $ "Parameter type mismatch: " ++ (show ty2) ++ " != " ++ (show ty1')
        _ -> error "Expected Arrow Type"
