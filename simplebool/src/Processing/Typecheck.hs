module Processing.Typecheck (
    typeof
) where

import Data.Terms


typeof :: Context -> Term -> TermType
typeof ctx term
    | TermTrue _ <- term
    = TypeBool
    
    | TermFalse _ <- term
    = TypeBool

    | TermIf _ t1 t2 t3 <- term
    = if typeof ctx t1 == TypeBool then
        let typeT2 = typeof ctx t2 in
            if typeof ctx t3 == typeT2 then
                typeT2
            else error "Branches of Conditional have different Types"
      else error "Guard of conditional not a boolean"

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
            else error "Parameter type mismatch."
        _ -> error "Expected Arrow Type"
