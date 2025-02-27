#!/bin/bash

# For Linux:
#   apt update && apt install -y build-essential texinfo automake python3 wget zip unzip
#
# For macOS:
#   install xcode & xcode commandline tools
#   brew install autoconf automake
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

source "$(dirname "$0")/versions.sh"

BUILD_DIR="$(pwd)/build"
INSTALL_DIR="${BUILD_DIR}"/avr-toolchain

LIBC_DIR=$(echo ${LIBC_VERSION} | tr '.' '_')"-release"

# Use GCC_HOST from environment if set, otherwise empty
GCC_HOST=${GCC_HOST:-}
HOST_ARG=${GCC_HOST:+--host=${GCC_HOST}}

# Detect number of CPU cores
if [ "$(uname)" = "Darwin" ]; then
    MAKE_JOBS=$(sysctl -n hw.ncpu)
else
    MAKE_JOBS=$(nproc)
fi

mkdir -p $BUILD_DIR
mkdir -p $INSTALL_DIR
export PATH="${INSTALL_DIR}"/bin:$PATH

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
    wget "https://github.com/avrdudes/avr-libc/releases/download/avr-libc-${LIBC_DIR}/avr-libc-${LIBC_VERSION}.tar.bz2"
fi
if [[ ! -e "binutils-${BINTOOLS_VERSION}.tar.gz" ]]; then
    wget "https://ftp.gnu.org/gnu/binutils/binutils-${BINTOOLS_VERSION}.tar.gz"
fi
if [[ ! -e "gcc-${GCC_VERSION}.tar.xz" ]]; then
    wget "https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz"
fi

for pack in ${PACKS[@]}; do
    if [[ ! -e ${pack} ]]; then
        wget "http://packs.download.atmel.com/$pack"
    fi
done

popd

############################################################
heading "Build and install binutils"
############################################################
pushd "$BUILD_DIR"

tar xf download/binutils-${BINTOOLS_VERSION}.tar.gz
cd binutils-${BINTOOLS_VERSION}
./configure \
    --prefix="${INSTALL_DIR}" \
    --program-prefix=avr- \
    --target=avr \
    --disable-nls \
    --disable-werror \
    --without-zstd \
    ${HOST_ARG}
make -j ${MAKE_JOBS}
make install

popd

############################################################
heading "Build and install gcc"
############################################################
pushd "$BUILD_DIR"

tar xf download/gcc-${GCC_VERSION}.tar.xz
cd gcc-${GCC_VERSION}
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
    --with-dwarf2 \
    --disable-shared \
    --enable-plugin \
    --without-zstd \
    $([[ "${GCC_HOST}" == "i686-w64-mingw32" ]] && echo "--disable-win32-utf8-manifest") \
    $([[ "${GCC_HOST}" == *"mingw32"* ]] && echo "--enable-mingw-wildcard")
make -j ${MAKE_JOBS}
make install-strip

popd

pushd "$INSTALL_DIR"
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
    --host=avr
make -j ${MAKE_JOBS}
make install

popd

############################################################
heading "Install atpacks"
############################################################

pushd "$BUILD_DIR"

for packFile in ${PACKS[@]}; do
    echo "Installing ${packFile}"
    mkdir -p pack
    cd pack
    unzip -q ../download/${packFile}
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

cat > "${INSTALL_DIR}/versions.txt" << EOF
Build Information:
  Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
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
heading "Done."
############################################################
