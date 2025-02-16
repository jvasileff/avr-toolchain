#!/bin/bash

# For Linux:
#   apt install mingw-w64
#
# For macOS:
#   brew install mingw-w64
#
# Note: The Linux AVR toolchain must be available in the PATH when building
# the Windows AVR toolchain. Build and install the Linux version first:
#   ./build-avr-toolchain.sh
#   mv build build-linux
#   export PATH=$PWD/build-linux/avr-toolchain/bin:$PATH
#   ./build-avr-toolchain-windows-x86.sh

export HOST_ARG="--host=i686-w64-mingw32"
exec "$(dirname "$0")/build-avr-toolchain.sh"
