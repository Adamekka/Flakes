{
  description = "Typst project flake";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      perSystem =
        {
          config,
          self',
          inputs',
          pkgs,
          system,
          ...
        }:
        {
          devShells.default = pkgs.mkShell {
            name = "typst-novel-env";

            packages = with pkgs; [
              # Typst & LSP
              typst
              tinymist

              # Grammar & Spell Checking (LanguageTool supports EN and CZ out of the box)
              ltex-ls
              hunspell
              hunspellDicts.cs_CZ
              hunspellDicts.en_US-large

              # Local AI
              ollama
            ];

            # Environment variables to help LTeX find the Hunspell dictionaries
            DICPATH = "${pkgs.hunspellDicts.cs_CZ}/share/hunspell:${pkgs.hunspellDicts.en_US-large}/share/hunspell";

            shellHook = ''
              echo "======================================================"
              echo "🖋️  Typst Writing Environment (EN/CZ) Loaded!"
              echo "======================================================"

              # Runtime check for Nvidia GPU
              if command -v nvidia-smi &> /dev/null; then
                GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1)
                echo "✅ Nvidia GPU detected: $GPU_NAME"
                echo "🧠 Ollama is ready to use hardware acceleration for your models."
              else
                echo "⚠️  No Nvidia GPU detected on this host."
                echo "🐢 Ollama is available but will run entirely on the CPU (Not recommended for the Lenovo G15!)."
              fi
              echo "======================================================"
            '';
          };
        };
    };
}
