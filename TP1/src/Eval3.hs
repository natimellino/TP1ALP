module Eval3
  ( eval
  , State
  )
where

import           AST
import qualified Data.Map.Strict               as M
import           Data.Strict.Tuple

-- Estados
type State = (M.Map Variable Int, Integer)

-- Estado nulo
initState :: State
initState = (M.empty, 0)

-- Busca el valor de una variable en un estado
lookfor :: Variable -> State -> Either Error Int
lookfor v (m, _) = case M.lookup v m of
                    Nothing -> Left UndefVar
                    Just n -> Right n

-- Cambia el valor de una variable en un estado
update :: Variable -> Int -> State -> State
update x n (m, w) = (M.insert x n m, w)

-- Suma un costo dado al estado
addWork :: Integer -> State -> State
addWork n (m, w) = (m, w + n)

-- Evalua un programa en el estado nulo
eval :: Comm -> Either Error State
eval p = stepCommStar p initState

-- Evalua multiples pasos de un comnado en un estado,
-- hasta alcanzar un Skip
stepCommStar :: Comm -> State -> Either Error State
stepCommStar Skip s = return s
stepCommStar c    s = do
  (c' :!: s') <- stepComm c s
  stepCommStar c' s'

-- Evalua un paso de un comando en un estado dado
stepComm :: Comm -> State -> Either Error (Pair Comm State)
stepComm Skip s = Right (Skip :!: s)
stepComm (Let x e) s = case evalExp e s of
                        Left error -> Left error
                        Right (n :!: s') -> let s'' = update x n s'
                                            in Right (Skip :!: s'')
stepComm (Seq Skip c1) s = Right (c1 :!: s)                                      
stepComm (Seq c0 c1) s = case stepComm c0 s of
                           Left error -> Left error
                           Right (c0' :!: s') -> Right ((Seq c0' c1) :!: s')
stepComm (IfThenElse e c0 c1) s = case evalExp e s of
                                    Left error -> Left error
                                    Right (b :!: s') -> if b then Right (c0 :!: s')
                                                             else Right (c1 :!: s')
stepComm w@(While e c) s = case evalExp e s of
                            Left error -> Left error
                            Right (b :!: s') -> if b then Right ((Seq c w) :!: s')
                                                     else Right (Skip :!: s')

-- Evalua una expresion
evalExp :: Exp a -> State -> Either Error (Pair a State)
-- Expresiones enteras
evalExp (Const n) s = Right (n :!: s)
evalExp (Var x) s = case lookfor x s of
                      Left error -> Left error
                      Right n -> Right (n :!: s)
evalExp (UMinus e) s = case evalExp e s of
                        Left error -> Left error
                        Right (n :!: s') -> Right ((-n) :!: (addWork 1 s'))
evalExp (Plus e e') s = case evalExp e s of
                          Left error -> Left error
                          Right (n0 :!: s') -> case evalExp e' s' of
                                                 Left error -> Left error
                                                 Right (n1 :!: s'') -> Right (n0 + n1 :!: (addWork 1 s''))
evalExp (Minus e e') s = case evalExp e s of
                          Left error -> Left error
                          Right (n0 :!: s') -> case evalExp e' s' of
                                                 Left error -> Left error
                                                 Right (n1 :!: s'') -> Right (n0 - n1 :!: (addWork 1 s''))
evalExp (Times e e') s = case evalExp e s of
                          Left error -> Left error
                          Right (n0 :!: s') -> case evalExp e' s' of
                                                 Left error -> Left error
                                                 Right (n1 :!: s'') -> Right (n0 * n1 :!: (addWork 2 s''))
evalExp (Div e e') s = case evalExp e s of
                          Left error -> Left error
                          Right (n0 :!: s') -> case evalExp e' s' of
                                                 Left error -> Left error
                                                 Right (0 :!: _) -> Left DivByZero
                                                 Right (n1 :!: s'') -> Right (div n0 n1 :!: (addWork 2 s''))
evalExp (EAssgn x e) s = case evalExp e s of
                          Left error -> Left error
                          Right (n :!: s') -> let s'' = update x n s' in Right (n :!: s'')                            
evalExp (ESeq e e') s = case evalExp e s of
                          Left error -> Left error
                          Right (_ :!: s') -> evalExp e' s'
-- Expresiones booleanas
evalExp BTrue s = Right (True :!: s)
evalExp BFalse s = Right (False :!: s)
evalExp (Not e) s = case evalExp e s of
                      Left error -> Left error
                      Right (b :!: s') -> Right (not b :!: (addWork 1 s'))
evalExp (Lt e e') s = case evalExp e s of
                        Left error -> Left error
                        Right (n0 :!: s') -> case evalExp e' s' of
                                               Left error -> Left error
                                               Right (n1 :!: s'') -> Right (n0 < n1 :!: (addWork 1 s''))
evalExp (Gt e e') s = case evalExp e s of
                        Left error -> Left error
                        Right (n0 :!: s') -> case evalExp e' s' of
                                               Left error -> Left error
                                               Right (n1 :!: s'') -> Right (n0 > n1 :!: (addWork 1 s''))
evalExp (Eq e e') s = case evalExp e s of
                        Left error -> Left error
                        Right (n0 :!: s') -> case evalExp e' s' of
                                               Left error -> Left error
                                               Right (n1 :!: s'') -> Right (n0 == n1 :!: (addWork 1 s''))
evalExp (NEq e e') s = case evalExp e s of
                        Left error -> Left error
                        Right (n0 :!: s') -> case evalExp e' s' of
                                               Left error -> Left error
                                               Right (n1 :!: s'') -> Right (n0 /= n1 :!: (addWork 1 s''))
evalExp (And e e') s = case evalExp e s of
                        Left error -> Left error
                        Right (n0 :!: s') -> case evalExp e' s' of
                                               Left error -> Left error
                                               Right (n1 :!: s'') -> Right (n0 && n1 :!: (addWork 1 s''))                                                     
evalExp (Or e e') s = case evalExp e s of
                        Left error -> Left error
                        Right (n0 :!: s') -> case evalExp e' s' of
                                               Left error -> Left error
                                               Right (n1 :!: s'') -> Right ((n0 || n1) :!: (addWork 1 s''))
