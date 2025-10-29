#!/usr/bin/env bash

# For Linux:
#   apt update && apt install -y build-essential texinfo help2man automake python3 curl zip unzip
#
# For macOS:
#   install xcode & xcode commandline tools
#   brew install autoconf automake texinfo help2man gnu-tar
#
# For Windows cross-compilation (from Linux):
#   apt install mingw-w64
#   # Build native toolchain first:
#   ./build-avr-toolchain.sh
#   mv build build-native
#   export PATH=$PWD/build-native/avr-toolchain/bin:$PATH
#   # Then build Windows toolchain:
#   GCC_HOST=i686-w64-mingw32 ./build-avr-toolchain.sh     # for 32-bit
#   GCC_HOST=x86_64-w64-mingw32 ./build-avr-toolchain.sh   # for 64-bit
#
# For Windows cross-compilation (from macOS):
#   brew install mingw-w64
#   # Then follow the same steps as Linux above

set -eu
shopt -s expand_aliases

# Parse command-line arguments
TARGET_LIBS_ARCHIVE=""
NATIVE_AVR_TOOLCHAIN_ARCHIVE=""
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
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate and convert TARGET_LIBS_ARCHIVE to absolute path if provided
if [[ -n "$TARGET_LIBS_ARCHIVE" ]]; then
    # Verify the file exists and is readable
    if [[ ! -f "$TARGET_LIBS_ARCHIVE" || ! -r "$TARGET_LIBS_ARCHIVE" ]]; then
        echo "Error: Target libs archive not found or not readable: $TARGET_LIBS_ARCHIVE"
        exit 1
    fi

    # Convert to absolute path
    TARGET_LIBS_ARCHIVE="$(cd "$(dirname "$TARGET_LIBS_ARCHIVE")" && pwd)/$(basename "$TARGET_LIBS_ARCHIVE")"
    echo "Using pre-built target libraries: $TARGET_LIBS_ARCHIVE"
fi

# Validate and convert NATIVE_AVR_TOOLCHAIN_ARCHIVE to absolute path if provided
if [[ -n "$NATIVE_AVR_TOOLCHAIN_ARCHIVE" ]]; then
    # Verify the file exists and is readable
    if [[ ! -f "$NATIVE_AVR_TOOLCHAIN_ARCHIVE" || ! -r "$NATIVE_AVR_TOOLCHAIN_ARCHIVE" ]]; then
        echo "Error: Native AVR toolchain archive not found or not readable: $NATIVE_AVR_TOOLCHAIN_ARCHIVE"
        exit 1
    fi

    # Convert to absolute path
    NATIVE_AVR_TOOLCHAIN_ARCHIVE="$(cd "$(dirname "$NATIVE_AVR_TOOLCHAIN_ARCHIVE")" && pwd)/$(basename "$NATIVE_AVR_TOOLCHAIN_ARCHIVE")"
    echo "Using native AVR toolchain: $NATIVE_AVR_TOOLCHAIN_ARCHIVE"
fi

# For repeatable builds, unset all env vars
unset CC CXX CFLAGS CXXFLAGS CPPFLAGS LDFLAGS AR RANLIB
export CONFIG_SITE=/dev/null LC_ALL=C TZ=UTC
export SOURCE_DATE_EPOCH=$(git log -1 --format=%ct 2>/dev/null || date +%s)
umask 022

# Prefer GNU tar if available (Homebrew installs it as 'gtar')
if command -v gtar >/dev/null 2>&1; then
    TAR_CMD=gtar
else
    TAR_CMD=tar
fi

source ./versions.sh

# Detect OS family
case "$GCC_HOST" in
  *-apple-darwin*) OS=macos ;;
  *-w64-mingw32*)  OS=windows ;;
  *-linux-gnu*|*-linux-musl*|*-linux*) OS=linux ;;
  *) OS=unknown ;;
esac

# Provide --host argument for all but macos builds. It is needed for Canadian cross
# builds, and also for regular cross builds to select our custom compiler
case "$GCC_HOST" in
  *darwin*)
    HOST_ARG=""
    ;;
  *)
    HOST_ARG="--host=$GCC_HOST"
    ;;
esac

# Flags for libraries for microcontrollers
COMMON_FLAGS_FOR_TARGET="-Os -ffunction-sections -fdata-sections"

# Always compile with sectioning so linkers can drop unused code
COMMON_FLAGS_HOST="-O2 -ffunction-sections -fdata-sections"

