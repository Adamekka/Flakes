{
  description = "Flutter 3.13.x";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };
  outputs =
    inputs@{
      self,
      flake-parts,
      nixpkgs,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      perSystem =
        { system, ... }:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = {
              android_sdk.accept_license = true;
              allowUnfree = true;
            };
          };
          androidSdk =
            (pkgs.androidenv.composeAndroidPackages {
              platformVersions = [ "34" "33" ];
              buildToolsVersions = [ "34.0.0" ];
              includeNDK = false;
            }).androidsdk;
        in
        {
          devShells.default = pkgs.mkShell {
            ANDROID_SDK = "${androidSdk}/libexec/android-sdk";
            buildInputs = with pkgs; [
              flutter
              androidSdk
              jdk17
            ];
          };
        };
    };
}
