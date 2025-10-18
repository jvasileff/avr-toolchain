#!/bin/sh

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

# Work from the APP_HOME directory
cd "$APP_HOME" > /dev/null

source settings

docker run --rm -it --platform linux/arm64 -w /work -v"$APP_HOME"/..:/work $DOCKER_TAG /bin/bash -l
