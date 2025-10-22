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

# Verify that --gcc-host is provided
if [[ -z "$GCC_HOST" ]]; then
    echo "Error: --gcc-host is required"
    echo "Valid values: x86_64-linux-gnu, aarch64-linux-gnu, armv6-linux-gnueabihf, universal-apple-darwin, i686-w64-mingw32, x86_64-w64-mingw32"
    exit 1
fi

# Check for macOS builds which cannot be run in Docker
if [[ "$GCC_HOST" == "universal-apple-darwin" ]]; then
    echo "Error: macOS builds (universal-apple-darwin) cannot be run in Docker"
    echo "Please run ./build-avr-toolchain.sh directly on macOS"
    exit 1
fi

# Use the unified docker-cross-compilers docker image
DOCKER_RUN="./docker-cross-compilers/docker-run"

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
