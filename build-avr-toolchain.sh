#!/bin/bash

# For Linux:
#   sudo apt update
#   sudo apt install -y build-essential texinfo automake
#
# For macOS:
#   install xcode & xcode commandline tools
#   brew install autoconf automake

set -eu
shopt -s expand_aliases

BUILD_DIR="$(pwd)"
INSTALL_DIR="${BUILD_DIR}"/avr-toolchain
GCC_VERSION=11.5.0
BINTOOLS_VERSION=2.43
MAKE_JOBS=10

PACKS=(
    Atmel.ATtiny_DFP.2.0.368.atpack
    Atmel.AVR-Ex_DFP.2.10.205.atpack
    Atmel.ATmega_DFP.2.2.509.atpack
    Atmel.AVR-Dx_DFP.2.6.303.atpack
)

#PACKS=(
#    Atmel.ATtiny_DFP.1.10.348.atpack
#    Atmel.AVR-Ex_DFP.1.0.38.atpack
#    Atmel.ATmega_DFP.1.7.374.atpack
#    Atmel.AVR-Dx_DFP.1.10.114.atpack
#)

mkdir $INSTALL_DIR
export PATH="${INSTALL_DIR}"/bin:$PATH

if [ -z "$MAKE_JOBS" ]; then
    MAKE_JOBS="1"
fi

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
if [[ ! -e "avr-libc-2.2.1.tar.bz2" ]]; then
    wget 'https://github.com/avrdudes/avr-libc/releases/download/avr-libc-2_2_1-release/avr-libc-2.2.1.tar.bz2'
fi
if [[ ! -e "binutils-${BINTOOLS_VERSION}.tar.gz" ]]; then
    wget "https://ftp.gnu.org/gnu/binutils/binutils-${BINTOOLS_VERSION}.tar.gz"
fi
if [[ ! -e "gcc-${GCC_VERSION}.tar.xz" ]]; then
    wget "https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz"
fi
if [[ ! -e "00-binutils-data_region_length.patch" ]]; then
    wget 'https://raw.githubusercontent.com/arduino/toolchain-avr/master/binutils-patches/00-binutils-data_region_length.patch'
fi
if [[ ! -e "gcc-11-arm-darwin.patch" ]]; then
    wget 'https://gist.githubusercontent.com/DavidEGrayson/88bceb3f4e62f45725ecbb9248366300/raw/c1f515475aff1e1e3985569d9b715edb0f317648/gcc-11-arm-darwin.patch'
fi
if [[ ! -e "config.guess" ]]; then
    wget "http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD" -O "./config.guess"
fi
if [[ ! -e "config.sub" ]]; then
    wget "http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD" -O "./config.sub"
fi

#wget 'http://packs.download.atmel.com/Atmel.ATtiny_DFP.2.0.368.atpack'
for pack in ${PACKS[@]}; do
    if [[ ! -e ${pack} ]]; then
        wget "http://packs.download.atmel.com/$pack"
    fi
done

############################################################
heading "Build and install binutils"
############################################################
tar xf binutils-${BINTOOLS_VERSION}.tar.gz
cd binutils-${BINTOOLS_VERSION}
#patch -p1 < ../00-binutils-data_region_length.patch
./configure --prefix="${INSTALL_DIR}" --program-prefix=avr- --target=avr --disable-nls
make -j ${MAKE_JOBS}
make install
cd ..

############################################################
heading "Build and install gcc"
############################################################
tar xf gcc-${GCC_VERSION}.tar.xz
cd gcc-${GCC_VERSION}
if [ $(uname) = "Darwin" -a $(arch) = "arm64" ] ; then
    patch -p1 < ../gcc-11-arm-darwin.patch
fi
./contrib/download_prerequisites
cd ..
mkdir gcc-build
cd gcc-build
../gcc-${GCC_VERSION}/configure --prefix="${INSTALL_DIR}" --program-prefix=avr- --target=avr \
    --enable-languages=c,c++ --with-gnu-as --with-gnu-ld --disable-nls \
    --with-zstd=no \
    --enable-fixed-point \
    --disable-libssp \
    --disable-libada \
    --disable-shared \
    --with-avrlibc=yes \
    --with-dwarf2 \
    --disable-doc
make -j ${MAKE_JOBS}
make install
cd ..

############################################################
heading "Build and install avr-libc"
############################################################
if [ $(uname) = "Darwin" -a $(arch) = "arm64" ] ; then
    # workaround for arm mac
    export ac_cv_build=aarch64-apple-darwin
fi
tar xf avr-libc-2.2.1.tar.bz2
cd avr-libc-2.2.1
rm -f config.guess && cp -a ../config.guess .
rm -f config.sub && cp -a ../config.sub .
./bootstrap
./configure --prefix="${INSTALL_DIR}" --host=avr
make -j ${MAKE_JOBS}
make install
cd ..

############################################################
heading "Install atpacks"
############################################################
for packFile in ${PACKS[@]}; do
    echo "Installing ${packFile}"
    mkdir pack
    cd pack
    unzip -q ../${packFile}
    mv gcc/dev/*/device-specs/* "${INSTALL_DIR}"/lib/gcc/avr/${GCC_VERSION}/device-specs
    rmdir gcc/dev/*/device-specs
    cp -a gcc/dev/*/* "${INSTALL_DIR}"/avr/lib
    cp -a include/avr/* "${INSTALL_DIR}"/avr/include/avr/
    cd ..
    rm -rf pack
done

############################################################
heading "Done."
############################################################
