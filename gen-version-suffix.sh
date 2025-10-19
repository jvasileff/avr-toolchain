#!/usr/bin/env bash
set -euo pipefail

getScriptDir() {
  (
    TARGET="${BASH_SOURCE:-$0}"
    while [ -h "$TARGET" ]; do
      LINK=$(readlink "$TARGET") || break
      case "$LINK" in
        /*) TARGET="$LINK" ;;
        *) TARGET="$(cd -P "$(dirname "$TARGET")" && pwd)/$LINK" ;;
      esac
    done
    cd -P "$(dirname "$TARGET")" && pwd
  )
}

# Source versions.sh to get GCC_VERSION and other vars
source "$(getScriptDir)/versions.sh"

# --- helpers ---------------------------------------------------------------

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

get_version() {
  local version_tag=""

  # Look for version tag matching vMAJOR.MINOR.PATCH (optionally with underscores)
  if git_available; then
    local -a TAGS
    mapfile -t TAGS < <(get_tags_at_head || true)
    for t in "${TAGS[@]:-}"; do
      if [[ "$t" =~ ^v[0-9]+\.[0-9]+\.[0-9]+_*$ ]]; then
        version_tag="$t"
        break
      fi
    done
  fi

  if [[ -n "$version_tag" ]]; then
    # Strip leading 'v' and print
    echo "${version_tag#v}"
    return 0
  fi

  # Otherwise, compose timestamp-based version
  local git_hash datetime epoch dirty_suffix
  git_hash="$(get_git_hash_short)" || git_hash="unknown"
  datetime="$(get_commit_datetime_utc "$git_hash")" || datetime="unknown"

  # Fallback to SOURCE_DATE_EPOCH if no git date (e.g., tarball builds)
  if [[ "$datetime" == "unknown" || -z "$datetime" ]]; then
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

# --- main ------------------------------------------------------------------

get_version
