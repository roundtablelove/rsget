{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    blueprint = {
      url = "github:numtide/blueprint";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    crane.url = "github:ipetkov/crane";

    nix-github-actions = {
      url = "github:nix-community/nix-github-actions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-seed = {
      url = "github:roundtablelove/nix-seed";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    let
      inherit (inputs.nixpkgs) lib;
      bp = inputs.blueprint { inherit inputs; };
      # the only system blueprint actually builds anything for --
      # packages/devShells/checks are empty attrsets everywhere else
      # (see flake.nix's own githubActions matrix, restricted the same
      # way), so the seed only needs to exist here too.
      system = "x86_64-linux";
    in
    lib.recursiveUpdate bp {
      packages.${system}.seed = inputs.nix-seed.lib.mkSeed {
        pkgs = import inputs.nixpkgs { inherit system; };
        inherit (inputs) self;
        # blueprint's "pkgs-<name>"/"devshell-<name>" checks are the
        # same derivations as packages/devShells, just re-keyed (see
        # numtide/blueprint's lib/default.nix, withPrefix) -- so naming
        # the primitives here also covers what seed-build.yml's
        # `nix build .#checks.x86_64-linux."pkgs-default"` and
        # `"...devshell-default"` need. devShells.default also covers
        # the unconditional `nix develop -c cargo test` step.
        seedOutputs = [
          "packages.default"
          "devShells.default"
        ];
      };
      # blueprint derives a "pkgs-<name>" check per package from self
      # (a fixed point), so adding packages.${system}.seed above also
      # adds a pkgs-seed check here -- building the seed as a CI check
      # is redundant with seed.yml, and fails outright when run against
      # a mounted seed offline (it needs cmake/lz4/squashfs-tools, none
      # of which are baked in for building A seed from within one).
      githubActions = inputs.nix-github-actions.lib.mkGithubMatrix {
        checks = lib.mapAttrs (_: cs: removeAttrs cs [ "pkgs-seed" ]) (
          lib.getAttrs [ "x86_64-linux" ] bp.checks
        );
      };
    };
}
