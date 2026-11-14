#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${BUILD_DIR:-${SCRIPT_DIR}/build}"
FRAMEWORK_DIR="${FRAMEWORK_DIR:-${SCRIPT_DIR}/../..}"
DEBUG_BUILD_DIR="${BUILD_DIR}/Debug"
RELEASE_BUILD_DIR="${BUILD_DIR}/Release"

function clean_targets_from()
{
    local OUT_DIR=$1
    rm -Rf "${OUT_DIR}/libavcodec.xcframework"
    rm -Rf "${OUT_DIR}/libavdevice.xcframework"
    rm -Rf "${OUT_DIR}/libavfilter.xcframework"
    rm -Rf "${OUT_DIR}/libavformat.xcframework"
    rm -Rf "${OUT_DIR}/libavutil.xcframework"
    rm -Rf "${OUT_DIR}/libswresample.xcframework"
    rm -Rf "${OUT_DIR}/libswscale.xcframework"
}

function install_targets_from()
{
    local IN_DIR=$1
    local OUT_DIR=$2
    local LIBRARY
    for LIBRARY in libavcodec libavdevice libavfilter libavformat libavutil libswresample libswscale; do
        if [[ ! -d "${IN_DIR}/${LIBRARY}.xcframework" ]]; then
            printf 'Missing built XCFramework: %s\n' "${IN_DIR}/${LIBRARY}.xcframework" >&2
            return 1
        fi
    done
    clean_targets_from "${OUT_DIR}"
    ditto "${IN_DIR}/" "${OUT_DIR}/"
    rm -Rf "${OUT_DIR}/ffmpegkit.xcframework"
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
if [[ $# -gt 0 && "${1:-}" != -* ]]; then
    PLATFORM=$1
    shift 1
fi

case "$ACTION" in
    build|clean) ;;
    *) printf 'Unknown action: %s\n' "$ACTION" >&2; exit 1 ;;
esac

case "$PLATFORM" in
    iOS|tvOS|macOS|all) ;;
    *) printf 'Unknown platform: %s\n' "$PLATFORM" >&2; exit 1 ;;
esac

