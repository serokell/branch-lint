-- SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io>
--
-- SPDX-License-Identifier: MPL-2.0

module Test.BranchLintCliTest
  ( test_cli
  ) where

import Data.Either (isLeft, isRight)
import Data.Text qualified as T
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, testCase)

import BranchLint (parseBranch, renderError)

test_cli :: TestTree
test_cli = testGroup "CLI"
  [ testCase "valid YouTrack branch is accepted" $
      assertBool "should parse successfully"
        (isRight (parseBranch "alice/bl1-setup-repository"))
  , testCase "valid GitHub branch is accepted" $
      assertBool "should parse successfully"
        (isRight (parseBranch "alice/#5-setup-repository"))
  , testCase "invalid branch is rejected" $
      assertBool "should fail to parse"
        (isLeft (parseBranch "main"))
  , testCase "error message is non-empty on invalid branch" $
      case parseBranch "main" of
        Right _ -> assertBool "expected parse failure" False
        Left err -> assertBool "error message should be non-empty"
            (not (T.null (renderError err)))
  ]
