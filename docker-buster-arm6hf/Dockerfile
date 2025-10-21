######################################################################
## Stage 0: use debootstrap to create root filesystem
######################################################################
FROM debian:trixie-slim AS bootstrap

RUN DEBIAN_FRONTEND=noninteractive \
    apt-get update \
    && apt-get install -y --no-install-recommends debootstrap ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Setup keyring to verify packages
RUN mkdir -p /tmp/raspbian-key \
    && cd /tmp/raspbian-key \
    && wget -O keyring.deb https://archive.raspbian.org/raspbian/pool/main/r/raspbian-archive-keyring/raspbian-archive-keyring_20120528.4_all.deb \
    && dpkg-deb -x keyring.deb /tmp/raspbian-key/out \
    && cp /tmp/raspbian-key/out/usr/share/keyrings/raspbian-archive-keyring.gpg /usr/share/keyrings/

# Configuration
ARG RPI_MIRROR=http://archive.raspbian.org/raspbian
ARG SUITE=buster
ARG ROOTFS=/rootfs

# Generate root filesystem
RUN debootstrap \
      --arch=armhf \
      --variant=minbase \
      --keyring=/usr/share/keyrings/raspbian-archive-keyring.gpg \
      "$SUITE" "$ROOTFS" "$RPI_MIRROR"

# Cleanup
RUN bash -lc 'set -e \
    && chroot $ROOTFS bash -lc "apt-get clean" \
    && rm -rf $ROOTFS/var/lib/apt/lists/*'

######################################################################
## Stage 1: build base image from the generated rootfs
######################################################################
FROM scratch AS base
COPY --from=bootstrap /rootfs/ /
CMD ["/bin/bash"]

######################################################################
## Stage 2: build toolchain builder image
######################################################################
FROM base AS builder
RUN DEBIAN_FRONTEND=noninteractive \
    apt-get update \
    && apt-get install -y --no-install-recommends \
            ca-certificates build-essential texinfo help2man automake \
            python3 curl zip unzip git \
            procps tmux vim \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Workaround bug with update-ca-certificates and openssl rehash that affects
# debian buster and earlier
RUN c_rehash /etc/ssl/certs

