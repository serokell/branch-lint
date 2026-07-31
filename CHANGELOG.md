<!--
   - SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io>
   -
   - SPDX-License-Identifier: MPL-2.0
   -->

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added

- `BranchLint` library for parsing and validating Serokell branch names
  against the `<username>/<issue-id>-<description>` convention, with typed
  errors for each kind of violation. (#2)
- `branch-lint` CLI that accepts a branch name as an argument or from stdin
  and exits non-zero with a human-readable error message on validation
  failure. (#2)
