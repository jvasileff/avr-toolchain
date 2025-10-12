#!/bin/bash

# Generate checksums.txt file with expected SHA256 checksums for all dependencies
# This file will be used for verification and as a cache key

set -eu

source "$(dirname "$0")/versions.sh"

CHECKSUMS_FILE="checksums.txt"
DOWNLOAD_DIR="build/download"

# Create empty checksums file
> "$CHECKSUMS_FILE"

# Generate checksum for avr-libc
if [ -f "${DOWNLOAD_DIR}/avr-libc-${LIBC_VERSION}.tar.bz2" ]; then
    sha256sum "${DOWNLOAD_DIR}/avr-libc-${LIBC_VERSION}.tar.bz2" >> "$CHECKSUMS_FILE"
else
    echo "0000000000000000000000000000000000000000000000000000000000000000  ${DOWNLOAD_DIR}/avr-libc-${LIBC_VERSION}.tar.bz2" >> "$CHECKSUMS_FILE"
    echo "WARNING: Missing avr-libc-${LIBC_VERSION}.tar.bz2"
fi

# Generate checksum for binutils
if [ -f "${DOWNLOAD_DIR}/binutils-${BINTOOLS_VERSION}.tar.gz" ]; then
    sha256sum "${DOWNLOAD_DIR}/binutils-${BINTOOLS_VERSION}.tar.gz" >> "$CHECKSUMS_FILE"
else
    echo "0000000000000000000000000000000000000000000000000000000000000000  ${DOWNLOAD_DIR}/binutils-${BINTOOLS_VERSION}.tar.gz" >> "$CHECKSUMS_FILE"
    echo "WARNING: Missing binutils-${BINTOOLS_VERSION}.tar.gz"
fi

# Generate checksum for gcc
if [ -f "${DOWNLOAD_DIR}/gcc-${GCC_VERSION}.tar.xz" ]; then
    sha256sum "${DOWNLOAD_DIR}/gcc-${GCC_VERSION}.tar.xz" >> "$CHECKSUMS_FILE"
else
    echo "0000000000000000000000000000000000000000000000000000000000000000  ${DOWNLOAD_DIR}/gcc-${GCC_VERSION}.tar.xz" >> "$CHECKSUMS_FILE"
    echo "WARNING: Missing gcc-${GCC_VERSION}.tar.xz"
fi

# Add checksums for each pack
for pack in "${PACKS[@]}"; do
    if [ -f "${DOWNLOAD_DIR}/${pack}" ]; then
        sha256sum "${DOWNLOAD_DIR}/${pack}" >> "$CHECKSUMS_FILE"
    else
        echo "0000000000000000000000000000000000000000000000000000000000000000  ${DOWNLOAD_DIR}/${pack}" >> "$CHECKSUMS_FILE"
        echo "WARNING: Missing ${pack}"
    fi
done

echo "Generated $CHECKSUMS_FILE"
if grep -q "^0000000000000000000000000000000000000000000000000000000000000000" "$CHECKSUMS_FILE"; then
    echo "Some files were missing - download them first, then re-run this script"
else
    echo "All dependencies found and checksums generated"
fi
