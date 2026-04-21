{
  description = "Swift 6.3.1 toolchain for Linux, wrapped in an FHS env for NixOS.";

  inputs = {
    # Current nixpkgs supplies the main toolchain (glibc, gcc, coreutils,
    # etc.) at the versions this machine is likely to already have.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # libxml2 2.14+ bumped its SONAME to `libxml2.so.16`, but the Ubuntu
    # 24.04 Swift build links against `libxml2.so.2` (2.13.x). We pin a
    # separate 24.11 input just to pull libxml2 2.13.8, which still ships
    # the .so.2 SONAME the pre-built swift-build expects.
    nixpkgs-compat.url = "github:nixos/nixpkgs/nixos-24.11";
  };

  outputs = { self, nixpkgs, nixpkgs-compat }:
    let
      # Only x86_64-linux is supplied as an official Swift tarball today,
      # and that is what this machine is, so we intentionally do not try
      # to support other systems here.
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      compat = nixpkgs-compat.legacyPackages.${system};
      lib = pkgs.lib;

      swiftVersion = "6.3.1";

      # Official Swift binary distribution. Ubuntu 24.04 build is chosen
      # because its glibc (2.39) is the newest supported base that still
      # runs against NixOS's current glibc (2.40+) via the FHS env.
      swiftTarball = pkgs.fetchurl {
        url = "https://download.swift.org/swift-${swiftVersion}-release/ubuntu2404/swift-${swiftVersion}-RELEASE/swift-${swiftVersion}-RELEASE-ubuntu24.04.tar.gz";
        hash = "sha256-x5KKv9prkW2BLSMaXHJKamvfJYeCmPa97ORR9YWrml8=";
      };

      # Raw unpacked toolchain. We must disable every fixup Nix normally
      # applies to binaries, otherwise patchelf/strip would corrupt the
      # pre-linked Swift compiler and friends, which rely on the Ubuntu
      # ELF interpreter + library layout we restore via buildFHSEnv.
      swiftToolchain = pkgs.stdenvNoCC.mkDerivation {
        pname = "swift-toolchain";
        version = swiftVersion;
        src = swiftTarball;

        dontConfigure = true;
        dontBuild = true;
        dontPatchELF = true;
        dontStrip = true;
        dontFixup = true;

        # Preserve the tarball's `usr/{bin,lib,include,share,libexec}`
        # layout directly under $out so swift's argv0-relative resource
        # lookup (`$(dirname $0)/../lib/swift`) works unmodified.
        installPhase = ''
          runHook preInstall
          mkdir -p $out
          shopt -s dotglob
          cp -r ./usr/. $out/
          runHook postInstall
        '';

        meta = {
          description = "Unpacked Swift ${swiftVersion} toolchain (Ubuntu 24.04 build)";
          homepage = "https://swift.org";
          license = lib.licenses.asl20;
          platforms = [ system ];
        };
      };

      # Non-wide ncurses build. The default nixpkgs `ncurses` ships only
      # the UCS/wide variant and symlinks `libncurses.so.6` ->
      # `libncursesw.so.6`, which means the non-wide NCURSES6_*.x.xxx
      # symbol versions liblldb was linked against are missing. Rebuilding
      # with `unicodeSupport = false` produces a real, non-wide
      # libncurses.so.6 that exports those symbols.
      ncursesNonWide = pkgs.ncurses.override { unicodeSupport = false; };

      # Ubuntu 24.04 ships libedit with SONAME `libedit.so.2`, but current
      # nixpkgs libedit still uses the historical SONAME `libedit.so.0`.
      # The ABI is stable enough that a plain SONAME-level symlink is
      # sufficient to make lldb load. Wrapped as its own derivation so
      # buildFHSEnv picks it up via /usr/lib.
      libeditSoname2 = pkgs.runCommand "libedit-soname2-shim"
        {
          # We don't touch the original libedit; we just re-expose its
          # SONAME under the name Ubuntu's lldb hard-codes.
          passthru = { upstream = pkgs.libedit; };
        } ''
        mkdir -p $out/lib
        ln -s ${pkgs.libedit}/lib/libedit.so.0 $out/lib/libedit.so.2
      '';

      # libtinfo.so.6 compat. The non-wide ncurses build above bundles
      # terminfo symbols directly into libncurses, so lldb's dlopen of
      # libtinfo.so.6 only needs a filename alias pointing at the same
      # library.
      libtinfoSoname6 = pkgs.runCommand "libtinfo-soname6-shim" { } ''
        mkdir -p $out/lib
        ln -s ${ncursesNonWide}/lib/libncurses.so.6 $out/lib/libtinfo.so.6
      '';

      # Packages that must be visible inside the FHS sandbox so that the
      # pre-built Swift binaries can dynamically link, shell out to
      # system tools, and drive the usual SwiftPM build pipeline.
      swiftRuntimePkgs = with pkgs; [
        # C/C++ runtime and loader
        glibc
        glibc.dev
        gcc-unwrapped
        gcc-unwrapped.lib

        # Runtime libs that Swift itself and swift-corelibs depend on.
        # Mirrors the Debian-style dependency list Apple publishes for
        # the ubuntu24.04 tarball.
        curl
        icu
        libedit
        libuuid
        openssl
        sqlite
        zlib

        # lldb (and therefore `swift repl`) links to libpython3.12. The
        # default `python3` alias is currently 3.13, so pin 3.12.
        python312

        # Tools SwiftPM / clang will invoke on the user's behalf during
        # normal builds. Keeping them inside the FHS means the user does
        # not need extra system packages installed just to compile.
        binutils
        coreutils
        file
        findutils
        gawk
        gnugrep
        gnumake
        gnused
        gnutar
        gzip
        patchelf
        pkg-config
        which
        xz
      ] ++ [
        # Older-SONAME compatibility shims. These are pulled from pinned
        # nixpkgs branches or locally rebuilt because current nixpkgs
        # ships SONAMEs/ABIs that do not match what the Ubuntu 24.04
        # Swift tarball was linked against.
        compat.libxml2     # libxml2.so.2 (current nixpkgs is 2.15 -> libxml2.so.16)
        ncursesNonWide     # libncurses.so.6 with NCURSES6_* symbol versions
        libeditSoname2     # libedit.so.2 -> libedit.so.0 alias
        libtinfoSoname6    # libtinfo.so.6 -> libncurses.so.6 alias
      ];

      # Single FHS env that contains the toolchain plus every runtime
      # dependency above. We `runScript = "bash"` so we can re-enter it
      # from thin per-binary wrappers via `bash -c`.
      swiftFHS = pkgs.buildFHSEnv {
        name = "swift-fhs";
        targetPkgs = _: [ swiftToolchain ] ++ swiftRuntimePkgs;
        runScript = "bash";
        # Ensure the toolchain's own bin/ wins on PATH so users invoking
        # `clang` get the Swift-bundled clang (required for module
        # compatibility), not the stdenv one.
        profile = ''
          export PATH=${swiftToolchain}/bin:$PATH
        '';
      };

      # Build-time-generated thin wrappers, one per executable in the
      # toolchain's bin/. We generate at build time (not eval time) so
      # `nix flake check` does not require importing-from-derivation.
      #
      # Each wrapper:
      #   1. Enters the FHS env via `swift-fhs -c`.
      #   2. Prepends /lib:/usr/lib to LD_LIBRARY_PATH. This works around
      #      nixpkgs providing libncurses.so.6 and libtinfo.so.6 as
      #      symlinks to libncursesw.so.6, which means ldconfig only
      #      caches the `w` name; direct LD_LIBRARY_PATH lookup on the
      #      symlinks gives us the SONAMEs swift actually asks for.
      #   3. Re-execs the real binary with argv[0] set to the command
      #      name; Swift tools resolve some sibling binaries relative to
      #      their own argv[0].
      #
      # We only wrap actual executables (skipping clang .cfg config
      # files and any stray non-exec helpers).
      swift = pkgs.runCommand "swift-${swiftVersion}"
        {
          passthru = { inherit swiftToolchain swiftFHS; };
          meta = {
            description = "Swift ${swiftVersion} toolchain wrapped in an FHS env for NixOS";
            homepage = "https://swift.org";
            license = lib.licenses.asl20;
            mainProgram = "swift";
            platforms = [ system ];
          };
        } ''
        mkdir -p $out/bin
        for bin in ${swiftToolchain}/bin/*; do
          # Skip non-executable sidecar files such as the clang
          # `*-clang*.cfg` driver config files that live next to the real
          # binaries and would otherwise get spurious wrappers.
          [ -x "$bin" ] || continue
          [ -f "$bin" ] || continue

          name=$(basename "$bin")
          cat > "$out/bin/$name" <<WRAPPER
        #!${pkgs.runtimeShell}
        exec ${swiftFHS}/bin/swift-fhs -c 'export LD_LIBRARY_PATH="/lib:/usr/lib\''${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"; exec "\$0" "\$@"' "$name" "\$@"
        WRAPPER
          chmod +x "$out/bin/$name"
        done
      '';
    in
    {
      packages.${system} = {
        inherit swift;
        default = swift;
        toolchain = swiftToolchain;
        fhs = swiftFHS;
      };

      apps.${system} = {
        default = {
          type = "app";
          program = "${swift}/bin/swift";
        };
        swift = {
          type = "app";
          program = "${swift}/bin/swift";
        };
        swiftc = {
          type = "app";
          program = "${swift}/bin/swiftc";
        };
        repl = {
          type = "app";
          program = "${swift}/bin/swift";
        };
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [ swift ];
        shellHook = ''
          echo "Swift ${swiftVersion} (Linux, FHS-wrapped) ready. Try: swift --version"
        '';
      };

      formatter.${system} = pkgs.nixpkgs-fmt;
    };
}
