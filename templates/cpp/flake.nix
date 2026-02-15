{
  description = "C++ Flake";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = inputs@{ flake-parts, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      perSystem =
        { pkgs, ... }: {
          devShells.default = pkgs.mkShell.override { stdenv = pkgs.clangStdenv; } {
            packages = with pkgs; [
              clang-tools
              clang-analyzer
              cmake
              lldb
              ninja
            ];

            shellHooks = ''
              echo "Make sure `programs.nix-ld.enable` is set to true for LLDB to work.";
              echo "Change executable name in `.vscode/launch.json` and `CMakeLists.txt`";
            '';
          };
        };
    };
}
