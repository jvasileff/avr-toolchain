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

# Detect OS family: prefer GCC_HOST, fallback to uname
if [ -n "${GCC_HOST:-}" ]; then
  case "$GCC_HOST" in
    *-apple-darwin*) OS=macos ;;
    *-w64-mingw32*)  OS=windows ;;
    *-linux-gnu*|*-linux-musl*|*-linux*) OS=linux ;;
    *) OS=unknown ;;
  esac
else
  case "$(uname -s)" in
    Darwin) OS=macos ;;
    Linux)  OS=linux ;;
    MINGW*|MSYS*|CYGWIN*) OS=windows ;;
    *) OS=unknown ;;
  esac
fi

# Use GCC_HOST from environment if set, otherwise empty
GCC_HOST=${GCC_HOST:-}
HOST_ARG=${GCC_HOST:+--host=${GCC_HOST}}

# Flags for libraries for microcontrollers
COMMON_FLAGS_FOR_TARGET="-Os -ffunction-sections -fdata-sections"

# Always compile with sectioning so linkers can drop unused code
COMMON_FLAGS_HOST="-O2 -ffunction-sections -fdata-sections"

# Special flags for macOS, Linux, or Windows targets
PLATFORM_FLAGS=""
LDFLAGS_HOST=""

case "$OS" in
  macos)
    # Universal build; the -arch/min go in CFLAGS/CXXFLAGS (they propagate to link)
    PLATFORM_FLAGS="-arch x86_64 -arch arm64 -mmacosx-version-min=10.8"
    LDFLAGS_HOST="-Wl,-dead_strip"
    ;;
  linux)
    LDFLAGS_HOST="-Wl,--gc-sections -Wl,--as-needed"
    ;;
  windows)
    LDFLAGS_HOST="-Wl,--gc-sections"
    ;;
esac

source ./versions.sh

BUILD_DIR="$(pwd)/build"
INSTALL_DIR="${BUILD_DIR}"/avr-toolchain

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

for pack in "${PACKS[@]}"; do
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
    if ! sha256sum -c --strict checksums.txt; then
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

make -j ${MAKE_JOBS}
make install-strip

find "${INSTALL_DIR}/lib/gcc/avr" -type f -name '*.a' \
    -exec avr-strip --strip-debug {} +

find "${INSTALL_DIR}/lib/gcc/avr" -type f -name '*.a' \
    -exec avr-ranlib {} +

popd

pushd "$INSTALL_DIR"
mkdir -p "lib/bfd-plugins"
if [[ -n "${GCC_HOST}" && "${GCC_HOST}" == *"mingw32"* ]]; then
    cp -a libexec/gcc/avr/${GCC_VERSION}/liblto_plugin.dll lib/bfd-plugins/
else
    cp -a libexec/gcc/avr/${GCC_VERSION}/liblto_plugin.so lib/bfd-plugins/
fi
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
make install-strip

popd

############################################################
heading "Install atpacks"
############################################################

pushd "$BUILD_DIR"

for packFile in "${PACKS[@]}"; do
    echo "Installing ${packFile}"
    mkdir -p pack
    cd pack
    unzip -q "../download/${packFile}"
    mv gcc/dev/*/device-specs/* "${INSTALL_DIR}"/lib/gcc/avr/${GCC_VERSION}/device-specs
    rmdir gcc/dev/*/device-specs
    cp -a gcc/dev/*/* "${INSTALL_DIR}"/avr/lib
    cp -a include/avr/* "${INSTALL_DIR}"/avr/include/avr/
    cd ..
    rm -rf pack
done

popd

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

Microcontroller Support:
$(printf '  - %s\n' "${PACKS[@]}")
EOF

############################################################
heading "Generate Archive"
############################################################

# --sort=name is not available on older versions of tar

"$TAR_CMD" \
    --mtime="@${SOURCE_DATE_EPOCH:-0}" \
    --owner=0 --group=0 --numeric-owner \
    --no-xattrs \
    -C "$BUILD_DIR" \
    -cjf "$BUILD_DIR"/avr-toolchain.tar.bz2 avr-toolchain

############################################################
heading "Done."
############################################################
