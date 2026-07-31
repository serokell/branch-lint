-- SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io>
--
-- SPDX-License-Identifier: MPL-2.0

-- | Validation of Serokell git branch names.
--
-- Serokell branches follow the convention:
-- @\<github-username\>\/\<issue-id\>-\<brief-description\>@
--
-- Two issue-ID formats are supported:
--
-- * YouTrack: @\<alphanumeric-key\>\<number\>@ — e.g. @alice\/bl1-setup-repository@
-- * GitHub Issues: @#\<number\>@ — e.g. @alice\/#5-setup-repository@
module BranchLint
  ( BranchName (..)
  , BranchError (..)
  , parseBranch
  , renderError
  ) where

import Control.Monad (unless, when)
import Data.Char (isAlphaNum, isDigit, isLower)
import Data.Kind (Type)
import Data.Text (Text)
import Data.Text qualified as T

-- | A successfully parsed Serokell branch name.
type BranchName :: Type
data BranchName = BranchName
  { bnUsername    :: Text
    -- ^ GitHub username, e.g. @alice@.
  , bnIssueId     :: Text
    -- ^ Issue tracker ID, e.g. @bl1@ (YouTrack) or @#5@ (GitHub).
  , bnDescription :: Text
    -- ^ Brief description in lowercase kebab-case, optionally with digits,
    --   e.g. @setup-repository@ or @release-2-notes@.
  } deriving stock (Eq, Show)

-- | Reasons a branch name can fail validation.
type BranchError :: Type
data BranchError
  = MissingSlash
    -- ^ Branch name contains no @\/@ separator.
  | EmptyUsername
    -- ^ The GitHub username part is empty.
  | EmptyIssueSlug
    -- ^ The part after @\/@ is empty.
  | MissingIssueKey
    -- ^ Issue slug is missing the project key (e.g. @bl@).
  | InvalidIssueKey Text
    -- ^ Project key contains non-alphanumeric characters.
  | MissingIssueNumber
    -- ^ Issue slug is missing the numeric part (e.g. @1@).
  | InvalidIssueNumber Text
    -- ^ Issue number contains non-digit characters.
  | EmptyDescription
    -- ^ No description follows the issue ID.
  | InvalidDescription Text
    -- ^ Description contains characters other than lowercase letters, digits, and dashes.
  deriving stock (Eq, Show)

-- | Parse a raw branch name into its constituent parts.
--
-- Returns 'Left' with a 'BranchError' describing the first violation
-- found, or 'Right' with the parsed 'BranchName'.
--
-- Both YouTrack-style (@bl1@) and GitHub-style (@#5@) issue IDs are
-- accepted.
parseBranch :: Text -> Either BranchError BranchName
parseBranch raw = do
  let (username, afterSlash) = T.break (== '/') raw
  when (T.null afterSlash) $ Left MissingSlash
  let slug = T.drop 1 afterSlash
  when (T.null username) $ Left EmptyUsername
  when (T.null slug) $ Left EmptyIssueSlug
  (issueId, description) <- parseIssueSlug slug
  pure BranchName
    { bnUsername    = username
    , bnIssueId     = issueId
    , bnDescription = description
    }

-- | Render a 'BranchError' as a human-readable message.
renderError :: BranchError -> Text
renderError MissingSlash =
  "Branch name must contain '/' separating username from issue slug \
  \(e.g. 'alice/bl1-short-desc')."
renderError EmptyUsername =
  "GitHub username part (before '/') is empty."
renderError EmptyIssueSlug =
  "Issue slug part (after '/') is empty."
renderError MissingIssueKey =
  "Issue slug must start with a project key (e.g. 'bl1-description')."
renderError (InvalidIssueKey key) =
  "Issue project key '" <> key <> "' must contain only letters and digits \
  \(e.g. 'bl', 'SEROKELL', '21c')."
renderError MissingIssueNumber =
  "Issue ID must end with a numeric issue number (e.g. 'bl1' in 'bl1-description')."
renderError (InvalidIssueNumber num) =
  "Issue number '" <> num <> "' must contain only digits."
renderError EmptyDescription =
  "Branch name must include a description after the issue ID \
  \(e.g. 'bl1-setup-repository')."
renderError (InvalidDescription description) =
  "Description '" <> description <> "' must contain only lowercase letters, \
  \digits, and dashes (e.g. 'setup-repository' or 'release-2-notes')."

-- Dispatch on the issue-ID format: GitHub ("#<n>-<desc>") or YouTrack ("<key><n>-<desc>").
parseIssueSlug :: Text -> Either BranchError (Text, Text)
parseIssueSlug slug
  | T.isPrefixOf "#" slug = parseGitHubSlug slug
  | otherwise             = parseYouTrackSlug slug

-- Parse "#<number>-<description>" (GitHub Issues format).
-- The leading '#' is part of the slug and is included in the returned issue ID.
parseGitHubSlug :: Text -> Either BranchError (Text, Text)
parseGitHubSlug slug = do
  let afterHash = T.drop 1 slug
  let (num, rest) = T.breakOn "-" afterHash
  when (T.null num) $ Left MissingIssueNumber
  unless (T.all isDigit num) $ Left (InvalidIssueNumber num)
  let description = T.drop 1 rest
  when (T.null description) $ Left EmptyDescription
  validateDescription description
  pure ("#" <> num, description)

-- Parse "<key><number>-<description>" (YouTrack format).
-- The key is the alphanumeric prefix; the number is the trailing digit sequence.
parseYouTrackSlug :: Text -> Either BranchError (Text, Text)
parseYouTrackSlug slug = do
  let (issueId, rest) = T.breakOn "-" slug
  when (T.null issueId) $ Left MissingIssueKey
  let key = T.dropWhileEnd isDigit issueId
      num = T.takeWhileEnd isDigit issueId
  when (T.null key)  $ Left MissingIssueKey
  unless (T.all isAlphaNum key) $ Left (InvalidIssueKey key)
  when (T.null num)  $ Left MissingIssueNumber
  let description = T.drop 1 rest
  when (T.null description) $ Left EmptyDescription
  validateDescription description
  pure (issueId, description)

validateDescription :: Text -> Either BranchError ()
validateDescription description =
  unless (T.all isValidDescriptionChar description) $
    Left (InvalidDescription description)

isValidDescriptionChar :: Char -> Bool
isValidDescriptionChar c = isLower c || isDigit c || c == '-'
