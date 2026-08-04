#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io>
#
# SPDX-License-Identifier: MPL-2.0

# Exercises the compiled branch-lint executable directly, not the library
# API. Uses argv and stdin, like a real user. `branch-lint` must already
# be on PATH.
set -euo pipefail

branch-lint "alice/bl1-setup-repository"
branch-lint "alice/#5-setup-repository"
echo "alice/bl1-setup-repository" | branch-lint

! branch-lint "main" 2>/dev/null
! branch-lint "alice/bl-setup-repository" 2>/dev/null
! branch-lint "alice/bl1-BAD" 2>/dev/null
! branch-lint "one" "two" 2>/dev/null

echo "all cli assertions passed"
