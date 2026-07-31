-- SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io>
--
-- SPDX-License-Identifier: MPL-2.0

module Main (main) where

import Data.Text qualified as T
import Data.Text.IO qualified as TIO
import Main.Utf8 (withUtf8)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

import BranchLint (parseBranch, renderError)

main :: IO ()
main = withUtf8 $ do
  args <- getArgs
  branch <- case args of
    [b] -> pure (T.pack b)
    []  -> TIO.getLine
    _   -> do
      hPutStrLn stderr "usage: branch-lint [BRANCH-NAME]"
      exitFailure
  case parseBranch branch of
    Right _ -> pure ()
    Left err -> do
      TIO.hPutStrLn stderr $ "Invalid branch name: " <> renderError err
      exitFailure
