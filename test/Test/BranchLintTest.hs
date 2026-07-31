-- SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io>
--
-- SPDX-License-Identifier: MPL-2.0

module Test.BranchLintTest
  ( test_parseBranch
  , test_renderError
  ) where

import Data.Text (Text)
import Data.Text qualified as T
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, assertEqual, testCase)

import BranchLint (BranchError(..), BranchName(..), parseBranch, renderError)

test_parseBranch :: TestTree
test_parseBranch = testGroup "parseBranch"
  [ testGroup "valid (YouTrack format)"
    [ testCase "simple" $
        assertEqual "" (rb "alice" "bl1" "setup-repository")
          (parseBranch "alice/bl1-setup-repository")
    , testCase "uppercase project key" $
        assertEqual "" (rb "bob" "SEROKELL123" "fix-bug")
          (parseBranch "bob/SEROKELL123-fix-bug")
    , testCase "multi-word description" $
        assertEqual "" (rb "charlie" "AD456" "refactor-auth-module")
          (parseBranch "charlie/AD456-refactor-auth-module")
    , testCase "project key with leading digits" $
        assertEqual "" (rb "dave" "21c5" "some-feature")
          (parseBranch "dave/21c5-some-feature")
    ]
  , testGroup "valid (GitHub Issues format)"
    [ testCase "simple github issue" $
        assertEqual "" (rb "alice" "#5" "setup-repository")
          (parseBranch "alice/#5-setup-repository")
    , testCase "multi-digit github issue" $
        assertEqual "" (rb "bob" "#228" "add-yellow-button")
          (parseBranch "bob/#228-add-yellow-button")
    , testCase "description may include digits" $
        assertEqual "" (rb "eve" "#19" "release-2-notes")
          (parseBranch "eve/#19-release-2-notes")
    ]
  , testGroup "invalid"
    [ testCase "no slash" $
        assertEqual "" (Left MissingSlash)
          (parseBranch "main")
    , testCase "empty username" $
        assertEqual "" (Left EmptyUsername)
          (parseBranch "/bl1-desc")
    , testCase "empty issue slug" $
        assertEqual "" (Left EmptyIssueSlug)
          (parseBranch "alice/")
    , testCase "missing issue key" $
        assertEqual "" (Left MissingIssueKey)
          (parseBranch "alice/-desc")
    , testCase "invalid issue key" $
        assertEqual "" (Left (InvalidIssueKey "bl@"))
          (parseBranch "alice/bl@1-desc")
    , testCase "missing issue number" $
        assertEqual "" (Left MissingIssueNumber)
          (parseBranch "alice/bl-desc")
    , testCase "invalid issue number (github)" $
        assertEqual "" (Left (InvalidIssueNumber "abc"))
          (parseBranch "alice/#abc-desc")
    , testCase "empty description (youtrack)" $
        assertEqual "" (Left EmptyDescription)
          (parseBranch "alice/bl1")
    , testCase "github issue missing number" $
        assertEqual "" (Left MissingIssueNumber)
          (parseBranch "alice/#-desc")
    , testCase "github issue empty description" $
        assertEqual "" (Left EmptyDescription)
          (parseBranch "alice/#5")
    , testCase "description rejects uppercase letters" $
        assertEqual "" (Left (InvalidDescription "Setup-repository"))
          (parseBranch "alice/bl1-Setup-repository")
    , testCase "description rejects underscores" $
        assertEqual "" (Left (InvalidDescription "setup_repository"))
          (parseBranch "alice/bl1-setup_repository")
    ]
  ]

test_renderError :: TestTree
test_renderError = testGroup "renderError"
  [ testCase "non-empty for MissingSlash" $
      assertNonEmpty (renderError MissingSlash)
  , testCase "non-empty for EmptyUsername" $
      assertNonEmpty (renderError EmptyUsername)
  , testCase "non-empty for EmptyIssueSlug" $
      assertNonEmpty (renderError EmptyIssueSlug)
  , testCase "non-empty for MissingIssueKey" $
      assertNonEmpty (renderError MissingIssueKey)
  , testCase "non-empty for InvalidIssueKey" $
      assertNonEmpty (renderError (InvalidIssueKey "bl@"))
  , testCase "non-empty for MissingIssueNumber" $
      assertNonEmpty (renderError MissingIssueNumber)
  , testCase "non-empty for InvalidIssueNumber" $
      assertNonEmpty (renderError (InvalidIssueNumber "abc"))
  , testCase "non-empty for EmptyDescription" $
      assertNonEmpty (renderError EmptyDescription)
  , testCase "non-empty for InvalidDescription" $
      assertNonEmpty (renderError (InvalidDescription "Setup-repository"))
  , testCase "InvalidIssueKey message contains the key" $
      assertBool "message should contain the key" $
        T.isInfixOf "bl@" (renderError (InvalidIssueKey "bl@"))
  , testCase "InvalidIssueNumber message contains the number" $
      assertBool "message should contain the number" $
        T.isInfixOf "abc" (renderError (InvalidIssueNumber "abc"))
  , testCase "InvalidDescription message contains the description" $
      assertBool "message should contain the description" $
        T.isInfixOf "Setup-repository"
          (renderError (InvalidDescription "Setup-repository"))
  ]

-- Helpers

rb :: Text -> Text -> Text -> Either BranchError BranchName
rb u i d = Right (BranchName u i d)

assertNonEmpty :: Text -> IO ()
assertNonEmpty t = assertBool "error message should be non-empty" (not (T.null t))
