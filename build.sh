#!/bin/sh

set -e

PLATFORM=$1
ACTION=$2

FFMPEG_VERSION=n5.0.2
OPENSSL_VERSION=OpenSSL_1_1_1s

echo "Do not use attached FFMpeg build support! Use FFMpegKit instead that supports iOS simulator builds as well!"
exit 1

if [ "$ACTION" = "build" ]; then
    # on macOS one can use the latest built in or use homebrew to get it
    #if [ "$PLATFORM" != "macOS" ]; then
        sh scripts/init-openssl.sh $PLATFORM $OPENSSL_VERSION
    #fi
    sh scripts/init-ffmpeg.sh  $PLATFORM $FFMPEG_VERSION
    #if [ "$PLATFORM" != "macOS" ]; then
        sh scripts/compile-openssl.sh $PLATFORM "build"
    #fi
    sh scripts/compile-ffmpeg.sh $PLATFORM "build"
elif [ "$ACTION" = "clean" ]; then
    #if [ "$PLATFORM" != "macOS" ]; then
        sh scripts/compile-openssl.sh $PLATFORM "clean"
    #fi
    sh scripts/compile-ffmpeg.sh $PLATFORM "clean"
else
    echo "Usage:"
    echo "  build.sh iOS build"
    echo "  build.sh iOS clean"
    echo " ---"
    echo "  build.sh iOS-Simulator build"
    echo "  build.sh iOS-Simulator clean"
    echo " ---"
    echo "  build.sh tvOS build"
    echo "  build.sh tvOS clean"
    echo " ---"
    echo "  build.sh macOS build"
    echo "  build.sh macOS clean"
    exit 1
fi