# Special flags for macOS, Linux, or Windows targets
PLATFORM_FLAGS=""
LDFLAGS_HOST=""

case "$OS" in
  macos)
    # universal build
    PLATFORM_FLAGS="-arch x86_64 -arch arm64 -mmacosx-version-min=10.8"
    LDFLAGS_HOST="-Wl,-dead_strip"
    ;;
  linux)
    LDFLAGS_HOST="-Wl,--gc-sections -Wl,--as-needed"
    ;;
  windows)
    PLATFORM_FLAGS="--static"
    LDFLAGS_HOST="-Wl,--gc-sections"
    ;;
esac

# Source versions.sh to get BUILD_VERSION and other version info
source ./versions.sh

BUILD_DIR="$(pwd)/build"
INSTALL_DIR="${BUILD_DIR}"/avr-toolchain
INSTALL_TARGET_DIR="${BUILD_DIR}"/avr-target-libs

LIBC_DIR="$(echo "${LIBC_VERSION}" | tr '.' '_')-release"

# Detect number of CPU cores
if command -v sysctl >/dev/null && [ "$(uname)" = "Darwin" ]; then
    MAKE_JOBS=$(sysctl -n hw.ncpu)
elif command -v nproc >/dev/null; then
    MAKE_JOBS=$(nproc)
else
    MAKE_JOBS=1
fi

mkdir -p "$BUILD_DIR"
mkdir -p "$INSTALL_DIR"

# Extract and set up native AVR toolchain if provided
if [[ -n "$NATIVE_AVR_TOOLCHAIN_ARCHIVE" ]]; then
    NATIVE_TOOLCHAIN_DIR="${BUILD_DIR}/native-avr-toolchain"

    echo "Extracting native AVR toolchain to ${NATIVE_TOOLCHAIN_DIR}..."
    mkdir -p "$NATIVE_TOOLCHAIN_DIR"
    "$TAR_CMD" -xf "$NATIVE_AVR_TOOLCHAIN_ARCHIVE" -C "$NATIVE_TOOLCHAIN_DIR" --strip-components=1

    # Add native toolchain to PATH
    export PATH="$NATIVE_TOOLCHAIN_DIR/bin:$PATH"
    echo "Native AVR toolchain added to PATH"
fi

export PATH="$INSTALL_DIR/bin:$PATH"

heading_and_restore() {
    >&2 echo "----------------------------------------"
    >&2 echo "$*"
    >&2 echo "----------------------------------------"
    case "$save_flags" in
     (*x*)  set -x
    esac
}
alias heading='{ save_flags="$-"; set +x;} 2> /dev/null; heading_and_restore'

set -x

############################################################
heading "Download Sources"
############################################################
mkdir -p "${BUILD_DIR}/download"
pushd "${BUILD_DIR}/download"

if [[ ! -e "avr-libc-${LIBC_VERSION}.tar.bz2" ]]; then
    curl -L -O "https://github.com/avrdudes/avr-libc/releases/download/avr-libc-${LIBC_DIR}/avr-libc-${LIBC_VERSION}.tar.bz2"
fi
if [[ ! -e "binutils-${BINTOOLS_VERSION}.tar.gz" ]]; then
    curl -L -O "https://ftpmirror.gnu.org/gnu/binutils/binutils-${BINTOOLS_VERSION}.tar.gz"
fi
if [[ ! -e "gcc-${GCC_VERSION}.tar.xz" ]]; then
    curl -L -O "https://ftpmirror.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz"
fi

for pack in $PACKS; do
    if [[ ! -e "${pack}" ]]; then
        curl -L -O "http://packs.download.atmel.com/$pack"
    fi
done

popd

############################################################
heading "Verify Dependencies"
############################################################
if [ -f "checksums.txt" ]; then
    echo "Verifying downloaded dependencies..."
    if ! sha256sum -c checksums.txt; then
        echo "Error: Checksum verification failed!"
        echo "Dependencies may be corrupted or checksums.txt needs updating."
        exit 1
    fi
    echo "All checksums verified successfully!"
else
    echo "Error: checksums.txt not found!"
    echo "Run ./generate-checksums.sh to create checksums for downloaded dependencies."
    exit 1
fi

############################################################
heading "Build and install binutils"
############################################################
pushd "$BUILD_DIR"

tar xf download/binutils-${BINTOOLS_VERSION}.tar.gz
cd binutils-${BINTOOLS_VERSION}

# Apply macOS patch
if [ "$OS" = "macos" ]; then
    patch -p2 < "${PWD}/../../patches/binutils-macos.patch"
