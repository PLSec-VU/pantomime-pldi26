module Adder
  ( add,
    leak,
    sim,
    proj,
    theory,
  )
where

import qualified Pantomime as P
import qualified Pantomime.Base as Base

add :: Maybe Int -> (Maybe Int, Maybe Int) -> (Maybe Int, Maybe Int)
add _ (Just 0, Just b) = (Nothing, Just b)
add _ (Just a, Just b) = (Just (a + b), Nothing)
add s _ = (Nothing, s)

isJust :: Maybe a -> Bool
isJust (Just _) = True
isJust _ = False

leak :: () -> (Maybe Int, Maybe Int) -> ((), (Maybe Bool, Bool))
leak _ (Just a, i2) = ((), (Just (a == 0), isJust i2))
leak _ (Nothing, i2) = ((), (Nothing, isJust i2))

sim :: Bool -> (Maybe Bool, Bool) -> (Bool, Bool)
sim _ (Just True, True) = (False, True)
sim _ (Just False, True) = (True, False)
sim s _ = (False, s)

proj :: Maybe Int -> ((), Bool)
proj (Just _) = ((), True)
proj Nothing = ((), False)

{-# ANN theory (P.Theory Base.axioms) #-}
theory :: Maybe Int -> (Maybe Int, Maybe Int) -> Bool
theory =
  P.pantomime
    P.Pantomime
      { observation = isJust,
        implementation = add,
        leakage = leak,
        simulator = sim,
        projection = proj
      }
