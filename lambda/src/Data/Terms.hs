module Data.Terms (
    Term(..),
    Info(..),
    Binding(..),
    Context(..),
    showTermInContext,
    isValue
) where

data Info =
    Info {
        line:: Int,
        column:: Int
    }
    | Blank

instance Show Info where
    show (Info line column) = "{ line: " ++ (show line) ++ ", column: " ++ (show column) ++ "}"
    show Blank = ""

data Term = 
      TermVar Info Int Int
    | TermAbs Info String Term
    | TermApp Info Term Term
    deriving (Show)

data Binding = NameBind
    deriving (Show)

type Context = [(String, Binding)]

contextLength :: Context -> Int
contextLength = length

indexToName :: Context -> Int -> String
indexToName ctx n = fst $ ctx !! n

inContext :: String -> Context -> Bool
inContext name = any (\(s, _) -> name == s)

pickFreshName :: Context -> String -> (Context, String)
pickFreshName ctx x
    | x `inContext` ctx
    = pickFreshName ctx (x ++ "'")

    | otherwise = (ctx ++ [(x, NameBind)], x)

showTermInContext :: Context -> Term -> String
showTermInContext ctx (TermAbs _ x t1) =
    let (ctx', x') = pickFreshName ctx x in
        "(λ" ++ x' ++ ". " ++ showTermInContext ctx' t1 ++ ")"
showTermInContext ctx (TermApp _ t1 t2) =
    "(" ++ showTermInContext ctx t1 ++ " " ++ showTermInContext ctx t2 ++ ")"
showTermInContext ctx (TermVar _ x n) =
    if contextLength ctx == n then
        indexToName ctx x
    else
        "[bad index]"

isValue :: Term -> Bool
isValue (TermAbs _ _ _) = True
isValue _ = False