fi

./configure \
    --prefix="${INSTALL_DIR}" \
    --program-prefix=avr- \
    --target=avr \
    --disable-nls \
    --disable-werror \
    --disable-shared \
    --without-zstd \
    --enable-deterministic-archives \
    CFLAGS="$PLATFORM_FLAGS $COMMON_FLAGS_HOST" \
    CXXFLAGS="$PLATFORM_FLAGS $COMMON_FLAGS_HOST" \
    LDFLAGS="$LDFLAGS_HOST" \
    ${HOST_ARG}

make -j ${MAKE_JOBS}
make install-strip

popd

############################################################
heading "Build and install gcc"
############################################################

pushd "$BUILD_DIR"

tar xf download/gcc-${GCC_VERSION}.tar.xz
cd gcc-${GCC_VERSION}

# Apply macOS patch (same as binutils patch)
if [ "$OS" = "macos" ]; then
    patch -p2 < "${PWD}/../../patches/binutils-macos.patch"
fi

./contrib/download_prerequisites
cd ..
mkdir -p gcc-build
cd gcc-build
../gcc-${GCC_VERSION}/configure \
    --prefix="${INSTALL_DIR}" \
    --program-prefix=avr- \
    --target=avr ${HOST_ARG} \
    --enable-languages=c,c++ \
    --disable-nls \
    --disable-libssp \
    --disable-libada \
    --disable-libcc1 \
    --disable-plugin \
    --with-dwarf2 \
    --disable-shared \
    --without-zstd \
    BOOT_CFLAGS="-O2 -g0" \
    CFLAGS="$PLATFORM_FLAGS -O2" \
    CXXFLAGS="$PLATFORM_FLAGS -O2" \
    CFLAGS_FOR_TARGET="$COMMON_FLAGS_FOR_TARGET" \
    CXXFLAGS_FOR_TARGET="$COMMON_FLAGS_FOR_TARGET" \
    $([[ "${GCC_HOST}" == "i686-w64-mingw32" ]] && echo "--disable-win32-utf8-manifest") \
    $([[ "${GCC_HOST}" == *"mingw32"* ]] && echo "--enable-mingw-wildcard")

# Stage 1: host (compiler) binaries

make -j ${MAKE_JOBS} all-host
make install-strip-host
popd

pushd "$INSTALL_DIR"
mkdir -p "lib/bfd-plugins"
if [[ -n "${GCC_HOST}" && "${GCC_HOST}" == *"mingw32"* ]]; then
    cp -a libexec/gcc/avr/${GCC_VERSION}/liblto_plugin.dll lib/bfd-plugins/
else
    cp -a libexec/gcc/avr/${GCC_VERSION}/liblto_plugin.so lib/bfd-plugins/
fi
popd

if [[ -n "$TARGET_LIBS_ARCHIVE" ]]; then
    ############################################################
    heading "Extract pre-built avr libraries"
    ############################################################

    "$TAR_CMD" -xf "$TARGET_LIBS_ARCHIVE" -C "$INSTALL_DIR" --strip-components=1
