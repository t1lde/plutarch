module Plutarch.Prelude (
  -- * eDSL types and functions.
  (:-->),
  PDelayed,
  Term,
  ClosedTerm,
  plam,
  plam',
  papp,
  pdelay,
  pforce,
  phoistAcyclic,
  perror,
  (#$),
  (#),
  plet,
  pinl,
  pto,
  pfix,
  Type,
  S,
  PType,
  PlutusType (PInner),
  PCon (pcon),
  PMatch (pmatch),

  -- * Integers and integer utilities
  PInteger,
  PIntegral (pdiv, pmod, pquot, prem),

  -- * Rational numbers and utilities
  PRational,
  pnumerator,
  pdenominator,
  pfromInteger,
  pround,

  -- * Booleans and boolean functions
  PBool (..),
  PEq ((#==)),
  POrd ((#<=), (#<)),
  pif,
  pnot,
  (#&&),
  (#||),

  -- * Bytestrings and bytestring utilities
  PByteString,
  phexByteStr,
  pconsBS,
  psliceBS,
  plengthBS,
  pindexBS,

  -- * String and string utilities
  PString,
  pencodeUtf8,
  pdecodeUtf8,

  -- * Unit type and utilities
  PUnit (..),

  -- * Common list typeclass and utilities
  PListLike (PElemConstraint, pelimList, pcons, pnil, phead, ptail, pnull),
  PIsListLike,
  plistEquals,
  pelem,
  pelemAt,
  plength,
  ptryIndex,
  pdrop,
  psingleton,
  pconcat,
  pzipWith,
  pzipWith',
  pzip,
  pmap,
  pfilter,
  pfind,
  precList,
  pfoldr,
  pfoldrLazy,
  pfoldl,
  pall,
  pany,
  (#!!),

  -- * Scott encoded list type
  PList (..),

  -- * Scott encoded maybe type and utilities
  PMaybe (..),

  -- * Scott encoded either type and utilities
  PEither (..),

  -- * Scott encoded pair type and utilities
  PPair (..),

  -- * Opaque type
  POpaque (POpaque),
  popaque,

  -- * Builtin types and utilities
  PData,
  pfstBuiltin,
  psndBuiltin,
  PBuiltinPair,
  PBuiltinList (..),
  PIsData (pfromData, pdata),
  PAsData,

  -- * DataRepr and related functions
  PDataRecord,
  PDataSum,
  PIsDataRepr,
  PLabeledType ((:=)),
  pdcons,
  pdnil,
  pfield,
  getField,
  pletFields,

  -- * Tracing
  ptrace,
  ptraceShowId,
  ptraceIfFalse,
  ptraceIfTrue,
  ptraceError,
  pshow,

  -- * Cryptographic hashes and signatures
  psha2_256,
  psha3_256,
  pverifySignature,

  -- * Converstion between Plutarch terms and Haskell types
  pconstant,
  pconstantData,
  plift,
  PConstant,
  PLift,
  PConstantData,
  PLiftData,

  -- * Typeclass derivers.
  DerivePNewtype (DerivePNewtype),

  -- * Continuation monad
  TermCont (TermCont, runTermCont),
  unTermCont,
  tcont,
) where

import Prelude ()

import Data.Kind (Type)
import GHC.Records (getField)
import Plutarch
import Plutarch.Bool
import Plutarch.Builtin
import Plutarch.ByteString
import Plutarch.Crypto
import Plutarch.DataRepr
import Plutarch.Either
import Plutarch.Integer
import Plutarch.Lift
import Plutarch.List
import Plutarch.Maybe
import Plutarch.Pair
import Plutarch.Rational
import Plutarch.Show
import Plutarch.String
import Plutarch.TermCont
import Plutarch.Trace
import Plutarch.Unit
