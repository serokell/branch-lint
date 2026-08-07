# SPDX-FileCopyrightText: 2026 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: MPL-2.0

{
  nixConfig = {
    flake-registry = "https://github.com/serokell/flake-registry/raw/master/flake-registry.json";
  };

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat = {
      flake = false;
    };
    haskell-nix = {
      inputs.hackage.follows = "hackage";
      inputs.stackage.follows = "stackage";
    };
    hackage = {
      flake = false;
    };
    stackage = {
      flake = false;
    };
  };

  outputs = { self, nixpkgs, haskell-nix, hackage, stackage, serokell-nix, flake-compat, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        haskellPkgs = haskell-nix.legacyPackages."${system}";
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            serokell-nix.overlay
          ];
        };

        lib = pkgs.lib;
        ci = serokell-nix.lib.haskell.makeCI haskellPkgs {
          # specify the path to the root of your haskell project (the directory containing stack.yaml or cabal.project)
          src = ./.;
          # you can specify a list of ghc versions to build packages,
          # if not specified the ghc versions will be taken from tested-with stanzas from .cabal files
          # ghcVersions = [ "ghc902" "ghc926" ];
          # you can specify additional stack yaml files in addition to stack.yaml
          # stackFiles = [ "stack-lts-21-5.yaml" ];
          # you can specify additional stack resolvers, they will be replaced in stack.yaml
          # resolvers = [ "lts-19.13" ];
          # you can disable building with stack if your project does not use stack
          buildWithStack = false;
        };

        # Uncomment if your project uses stack2cabal to generate cabal files
        # stack2cabal = haskellPkgs.haskell.lib.overrideCabal haskellPkgs.haskellPackages.stack2cabal
        # (drv: { jailbreak = true; broken = false; });

        # A separate haskell.nix project instance with GHC/HPC coverage
        # instrumentation (`doCoverage`) enabled on the library component.
        # Kept separate from `packages.branch-lint` below (the executable
        # we actually ship) because coverage-instrumented builds are only
        # needed to produce HPC data for the checks below, and folding this
        # into the main project would instrument code we don't want slowed
        # down by -fhpc.
        coverageProject = haskellPkgs.haskell-nix.cabalProject' {
          src = ./.;
          compiler-nix-name = "ghc9102";
          modules = [{
            packages.branch-lint.components.library.doCoverage = true;
          }];
        };

        # "<name>-<version>" identifier haskell.nix uses to lay out the HPC
        # mix/tix files inside a coverage report derivation (see
        # `share/hpc/vanilla/{mix,tix}/<id>` below).
        branchLintPkgId = coverageProject.hsPkgs.branch-lint.identifier.id;

        # HPC mix/tix/HTML coverage report: runs `branch-lint-test` with
        # coverage instrumentation and reports how much of the `branch-lint`
        # library it exercises.
        coverageReport = coverageProject.hsPkgs.branch-lint.coverageReport;

      in {
        # nixpkgs revision pinned by this flake
        legacyPackages = pkgs;

        # Expose the build matrix for GitHub Actions
        inherit (ci) build-matrix;

        packages.branch-lint =
          (haskellPkgs.haskell-nix.cabalProject' {
            src = ./.;
            compiler-nix-name = "ghc9102";
          }).getComponent "branch-lint:exe:branch-lint";

        # Integration derivation: exercises the compiled executable
        # (not just the library API), which is not on PATH in the
        # `ci.test-all` derivation because it's built by a separate
        # derivation. Takes both as explicit inputs. Lives under
        # `packages`, not `checks`, so building it doesn't force
        # evaluation of `ci.build-all`/`ci.test-all`.
        packages.cli-integration-test = pkgs.runCommand "branch-lint-cli-test"
          {
            nativeBuildInputs = [ self.packages."${system}".branch-lint ];
          } ''
          bash ${./test/cli/run.sh}
          touch $out
        '';

        # HPC mix/tix/HTML coverage report, exposed so it can be inspected
        # directly (e.g. `nix build .#coverage-report` and open the HTML
        # under `result/share/hpc/vanilla/html`).
        packages.coverage-report = coverageReport;

        # Extracts a single overall coverage percentage (HPC's "expressions
        # used" figure) from the report above and fails the build if it has
        # dropped below the baseline checked in at `.coverage-baseline`.
        # Bump that file in your PR when you intentionally raise coverage.
        #
        # Lives under `packages`, like `cli-integration-test` above, rather
        # than `checks`, since merging it into `checks.<system>` would force
        # evaluating the whole CI check set just to build this one
        # derivation. `check.yml` builds it via an explicit step instead.
        packages.coverage-check = pkgs.runCommand "branch-lint-coverage-check"
          {
            nativeBuildInputs =
              let ghc = coverageProject.pkg-set.config.ghc.package;
              in [ (ghc.buildGHC or ghc) pkgs.gawk ];
          } ''
            tixFile="${coverageReport}/share/hpc/vanilla/tix/${branchLintPkgId}/${branchLintPkgId}.tix"
            # `--hpcdir` must be the "mix" directory itself, not the
            # "<id>-<unit-hash>" directory inside it: `hpc` resolves each
            # module by appending the tix's package-qualified module name
            # (e.g. "branch-lint-0.0.0-<hash>/BranchLint") to `--hpcdir`
            # itself, the same way haskell.nix's own internal `hpc markup`
            # calls do when building this coverage report.
            mixDir="${coverageReport}/share/hpc/vanilla/mix"

            if [ ! -f "$tixFile" ] || [ ! -d "$mixDir" ]; then
              echo "Could not locate HPC tix/mix output under ${coverageReport}" >&2
              exit 1
            fi

            hpc report --hpcdir="$mixDir" "$tixFile" | tee report.txt

            percent=$(gawk '/expressions used/ { gsub(/%.*/, "", $1); print $1; exit }' report.txt)
            if [ -z "$percent" ]; then
              echo "Could not parse a coverage percentage from hpc report output" >&2
              exit 1
            fi

            baseline=$(tr -d '[:space:]' < ${./.coverage-baseline})
            echo "Current coverage:  $percent%"
            echo "Baseline coverage: $baseline%"

            if gawk -v cur="$percent" -v base="$baseline" 'BEGIN { exit !(cur < base) }'; then
              echo "Coverage regressed: $percent% < $baseline% (baseline: .coverage-baseline)" >&2
              exit 1
            fi

            mkdir -p $out
            echo "$percent" > $out/coverage-percent.txt
          '';

        devShell = {
          ci = pkgs.mkShell {
            buildInputs = [
              # To avoid version mismatches, use `nix develop .#ci -c hpack`
              pkgs.hpack

              # Uncomment if your project uses scheduled pipeline for `cabal outdated` check
              # pkgs.cabal-install
              # pkgs.curl
              # # GHC is required for `cabal outdated`
              # pkgs.ghc
            ];
          };
        };

        # derivations that we can run from CI
        checks = ci.build-all // ci.test-all // {

          trailing-whitespace = pkgs.build.checkTrailingWhitespace ./.;
          reuse-lint = pkgs.build.reuseLint ./.;
          # Uncomment in case your project sources contain bash scripts
          # shellcheck = pkgs.build.shellcheck ./.;

          hlint = pkgs.build.haskell.hlint ./.;
          stylish-haskell = pkgs.build.haskell.stylish-haskell ./.;
          cabal-check = pkgs.build.haskell.cabal-check ./.;
          hpack = pkgs.build.haskell.hpack ./.;
        };
      });
}
