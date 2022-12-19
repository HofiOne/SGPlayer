#!/bin/sh

set -e

function clean_targets_from()
{
    local OUT_DIR=$1
    rm -Rf "${OUT_DIR}/libavcodec.xcframework"
    rm -Rf "${OUT_DIR}/libavdevice.xcframework"
    rm -Rf "${OUT_DIR}/libavfilter.xcframework"
    rm -Rf "${OUT_DIR}/ibavformat.xcframework"
    rm -Rf "${OUT_DIR}/libavutil.xcframework"
    rm -Rf "${OUT_DIR}/libswresample.xcframework"
    rm -Rf "${OUT_DIR}/libswscale.xcframework"
}


if [ $# -lt 1 ]; then
    echo "Usage:"
    echo "  buildkit.sh build iOS"
    echo " ---"
    echo "  buildkit.sh build tvOS"
    echo " ---"
    echo "  buildkit.sh build macOS"
    echo " ---"
    echo "  buildkit.sh build [all]"
    echo " ---"
    echo "  buildkit.sh clean"
    exit 1
fi
ACTION=$1
shift 1

PLATFORM="all"
if [ -n $1 ]; then
    PLATFORM=$1
    shift 1
fi

echo "Ok, $ACTION $PLATFORM $@"

BUILD_DIR=build
FRAMEWORK_DIR="${PWD}/../../../Frameworks"
DEBUG_BUILD_DIR=${BUILD_DIR}/Debug
RELEASE_BUILD_DIR=${BUILD_DIR}/Release

if [ "$ACTION" = "build" ]; then
    unset PKG_CONFIG_PATH
    
    if [ ! -d "${DEBUG_BUILD_DIR}" ]; then
        mkdir -p "${DEBUG_BUILD_DIR}"
        git clone https://github.com/arthenica/ffmpeg-kit.git "${DEBUG_BUILD_DIR}"
    fi
    if [ ! -d "${RELEASE_BUILD_DIR}" ]; then
        mkdir -p "${RELEASE_BUILD_DIR}"
        ditto "${DEBUG_BUILD_DIR}" "${RELEASE_BUILD_DIR}"
    fi
    
    if [ "$PLATFORM" = "macOS" ] || [ "$PLATFORM" = "all" ]; then
        pushd "${DEBUG_BUILD_DIR}"
        ./macos.sh  --enable-macos-avfoundation --enable-macos-audiotoolbox --enable-macos-videotoolbox --enable-macos-bzip2 --enable-macos-zlib --enable-macos-libiconv --enable-openssl --target=10.15  -x -d $@
        
        OUT_DIR="${FRAMEWORK_DIR}/macOS/Debug/"
        clean_targets_from "${OUT_DIR}"
        ditto "${PWD}/prebuilt/bundle-apple-xcframework-macos/" "${OUT_DIR}/"
        # we do not need this now
        rm -Rf "${OUT_DIR}/ffmpegkit.xcframework"
        popd
        
        pushd "${RELEASE_BUILD_DIR}"
        ./macos.sh  --enable-macos-avfoundation --enable-macos-audiotoolbox --enable-macos-videotoolbox --enable-macos-bzip2 --enable-macos-zlib --enable-macos-libiconv --enable-openssl --target=10.15 -x -s $@

        OUT_DIR="${FRAMEWORK_DIR}/macOS/Release/"
        clean_targets_from "${OUT_DIR}"
        ditto "${PWD}/prebuilt/bundle-apple-xcframework-macos/" "${OUT_DIR}/"
        # we do not need this now
        rm -Rf "${OUT_DIR}/ffmpegkit.xcframework"
        popd
    fi

    if [ "$PLATFORM" = "iOS" ] || [ "$PLATFORM" = "all" ]; then
        pushd "${DEBUG_BUILD_DIR}"
        ./ios.sh --enable-ios-avfoundation --enable-ios-audiotoolbox --enable-ios-videotoolbox --enable-ios-bzip2 --enable-ios-zlib --enable-ios-libiconv --enable-openssl --disable-armv7 --target=13.0 -x -d $@

        OUT_DIR="${FRAMEWORK_DIR}/iOS/Debug/"
        clean_targets_from "${OUT_DIR}"
        ditto "${PWD}/prebuilt/bundle-apple-xcframework-ios/" "${OUT_DIR}/"
        # we do not need this now
        rm -Rf "${OUT_DIR}/ffmpegkit.xcframework"
        popd
        
        pushd "${RELEASE_BUILD_DIR}"
        ./ios.sh --enable-ios-avfoundation --enable-ios-audiotoolbox --enable-ios-videotoolbox --enable-ios-bzip2 --enable-ios-zlib --enable-ios-libiconv --enable-openssl --disable-armv7 --target=13.0 -x -s $@

        OUT_DIR="${FRAMEWORK_DIR}/iOS/Release/"
        clean_targets_from "${OUT_DIR}"
        ditto "${PWD}/prebuilt/bundle-apple-xcframework-ios/" "${OUT_DIR}/"
        # we do not need this now
        rm -Rf "${OUT_DIR}/ffmpegkit.xcframework"
        popd

    fi

    if [ "$PLATFORM" = "tvOS" ] || [ "$PLATFORM" = "all" ]; then
        true
    fi

elif [ "$ACTION" = "clean" ]; then

    rm -Rf "${DEBUG_BUILD_DIR}"
    rm -Rf "${RELEASE_BUILD_DIR}"

fi
