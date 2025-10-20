FROM alpine AS builder

RUN apk update --no-cache

RUN apk add --no-cache \
    bash build-base texinfo help2man automake autoconf \
    python3 curl zip unzip git tar xz \
    tmux vim

CMD ["/bin/bash"]
