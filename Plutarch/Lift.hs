{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE UndecidableSuperClasses #-}

{- |
Module: Plutarch.Lift
Description: Conversion to and from Plutarch terms and Haskell types

This module defines functions, associated type families, and newtypes for use with
[@DerivingVia@](https://ryanglscott.github.io/papers/deriving-via.pdf) to allow
Plutarch to convert to and from PTypes and Haskell types.
-}
module Plutarch.Lift (
  -- * Converstion between Plutarch terms and Haskell types
  pconstant,
  plift,
  plift',
  LiftError,

  -- * Define your own conversion
  PConstantDecl (..),
  PLift,
  PConstant,
  DerivePConstantDirect (..),
  DerivePConstantViaNewtype (..),
  DerivePConstantViaBuiltin (..),

  -- * Internal use
  PUnsafeLiftDecl (..),
) where

import Control.Lens ((^?))
import Data.Coerce (Coercible, coerce)
import Data.Kind (Constraint, Type)
import GHC.Stack (HasCallStack)
import Plutarch.Evaluate (EvalError, evalScript)
import Plutarch.Internal (ClosedTerm, PType, Term, compile, punsafeConstantInternal)
import qualified Plutus.V1.Ledger.Scripts as Scripts
import qualified PlutusCore as PLC
import PlutusCore.Builtin (ReadKnownError, readKnownConstant)
import PlutusCore.Evaluation.Machine.Exception (ErrorWithCause (ErrorWithCause), MachineError, _UnliftingErrorE)
import PlutusTx (BuiltinData, Data, builtinDataToData, dataToBuiltinData)
import PlutusTx.Builtins.Class (FromBuiltin, ToBuiltin, fromBuiltin, toBuiltin)
import qualified UntypedPlutusCore as UPLC

{- |
Laws:
 - It must be that @PConstantRepr (PLifted p)@ when encoded as a constant
   in UPLC (via the 'UntypedPlutusCore.Constant' constructor) is a valid @p@.
-}
class (PConstantDecl (PLifted p), PConstanted (PLifted p) ~ p) => PUnsafeLiftDecl (p :: PType) where
  type PLifted p = (r :: Type) | r -> p

{- | Class of Haskell types `h` that can be represented as a Plutus core builtin
and converted to a Plutarch type.

The Plutarch type is determined by `PConstanted h`. Its Plutus Core representation is given by `PConstantRepr h`.

This typeclass is closely tied with 'PLift'.

Laws:
 - @pconstantFromRepr . pconstantToRepr ≡ Just@
 - @(pconstantToRepr <$>) . pconstantFromRepr ≡ Just@
 - @plift . pfromData . punsafeCoerce . pconstant . toData ≡ id@
 - @fromData . plift . pforgetData . ptoData . pconstant ≡ Just@

These laws must be upheld for the sake of soundness of the type system.
-}
class
  ( PUnsafeLiftDecl (PConstanted h)
  , PLC.DefaultUni `PLC.Includes` PConstantRepr h
  ) =>
  PConstantDecl (h :: Type)
  where
  type PConstantRepr h :: Type
  type PConstanted h :: PType
  pconstantToRepr :: h -> PConstantRepr h
  pconstantFromRepr :: PConstantRepr h -> Maybe h

{- | Class of Plutarch types `p` that can be converted to/from a Haskell type.

The Haskell type is determined by `PLifted p`.

This typeclass is closely tied with 'PConstant'.
-}
type PLift :: PType -> Constraint
type PLift = PUnsafeLiftDecl

{- | Create a Plutarch-level constant, from a Haskell value.
Example:
> pconstant @PInteger 42
-}
pconstant :: forall p s. PLift p => PLifted p -> Term s p
pconstant x = punsafeConstantInternal $ PLC.someValue @(PConstantRepr (PLifted p)) @PLC.DefaultUni $ pconstantToRepr x

-- | Error during script evaluation.
data LiftError
  = LiftError_EvalError EvalError
  | LiftError_ReadKnownError (ErrorWithCause ReadKnownError (MachineError PLC.DefaultFun))
  | LiftError_FromRepr
  deriving stock (Eq)

{- | Convert a Plutarch term to the associated Haskell value. Fail otherwise.
This will fully evaluate the arbitrary closed expression, and convert the resulting value.
-}
plift' :: forall p. PUnsafeLiftDecl p => ClosedTerm p -> Either LiftError (PLifted p)
plift' prog = case evalScript (compile prog) of
  (Right (Scripts.unScript -> UPLC.Program _ _ term), _, _) ->
    case readKnownConstant @_ @(PConstantRepr (PLifted p)) @(MachineError PLC.DefaultFun) Nothing term of
      Right r -> case pconstantFromRepr r of
        Just h -> Right h
        Nothing -> Left LiftError_FromRepr
      Left e -> Left $ LiftError_ReadKnownError e
  (Left e, _, _) -> Left $ LiftError_EvalError e

-- | Like `plift'` but throws on failure.
plift :: forall p. (HasCallStack, PLift p) => ClosedTerm p -> PLifted p
plift prog = case plift' prog of
  Right x -> x
  Left LiftError_FromRepr -> error "plift failed: pconstantFromRepr returned 'Nothing'"
  Left (LiftError_ReadKnownError (ErrorWithCause e causeMaybe)) ->
    let unliftErrMaybe = e ^? _UnliftingErrorE
     in error $
          "plift failed: incorrect type: "
            <> maybe "absurd evaluation failure" show unliftErrMaybe
            <> "\n"
            <> maybe "" (\x -> "cause: " <> show x) causeMaybe
  Left (LiftError_EvalError e) -> error $ "plift failed: erring term: " <> show e

{- | Newtype wrapper for deriving @PConstant@ when the wrapped type is directly
represented by a builtin UPLC type that is /not/ @Data@.

  Ex: @PInteger@ is directly represented as a builtin integer.
-}
newtype DerivePConstantDirect (h :: Type) (p :: PType) = DerivePConstantDirect h

instance
  (PLift p, PLC.DefaultUni `PLC.Includes` h) =>
  PConstantDecl (DerivePConstantDirect h p)
  where
  type PConstantRepr (DerivePConstantDirect h p) = h
  type PConstanted (DerivePConstantDirect h p) = p
  pconstantToRepr = coerce
  pconstantFromRepr = Just . coerce

{- | Newtype wrapper for deriving @PConstant@ when the wrapped type is represented
indirectly by a builtin UPLC type that is /not/ @Data@.

  Ex: @PPubKeyHash@ is a newtype to a @PByteString@ and @PByteString@ is directly
  represented as a builtin bytestring.

Polymorphic types can be derived as follows:

>newtype Foo a = Foo a
>
>newtype PFoo a s = PFoo (Term s a)
>
>instance forall a. PLift a => PUnsafeLiftDecl (PFoo a) where
>  type PLifted (PFoo a) = Foo (PLifted a)
>
>deriving via
>  ( DerivePConstantViaNewtype
>      (Foo a)
>      (PFoo (PConstanted a))
>      (PConstanted a)
>  )
>  instance
>    PConstant a =>
>    PConstantDecl (Foo a)
-}
newtype
  DerivePConstantViaNewtype
    (h :: Type)
    (p :: PType) -- PType to associate with the newtype
    (p' :: PType) -- Underlying UPLC representation type
  = -- | The Haskell newtype we are deriving a @PConstant@ instance for
    DerivePConstantViaNewtype h

{- | Type synonym to simplify deriving of @PConstant@ via @DerivePConstantViaNewtype@.

A newtype @Foo a@ is considered "Constantable" if:

- The wrapped type @a@ has a @PConstant@ instance.
- The lifted type of @a@ has a @PUnsafeLiftDecl@ instance.
- There is type equality between @a@ and @PLifted (PConstanted a)@.

These constraints are sufficient to derive a @PConstant@ instance for the newtype.

For deriving @PConstant@ for a wrapped type represented in UPLC as @Data@, see
@DerivePConstantViaData@.
-}
type PConstant :: Type -> Constraint
type PConstant a = (a ~ PLifted (PConstanted a), PConstantDecl a)

instance (PLift p, PLift p', Coercible h (PLifted p')) => PConstantDecl (DerivePConstantViaNewtype h p p') where
  type PConstantRepr (DerivePConstantViaNewtype h p p') = PConstantRepr (PLifted p')
  type PConstanted (DerivePConstantViaNewtype h p p') = p
  pconstantToRepr x = pconstantToRepr @(PLifted p') $ coerce x
  pconstantFromRepr x = coerce $ pconstantFromRepr @(PLifted p') x

class ToBuiltin' a arep | a -> arep where
  toBuiltin' :: a -> arep

class FromBuiltin' arep a | arep -> a where
  fromBuiltin' :: arep -> a

instance {-# OVERLAPPABLE #-} ToBuiltin a arep => ToBuiltin' a arep where
  toBuiltin' = toBuiltin

instance {-# OVERLAPPABLE #-} FromBuiltin arep a => FromBuiltin' arep a where
  fromBuiltin' = fromBuiltin

instance ToBuiltin' Data BuiltinData where
  toBuiltin' = dataToBuiltinData

instance FromBuiltin' BuiltinData Data where
  fromBuiltin' = builtinDataToData

newtype DerivePConstantViaBuiltin (h :: Type) (p :: PType) (p' :: PType) = DerivePConstantViaBuiltin h

instance
  ( PLift p
  , PLift p'
  , Coercible h h'
  , ToBuiltin' (PLifted p') h'
  , FromBuiltin' h' (PLifted p')
  ) =>
  PConstantDecl (DerivePConstantViaBuiltin h p p')
  where
  type PConstantRepr (DerivePConstantViaBuiltin h p p') = PConstantRepr (PLifted p')
  type PConstanted (DerivePConstantViaBuiltin h p p') = p
  pconstantToRepr x = pconstantToRepr @(PLifted p') $ fromBuiltin' (coerce x :: h')
  pconstantFromRepr x = coerce (toBuiltin' <$> pconstantFromRepr @(PLifted p') x :: Maybe h')
