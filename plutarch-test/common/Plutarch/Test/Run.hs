module Plutarch.Test.Run (noUnusedGoldens, noUnusedGoldens') where

import Control.Monad (forM_)
import Data.Default (def)
import Data.Set (Set)
import qualified Data.Set as Set
import qualified Data.Text as T
import Plutarch.Test.Golden (
  GoldenConf (GoldenConf, chosenTests, goldenBasePath),
  GoldenKey,
  goldenTestPath,
  mkGoldenKeyFromSpecPath,
 )
import System.Directory (listDirectory)
import System.Exit (ExitCode (ExitFailure), exitWith)
import System.FilePath ((</>))
import Test.Hspec (Spec)
import Test.Hspec.Core.Spec (SpecTree, Tree (Leaf, Node, NodeWithCleanup), runSpecM)

{- | Ensures that there are no unused goldens left behind.

  Use this on any `SpecTree` that interally uses `pgoldenSpec` to define the
  golden tests. These golden file paths are accumulated, and compared to the
  actual files existing on disk. If any golden file exists on disk, but is not
  tracked by the `SpecTree` this function will fail, reporting the list of
  untracked golden files.
-}
noUnusedGoldens :: Spec -> IO ()
noUnusedGoldens = noUnusedGoldens' def

{- | Like 'noUnusedGoldens' but takes a custom path to the golden storage.

NOTE: This relies on the same 'GoldenConf' being used in all 'pgoldenSpec'' calls.
-}
noUnusedGoldens' :: GoldenConf -> Spec -> IO ()
noUnusedGoldens' conf@(GoldenConf {goldenBasePath}) spec = do
  -- A second traversal here (`runSpecM`) can be obviated after
  -- https://github.com/hspec/hspec/issues/649
  usedGoldens <- goldenPathsUsedBy conf . snd <$> runSpecM spec
  unusedGoldens goldenBasePath usedGoldens >>= \case
    [] -> pure ()
    unused -> do
      putStrLn "ERROR: Unused golden files found lying around! Namely:"
      forM_ unused $ \fp ->
        putStrLn $ "- " <> fp
      exitWith (ExitFailure 1)

-- | Given a list of "used" goldens, return any unused golden files on disk.
unusedGoldens :: FilePath -> [FilePath] -> IO [FilePath]
unusedGoldens goldenBasePath usedGoldens' = do
  let usedGoldens = foldMap knownGoldens usedGoldens'
  allGoldens <- Set.fromList . fmap (goldenBasePath </>) <$> listDirectory goldenBasePath
  pure $ Set.toList $ allGoldens `Set.difference` usedGoldens
  where
    knownGoldens :: FilePath -> Set FilePath
    knownGoldens fp =
      Set.fromList
        [ fp
        , -- Inject goldens for other flag values to be comprehensive in our
          -- search.
          replace "dev=true" "dev=false" fp
        , replace "dev=false" "dev=true" fp
        ]
    replace a b = T.unpack . T.replace a b . T.pack

goldenPathsUsedBy :: GoldenConf -> [SpecTree a] -> [FilePath]
goldenPathsUsedBy (GoldenConf {chosenTests, goldenBasePath}) trees = do
  flip foldMap (queryGoldens trees) $ \k ->
    flip fmap (Set.toList chosenTests) $ \t ->
      goldenTestPath goldenBasePath k t

-- | Retrieve all golden keys used by the given test tree.
queryGoldens :: [SpecTree a] -> [GoldenKey]
queryGoldens =
  -- `drop 1`, to drop the hspec-discover generated root node.
  fmap mkGoldenKeyFromSpecPath . concatMap (go [])
  where
    go ancestors = \case
      Node "golden" _children ->
        ancestors : []
      Node k children ->
        concatMap (go $ T.pack k : ancestors) children
      NodeWithCleanup _ _ trees ->
        concatMap (go ancestors) trees
      Leaf _ ->
        mempty
