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

Run the commands below from this repository's root. Building the FFmpeg
dependencies and building the SGPlayer framework are separate steps.

### FFmpeg Dependencies

Use [buildkit.sh](buildkit.sh), not the legacy `build.sh`, for this fork's
FFmpeg dependencies. Select an Xcode installation with the required platform
SDKs before running it.

```sh
bash ./buildkit.sh build iOS
bash ./buildkit.sh build tvOS
bash ./buildkit.sh build macOS

# Build all three platforms.
bash ./buildkit.sh build all
```

The script creates FFmpegKit checkouts under `build/Debug` and `build/Release`,
builds the dependencies, and copies their XCFramework bundles automatically:

| Platform | Generated Bundle | Installed Location |
| --- | --- | --- |
| iOS | `build/{Debug,Release}/prebuilt/bundle-apple-xcframework-ios` | `../../iOS/{Debug,Release}` |
| tvOS | `build/{Debug,Release}/prebuilt/bundle-apple-xcframework-tvos` | `../../tvOS/{Debug,Release}` |
| macOS | `build/{Debug,Release}/prebuilt/bundle-apple-xcframework-macos` | `../../macOS/{Debug,Release}` |

The installed locations are relative to this repository. A manual copy is not
normally needed. The iOS and tvOS XCFrameworks contain device and Simulator
slices, which Xcode selects for the destination; they do not need separate
Simulator directories. Running the real build installs dependencies outside
this repository into the parent Frameworks tree shown above.

Compilation and packaging are different steps: FFmpegKit first creates the
architecture builds, then the platform-specific universal frameworks under
`prebuilt/bundle-apple-framework-*`, and finally its XCFramework bundles. The
copy performed by this wrapper installs those already assembled bundles; it
does not create their universal binaries.

To explicitly recreate the final iOS/macOS/tvOS packages from the completed
platform frameworks after `buildkit.sh`, run:

```sh
../make-universal-frameworks.rb --configuration all
```

The [separate assembler](../make-universal-frameworks.rb) calls
`xcodebuild -create-xcframework`, checks platform slices and architectures, and
installs one package per library/OS/configuration. It includes device, Simulator
and Catalyst slices together where applicable, without separate Simulator output
directories. Use `--configuration Debug` for only the Debug build or `--dry-run`
to inspect the plan. See the [Sources README](../README.md) for all inputs,
destinations and command examples.

Before replacing installed dependencies, the wrapper checks that all seven
required XCFramework directories exist in the generated bundle. Missing build
output stops installation without deleting the previously installed frameworks.

The tvOS build enables AudioToolbox, VideoToolbox, bzip2, zlib, iconv and GnuTLS
with its GMP/Nettle dependencies. This FFmpegKit version rejects OpenSSL on tvOS;
GnuTLS retains TLS support for protocols such as HTTPS and RTMPS instead of
disabling encrypted networking. The iOS and macOS builds continue using OpenSSL.
The tvOS build disables bitcode and defaults to tvOS 11.0. Override
`TVOS_DEPLOYMENT_TARGET` when a different dependency minimum is required, and keep
the consuming target's minimum at least as high. There is no tvOS AVFoundation
build option.

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

The wrapper resolves its directories relative to its own location, not the
calling directory. `BUILD_DIR` and `FRAMEWORK_DIR` can override the checkout/build
root and installation root respectively; use absolute paths. Additional options
after the platform are forwarded to each FFmpegKit build without splitting
quoted arguments. Omitting the platform selects `all`.

`bash ./buildkit.sh clean` removes the local FFmpegKit checkout/build trees under
`build/Debug` and `build/Release` (or the overridden `BUILD_DIR`); it does not
remove the installed XCFrameworks.

### SGPlayer Framework

After preparing the dependencies, build the appropriate SGPlayer target in
Xcode for the intended destination. In the MeMyselfAndI integration, use the
workspace at `../../../MeMyselfAndI/MeMyselfAndI.xcworkspace`, which includes this
SGPlayer project. Use `SGPlayer iOS` for iOS devices or simulators and
`SGPlayer tvOS` for Apple TV devices or simulators.

The tvOS target selects dependencies from `../../tvOS/$(CONFIGURATION)`, uses
the selected tvOS SDK's system frameworks, and supports tvOS 11.0 on devices
and tvOS 13.0 in Simulator. The Simulator minimum matches its Metal shader.

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
bash scripts/generate-tvos-simulator-shader.sh
```

[generate-tvos-simulator-shader.sh](scripts/generate-tvos-simulator-shader.sh)
uses the `appletvsimulator` SDK, Metal language version 2.1, and a default
Simulator minimum of tvOS 13.0. Its optional first argument selects the output
header, and `TVOS_SIMULATOR_DEPLOYMENT_TARGET` overrides the shader minimum.
Keep that value compatible with the tvOS target's Simulator deployment setting.
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
