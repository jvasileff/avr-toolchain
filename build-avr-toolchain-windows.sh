#!/bin/bash

# For Linux:
#   apt install mingw-w64
#
# For macOS:
#   brew install mingw-w64

set -eu
shopt -s expand_aliases

source "$(dirname "$0")/versions.sh"

BUILD_DIR="$(pwd)/build-x64-windows"
INSTALL_DIR="${BUILD_DIR}"/avr-toolchain

LIBC_DIR=$(echo ${LIBC_VERSION} | tr '.' '_')"-release"
HOST=x86_64-w64-mingw32

# Detect number of CPU cores
if [ "$(uname)" = "Darwin" ]; then
    MAKE_JOBS=$(sysctl -n hw.ncpu)
else
    MAKE_JOBS=$(nproc)
fi

# Check for MinGW
if ! command -v ${HOST}-gcc >/dev/null 2>&1; then
    echo "Error: MinGW cross-compiler not found"
    echo "Please install mingw-w64 package"
    exit 1
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
./configure --prefix="${INSTALL_DIR}" --program-prefix=avr- --target=avr --disable-nls --disable-werror \
    --host=${HOST} \
    --without-zstd
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
../gcc-${GCC_VERSION}/configure --prefix="${INSTALL_DIR}" --program-prefix=avr- --target=avr \
    --host=${HOST} \
    --enable-languages=c,c++ \
    --disable-nls \
    --disable-libssp \
    --disable-libada \
    --with-dwarf2 \
    --disable-shared \
    --enable-static \
    --enable-mingw-wildcard \
    --enable-plugin \
    --with-gnu-as \
    --with-gnu-ld \
    --without-zstd

make -j ${MAKE_JOBS}
make install-strip

popd

pushd "$INSTALL_DIR"
cp -a libexec/gcc/avr/${GCC_VERSION}/liblto_plugin.dll lib/bfd-plugins/
popd

############################################################
heading "Build and install avr-libc"
############################################################
pushd "$BUILD_DIR"

tar xf download/avr-libc-${LIBC_VERSION}.tar.bz2
cd avr-libc-${LIBC_VERSION}
./bootstrap
./configure --prefix="${INSTALL_DIR}" --host=avr
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
heading "Done."
############################################################
