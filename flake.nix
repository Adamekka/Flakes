{
  description = "A templating flake for my projects";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs@{ flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];

      flake = let
        inherit (nixpkgs.lib) mapAttrs filterAttrs;

        templatesDir = ./templates;

        templateDirContents = builtins.readDir templatesDir;

        dirs = filterAttrs (_: type: type == "directory") templateDirContents;

        templates = mapAttrs (name: _: {
          path = templatesDir + "/${name}";
          description = "${name} template";
        }) dirs;
      in {
        inherit templates;
      };
    };
}
