# SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io>
#
# SPDX-License-Identifier: MPL-2.0

.PHONY: branch-lint test test-dumb-term test-hide-successes haddock haddock-no-deps stylish lint clean

MAKEU = $(MAKE) -C make/

MAKE_PACKAGE = $(MAKEU) PACKAGE=branch-lint

branch-lint:
	$(MAKE_PACKAGE) dev
test:
	$(MAKE_PACKAGE) test
test-dumb-term:
	$(MAKE_PACKAGE) test-dumb-term
test-hide-successes:
	$(MAKE_PACKAGE) test-hide-successes
haddock:
	$(MAKE_PACKAGE) haddock
haddock-no-deps:
	$(MAKE_PACKAGE) haddock-no-deps
clean:
	$(MAKE_PACKAGE) clean
