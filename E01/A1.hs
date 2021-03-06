-- We need this declarations if we want to refer to this file (module) from
-- another file (module) in Haskell:
-- Module names must start with an uppercase character.
-- We use the following convention: E for Exercise and A for Assignment
module E01.A1 where

-- Explicit
square :: [Int] -> [Int]
square [] = []
square (x:xs) = x^2:square xs


-- Slightly advanced: List comprehensions
square' :: [Int] -> [Int]
square' xs = [x^2 | x<-xs]


-- Currently very advanced:
-- We can use the higher order function map which constructs a new list out of
-- a given list, by applying a given function f to each element of the old
-- list.
{-
map :: (a -> b) -> [a] -> [b]
map _ [] = []
map f (a:as) = f a:map f as
-}

square'' :: [Int] -> [Int]
square'' = map (^2)

-- (b):
-- Let's start with a basic solution:
at :: [Int] -> Int -> Int
at (x:xs) n = if n == 0 then x else at xs (n-1)

-- Problems:
-- * what happens if we pass in a negative index?
-- * what happens if the list is too short?
-- * the if looks ugly (to an Haskell programmer)

-- We can do better:
at' :: [Int] -> Int -> Int
-- The | denotes a so called "guard" that specifies an additional condition
-- for the pattern match
at' _      n | n < 0 = error "E01.A2: negative index"
at' []     _         = error "E01.A2: index too large"
at' (x:_)  0         = x
at' (_:xs) n         = at' xs (n-1)

-- Note:
-- The Haskell Prelude already includes the operator (!!) which does the same
-- as at for any type of list (not just [Int]), e.g. [1, 2, 3] !! 1 = 2

-- (c):
dup :: [Int] -> [Int] -> [Int]
dup []     _  = []
dup _      [] = []
dup (x:xs) ys = if contains x ys then x:dup xs ys
                                 else dup xs ys

-- Note: The Haskell Prelude obviously already includes a function that does
-- the same as contains called elem.


contains :: Int -> [Int] -> Bool
contains _ []     = False
--contains x (y:ys) = if x == y then True else contains x ys
-- if-then-else is valid but unnecessary as the result of then and else is
-- already Bool
contains x (y:ys) = x == y || contains x ys

-- Advanced:
-- We can use the any function which is True if any item evaluates to True
-- under a given predicate
contains' :: Int -> [Int] -> Bool
contains' x ys = any (==x) ys

