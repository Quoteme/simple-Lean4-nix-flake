{
  nixConfig.trusted-substituters = "https://lean4.cachix.org/";
  nixConfig.trusted-public-keys = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= lean4.cachix.org-1:mawtxSxcaiWE24xCXXgh3qnvlTkyU7evRRnGeAhD4Wk=";
  nixConfig.max-jobs = "auto"; # Allow building multiple derivations in parallel
  # nixConfig.keep-outputs = true; # Do not garbage-collect build time-only dependencies (e.g. clang)

  inputs.lean.url = "github:leanprover/lean4?ref=v4.2.0";
  # Here we will add our dependency on Mathlib
  # I stole this from https://github.com/stites/templates/blob/492ffebb29b479d3ee85fa24beb214ecb227fbb0/lean4/flake.nix
  inputs.mathlib4 = {
    url = "github:leanprover-community/mathlib4?ref=v4.2.0";
    flake = false;
  };
  inputs.std4 = {
    url = "github:leanprover/std4?ref=v4.2.0";
    flake = false;
  };
  inputs.aesop = {
    url = "github:JLimperg/aesop?ref=v4.2.0";
    flake = false;
  };
  inputs.quote = {
    url = "github:leanprover-community/quote4";
    flake = false;
  };
  inputs.proofWidgets4 = {
    url = "github:leanprover-community/ProofWidgets4?ref=v0.0.22";
    flake = false;
  };
  inputs.cli = {
    url = "github:leanprover/lean4-cli?ref=v2.2.0-lv4.0.0";
    flake = false;
  };
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, lean, flake-utils, ... }@inputs: flake-utils.lib.eachDefaultSystem (system:
    let
      leanPkgs = lean.packages.${system};
      pkg = leanPkgs.buildLeanPackage {
        name = "MyPackage"; # must match the name of the top-level .lean file
        src = ./.;
      };
      aesop = leanPkgs.buildLeanPackage {
        name = "Aesop";
        src = inputs.aesop;
        precompilePackage = true;
        deps = [ std4 ];
      };
      quote = leanPkgs.buildLeanPackage {
        name = "Qq";
        src = inputs.quote;
        precompilePackage = true;
      };
      cli = leanPkgs.buildLeanPackage {
        name = "Cli";
        src = inputs.cli;
        precompilePackage = true;
      };
      std4 = leanPkgs.buildLeanPackage {
        name = "Std";
        src = inputs.std4;
        precompilePackage = true;
        deps = [ cli ];
      };
      proofWidgets4 = leanPkgs.buildLeanPackage {
        name = "ProofWidgets";
        src = inputs.proofWidgets4;
        precompilePackage = true;
        deps = [ std4 ];
      };
      mathlib = leanPkgs.buildLeanPackage {
        name = "Mathlib";
        src = inputs.mathlib4;
        precompilePackage = true;
        deps = [
          aesop
          quote
          std4
          proofWidgets4
          # optional doc-gen4
        ];
      };
    in
    {
      packages = pkg // {
        inherit (leanPkgs) lean;
      } // mathlib;

      defaultPackage = pkg.modRoot;
    });
}
