{
  description = "default flake-parts flake";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        # Optional: use external flake logic, e.g.
        # inputs.foo.flakeModules.default
      ];
      flake = {
        # Put your original flake attributes here.
      };
      systems = [
        # systems for which you want to build the `perSystem` attributes
        "x86_64-linux"
        # ...
      ];
      perSystem =
        { config, pkgs, ... }:
        {
          # Recommended: move all package definitions here.
          # e.g. (assuming you have a nixpkgs input)
          # packages.foo = pkgs.callPackage ./foo/package.nix { };
          # packages.bar = pkgs.callPackage ./bar/package.nix {
          #   foo = config.packages.foo;
          # };
        };
    };
}
