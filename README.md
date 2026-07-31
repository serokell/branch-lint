<!--
   - SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io>
   -
   - SPDX-License-Identifier: MPL-2.0
   -->

# branch-lint

> Validate git branch names against Serokell conventions.

`branch-lint` is a Haskell library and CLI tool that checks whether a git branch name follows [Serokell's branching conventions](docs/branching.md). Valid branch names take the form `<github-username>/<issue-id>-<brief-description>`.

## Table of Contents

- [Background](#background)
- [Install](#install)
- [Usage](#usage)
- [For Contributors](#for-contributors)
- [License](#license)

## Background

Serokell uses a OneFlow variant where every branch is owned by a developer and tied to an issue:

```
alice/bl1-setup-repository
```

- `<github-username>`: the branch owner's GitHub username
- `<issue-id>`: a YouTrack ID (e.g. `bl5`) or GitHub issue number (e.g. `#42`)
- `<brief-description>`: lowercase letters and dashes

`branch-lint` encodes these rules and can run as a pre-commit hook, a CI check, or a standalone CLI.

## Install

Build from source with Nix:

```bash
nix build
```

Or with Cabal:

```bash
cabal build
```

## Usage

Check a branch name:

```bash
branch-lint alice/bl1-setup-repository
```

Exit code `0` means the branch is valid. Any non-zero exit code means it is invalid; the error is printed to stderr.

Use as a pre-commit hook by adding to `.git/hooks/pre-commit`:

```bash
branch-lint "$(git rev-parse --abbrev-ref HEAD)"
```

## For Contributors

Please see [CONTRIBUTING.md](CONTRIBUTING.md) and [docs/branching.md](docs/branching.md).

Issues are tracked on [GitHub](https://github.com/serokell/branch-lint/issues).

## License

[MPL-2.0](LICENSE) © [Serokell](https://serokell.io)

## About Serokell

`branch-lint` is maintained and funded with ❤️ by [Serokell](https://serokell.io/).
The names and logo for Serokell are trademark of Serokell OÜ.

We love open source software! See [our other projects](https://serokell.io/projects?utm_source=github) or [hire us](https://serokell.io/contacts?utm_source=github) to design, develop and grow your idea!
