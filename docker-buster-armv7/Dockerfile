FROM debian/eol:buster-slim AS builder

RUN DEBIAN_FRONTEND=noninteractive apt-get update

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates build-essential texinfo help2man automake \
        python3 curl zip unzip git \
        tmux vim

# Workaround bug with update-ca-certificates and openssl rehash that affects
# debian buster
RUN c_rehash /etc/ssl/certs

RUN DEBIAN_FRONTEND=noninteractive apt-get clean \
    && rm -rf /var/lib/apt/lists/*

CMD ["/bin/bash"]
