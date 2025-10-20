FROM debian:trixie-slim AS builder

RUN DEBIAN_FRONTEND=noninteractive apt-get update

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates build-essential texinfo help2man automake \
        mingw-w64 python3 curl zip unzip git \
        tmux vim

RUN DEBIAN_FRONTEND=noninteractive apt-get clean \
    && rm -rf /var/lib/apt/lists/*

CMD ["/bin/bash"]
