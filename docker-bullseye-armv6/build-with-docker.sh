#!/bin/sh

set -eu

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

APP_HOME="$(getScriptDir)"

# Work from the project directory (APP_HOME/..)
cd "$APP_HOME/.." > /dev/null

source "$APP_HOME"/settings

USE_TTY="" && test -t 1 && USE_TTY="-t"

set -x

"$APP_HOME"/build-dockerimage.sh
docker run --platform $PLATFORM --rm -i $USE_TTY -v"$APP_HOME"/..:/work $DOCKER_TAG /bin/bash -c 'cd /work && ./build-avr-toolchain.sh'
