# SGPlayer

This fork adds basic Apple Silicon support to macOS SGPlayer and a separate
Metal shader library for iOS Simulator.

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
bash ./buildkit.sh build macOS

# Build both implemented platforms.
bash ./buildkit.sh build all
```

The script creates FFmpegKit checkouts under `build/Debug` and `build/Release`,
builds the dependencies, and copies their XCFramework bundles automatically:

| Platform | Generated Bundle | Installed Location |
| --- | --- | --- |
| iOS | `build/{Debug,Release}/prebuilt/bundle-apple-xcframework-ios` | `../../iOS/{Debug,Release}` |
| macOS | `build/{Debug,Release}/prebuilt/bundle-apple-xcframework-macos` | `../../macOS/{Debug,Release}` |

The installed locations are relative to this repository. A manual copy is not
normally needed. The iOS XCFrameworks contain device and Simulator slices, which
Xcode selects for the destination; they do not need a separate `iOSSimulator`
directory. The script's tvOS branch is currently a no-op, including when using
`build all`.

`bash ./buildkit.sh clean` removes the local FFmpegKit checkout/build trees under
`build/Debug` and `build/Release`; it does not remove the installed XCFrameworks.

### SGPlayer Framework

After preparing the dependencies, build the appropriate SGPlayer target in
Xcode for the intended destination. In the MeMyselfAndI integration, use the
workspace at `../../../MeMyselfAndI/MeMyselfAndI.xcworkspace`, which includes this
SGPlayer project, and the `SGPlayer iOS` target for iOS devices or simulators.

The app links the SGPlayer framework from Xcode's `BUILT_PRODUCTS_DIR`.
Simulator products are generated under `Debug-iphonesimulator` or
`Release-iphonesimulator`; an empty external `iOSSimulator` directory does not
mean that the SGPlayer Simulator build is missing.

### iOS Simulator Metal Shaders

SGPlayer embeds compiled Metal libraries as byte arrays. Device and Simulator
shader binaries are not interchangeable, even when both use ARM64. Using the
device shader in Simulator fails when creating a render pipeline with
`Target OS is incompatible: library was not compiled for the simulator`.

[SGMetalRenderPipelinePool.m](SGPlayer/Classes/Core/SGMetal/SGMetalRenderPipelinePool.m)
selects the checked-in
[Simulator header](SGPlayer/Classes/Core/SGMetal/SGMetalShader_iOSSimulator.h)
when both the iOS platform and `TARGET_OS_SIMULATOR` are selected. Physical iOS
devices continue using the existing device shader. The tvOS and macOS shader
paths are unchanged.

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
the iOS Simulator shader, not the device, tvOS, or macOS shaders.

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
