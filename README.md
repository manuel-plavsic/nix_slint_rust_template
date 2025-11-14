# Cross-platform template for Slint and Rust apps using Nix

This template allows to create cross-platform Slint applications using a Nix flake, which is in charge of all the dependencies for all platforms. This leads to the same environment being easily reproduced across different machines. The template can be used to also include additional logic (e.g., backend dependencies).

The Android emulator is also included in the dependencies. The right configuration has already been set in place to run it with hardware acceleration.

## Platforms and corresponding crates

This template supports GNU/Linux, MacOS, Android and iOS.

Since Windows is not supported by Nix, there is currently no support for it. However, a PR that adds Windows support (maybe through through WSL and cross compilation?) is very welcome.

A Rust crate is defined per platform. This allows to fine-tune the configuration per platform, in detail. A reusable crate for the UI components is not yet included, but it is also planned.

## How to use

- Ensure you have `nix` installed.
- Download and all that is in this repo to a new git repo, change/remove the README.md and the LICENSE, make optional small adjustments and create your first commit.
- Run `nix develop -c nu` (this ensures that nushell is already entered).
  - Note that Nushell is the shell used throughout this guide. Feel free to use another one, such as Bash, or Zsh.
  - Note that just `nix develop` will enter Bash automatically, regardless of which shell you are calling the command from or you set as default.

### Run app on GNU/Linux or MacOS

NB: If you are on GNU/Linux, this template assumes that you are using Wayland (it is possible that it works also on X.11 out of the box). On MacOS, there are no considerations to be made.

The Desktop app uses WGPU with hardware acceleration, but it is possible to use other backends (this will require updating the `Cargo.toml` files of the targeted platforms and potentially the `flake.nix`).

Steps to run the app:

- `cd ./app-linux` or `cd ./app-macos`, depending on your platform.

- ```nu
  SLINT_LIVE_PREVIEW=1 cargo run
  ```

#### Live Preview

Note that *Live Preview* functionality is enabled out of the box. To disable it, just call `cargo run` (preferably also remove the feature from the respective `Cargo.toml`).

### Run app on Android

- **Prerequisite**: you need to have an Android emulator created.
  <details>
  <summary>Show how to create an emulator</summary>
    <pre><code class="language-bash">avdmanager create avd -n a16 -k "system-images;android-36;google_apis_playstore;x86_64" --device "resizable"</code></pre>
    NB: This assumes you are running the emulator from a x86_64 system. In case of an ARM workstation, please use the following code instead:
    <pre><code class="language-bash">avdmanager create avd -n a16 -k "system-images;android-36;google_apis_playstore;arm64-v8a" --device "resizable"</code></pre>
    NB: The emulator will have Android version 16 (API 36).
  </details>

- Change the current directory to `app-android` and ensure the Emulator is running in the background (instructions are below):

  ```nu
  cd ./app-android
  job spawn { emulator -avd a16 -gpu host }
  ```

  The `job spawn` command allows to run the emulator in the background, allowing you to enter other commands. Its concept is similar to `&` in bash.

- At this point you can install the APK on the emulator:

  ```nu
  cargo apk run --target x86_64-linux-android --lib
  ```

  NB: The specified platform is x86_64. You can change it to, e.g., `aarch64-linux-android` to target real devices or the Android emulator on an ARM workstation.

#### Live Preview

The Slint feature *Live Preview* does not seem to be compatible with Android at the moment.

### Run app on iOS

**Note:** Running the iOS app requires the iOS SDK to be present on the system. At the moment, this is possible only with the SDK installed directly from a version of Xcode not from nixpkgs, because the iOS SDK is not yet available on nixpkgs (`apple-sdk` only contains the macOS SDK). The only package that is included in the flake, and thus does not need to be installed separately, is `xcodegen`.

Steps:
1. Install Xcode from the App Store.
2. Open Xcode and go to Settings > Components.
3. Select the iOS SDK (ensure it matches the version defined in the flake.nix). The iOS Simulator SDK is not required to run the slint app on the simulator.
4. Run `nix develop -c nu` and enter `app-ios`.
5. Try running `cargo run --target aarch64-apple-ios` to test if the application compiles successfully. If not, check the output for any errors and try to resolve them.
6. Adapt the information in the `project.yml` file.
  - Note that `ExampleApp` is present twice. Replace both occurrences.
  - `app-ios` is the name of the binary cargo produces. If you changed this name, you need to update the corresponding part in the `project.yml` file accordingly.
7. Run `xcodegen`.
8. Open XCode and build the app, it should complete fine.
9. You can now run the app on your device or simulator.

