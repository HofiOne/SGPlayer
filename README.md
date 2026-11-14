# SGPlayer

This fork adds basic Apple Silicon support to macOS SGPlayer and separate
Metal shader libraries for iOS Simulator and tvOS Simulator.

![Logo](https://github.com/libobjc/SGPlayer/blob/master/documents/banner.jpg?raw=true)

![Build Status](https://img.shields.io/badge/build-%20passing%20-brightgreen.svg)
![Platform](https://img.shields.io/badge/Platform-%20iOS%20macOS%20tvOS%20-blue.svg)

SGPlayer is a media playback framework for iOS, macOS, and tvOS.

## Based On

- FFmpeg
- Metal
- AudioUnit

## Features

- iOS, tvOS, macOS.
- 360° panorama video.
- Background playback.
- RTMP/RTSP streaming.
- Setting playback speed.
- Multiple audio/video tracks.
- H.264/H.265 hardware accelerator.

## Build

Run the commands below from this repository's root, with the intended Xcode
selected. FFmpeg compilation, universal XCFramework packaging, and building the
SGPlayer framework are separate steps. Xcode's command-line tools and Ruby are
required.

```sh
IPHONEOS_DEPLOYMENT_TARGET=15.0 \
MACOSX_DEPLOYMENT_TARGET=12.0 \
TVOS_DEPLOYMENT_TARGET=15.0 \
./buildkit.sh build all
./make-universal-frameworks.rb --configuration all
```

If the dependency build output already exists, run only the packaging command.
For existing Debug output under `build/Debug/prebuilt`:

```sh
./make-universal-frameworks.rb --configuration Debug
```

### FFmpeg Dependencies

Use [buildkit.sh](buildkit.sh), not the legacy `build.sh`, for this fork's
FFmpeg dependencies. Select an Xcode installation with the required platform
SDKs before running it.

```sh
IPHONEOS_DEPLOYMENT_TARGET=15.0 bash ./buildkit.sh build iOS
TVOS_DEPLOYMENT_TARGET=15.0 bash ./buildkit.sh build tvOS
MACOSX_DEPLOYMENT_TARGET=12.0 bash ./buildkit.sh build macOS
```

Omitting the platform selects `all`. The wrapper resolves directories relative to
its own location rather than the calling directory. `BUILD_DIR` overrides the
FFmpegKit checkout/build root, and `FRAMEWORK_DIR` overrides its installation
root; use absolute paths. Extra arguments are forwarded without splitting quoted
values. `bash ./buildkit.sh clean` removes only the local Debug/Release checkout
and build trees, not installed XCFrameworks.

### Deployment Targets

The minimum OS version comes from an explicit forwarded `--target=VERSION`, then
the corresponding nonempty environment variable, then the matching SGPlayer
target in [project.pbxproj](SGPlayer.xcodeproj/project.pbxproj). Debug and Release
settings are read separately by [deployment-target.rb](scripts/deployment-target.rb).
Target settings inherit from the matching project configuration when necessary;
missing or unresolved values fail instead of using a guessed minimum.

| Platform | Environment Variable / Xcode Setting | Current Debug | Current Release |
| --- | --- | --- | --- |
| iOS | `IPHONEOS_DEPLOYMENT_TARGET` | 15.0 | 15.0 |
| macOS | `MACOSX_DEPLOYMENT_TARGET` | 12.0 | 12.0 |
| tvOS | `TVOS_DEPLOYMENT_TARGET` | 15.0 | 15.0 |

Environment variables may be exported by the calling shell or passed before the
command, as in the examples. The wrapper does not load an `.env` file. Omit or
empty a variable to follow the project rather than pinning a value. A forwarded
`--target` takes precedence over the environment and applies to all selected
platforms, so per-platform variables are preferable for `build all`.
The examples pin the current minimums explicitly; omit the assignments to follow
future project-setting changes, provided the variables are not already exported.
The effective deployment target is printed to stdout before each platform's
Debug and Release build invocation.
Deployment minimums are independent of the selected Xcode SDK version.
Rebuild affected dependencies after changing them; packaging existing binaries
does not update their deployment targets.

### Universal XCFramework Packaging

There are three stages in producing the dependency packages:

1. FFmpegKit compiles each architecture into `prebuilt/apple-*` directories.
2. FFmpegKit merges architectures belonging to the same platform variant into
   the universal binaries under `prebuilt/bundle-apple-framework-*`.
3. [make-universal-frameworks.rb](make-universal-frameworks.rb) runs
   `xcodebuild -create-xcframework` on those platform frameworks to assemble the
   final packages. It does not merely copy an existing XCFramework bundle.

The platform inputs below are relative to `build/{Debug,Release}/prebuilt`:

| Package | Platform Framework Inputs | Included Architectures |
| --- | --- | --- |
| iOS | `bundle-apple-framework-iphoneos` | Device: ARM64 |
| iOS | `bundle-apple-framework-iphonesimulator` | Simulator: ARM64 and x86_64 |
| iOS | `bundle-apple-framework-mac-catalyst` | Catalyst: ARM64 and x86_64 |
| macOS | `bundle-apple-framework-macos` | ARM64 and x86_64 |
| tvOS | `bundle-apple-framework-appletvos` | Device: ARM64 |
| tvOS | `bundle-apple-framework-appletvsimulator` | Simulator: ARM64 and x86_64 |

Each library has one `.xcframework` per OS and configuration. Device, Simulator
and Catalyst slices stay together in the iOS package; tvOS also contains its
device and Simulator slices together. Do not copy separate packages into
`iOSSimulator` or `tvOSSimulator` directories.

A single fat Mach-O binary cannot combine device ARM64 and Simulator ARM64:
their platform ABIs differ. The XCFramework is the multi-platform container;
its Simulator, Catalyst and macOS binaries are fat binaries where appropriate.

FFmpegKit also emits `bundle-apple-xcframework-{ios,macos,tvos}`. The current
`buildkit.sh` installs those upstream-generated bundles as part of the build;
that copy does not create their universal binaries. The separate assembler makes
packaging explicit and reproducible from the platform frameworks, independently
of previously assembled bundles.

The assembler installs `libavcodec`, `libavdevice`, `libavfilter`, `libavformat`,
`libavutil`, `libswresample` and `libswscale`, each as an `.xcframework`:

| Platform | Debug Destination | Release Destination |
| --- | --- | --- |
| iOS | `../../iOS/Debug` | `../../iOS/Release` |
| macOS | `../../macOS/Debug` | `../../macOS/Release` |
| tvOS | `../../tvOS/Debug` | `../../tvOS/Release` |

Destinations are relative to this repository, under the parent Frameworks tree.
The assembler checks all selected inputs before packaging, creates all packages
in a temporary directory, and validates actual platform slices and binary
architectures before replacing installed packages. Missing inputs or failed
package creation leave installed packages untouched. Unselected libraries and
unrelated files are not removed.

```sh
# Validate every Debug/Release input without writing output.
./make-universal-frameworks.rb --configuration all --dry-run

# Package one OS, or one library for all OSes.
./make-universal-frameworks.rb --platform tvOS --configuration all
./make-universal-frameworks.rb --library libavutil

# Use a different existing build tree or an isolated installation root.
./make-universal-frameworks.rb --build-root /path/to/SGPlayer/build --output-root /path/to/output
```

Defaults are all three OSes, all seven libraries, and Debug. Use
`--configuration Release` or `--configuration all` when needed. The default
build root is `build` beside the script, and the installation root is two levels
above it. These defaults are independent of the calling directory; relative
override paths are resolved from that directory. If `buildkit.sh` used a custom
`BUILD_DIR`, pass the same directory through `--build-root`. Likewise,
`FRAMEWORK_DIR` is a wrapper setting; use `--output-root` for the assembler.

Before replacing installed dependencies, the wrapper checks that all seven
required XCFramework directories exist in the generated bundle. Missing build
output stops installation without deleting the previously installed frameworks.

### tvOS Build Details

The tvOS build enables AudioToolbox, VideoToolbox, bzip2, zlib, iconv and GnuTLS
with its GMP/Nettle dependencies. This FFmpegKit version rejects OpenSSL on tvOS;
GnuTLS retains TLS support for protocols such as HTTPS and RTMPS instead of
disabling encrypted networking. The iOS and macOS builds continue using OpenSSL.
The tvOS build disables bitcode and reads its deployment minimum using the
selection order above; the current project minimum is tvOS 15.0. Keep the
consuming target's minimum at least as high as its dependencies. There is no
tvOS AVFoundation build option.

The tvOS wrapper uses [gnutls-autopoint.sh](scripts/gnutls-autopoint.sh) during
GnuTLS bootstrap. Newer gettext tools can mistake the old GnuTLS macro-name
guard for a second `AM_GNU_GETTEXT_REQUIRE_VERSION` invocation. The helper
adjusts only that guard in the GnuTLS checkout without changing its M4 meaning,
then delegates to the original `AUTOPOINT` program (or `autopoint` from `PATH`).
It is safe to run repeatedly and does not change the global gettext installation.

Before each tvOS build, [prepare-tvos-gnutls.rb](scripts/prepare-tvos-gnutls.rb)
adds a tvOS-only Gnulib inline compatibility flag to the FFmpegKit GnuTLS recipe.
This prevents modern Apple SDKs from producing a static library with an undefined
`c_isdigit` symbol. Existing tvOS GnuTLS archives with that missing definition
automatically request `--rebuild-gnutls`; valid archives and the GMP/Nettle cache
are retained. A full `clean` is not required for this repair.

Upstream FFmpegKit writes environment variables to `build.log`, which can expose
tokens or other credentials inherited from the shell. Remove sensitive variables
from the build environment and redact existing logs before sharing them.

### SGPlayer Framework

After preparing the dependencies, build the appropriate SGPlayer target in
Xcode for the intended destination. In the MeMyselfAndI integration, use the
workspace at `../../../MeMyselfAndI/MeMyselfAndI.xcworkspace`, which includes this
SGPlayer project. Use `SGPlayer iOS` for iOS devices or simulators and
`SGPlayer tvOS` for Apple TV devices or simulators.

The tvOS target selects dependencies from `../../tvOS/$(CONFIGURATION)`, uses
the selected tvOS SDK's system frameworks, and currently requires tvOS 15.0 on
both devices and Simulator. Its checked-in Simulator shader's lower minimum
remains compatible with that target.

The app links the SGPlayer framework from Xcode's `BUILT_PRODUCTS_DIR`.
Simulator products are generated under `Debug-iphonesimulator` or
`Release-iphonesimulator`; an empty external `iOSSimulator` directory does not
mean that the SGPlayer Simulator build is missing. The equivalent tvOS product
directories are `Debug-appletvsimulator` and `Release-appletvsimulator`.

Application integration is separate: the app target must link SGPlayer and
embed the dynamic FFmpeg frameworks for its destination. Changing this repository
does not update the external Stream Player TV app project or its embedding steps.

### iOS Simulator Metal Shaders

SGPlayer embeds compiled Metal libraries as byte arrays. Device and Simulator
shader binaries are not interchangeable, even when both use ARM64. Using the
device shader in Simulator fails when creating a render pipeline with
`Target OS is incompatible: library was not compiled for the simulator`.

[SGMetalRenderPipelinePool.m](SGPlayer/Classes/Core/SGMetal/SGMetalRenderPipelinePool.m)
selects the checked-in
[Simulator header](SGPlayer/Classes/Core/SGMetal/SGMetalShader_iOSSimulator.h)
when both the iOS platform and `TARGET_OS_SIMULATOR` are selected. Physical iOS
devices continue using the existing device shader. The physical tvOS and macOS
shader paths are unchanged; tvOS Simulator uses the separate header below.

Regenerate the Simulator header after changing
[SGMetalShader.metal](SGPlayer/Classes/Core/SGMetal/SGMetalShader.metal) or
[SGMetalTypes.h](SGPlayer/Classes/Core/SGMetal/SGMetalTypes.h):

```sh
bash scripts/generate-ios-simulator-shader.sh
```

[generate-ios-simulator-shader.sh](scripts/generate-ios-simulator-shader.sh)
compiles the shader with the `iphonesimulator` SDK, links a `.metallib`, and
converts it to the checked-in C byte array. It requires Xcode's Metal toolchain
and Ruby, uses Metal language version 2.1, and defaults to iOS Simulator 15.0.
Intermediate files are created in a temporary directory and removed on exit.

The optional first argument changes the output header path. The
`IPHONEOS_DEPLOYMENT_TARGET` environment variable changes the minimum Simulator
OS version:

```sh
bash scripts/generate-ios-simulator-shader.sh /tmp/SGMetalShader_iOSSimulator.h
IPHONEOS_DEPLOYMENT_TARGET=15.0 bash scripts/generate-ios-simulator-shader.sh
```

Commit the regenerated header together with shader-source changes. Ordinary
framework builds use the checked-in header and do not run this generator.
The generator does not build FFmpeg, the SGPlayer framework, or the app; rebuild
SGPlayer in Xcode after regeneration to embed the new bytes. It only regenerates
the iOS Simulator shader, not the device or macOS shaders. Use the separate
generator below for tvOS Simulator.

### tvOS Simulator Metal Shaders

The tvOS Simulator branch embeds
[SGMetalShader_tvOSSimulator.h](SGPlayer/Classes/Core/SGMetal/SGMetalShader_tvOSSimulator.h)
instead of the device library. Regenerate it after changing the shared Metal
shader source or types:

```sh
TVOS_SIMULATOR_DEPLOYMENT_TARGET=15.0 bash scripts/generate-tvos-simulator-shader.sh
```

[generate-tvos-simulator-shader.sh](scripts/generate-tvos-simulator-shader.sh)
uses the `appletvsimulator` SDK, Metal language version 2.1, and a default
Simulator minimum of tvOS 13.0. Its optional first argument selects the output
header, and `TVOS_SIMULATOR_DEPLOYMENT_TARGET` overrides the shader minimum.
The example explicitly uses the current tvOS target minimum of 15.0. Keep that
value compatible with the tvOS target's Simulator deployment setting.
Intermediate files stay under this repository's `build` directory and are removed
on exit. The script requires the Xcode Metal toolchain and Ruby; it does not build
FFmpeg, SGPlayer, or an app.

### Wrapper Regression Checks

```sh
ruby scripts/check-buildkit.rb
```

[check-buildkit.rb](scripts/check-buildkit.rb) runs the actual wrapper against
fake FFmpegKit platform scripts. It checks Debug/Release selection, tvOS options,
all-platform builds, quoted arguments, installation, stale-output cleanup and
failure propagation. It does not build dependencies or access the network, and
all temporary fixtures stay under this repository's `build` directory.

After the tvOS ARM64 GnuTLS dependencies have been built, the focused
[check-tvos-gnutls-link.rb](scripts/check-tvos-gnutls-link.rb) diagnostic can
verify the Gnulib compatibility flag and link `gnutls_global_init` against the
existing libraries with an isolated repaired object:

```sh
ruby scripts/check-tvos-gnutls-link.rb
```

It defaults to the Debug checkout; pass `Release` to inspect that configuration.
The probe builds only temporary C objects and an executable under `build`, not
the dependency libraries or an application.

## Usage

- Open demo/demo.xcworkspace with Xcode.

## Dependencies

```obj-c
- SGPlayer.framework
- AVFoundation.framework
- AudioToolbox.framework
- VideoToolBox.framework
- libiconv.tbd
- libbz2.tbd
- libz.tbd
```

## Flow Chart

![Flow Chart](https://github.com/libobjc/SGPlayer/blob/master/documents/flow-chart.jpg?raw=true)

## Related

- [KTVHTTPCache](https://github.com/ChangbaDevs/KTVHTTPCache) - A smart media cache framework.
- [KTVVideoProcess](https://github.com/ChangbaDevs/KTVVideoProcess) - A High-Performance video effects processing framework.

## Communication

- GitHub : [Single](https://github.com/libobjc)
- Email : [libobjc@gmail.com](mailto:libobjc@gmail.com)
