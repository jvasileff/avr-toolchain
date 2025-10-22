#!/usr/bin/env bash

set -eu

# Parse command-line arguments
TARGET_LIBS_ARCHIVE=""
NATIVE_AVR_TOOLCHAIN_ARCHIVE=""
GCC_HOST=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --target-libs=*)
            TARGET_LIBS_ARCHIVE="${1#*=}"
            shift
            ;;
        --target-libs)
            TARGET_LIBS_ARCHIVE="$2"
            shift 2
            ;;
        --native-avr-toolchain=*)
            NATIVE_AVR_TOOLCHAIN_ARCHIVE="${1#*=}"
            shift
            ;;
        --native-avr-toolchain)
            NATIVE_AVR_TOOLCHAIN_ARCHIVE="$2"
            shift 2
            ;;
        --gcc-host=*)
            GCC_HOST="${1#*=}"
            shift
            ;;
        --gcc-host)
            GCC_HOST="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--gcc-host=<host>] [--target-libs=<archive>] [--native-avr-toolchain=<archive>]"
            echo "Valid --gcc-host values:"
            echo "  x86_64-linux-gnu"
            echo "  aarch64-linux-gnu"
            echo "  armv6-linux-gnueabihf"
            echo "  universal-apple-darwin"
            echo "  i686-w64-mingw32"
            echo "  x86_64-w64-mingw32"
            exit 1
            ;;
    esac
done

# Determine which docker-run script to use based on GCC_HOST
case "$GCC_HOST" in
    x86_64-linux-gnu)
        DOCKER_RUN="./docker-manylinux2014/docker-run-x86_64"
        ;;
    aarch64-linux-gnu)
        DOCKER_RUN="./docker-manylinux2014/docker-run-arm64"
        ;;
    armv6-linux-gnueabihf)
        DOCKER_RUN="./docker-buster-arm6hf/docker-run"
        ;;
    universal-apple-darwin)
        echo "Error: macOS builds (universal-apple-darwin) cannot be run in Docker"
        echo "Please run ./build-avr-toolchain.sh directly on macOS"
        exit 1
        ;;
    i686-w64-mingw32|x86_64-w64-mingw32)
        DOCKER_RUN="./docker-trixie/docker-run"
        ;;
    "")
        echo "Error: --gcc-host is required"
        echo "Valid values: x86_64-linux-gnu, aarch64-linux-gnu, armv6-linux-gnueabihf, i686-w64-mingw32, x86_64-w64-mingw32"
        exit 1
        ;;
    *)
        echo "Error: Unknown --gcc-host value: $GCC_HOST"
        echo "Valid values: x86_64-linux-gnu, aarch64-linux-gnu, armv6-linux-gnueabihf, i686-w64-mingw32, x86_64-w64-mingw32"
        exit 1
        ;;
esac

# Verify docker-run script exists
if [[ ! -x "$DOCKER_RUN" ]]; then
    echo "Error: Docker run script not found or not executable: $DOCKER_RUN"
    exit 1
fi

# Build the command to run inside Docker
BUILD_CMD="GCC_HOST=$GCC_HOST ./build-avr-toolchain.sh"

# Add --target-libs if provided
if [[ -n "$TARGET_LIBS_ARCHIVE" ]]; then
    BUILD_CMD="$BUILD_CMD --target-libs=$TARGET_LIBS_ARCHIVE"
fi

# Add --native-avr-toolchain if provided
if [[ -n "$NATIVE_AVR_TOOLCHAIN_ARCHIVE" ]]; then
    BUILD_CMD="$BUILD_CMD --native-avr-toolchain=$NATIVE_AVR_TOOLCHAIN_ARCHIVE"
fi

echo "Building AVR toolchain in Docker container..."
echo "  GCC_HOST: $GCC_HOST"
echo "  Docker script: $DOCKER_RUN"
if [[ -n "$TARGET_LIBS_ARCHIVE" ]]; then
    echo "  Target libs: $TARGET_LIBS_ARCHIVE"
fi
if [[ -n "$NATIVE_AVR_TOOLCHAIN_ARCHIVE" ]]; then
    echo "  Native toolchain: $NATIVE_AVR_TOOLCHAIN_ARCHIVE"
fi
echo ""

# Execute the build in Docker
exec "$DOCKER_RUN" bash -c "$BUILD_CMD"