else
    ############################################################
    heading "Build and install gcc avr libraries"
    ############################################################

    pushd "$BUILD_DIR/gcc-build/"

    make -j ${MAKE_JOBS} all-target
    make prefix="$INSTALL_TARGET_DIR" install-strip-target

    find "${INSTALL_TARGET_DIR}/lib/gcc/avr" -type f -name '*.a' \
        -exec avr-strip --strip-debug {} +

    find "${INSTALL_TARGET_DIR}/lib/gcc/avr" -type f -name '*.a' \
        -exec avr-ranlib {} +

    # merge what we have so far; avr-libc needs these files
    cp -a "${INSTALL_TARGET_DIR}/"* "${INSTALL_DIR}/"

    popd

    ############################################################
    heading "Build and install avr-libc"
    ############################################################

    pushd "$BUILD_DIR"

    tar xf download/avr-libc-${LIBC_VERSION}.tar.bz2
    cd avr-libc-${LIBC_VERSION}
    ./bootstrap
    ./configure \
        --prefix="${INSTALL_DIR}" \
        --host=avr \
        CFLAGS="$COMMON_FLAGS_FOR_TARGET" \
        CXXFLAGS="$COMMON_FLAGS_FOR_TARGET"
    make -j ${MAKE_JOBS}
    make prefix="${INSTALL_TARGET_DIR}" install-strip

    # avr-man has absolute paths of the build machine. Better would be to patch the
    # script to look for man pages relative to itself
    rm "${INSTALL_TARGET_DIR}"/bin/avr-man

    popd

    # don't merge into $INSTALL_DIR yet; atpacks overwrite portions of avr-libc

    ############################################################
    heading "Install atpacks"
    ############################################################

    pushd "$BUILD_DIR"

    mkdir -p "${INSTALL_TARGET_DIR}/lib/gcc/avr/${GCC_VERSION}/device-specs"
    mkdir -p "${INSTALL_TARGET_DIR}/avr/lib"
    mkdir -p "${INSTALL_TARGET_DIR}/avr/include/avr"

    for packFile in $PACKS; do
        echo "Installing ${packFile}"
        mkdir -p pack
        cd pack
        unzip -q "../download/${packFile}"
        mv gcc/dev/*/device-specs/* "${INSTALL_TARGET_DIR}/lib/gcc/avr/${GCC_VERSION}/device-specs/"
        rmdir gcc/dev/*/device-specs
        cp -a gcc/dev/*/* "${INSTALL_TARGET_DIR}/avr/lib/"
        cp -a include/avr/* "${INSTALL_TARGET_DIR}/avr/include/avr/"
        cd ..
        rm -rf pack
    done

    popd

    # Merge avr-libc and atpack files into target
    cp -a "${INSTALL_TARGET_DIR}/"* "${INSTALL_DIR}/"
fi

############################################################
heading "Create versions.txt"
############################################################

DATE_FMT="+%Y-%m-%d %H:%M:%S UTC"
SOURCE_DATE=$(date -u -d "@$SOURCE_DATE_EPOCH" "$DATE_FMT" 2>/dev/null ||
        date -u -r "$SOURCE_DATE_EPOCH" "$DATE_FMT" 2>/dev/null ||
        date -u "$DATE_FMT")

cat > "${INSTALL_DIR}/versions.txt" << EOF
Build Information:
  Date: $SOURCE_DATE
  Host: $(uname -s) ($(uname -m))
  Build Host: ${GCC_HOST:-native}

Component Versions:
  GCC: ${GCC_VERSION}
  Binutils: ${BINTOOLS_VERSION}
  AVR-Libc: ${LIBC_VERSION}

Included AtPacks:
$(for pack in $PACKS; do echo "  - $pack"; done)
EOF

############################################################
heading "Generate Archives"
############################################################

# Set all file timestamps to SOURCE_DATE_EPOCH for reproducible builds
# Use BSD-compatible format that works on both macOS and Linux
TOUCH_DATE=$(date -u -r "$SOURCE_DATE_EPOCH" "+%Y%m%d%H%M.%S" 2>/dev/null || \
             date -u -d "@$SOURCE_DATE_EPOCH" "+%Y%m%d%H%M.%S" 2>/dev/null)
find "$BUILD_DIR/avr-toolchain" -exec touch -h -t "$TOUCH_DATE" {} +

# Determine archive format based on target platform
case "$GCC_HOST" in
  *mingw32*)
    # Windows builds use .zip for better native compatibility
    ARCHIVE_EXT=".zip"
    pushd "$BUILD_DIR"
    TZ=UTC LC_ALL=C find avr-toolchain -print | sort |
        zip -X -q -9 -@ "avr-toolchain-$BUILD_VERSION-$GCC_HOST.zip"
    popd
    ;;
  *)
    # Linux and macOS builds use .tar.xz
    ARCHIVE_EXT=".tar.xz"
    "$TAR_CMD" \
        --sort=name \
        --mtime="@${SOURCE_DATE_EPOCH:-0}" \
        --owner=0 --group=0 --numeric-owner \
        --no-xattrs \
        -C "$BUILD_DIR" \
        -cJf "$BUILD_DIR/avr-toolchain-$BUILD_VERSION-$GCC_HOST.tar.xz" avr-toolchain
    ;;
esac

# Also create target-only archive for reuse in cross builds (always tar.xz)
if [[ -z "$TARGET_LIBS_ARCHIVE" ]]; then
    "$TAR_CMD" \
        --sort=name \
        --mtime="@${SOURCE_DATE_EPOCH:-0}" \
        --owner=0 --group=0 --numeric-owner \
        --no-xattrs \
        -C "$BUILD_DIR" \
        -cJf "$BUILD_DIR/avr-target-libs-$BUILD_VERSION.tar.xz" avr-target-libs
fi

############################################################
heading "Done."
############################################################