**Technical details:**
- In the `shellHook` section of the flake, the two environment variables `DEVELOPER_DIR` and `SDKROOT` are unset to allow proper iOS SDK detection (note that these variables are initially set to nix-store paths when entering via `nix develop`. They are then immediately cleared with the mentioned `unset` calls to mimic the native macOS behavior where these variables aren't set globally).
- The `PATH` gets altered to use the globally installed `/usr/bin/xcrun` instead of the one provided by nixpkgs, to prevent some conflicts (note that this "workaround" is necessary because `xcbuild`, which contains `xcrun`, gets automatically pulled as dependency, even though it is not directly listed as a dependency in the flake).

## Disable certain platforms

It is possible to set one or more environment variables to disable certain platforms. When entering the dev shell, the `--impure` flag will be necessary, as it is required to allow reading from the environment variables.

All flags:

- `NO_ANDROID`: On GNU/Linux and macOS, Android support is enabled by default (including the Android emulator). To disable it, set the environment variable `NO_ANDROID=1`.
- `NO_IOS`: On MacOS, iOS support is enabled by default. To disable it, set the environment variable `NO_IOS=1`.
- `NO_MACOS`: On MacOS, macOS support is enabled by default. To disable it, set the environment variable `NO_MACOS=1`.
- `NO_LINUX`: On GNU/Linux, GNU/Linux support is enabled by default. To disable it, set the environment variable `NO_LINUX=1`.

### Example: Disable Android support

To disable Android support:

```nu
NO_ANDROID=1 nix develop . --impure -c nu
```

## Automatically load environment with `direnv`

`direnv` allows to automatically load environment defined in the Nix flake. It also does not change your shell after creating a cache.

Steps:

- Install `direnv` globally
- Create an `.envrc` file in your project's root folder. The file must contain:
  ```
  use flake
  ```
- In the same directory, run `direnv allow`.

Note that you might have to add a shell-specific hook command, and your IDE might need a `direnv` extension.

### Disable certain platforms (`direnv`)

Similarly to `nix develop`, you can disable certain platforms by setting the corresponding environment variables in `.envrc` and adding the `--impure` flag, which is necessary to read from the environment variables.

Do not forget to run again `direnv allow` every time the `.envrc` file is changed.

#### Example: Disable Android support (`direnv`)

To disable Android, change your `.envrc` file to:

```
export NO_ANDROID=1

use flake . --impure
```

# Troubleshooting

## All platforms

### Live Preview

There will be compile time errors if you set the `SLINT_LIVE_PREVIEW` envar without enabling the corresponding feature.

## GNU/Linux

### Vulkan (GNU/Linux)

Vulkan should work out of the box on GNU/Linux. Should it not happen, try adding the following environment variables to the flake:

```
VK_LAYER_PATH = "${pkgs.vulkan-validation-layers}/share/vulkan/explicit_layer.d";
VULKAN_SDK = "${pkgs.vulkan-headers}";
```

Maybe also add the following `linuxTools` and/or `linuxLdLibraryPath`:

```
pkgs.vulkan-headers
pkgs.vulkan-loader
```

### Use OpenGL (GNU/Linux)

To use OpenGL, add the following package to the `linuxLdLibraryPath`:

```
pkgs.libGL
```

You might have to also change the cargo features.

## Android

### SDK Issues

Some issues can be experienced if some of the platforms are removed.

For example, changing the following part of the Nix Flake:

```
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
```

to just:

```
buildToolsVersions = [
  "36.0.0"
];
platformVersions = [
  "36" # Android 16
];
```

will result in a platform-not-found error. In case this list needs to be shortened, try removing the unwanted platforms one by one and testing immediately afterwards.

### Android Emulator

#### Enable Vulkan support for the Android Emulator (Host: GNU/Linux)

At the time of writing, Vulkan is correctly detected only if `vulkan-loader` is present in the `LD_LIBRARY_PATH` and if the right paths to Vulkan ICD manifest files are present in `VK_ICD_FILENAMES`.

For example, the following can be used to set `VK_ICD_FILENAMES` to:

```
"/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json:/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json:/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json"
```

This should allow the emulator to use Vulkan using any x86_64 workstation. Of course, it is possible to remove some of the paths, or add more (see available ICDs on your machine with `ls /run/opengl-driver/share/vulkan/icd.d/`). This might be necessary if using GNU/Linux on ARM (not tested).

#### Vulkan fallbacks to OpenGL (Host: GNU/Linux)

While Vulkan is used, there seems to be a translation layer with OpenGL (in the logs appear `Graphics API Version OpenGL ES 3.0 (4.6 (Core Profile) Mesa 25.2.4)` and `useVulkanComposition: false`).

If someone finds a way to enable Vulkan Composition, please open a PR or open an issue/discussion. That would be highly appreciated.

#### Disable Vulkan (Host: GNU/Linux)

If the emulator is not running correctly, the added flag forces OpenGL-only rendering:

```bash
emulator -avd a16 -gpu host -feature -Vulkan
```

#### Disable Vulkan, GLDirectMem and GLESDynamicVersion (Host: GNU/Linux)

If the emulator is not running correctly, you might try a combination of the following flags:

```bash
emulator -avd a16 -gpu host -feature -Vulkan -feature -GLDirectMem -feature -GLESDynamicVersion
```

Short explanations:

- When enabled, GLDirectMem allows the emulator to share GPU memory directly between the Android guest and the host system for improved performance. Disabling GLDirectMem may improve compatibility.
- When enabled, `GLESDynamicVersion` allows the emulator to dynamically select the best OpenGL ES version for the host system. Disabling `GLESDynamicVersion` may improve compatibility (it may fix some driver issues).

#### Disable audio

If your workstation sound is distorted when running the emulator, a workaround is to run it with the `-noaudio` flag.

```bash
emulator -avd a16 -gpu host -noaudio
```
