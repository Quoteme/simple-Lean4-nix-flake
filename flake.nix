{
  description = "My Lean package";

  inputs.lean.url = "github:leanprover/lean4";
  # Here we will add our dependency on Mathlib
  inputs.mathlib.url = "github:leanprover-community/mathlib";
  inputs.mathlib.flake = false;
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, lean, flake-utils, mathlib }: flake-utils.lib.eachDefaultSystem (system:
    let
      leanPkgs = lean.packages.${system};
      pkg = leanPkgs.buildLeanPackage {
        name = "MyPackage"; # must match the name of the top-level .lean file
        src = ./.;
      };
    in
    {
      packages = pkg // {
        inherit (leanPkgs) lean;
      };

      defaultPackage = pkg.modRoot;
    });
}
