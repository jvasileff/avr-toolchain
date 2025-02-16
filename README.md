# AVR/ATtiny Toolchain Builder

This script builds a complete AVR toolchain including GCC, Binutils, and AVR-LibC, with support for various ATtiny and ATmega microcontrollers.

- GCC 14.2.0
- Binutils 2.44
- AVR-LibC 2.2.1

## Prerequisites

### Linux (Debian/Ubuntu)
```bash
apt update && apt install -y build-essential texinfo automake python3 wget zip unzip
```

### macOS
1. Install Xcode and Xcode Command Line Tools
2. Install required packages via Homebrew:
```bash
brew install autoconf automake zstd
```

## Building

1. Clone this repository:
2. Run the build script:
```bash
./build-avr-toolchain.sh
```

The toolchain will be installed in `build/avr-toolchain`. Add this to your PATH:
```bash
export PATH="$(pwd)/build/avr-toolchain/bin:$PATH"
```

## Included Device Support

- ATtiny Series (DFP 2.0.368)
- ATmega Series (DFP 2.2.509)
- AVR-Ex Series (DFP 2.10.205)
- AVR-Dx Series (DFP 2.6.303)

## License

This project is released under the MIT License. The built toolchain components are subject to their respective licenses:
- GCC: GPL v3
- Binutils: GPL v3
- AVR-LibC: Modified BSD License
