#!/bin/bash

GCC_VERSION=15.2.0
BINTOOLS_VERSION=2.45
LIBC_VERSION=2.2.1

PACKS=(
    Atmel.ATtiny_DFP.2.0.368.atpack
    Atmel.AVR-Ex_DFP.2.11.221.atpack
    Atmel.ATmega_DFP.2.2.509.atpack
    Atmel.AVR-Dx_DFP.2.7.321.atpack
)

# Set GCC_HOST if not already set
if [ -z "${GCC_HOST:-}" ]; then
  case "$(uname -s)" in
    Darwin)
      GCC_HOST=universal-apple-darwin
      ;;
    Linux)
      # Detect libc
      if [ -e /lib/ld-musl-*.so.* ] 2>/dev/null; then
        LIBC=musl
      else
        LIBC=gnu
      fi

      # Detect architecture on Linux
      case "$(uname -m)" in
        x86_64)  GCC_HOST=x86_64-linux-${LIBC} ;;
        i686|i386) GCC_HOST=i686-linux-${LIBC} ;;
        aarch64|arm64) GCC_HOST=aarch64-linux-${LIBC} ;;
        armv7l|armv6l|arm*) GCC_HOST=arm-linux-${LIBC}eabihf ;;
        *) GCC_HOST=unknown-linux-${LIBC} ;;
      esac
      ;;
    MINGW*|MSYS*|CYGWIN*)
      # Detect architecture on Windows
      case "$(uname -m)" in
        x86_64) GCC_HOST=x86_64-w64-mingw32 ;;
        i686|i386) GCC_HOST=i686-w64-mingw32 ;;
        *) GCC_HOST=unknown-w64-mingw32 ;;
      esac
      ;;
    *)
      GCC_HOST=unknown
      ;;
  esac
fi
