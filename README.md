# AVR/ATtiny Toolchain Builder

This script builds a complete AVR toolchain including GCC, Binutils, and AVR-LibC, with support for various ATtiny and ATmega microcontrollers.

- GCC 15.2.0
- Binutils 2.45
- AVR-LibC 2.2.1

## Prerequisites

### Linux (Debian/Ubuntu)
```bash
apt update && apt install -y build-essential texinfo help2man automake python3 curl zip unzip
```

### macOS
1. Install Xcode and Xcode Command Line Tools
2. Install required packages via Homebrew:
```bash
brew install autoconf automake texinfo help2man
```

### Windows Cross-compilation
The toolchain can be cross-compiled for Windows from either Linux or macOS.

#### From Linux:
```bash
apt install mingw-w64
```

#### From macOS:
```bash
brew install mingw-w64
```

## Building

### Native Build (Linux/macOS)
```bash
./build-avr-toolchain.sh
```

### Windows Cross-compilation
First build the native toolchain, which will be used during the build of the Windows
version.
```bash
# Build native version first
./build-avr-toolchain.sh
mv build build-native
export PATH="$PWD/build-native/avr-toolchain/bin:$PATH"

# Build Windows version (choose one)
GCC_HOST=i686-w64-mingw32 ./build-avr-toolchain.sh     # 32-bit Windows
GCC_HOST=x86_64-w64-mingw32 ./build-avr-toolchain.sh   # 64-bit Windows
```

The toolchain will be installed in `build/compile/avr-toolchain`, and archives will be
placed in `build/artifacts/`.

## Included Device Support

- ATmega Series (DFP 3.6.299)
- ATtiny Series (DFP 3.3.272)
- AVR-Dx Series (DFP 2.7.321)
- AVR-Ex Series (DFP 2.11.221)
- AVR-Lx Series (DFP 1.1.20)

## License

This project is released under the MIT License. The built toolchain components are subject to their respective licenses:
- GCC: GPL v3
- Binutils: GPL v3
- AVR-LibC: Modified BSD License