if [[ "$ACTION" == clean && ( "$PLATFORM" != all || $# -gt 0 ) ]]; then
    printf 'Usage: buildkit.sh clean\n' >&2
    exit 1
fi

echo "Ok, $ACTION $PLATFORM $*"

if [ "$ACTION" = "build" ]; then
    unset PKG_CONFIG_PATH
    
    if [ ! -d "${DEBUG_BUILD_DIR}" ]; then
        mkdir -p "${BUILD_DIR}"
        git clone https://github.com/arthenica/ffmpeg-kit.git "${DEBUG_BUILD_DIR}"
    fi
    if [ ! -d "${RELEASE_BUILD_DIR}" ]; then
        mkdir -p "${RELEASE_BUILD_DIR}"
        ditto "${DEBUG_BUILD_DIR}" "${RELEASE_BUILD_DIR}"
    fi
    
    if [ "$PLATFORM" = "macOS" ] || [ "$PLATFORM" = "all" ]; then
        pushd "${DEBUG_BUILD_DIR}"
        ./macos.sh  --enable-macos-avfoundation --enable-macos-audiotoolbox --enable-macos-videotoolbox --enable-macos-bzip2 --enable-macos-zlib --enable-macos-libiconv --enable-openssl --target=10.15  -x -d "$@"
        
        install_targets_from "${PWD}/prebuilt/bundle-apple-xcframework-macos" "${FRAMEWORK_DIR}/macOS/Debug"
        popd
        
        pushd "${RELEASE_BUILD_DIR}"
        ./macos.sh  --enable-macos-avfoundation --enable-macos-audiotoolbox --enable-macos-videotoolbox --enable-macos-bzip2 --enable-macos-zlib --enable-macos-libiconv --enable-openssl --target=10.15 -x -s "$@"

        install_targets_from "${PWD}/prebuilt/bundle-apple-xcframework-macos" "${FRAMEWORK_DIR}/macOS/Release"
        popd
    fi

    if [ "$PLATFORM" = "iOS" ] || [ "$PLATFORM" = "all" ]; then
        pushd "${DEBUG_BUILD_DIR}"
        ./ios.sh --enable-ios-avfoundation --enable-ios-audiotoolbox --enable-ios-videotoolbox --enable-ios-bzip2 --enable-ios-zlib --enable-ios-libiconv --enable-openssl --disable-armv7 --disable-arm64e --target=13.0 -x -d "$@"

        install_targets_from "${PWD}/prebuilt/bundle-apple-xcframework-ios" "${FRAMEWORK_DIR}/iOS/Debug"
        popd
        
        pushd "${RELEASE_BUILD_DIR}"
        ./ios.sh --enable-ios-avfoundation --enable-ios-audiotoolbox --enable-ios-videotoolbox --enable-ios-bzip2 --enable-ios-zlib --enable-ios-libiconv --enable-openssl --disable-armv7 --disable-arm64e --target=13.0 -x -s "$@"

        install_targets_from "${PWD}/prebuilt/bundle-apple-xcframework-ios" "${FRAMEWORK_DIR}/iOS/Release"
        popd

    fi

    if [ "$PLATFORM" = "tvOS" ] || [ "$PLATFORM" = "all" ]; then
        pushd "${DEBUG_BUILD_DIR}"
        TVOS_PREPARATION="$(ruby "${SCRIPT_DIR}/scripts/prepare-tvos-gnutls.rb" "${PWD}")"
        TVOS_BUILD_OPTIONS=(-x)
        if [[ "$TVOS_PREPARATION" == rebuild-gnutls ]]; then
            TVOS_BUILD_OPTIONS+=(--rebuild-gnutls)
        fi
        SGPLAYER_AUTOPOINT="${AUTOPOINT:-autopoint}" AUTOPOINT="${SCRIPT_DIR}/scripts/gnutls-autopoint.sh" \
            ./tvos.sh --enable-tvos-audiotoolbox --enable-tvos-videotoolbox --enable-tvos-bzip2 --enable-tvos-zlib --enable-tvos-libiconv --enable-gnutls --enable-gmp --enable-nettle --no-bitcode --target="${TVOS_DEPLOYMENT_TARGET:-11.0}" "${TVOS_BUILD_OPTIONS[@]}" -d "$@"

        install_targets_from "${PWD}/prebuilt/bundle-apple-xcframework-tvos" "${FRAMEWORK_DIR}/tvOS/Debug"
        popd

        pushd "${RELEASE_BUILD_DIR}"
        TVOS_PREPARATION="$(ruby "${SCRIPT_DIR}/scripts/prepare-tvos-gnutls.rb" "${PWD}")"
        TVOS_BUILD_OPTIONS=(-x)
        if [[ "$TVOS_PREPARATION" == rebuild-gnutls ]]; then
            TVOS_BUILD_OPTIONS+=(--rebuild-gnutls)
        fi
        SGPLAYER_AUTOPOINT="${AUTOPOINT:-autopoint}" AUTOPOINT="${SCRIPT_DIR}/scripts/gnutls-autopoint.sh" \
            ./tvos.sh --enable-tvos-audiotoolbox --enable-tvos-videotoolbox --enable-tvos-bzip2 --enable-tvos-zlib --enable-tvos-libiconv --enable-gnutls --enable-gmp --enable-nettle --no-bitcode --target="${TVOS_DEPLOYMENT_TARGET:-11.0}" "${TVOS_BUILD_OPTIONS[@]}" -s "$@"

        install_targets_from "${PWD}/prebuilt/bundle-apple-xcframework-tvos" "${FRAMEWORK_DIR}/tvOS/Release"
        popd
    fi

elif [ "$ACTION" = "clean" ]; then

    rm -Rf "${DEBUG_BUILD_DIR}"
    rm -Rf "${RELEASE_BUILD_DIR}"

fi
