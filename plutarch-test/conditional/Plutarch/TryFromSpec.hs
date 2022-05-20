{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE UndecidableInstances #-}

module Plutarch.TryFromSpec (spec) where

import Data.Coerce (coerce)

-- Haskell imports
import qualified GHC.Generics as GHC

import Generics.SOP (Generic, I (I))

-- Plutus and PlutusTx imports

import PlutusTx (
  Data (B, Constr, I),
 )

-- Plutarch imports
import Plutarch.Prelude

import Plutarch.Test

import Plutarch.Unsafe (
  punsafeCoerce,
 )

import Plutarch.Api.V1 (
  PAddress,
  PDatum,
  PDatumHash,
  PMaybeData (PDJust),
  PScriptContext,
  PScriptPurpose (PSpending),
  PTuple,
  PTxInInfo,
  PTxInfo,
  PTxOut,
  PTxOutRef,
  PValidator,
 )

import Plutarch.Builtin (
  PBuiltinMap,
  pforgetData,
  ppairDataBuiltin,
 )

import Plutarch.TryFrom (
  PTryFromExcess,
  ptryFrom',
 )

import Plutarch.Reducible (Reduce, Reducible)

import Plutarch.ApiSpec (invalidContext1, validContext0)
import Plutarch.DataRepr (PIsDataReprInstances (PIsDataReprInstances))

import Test.Hspec

spec :: Spec
spec = do
  describe "verification_untrusted_data" . plutarchDevFlagDescribe . pgoldenSpec $ do
    "erroneous" @\ do
      "(String, Integer) /= (String, String)"
        @| checkDeep
          @(PBuiltinPair (PAsData PInteger) (PAsData PByteString))
          @(PBuiltinPair (PAsData PByteString) (PAsData PByteString))
          (pdata $ ppairDataBuiltin # (pdata $ pconstant "foo") # (pdata $ pconstant "bar"))
        @-> pfails
      "[String] /= [Integer]"
        @| checkDeep
          @(PBuiltinList (PAsData PByteString))
          @(PBuiltinList (PAsData PInteger))
          (pdata $ (pcons # (pdata $ pconstant 3)) #$ (psingleton # (pdata $ pconstant 4)))
        @-> pfails
      "A { test := Integer, test2 := Integer } /= { test := String, test2 := Integer }"
        @| checkDeep
          @(PDataRecord (("foo" ':= PInteger) ': ("bar" ':= PInteger) ': '[]))
          @(PDataRecord (("foo" ':= PByteString) ': ("bar" ':= PInteger) ': '[]))
          (pdata (pdcons @"foo" # (pdata $ pconstant "baz") #$ pdcons @"bar" # (pdata $ pconstant 42) # pdnil))
        @-> pfails
      "Map Int String /= Map Int Int"
        @| mapTestFails @-> pfails
      "PDataSum constr 2"
        @| checkDeep
          @(PDataSum '[ '["i1" ':= PInteger, "b2" ':= PByteString]])
          @(PDataSum '[ '["i1" ':= PInteger, "b2" ':= PByteString], '["i3" ':= PInteger, "b4" ':= PByteString]])
          (punsafeCoerce $ pconstant $ Constr 1 [PlutusTx.I 5, B "foo"])
          @-> pfails
      "PDataSum wrong record type"
        @| checkDeep
          @(PDataSum '[ '["i1" ':= PInteger, "b2" ':= PByteString], '["i3" ':= PByteString, "b4" ':= PByteString]])
          @(PDataSum '[ '["i1" ':= PInteger, "b2" ':= PByteString], '["i3" ':= PInteger, "b4" ':= PByteString]])
          (punsafeCoerce $ pconstant $ Constr 2 [PlutusTx.I 5, B "foo"])
          @-> pfails
    "working" @\ do
      "(String, String) == (String, String)"
        @| checkDeep
          @(PBuiltinPair (PAsData PByteString) (PAsData PByteString))
          @(PBuiltinPair (PAsData PByteString) (PAsData PByteString))
          (pdata $ ppairDataBuiltin # (pdata $ pconstant "foo") # (pdata $ pconstant "bar"))
        @-> psucceeds
      "[String] == [String]"
        @| checkDeep
          @(PBuiltinList (PAsData PByteString))
          @(PBuiltinList (PAsData PByteString))
          (pdata $ (pcons # (pdata $ pconstant "foo")) #$ (psingleton # (pdata $ pconstant "bar")))
        @-> psucceeds
      "A { test := Integer, test2 := Integer } == { test := Integer, test2 := Integer }"
        @| checkDeep
          @(PDataRecord (("foo" ':= PInteger) ': ("bar" ':= PInteger) ': '[]))
          @(PDataRecord (("foo" ':= PInteger) ': ("bar" ':= PInteger) ': '[]))
          (pdata (pdcons @"foo" # (pdata $ pconstant 7) #$ pdcons @"bar" # (pdata $ pconstant 42) # pdnil))
        @-> psucceeds
      "A { test := Integer, test2 := Integer } == [Integer]"
        @| checkDeep
          @(PDataRecord (("foo" ':= PInteger) ': ("bar" ':= PInteger) ': '[]))
          @(PBuiltinList (PAsData PInteger))
          (pdata (pcons # (pdata $ pconstant 7) #$ pcons # (pdata $ pconstant 42) # pnil))
        @-> psucceeds
      "A { test := String, test2 := Integer } == { test := String, test2 := Integer }"
        @| checkDeep
          @(PDataRecord (("foo" ':= PByteString) ': ("bar" ':= PInteger) ': '[]))
          @(PDataRecord (("foo" ':= PByteString) ': ("bar" ':= PInteger) ': '[]))
          (pdata (pdcons @"foo" # (pdata $ pconstant "baz") #$ pdcons @"bar" # (pdata $ pconstant 42) # pdnil))
        @-> psucceeds
      "Map Int String == Map Int String"
        @| mapTestSucceeds @-> psucceeds
      "PDataSum constr 0"
        @| checkDeep
          @(PDataSum '[ '["i1" ':= PInteger, "b2" ':= PByteString], '["i3" ':= PInteger, "b4" ':= PByteString]])
          @(PDataSum '[ '["i1" ':= PInteger, "b2" ':= PByteString], '["i3" ':= PInteger, "b4" ':= PByteString]])
          (punsafeCoerce $ pconstant $ Constr 0 [PlutusTx.I 5, B "foo"])
        @-> psucceeds
      "PDataSum constr 1"
        @| checkDeep
          @(PDataSum '[ '["i1" ':= PInteger, "b2" ':= PByteString], '["i3" ':= PInteger, "b4" ':= PByteString]])
          @(PDataSum '[ '["i1" ':= PInteger, "b2" ':= PByteString], '["i3" ':= PInteger, "b4" ':= PByteString]])
          (punsafeCoerce $ pconstant $ Constr 1 [PlutusTx.I 5, B "foo"])
        @-> psucceeds
      "recover PWrapInt"
        @| pconstant 42 #== (unTermCont $ snd <$> tcont (ptryFrom @(PAsData PWrapInt) (pforgetData $ pdata $ pconstant @PInteger 42)))
        @-> passert
    "recovering a record partially vs completely" @\ do
      "partially"
        @| checkDeep
          @(PDataRecord '["foo" ':= PInteger, "bar" ':= PData])
          @(PDataRecord '["foo" ':= PInteger, "bar" ':= PByteString])
          (pdata $ pdcons @"foo" # (pdata $ pconstant 3) #$ pdcons @"bar" # (pdata $ pconstant "baz") # pdnil)
        @-> psucceeds
      "completely"
        @| checkDeep
          @(PDataRecord '["foo" ':= PInteger, "bar" ':= PByteString])
          @(PDataRecord '["foo" ':= PInteger, "bar" ':= PByteString])
          (pdata (pdcons @"foo" # (pdata $ pconstant 3) #$ pdcons @"bar" # (pdata $ pconstant "baz") # pdnil))
        @-> psucceeds
    "removing the data wrapper" @\ do
      "erroneous" @\ do
        "(String, Integer) /= (String, String)"
          @| checkDeepUnwrap
            @(PBuiltinPair (PAsData PByteString) (PAsData PByteString))
            @(PBuiltinPair (PAsData PInteger) (PAsData PByteString))
            (pdata $ ppairDataBuiltin # (pdata $ pconstant 42) # (pdata $ pconstant "bar"))
          @-> pfails
        "[String] /= [Integer]"
          @| ( checkDeepUnwrap
                @(PBuiltinList (PAsData PInteger))
                @(PBuiltinList (PAsData PByteString))
                (pdata $ (pcons # (pdata $ pconstant "foo")) #$ (psingleton # (pdata $ pconstant "baz")))
             )
          @-> pfails
      "working" @\ do
        "(String, String) == (String, String)"
          @| ( checkDeepUnwrap
                @(PBuiltinPair (PAsData PByteString) (PAsData PByteString))
                @(PBuiltinPair (PAsData PByteString) (PAsData PByteString))
                (pdata $ ppairDataBuiltin # (pdata $ pconstant "foo") # (pdata $ pconstant "bar"))
             )
          @-> psucceeds
        "[String] == [String]"
          @| checkDeepUnwrap
            @(PBuiltinList (PAsData PByteString))
            @(PBuiltinList (PAsData PByteString))
            (pdata $ (pcons # (pdata $ pconstant "foo")) #$ (psingleton # (pdata $ pconstant "bar")))
          @-> psucceeds
      "partial checks" @\ do
        -- this is way more expensive ...
        "check whole structure"
          @| fullCheck @-> psucceeds
        -- ... than this
        "check structure partly"
          @| partialCheck @-> psucceeds
      "recovering a nested record" @\ do
        "succeeds"
          @| checkDeep
            @(PDataRecord '["_0" ':= (PDataRecord '["_1" ':= PInteger])])
            @(PDataRecord '["_0" ':= (PDataRecord '["_1" ':= PInteger])])
            (pdata $ pdcons # (pdata $ pdcons # pdata (pconstant 42) # pdnil) # pdnil)
          @-> psucceeds
        "fails"
          @| checkDeep
            @(PDataRecord '["_0" ':= (PDataRecord '["_1" ':= PByteString])])
            @(PDataRecord '["_0" ':= (PDataRecord '["_1" ':= PInteger])])
            (pdata $ pdcons # (pdata $ pdcons # pdata (pconstant 42) # pdnil) # pdnil)
          @-> pfails
        "sample usage contains the right value"
          @| pconstant 42 #== theField @-> passert
    "example" @\ do
      let l1 :: Term _ (PAsData (PBuiltinList (PAsData PInteger)))
          l1 = toDatadList [1 .. 5]
          l2 :: Term _ (PAsData (PBuiltinList (PAsData PInteger)))
          l2 = toDatadList [6 .. 10]
          l3 :: Term _ (PAsData (PBuiltinList (PAsData PInteger)))
          l3 = toDatadList [6 .. 9]
          l4 :: Term _ (PAsData (PBuiltinList (PAsData PInteger)))
          l4 = toDatadList [6, 8, 8, 9, 10]
      "concatenate two lists, legal"
        @| validator # pforgetData l1 # pforgetData l2 # validContext0 @-> psucceeds
      "concatenate two lists, illegal (list too short)"
        @| validator # pforgetData l1 # pforgetData l3 # validContext0 @-> pfails
      "concatenate two lists, illegal (wrong elements in list)"
        @| validator # pforgetData l1 # pforgetData l4 # validContext0 @-> pfails
      "concatenate two lists, illegal (more than one output)"
        @| validator # pforgetData l1 # pforgetData l2 # invalidContext1 @-> pfails
    "example2" @\ do
      "recovering a record succeeds"
        @| recoverAB @-> psucceeds

------------------- Checking deeply, shallowly and unwrapping ----------------------

checkDeep ::
  forall (target :: PType) (actual :: PType).
  ( PTryFrom PData (PAsData target)
  , PIsData actual
  , PIsData target
  ) =>
  ClosedTerm (PAsData actual) ->
  ClosedTerm (PAsData target)
checkDeep t = unTermCont $ fst <$> TermCont (ptryFrom @(PAsData target) $ pforgetData t)

checkDeepUnwrap ::
  forall (target :: PType) (actual :: PType) (s :: S).
  ( PTryFrom PData (PAsData target)
  , PIsData actual
  , PIsData target
  ) =>
  Term s (PAsData actual) ->
  Term s (PAsData target)
checkDeepUnwrap t = unTermCont $ fst <$> TermCont (ptryFrom @(PAsData target) $ pforgetData t)

sampleStructure :: Term _ (PAsData (PBuiltinList (PAsData (PBuiltinList (PAsData (PBuiltinList (PAsData PInteger)))))))
sampleStructure = pdata $ psingleton #$ pdata $ psingleton #$ toDatadList [1 .. 100]

-- | PData serves as the base case for recursing into the structure
partialCheck :: Term _ (PAsData (PBuiltinList (PAsData (PBuiltinList PData))))
partialCheck =
  let dat :: Term _ PData
      dat = pforgetData sampleStructure
   in unTermCont $ fst <$> TermCont (ptryFrom dat)

fullCheck :: Term _ (PAsData (PBuiltinList (PAsData (PBuiltinList (PAsData (PBuiltinList (PAsData PInteger)))))))
fullCheck = unTermCont $ fst <$> TermCont (ptryFrom $ pforgetData sampleStructure)

------------------- Example: untrusted Redeemer ------------------------------------

newtype PNatural (s :: S) = PMkNatural (Term s PInteger)
  deriving (PlutusType, PIsData, PEq, POrd) via (DerivePNewtype PNatural PInteger)

-- | partial
pmkNatural :: Term s (PInteger :--> PNatural)
pmkNatural = plam $ \i -> pif (i #< 0) (ptraceError "could not make natural") (pcon $ PMkNatural i)

newtype Flip f b a = Flip (f a b)

instance Reducible (f a b) => Reducible (Flip f b a) where
  type Reduce (Flip f b a) = Reduce (f a b)

instance PTryFrom PData (PAsData PNatural) where
  type PTryFromExcess PData (PAsData PNatural) = Flip Term PNatural
  ptryFrom' opq = runTermCont $ do
    (ter, exc) <- TermCont $ ptryFrom @(PAsData PInteger) opq
    ver <- tcont $ plet $ pmkNatural #$ exc
    pure $ (punsafeCoerce ter, ver)

validator :: Term s PValidator
validator = phoistAcyclic $
  plam $ \dat red ctx -> unTermCont $ do
    trustedRedeemer <- (\(snd -> red) -> red) <$> (TermCont $ ptryFrom @(PAsData (PBuiltinList (PAsData PNatural))) red)
    let trustedDatum :: Term _ (PBuiltinList (PAsData PNatural))
        trustedDatum = pfromData $ punsafeCoerce dat
    -- make the Datum and Redeemer trusted

    txInfo :: (Term _ PTxInfo) <- tcont $ plet $ pfield @"txInfo" # ctx

    PJust ownInput <- tcont $ pmatch $ pfindOwnInput # ctx
    resolved <- tcont $ pletFields @["address", "datumHash"] $ pfield @"resolved" # ownInput

    let ownAddress :: Term _ PAddress
        ownAddress = resolved.address
        -- find own script address matching DatumHash

        ownHash :: Term _ PDatumHash
        ownHash = unTermCont $ do
          PDJust dhash <- tcont $ pmatch resolved.datumHash
          pure $ pfield @"_0" # dhash

        data' :: Term _ (PBuiltinList (PAsData (PTuple PDatumHash PDatum)))
        data' = pfield @"datums" # txInfo

        outputs :: Term _ (PBuiltinList (PAsData PTxOut))
        outputs = pfield @"outputs" # txInfo
        -- find the list of the outputs

        matchingHashDatum :: Term _ (PBuiltinList PDatum)
        matchingHashDatum =
          precList
            ( \self x xs -> pletFields @["_0", "_1"] x $
                \tup ->
                  ptrace "iteration" $
                    pif
                      (tup._0 #== ownHash)
                      (ptrace "appended something" pcons # (tup._1) # (self # xs))
                      (ptrace "called without appending" self # xs)
            )
            (const pnil)
            #$ data'
        -- filter and map at the same time, as there is no efficient way
        -- to do that with tools available, I wrote it by hand

        singleOutput :: Term _ PBool
        singleOutput = pnull #$ ptail #$ pfilter # pred # outputs
          where
            pred :: Term _ (PAsData PTxOut :--> PBool)
            pred = plam $ \out -> unTermCont $ do
              pure $ pfield @"address" # out #== (pdata $ ownAddress)

        -- make sure that after filtering the outputs, only one output
        -- remains

        resultList :: Term _ (PAsData (PBuiltinList (PAsData PNatural)))
        resultList = pdata $ pconcat # trustedDatum # trustedRedeemer
        -- the resulting list with trusted datum and trusted redeemer

        isValid :: Term _ PBool
        isValid = pif singleOutput (pto (phead # matchingHashDatum) #== pforgetData resultList) (pcon PFalse)
    -- the final check for validity
    pure $
      pif isValid (popaque $ pcon PUnit) (ptraceError "not valid")

pfindOwnInput :: Term s (PScriptContext :--> PMaybe (PAsData PTxInInfo))
pfindOwnInput = phoistAcyclic $
  plam $ \ctx' -> unTermCont $ do
    ctx <- tcont $ pletFields @["txInfo", "purpose"] ctx'
    PSpending txoutRef <- tcont $ pmatch $ ctx.purpose
    let txInInfos :: Term _ (PBuiltinList (PAsData PTxInInfo))
        txInInfos = pfield @"inputs" #$ ctx.txInfo
        target :: Term _ PTxOutRef
        target = pfield @"_0" # txoutRef
        pred :: Term _ (PAsData PTxInInfo :--> PBool)
        pred = plam $ \actual ->
          target #== pfield @"outRef" # pfromData actual
    pure $ pfind # pred # txInInfos

------------- Helpers --------------------------------------------------------

toDatadList :: [Integer] -> Term s (PAsData (PBuiltinList (PAsData PInteger)))
toDatadList = pdata . (foldr go pnil)
  where
    go :: Integer -> Term _ (PBuiltinList (PAsData PInteger)) -> Term _ (PBuiltinList (PAsData PInteger))
    go i acc = pcons # (pdata $ pconstant i) # acc

------------------- Special cases for maps -----------------------------------------

mapTestSucceeds :: ClosedTerm (PAsData (PBuiltinMap PByteString PInteger))
mapTestSucceeds = unTermCont $ do
  (val, _) <- TermCont $ ptryFrom $ pforgetData sampleMap
  pure val

mapTestFails :: ClosedTerm (PAsData (PBuiltinMap PInteger PInteger))
mapTestFails = unTermCont $ do
  (val, _) <- TermCont $ ptryFrom $ pforgetData sampleMap
  pure val

sampleMap :: Term _ (PAsData (PBuiltinMap PByteString PInteger))
sampleMap =
  pdata $
    pcons
      # (ppairDataBuiltin # (pdata $ pconstant "foo") # (pdata $ pconstant 42)) #$ pcons
      # (ppairDataBuiltin # (pdata $ pconstant "bar") # (pdata $ pconstant 41))
      # pnil

------------------- Sample type with PIsDataRepr -----------------------------------

sampleAB :: Term s (PAsData PAB)
sampleAB = pdata $ pcon $ PA (pdcons @"_0" # (pdata $ pconstant 4) #$ pdcons # (pdata $ pconstant "foo") # pdnil)

sampleABdata :: Term s PData
sampleABdata = pforgetData sampleAB

recoverAB :: Term s (PAsData PAB)
recoverAB = unTermCont $ fst <$> (tcont $ ptryFrom sampleABdata)

data PAB (s :: S)
  = PA (Term s (PDataRecord '["_0" ':= PInteger, "_1" ':= PByteString]))
  | PB (Term s (PDataRecord '["_0" ':= PBuiltinList (PAsData PInteger), "_1" ':= PByteString]))
  deriving stock (GHC.Generic)
  deriving anyclass (Generic, PIsDataRepr)
  deriving
    (PlutusType, PIsData)
    via PIsDataReprInstances PAB

-- here we can derive the `PTryFrom` instance for PAB via the newtype wrapper
-- `PIsDataReprInstances`
deriving via PAsData (PIsDataReprInstances PAB) instance PTryFrom PData (PAsData PAB)

------------------- Sample usage with recovered record type ------------------------

untrustedRecord :: Term s PData
untrustedRecord =
  let rec :: Term s (PAsData (PDataRecord '["_0" ':= (PDataRecord '["_1" ':= PInteger])]))
      rec = pdata $ pdcons # (pdata $ pdcons # pdata (pconstant 42) # pdnil) # pdnil
   in pforgetData rec

theField :: Term s PInteger
theField = unTermCont $ do
  (_, exc) <- tcont (ptryFrom @(PAsData (PDataRecord '["_0" ':= (PDataRecord '["_1" ':= PInteger])])) untrustedRecord)
  pure $ snd . getField @"_1" . snd . snd . getField @"_0" . snd $ exc

------------------- Sample usage DerivePNewType ------------------------------------

newtype PWrapInt (s :: S) = PWrapInt (PInteger s)
  deriving newtype (PIsData, PEq, POrd)

instance PTryFrom PData (PAsData PWrapInt) where
  type PTryFromExcess PData (PAsData PWrapInt) = PTryFromExcess PData (PAsData PInteger)
  ptryFrom' t f = ptryFrom' t $ \(t', exc) -> f (coerce (t' :: Term _ (PAsData PInteger)), exc)
