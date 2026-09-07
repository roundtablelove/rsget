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
      };
      githubActions = inputs.nix-github-actions.lib.mkGithubMatrix {
        checks = lib.getAttrs [ "x86_64-linux" ] bp.checks;
      };
    };
}
