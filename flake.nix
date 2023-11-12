{
  nixConfig.trusted-substituters = "https://lean4.cachix.org/";
  nixConfig.trusted-public-keys = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= lean4.cachix.org-1:mawtxSxcaiWE24xCXXgh3qnvlTkyU7evRRnGeAhD4Wk=";
  nixConfig.max-jobs = "auto"; # Allow building multiple derivations in parallel
  # nixConfig.keep-outputs = true; # Do not garbage-collect build time-only dependencies (e.g. clang)

  inputs = {
    nixpkgs =
      {
        url = "github:NixOS/nixpkgs";
        follows = "lean/nixpkgs";
      };

    lean.url = "github:leanprover/lean4?ref=v4.2.0";

    # Here we will add our dependency on Mathlib
    # I stole this from https://github.com/stites/templates/blob/492ffebb29b479d3ee85fa24beb214ecb227fbb0/lean4/flake.nix
    std4 = {
      url = "github:leanprover/std4?ref=v4.2.0";
      flake = false;
    };
    mathlib4 = {
      url = "github:leanprover-community/mathlib4?ref=v4.2.0";
      flake = false;
    };
    aesop = {
      url = "github:JLimperg/aesop?ref=v4.2.0";
      flake = false;
    };
    quote4 = {
      url = "github:leanprover-community/quote4";
      flake = false;
    };
    proofWidgets4 = {
      url = "github:leanprover-community/ProofWidgets4?ref=v0.0.22";
      flake = false;
    };
    cli = {
      url = "github:leanprover/lean4-cli?ref=v2.2.0-lv4.0.0";
      flake = false;
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, lean, flake-utils, ... }@inputs: flake-utils.lib.eachDefaultSystem (system:
    let
      leanPkgs = lean.packages.${system};
      pkgs = nixpkgs.legacyPackages.${system};
      pkg = leanPkgs.buildLeanPackage {
        name = "MyPackage"; # must match the name of the top-level .lean file
        src = ./.;
      };
      aesop = leanPkgs.buildLeanPackage {
        name = "Aesop";
        src = inputs.aesop;
        precompilePackage = true;
        deps = [ std4 ];
        roots = [ "Aesop" ];
      };
      quote4 = leanPkgs.buildLeanPackage {
        name = "Qq";
        src = inputs.quote4;
        precompilePackage = true;
        roots = [{ mod = "Qq"; glob = "one"; }];
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
        roots = [{ mod = "Std"; glob = "one"; }];
      };
      proofWidgets4 = leanPkgs.buildLeanPackage {
        name = "ProofWidgets";
        src = inputs.proofWidgets4;
        precompilePackage = true;
        deps = [ std4 ];
        roots = [ "ProofWidgets" ];
        overrideBuildModAttrs = addFakeFiles {
          "ProofWidgets.Compat" = [ "build/js/compat.js" ];
          "ProofWidgets.Component.Basic" = [ "build/js/interactiveExpr.js" ];
          "ProofWidgets.Component.GoalTypePanel" = [ "build/js/goalTypePanel.js" ];
          "ProofWidgets.Component.Recharts" = [ "build/js/recharts.js" ];
          "ProofWidgets.Component.PenroseDiagram" = [ "build/js/penroseDisplay.js" ];
          "ProofWidgets.Component.Panel.SelectionPanel" = [ "build/js/presentSelection.js" ];
          "ProofWidgets.Component.Panel.GoalTypePanel" = [ "build/js/goalTypePanel.js" ];
          "ProofWidgets.Component.MakeEditLink" = [ "build/js/makeEditLink.js" ];
          "ProofWidgets.Component.OfRpcMethod" = [ "build/js/ofRpcMethod.js" ];
          "ProofWidgets.Component.HtmlDisplay" =
            [ "build/js/htmlDisplay.js" "build/js/htmlDisplayPanel.js" ];
          "ProofWidgets.Presentation.Expr" = [ "build/js/exprPresentation.js" ];
        };
      };
      mathlib4 = leanPkgs.buildLeanPackage {
        name = "Mathlib";
        src = inputs.mathlib4;
        roots = [{ mod = "Mathlib"; glob = "one"; }];
        leanFlags = [
          "-Dpp.unicode.fun=true"
          "-DautoImplicit=false"
          "-DrelaxedAutoImplicit=false"
        ];
        deps = [ std4 quote4 aesop proofWidgets4 ];
        overrideBuildModAttrs = addFakeFiles {
          "Mathlib.Tactic.Widget.CommDiag" = [
            "widget/src/penrose/commutative.dsl"
            "widget/src/penrose/commutative.sty"
            "widget/src/penrose/triangle.sub"
            "widget/src/penrose/square.sub"
          ];
        };
      };

      # addFakeFile can plug into buildLeanPackage’s overrideBuildModAttrs
      # it takes a lean module name and a filename, and makes that file available
      # (as an empty file) in the build tree, e.g. for include_str.
      addFakeFiles = m: self: super:
        if m ? ${super.name}
        then
          let
            paths = m.${super.name};
          in
          {
            src = pkgs.runCommandCC "${super.name}-patched"
              {
                inherit (super) leanPath src relpath;
              }
              (''
                dir=$(dirname $relpath)
                mkdir -p $out/$dir
                if [ -d $src ]; then cp -r $src/. $out/$dir/; else cp $src $out/$leanPath; fi
              '' + pkgs.lib.concatMapStringsSep "\n"
                (p: ''
                  install -D -m 644 ${pkgs.emptyFile} $out/${p}
                '')
                paths);
          }
        else { };
    in
    {
      packages = pkg // {
        inherit (leanPkgs) lean;
      } // std4 // quote4 // aesop // proofWidgets4 // mathlib4;

      defaultPackage = pkg.modRoot;
    });
}
