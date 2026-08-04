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
