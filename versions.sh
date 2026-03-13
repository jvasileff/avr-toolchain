#!/bin/sh

GCC_VERSION=15.2.0
BINTOOLS_VERSION=2.45
LIBC_VERSION=2.2.1

PACKS="
    Microchip.ATmega_DFP.3.6.299.atpack
    Microchip.ATtiny_DFP.3.3.272.atpack
    Microchip.AVR-Dx_DFP.2.7.321.atpack
    Microchip.AVR-Ex_DFP.2.11.221.atpack
    Microchip.AVR-Lx_DFP.1.1.20.atpack
"

# --- Set BUILD_VERSION ------------------------------------------------------

BUILD_VERSION=$(
  git_available() {
    command -v git >/dev/null 2>&1
  }

  get_git_hash_short() {
    if ! git_available; then
      echo "unknown"
      return 1
    fi
    git rev-parse --short HEAD 2>/dev/null || {
      echo "unknown"
      return 1
    }
  }

  get_tags_at_head() {
    if ! git_available; then
      return 1
    fi
    git tag --points-at HEAD 2>/dev/null
  }

  get_commit_datetime_utc() {
    local hash="$1"
    if ! git_available; then
      echo "unknown"
      return 1
    fi
    TZ=UTC git log -1 --format=%cd --date=format-local:'%Y%m%d-%H%M' "$hash" 2>/dev/null || {
      echo "unknown"
      return 1
    }
  }

  is_git_dirty() {
    if ! git_available; then
      return 1
    fi
    ! git diff --quiet HEAD 2>/dev/null
  }

  get_version_suffix() {
    local version_tag=""

    # Look for version tag matching vMAJOR.MINOR.PATCH (optionally with underscores)
    if git_available; then
      local tags=$(get_tags_at_head || true)
      for t in $tags; do
        if echo "$t" | grep -q '^v[0-9]\+\.[0-9]\+\.[0-9]\+_*$'; then
          version_tag="$t"
          break
        fi
      done
    fi

    if [ -n "$version_tag" ]; then
      # Strip leading 'v' and print (just the version number)
      echo "${version_tag#v}"
      return 0
    fi

    # Otherwise, compose timestamp-based version suffix
    local git_hash datetime epoch dirty_suffix
    git_hash="$(get_git_hash_short)" || git_hash="unknown"
    datetime="$(get_commit_datetime_utc "$git_hash")" || datetime="unknown"

    # Fallback to SOURCE_DATE_EPOCH if no git date (e.g., tarball builds)
    if [ "$datetime" = "unknown" ] || [ -z "$datetime" ]; then
      epoch="${SOURCE_DATE_EPOCH:-$(date +%s)}"
      datetime=$(date -u -d "@$epoch" '+%Y%m%d-%H%M' 2>/dev/null) || \
      datetime=$(date -u -r "$epoch" '+%Y%m%d-%H%M' 2>/dev/null) || \
      datetime="unknown"
    fi

    # Add "-dirty" suffix if working directory has uncommitted changes
    dirty_suffix=""
    if is_git_dirty; then
      dirty_suffix="-dirty"
    fi

    echo "${GCC_VERSION}_${datetime}-${git_hash}${dirty_suffix}"
  }

  # Call the function and output to stdout (captured by command substitution)
  get_version_suffix
)

# --- Set GCC_HOST -----------------------------------------------------------

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
        armv7l) GCC_HOST=armv7-linux-${LIBC}eabihf ;;
        armv6l) GCC_HOST=armv6-linux-${LIBC}eabihf ;;
        arm*) GCC_HOST=arm-linux-${LIBC}eabihf ;;
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
