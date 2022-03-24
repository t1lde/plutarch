{-# LANGUAGE UndecidableInstances #-}
{-# OPTIONS_GHC -Wno-orphans #-}

module Plutarch.Api.V1.These (PTheseData (..)) where

import qualified GHC.Generics as GHC
import qualified Generics.SOP as SOP
import Plutarch.DataRepr (PIsDataReprInstances (PIsDataReprInstances))
import Plutarch.Lift
  ( PConstantRepr,
    PConstanted,
    PLifted,
    PUnsafeLiftDecl,
    pconstantFromRepr,
    pconstantToRepr,
  )
import qualified Plutus.V1.Ledger.Api as Plutus
import qualified PlutusTx.These as PlutusThese

data PTheseData (a :: PType) (b :: PType) (s :: S)
  = PDThis (Term s (PDataRecord '["_0" ':= a]))
  | PDThat (Term s (PDataRecord '["_0" ':= b]))
  | PDThese (Term s (PDataRecord '["_0" ':= a, "_1" ':= b]))
  deriving stock (GHC.Generic)
  deriving anyclass (SOP.Generic, PIsDataRepr)
  deriving
    (PlutusType, PIsData)
    via PIsDataReprInstances (PTheseData a b)

instance
  ( Plutus.ToData (PLifted a),
    Plutus.ToData (PLifted b),
    Plutus.FromData (PLifted a),
    Plutus.FromData (PLifted b),
    PLift a,
    PLift b
  ) =>
  PUnsafeLiftDecl (PTheseData a b)
  where
  type PLifted (PTheseData a b) = PlutusThese.These (PLifted a) (PLifted b)

{- TODO: Make PTheseData an instance of PConstant:
         https://github.com/Plutonomicon/plutarch/pull/355
-}

instance
  ( PLifted (PConstanted a) ~ a,
    Plutus.ToData b,
    Plutus.FromData b,
    Plutus.ToData a,
    Plutus.FromData a,
    PConstant a,
    PLifted (PConstanted b) ~ b,
    Plutus.FromData b,
    Plutus.ToData b,
    PConstant b
  ) =>
  PConstant (PlutusThese.These a b)
  where
  type PConstantRepr (PlutusThese.These a b) = [(Plutus.Data, Plutus.Data)]
  type PConstanted (PlutusThese.These a b) = PTheseData (PConstanted a) (PConstanted b)
  pconstantToRepr _t = undefined
  pconstantFromRepr _t = undefined
