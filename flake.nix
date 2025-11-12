{
  description = "Full-stack environment with dynamic roles (Rust-overlay flake)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      rust-overlay,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        overlays = [ (import rust-overlay) ];
        
        pkgs = import nixpkgs {
          inherit system overlays;
          config.allowUnfree = true;
          android_sdk.accept_license = if roles.android then true else false; # todo: try if it works
        };

        isMac = pkgs.stdenv.isDarwin;
        isLinux = pkgs.stdenv.isLinux;

        # check if a flag is enabled
        enabled = v: v == "1";

        roles = {
          android = if enabled (builtins.getEnv "NO_ANDROID") then false else true;
          ios =
            if enabled (builtins.getEnv "NO_IOS") then
              false
            # otherwise (if NO_IOS is not set):
            else if isMac then
              true
            else
              false; # iOS utils only work on a Mac
          linux =
            if enabled (builtins.getEnv "NO_LINUX") then
              false
            # otherwise (if NO_LINUX is not set):
            else if isLinux then
              true
            else
              false; # Linux utils only work on a Linux machine
          macos =
            if enabled (builtins.getEnv "NO_MACOS") then
              false
            # otherwise (if NO_MACOS is not set):
            else if isMac then
              true
            else
              false; # MacOS utils only work on a Linux machine
        };

        # minimal set of packages
        rustTools = with pkgs; [
          (rust-bin.stable.latest.default.override {
            extensions = [ "rust-src" ];
            targets = (if roles.linux then if system == "aarch64-linux" then ["aarch64-unknown-linux-gnu"] else ["x86_64-unknown-linux-gnu"] else [ ])
            ++ (if roles.macos then if system == "aarch64-darwin" then ["aarch64-apple-darwin"] else ["x86_64-apple-darwin"] else [ ])
            ++ (if roles.android then ["aarch64-linux-android" "x86_64-linux-android"] else [ ]) # optionally include older "armv7-linux-androideabi" and "i686-linux-android"
            ++ (if roles.ios then ["aarch64-apple-ios" "aarch64-apple-ios-sim"] else [ ]);
            # TODO: find a way to include "aarch64-pc-windows-msvc" "x86_64-pc-windows-msvc"
          })
          clippy
          rust-analyzer
          cargo
          just
          gcc
          openssl
          pkg-config
          nushell
        ];

        slintTools = with pkgs; [
          slint-lsp
          slint-viewer
        ];

        linuxLdLibraryPath =
          if roles.linux then
            [
              pkgs.wayland # REQUIRED to build and run the app on Linux with Wayland
              pkgs.libxkbcommon # REQUIRED (this prevents `called `Result::unwrap()` on an `Err` value: XKBNotFound`)
            ]
          else
            [ ];
        linuxTools =
          if roles.linux then
            [
            ]
          else
            [ ];

        macosLdLibraryPath = if roles.macos then [ ] else [ ];
        macosTools = if roles.macos then [ ] else [ ];

        # TODO
        iosLdLibraryPath = if roles.ios then [ ] else [ ];
        iosTools = if roles.ios then [ ] else [ ];

        androidLdLibraryPath =
          if roles.android then
            if isLinux then
              [
                pkgs.vulkan-loader
                pkgs.libGL # REQUIRED to run the emulator with OpenGL (common fallback from Vulkan to OpenGL in case of `useVulkanComposition: false`)
              ]
            else
              [ ] # macOS does not need vulkan-loader and libGL
          else
            [ ];
        androidTools =
          if roles.android then
            [
              pkgs.gradle # REQUIRED to build and run the app
              pkgs.jdk17 # REQUIRED to build and run the app
              androidSdk # REQUIRED to build and run the app
              pkgs.cargo-apk # REQUIRED to build and run the app with Cargo
              pkgs.cargo-ndk # REQUIRED to build and run the app with Rust
            ]
          else
            [ ];

        # complements androidTools
        androidSdk =
          if roles.android then
            let
              androidEnv = pkgs.androidenv.override { licenseAccepted = true; };
              composition = androidEnv.composeAndroidPackages {
                includeNDK = true;
                cmdLineToolsVersion = "8.0";
                platformToolsVersion = "36.0.0";
                buildToolsVersions = [
                  "30.0.3"
                  "33.0.2"
                  "34.0.0"
                  "35.0.0"
                  "36.0.0"
                ];
                platformVersions = [
                  "30" # Android 11
                  "31" # Android 12
                  "32" # Android 12L
                  "33" # Android 13
                  "34" # Android 14
                  "35" # Android 15
                  "36" # Android 16
                ];
                abiVersions = abiVersions;
                includeEmulator = true;
                includeSystemImages = true;
                systemImageTypes = [ "google_apis_playstore" ];
              };
            in
            composition.androidsdk
          else
            null;

        # complements androidSdk
        abiVersions =
          if system == "x86_64-linux" || system == "x86_64-darwin" then
            [ "x86_64" ]
          else if system == "aarch64-linux" || system == "aarch64-darwin" then
            [ "arm64-v8a" ]
          else
            builtins.throw "Unsupported architecture: ${system}. Only x86_64-linux, x86_64-darwin, aarch64-linux, and aarch64-darwin are supported for Android development.";
      in
      {
        devShells.default = pkgs.mkShell {
          name = "dev";

          buildInputs =
            rustTools
            ++ slintTools
            ++ (if roles.linux then linuxTools else [ ])
            ++ (if roles.macos then macosTools else [ ])
            ++ (if roles.android then androidTools else [ ])
            ++ (if roles.ios then iosTools else [ ]);

          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (
            (if roles.linux then linuxLdLibraryPath else [ ])
            ++ (if roles.macos then macosLdLibraryPath else [ ])
            ++ (if roles.android then androidLdLibraryPath else [ ])
            ++ (if roles.ios then iosLdLibraryPath else [ ])
          );

          # Android graphics envars
          QT_QPA_PLATFORM = if roles.android then if isLinux then "wayland;xcb" else "cocoa" else null; # cocoa is the mac platform
          LIBGL_DRIVERS_PATH = if roles.android then "/run/opengl-driver/lib/dri" else null;
          VK_ICD_FILENAMES =
            if roles.android then
              if isLinux then
                "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json:/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json:/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json:/run/opengl-driver/share/vulkan/icd.d/gfxstream_vk_icd.x86_64.json"
              else
                null # in case of macOS, Vulkan is not used, so `null`
            else
              null;

          # Android envars
          ANDROID_HOME = if roles.android then "${androidSdk}/libexec/android-sdk" else null;
          ANDROID_NDK_ROOT = if roles.android then "${androidSdk}/libexec/android-sdk/ndk-bundle" else null;
          JAVA_HOME = if roles.android then pkgs.jdk17.home else null;
          GRADLE_OPTS =
            if roles.android then
              "-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidSdk}/libexec/android-sdk/build-tools/36.0.0/aapt2"
            else
              null;

          # desktop envars
          SLINT_BACKEND = if roles.linux || roles.macos then "winit-femtovg-wgpu" else "";
          # SLINT_LIVE_PREVIEW: do not set this envar here.

          shellHook = ''
            echo "Loaded roles:"
            echo "  android: ${toString roles.android}"
            echo "  ios:     ${toString roles.ios}"
            echo "  linux:   ${toString roles.linux}"
            echo "  macos:   ${toString roles.macos}"
          '';
        };
      }
    );
}
