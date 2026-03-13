#!/usr/bin/env bash

# Wrapper around build-avr-toolchain.sh that performs the build on a temporary
# directory (container-local filesystem) rather than on the bind mount. This
# gives native filesystem performance and guarantees a case-sensitive, clean
# build environment.
#
# Inputs are copied from the bind mount; outputs (artifacts and download cache)
# are copied back on success.
#
# This script accepts the same arguments as build-avr-toolchain.sh.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR=$(mktemp -d)

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

echo "Clean build: using temporary directory $WORK_DIR"

# Copy cached downloads from the bind mount (if they exist)
if [[ -d "$SCRIPT_DIR/build/download" ]]; then
    mkdir -p "$WORK_DIR/build/download"
    cp -a "$SCRIPT_DIR/build/download/." "$WORK_DIR/build/download/"
    echo "Clean build: copied cached downloads"
fi

# Rewrite --target-libs and --native-avr-toolchain arguments to absolute paths
# before changing directory, so build-avr-toolchain.sh can find them.
ARGS=()
for arg in "$@"; do
    case "$arg" in
        --target-libs=*)
            FILE="${arg#*=}"
            [[ "$FILE" != /* ]] && FILE="$SCRIPT_DIR/$FILE"
            ARGS+=("--target-libs=$FILE")
            ;;
        --native-avr-toolchain=*)
            FILE="${arg#*=}"
            [[ "$FILE" != /* ]] && FILE="$SCRIPT_DIR/$FILE"
            ARGS+=("--native-avr-toolchain=$FILE")
            ;;
        *)
            ARGS+=("$arg")
            ;;
    esac
done

# Run the build from the temporary directory. build-avr-toolchain.sh uses
# BUILD_DIR="$(pwd)/build", so this places all compilation on the local
# filesystem.
cd "$WORK_DIR"
"$SCRIPT_DIR/build-avr-toolchain.sh" "${ARGS[@]}"

# Copy artifacts back to the bind mount
mkdir -p "$SCRIPT_DIR/build/artifacts"
cp -a "$WORK_DIR/build/artifacts/." "$SCRIPT_DIR/build/artifacts/"
echo "Clean build: copied artifacts to $SCRIPT_DIR/build/artifacts/"

# Sync download cache back (picks up any newly downloaded sources)
mkdir -p "$SCRIPT_DIR/build/download"
cp -a "$WORK_DIR/build/download/." "$SCRIPT_DIR/build/download/"
echo "Clean build: synced download cache"
