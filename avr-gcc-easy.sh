#!/bin/bash

GCC_VERSION=7.3.0

# Uncomment one of the following three groups of settings to build for macOS,
# Linux, or Windows

UPSTREAM_ARCHIVE=avr8-gnu-toolchain-osx-3.7.0.518-darwin.any.x86_64.tar.gz
UPSTREAM_DIR=avr8-gnu-toolchain-darwin_x86_64
TARGET_NAME=avr-toolchain-macOS-x86_64

#UPSTREAM_ARCHIVE=avr8-gnu-toolchain-3.7.0.1796-linux.any.x86_64.tar.gz
#UPSTREAM_DIR=avr8-gnu-toolchain-linux_x86_64
#TARGET_NAME=avr-toolchain-linux-x86_64

#UPSTREAM_ARCHIVE=avr8-gnu-toolchain-3.7.0.1796-win32.any.x86_64.zip
#UPSTREAM_DIR=avr8-gnu-toolchain-win32_x86_64
#TARGET_NAME=avr-toolchain-win32-x86_64

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

set -eux

# download upstream toolchain
if [[ ! -e ${UPSTREAM_ARCHIVE} ]]; then
    wget "https://ww1.microchip.com/downloads/aemDocuments/documents/DEV/ProductDocuments/SoftwareTools/${UPSTREAM_ARCHIVE}"
fi

# download atpacks
for pack in ${PACKS[@]}; do
    if [[ ! -e ${pack} ]]; then
        wget "http://packs.download.atmel.com/$pack"
    fi
done

# unpack upstream toolchain
echo "Unpacking upstream toolchain"
if [ ${UPSTREAM_ARCHIVE##*.} = "zip" ] ; then
    unzip -qn "${UPSTREAM_ARCHIVE}"
else
    tar xf "${UPSTREAM_ARCHIVE}"
fi

# install atpacks
for packFile in ${PACKS[@]}; do
    echo "Installing ${packFile}"

    mkdir pack
    cd pack
    unzip -q ../${packFile}
    mv gcc/dev/*/device-specs/* ../"${UPSTREAM_DIR}"/lib/gcc/avr/${GCC_VERSION}/device-specs
    rmdir gcc/dev/*/device-specs
    cp -a gcc/dev/*/* ../"${UPSTREAM_DIR}"/avr/lib
    cp -a include/avr/* ../"${UPSTREAM_DIR}"/avr/include/avr/
    cd ..
    rm -rf pack
done

# rename and package
mv "${UPSTREAM_DIR}" "${TARGET_NAME}"
if [ ${UPSTREAM_ARCHIVE##*.} = "zip" ] ; then
    zip -q -r "${TARGET_NAME}.zip" "${TARGET_NAME}"
else
    tar cfz "${TARGET_NAME}.tar.gz" "${TARGET_NAME}"
fi

