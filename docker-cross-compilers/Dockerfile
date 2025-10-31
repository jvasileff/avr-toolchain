######################################################################
## Stage 1: build the cross compilers
######################################################################
FROM debian:trixie-slim AS bootstrap

RUN DEBIAN_FRONTEND=noninteractive apt-get update

# basics
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates curl zip unzip git file procps tmux vim

# from crosstool-ng sample Dockerfile
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    gcc g++ gperf bison flex texinfo help2man make libncurses5-dev \
    python3-dev autoconf automake libtool libtool-bin gawk wget bzip2 \
    xz-utils unzip patch libstdc++6 rsync git meson ninja-build

WORKDIR /root

RUN curl -L -O "https://github.com/crosstool-ng/crosstool-ng/releases/download/crosstool-ng-1.28.0/crosstool-ng-1.28.0.tar.xz"

RUN mkdir crosstool-ng \
    && cd crosstool-ng \
    && tar --strip-components 1 -xf ../crosstool-ng-*

RUN cd crosstool-ng \
    && ./configure --prefix=/opt/x-tools/crosstool-ng \
    && make \
    && make install \
    && mkdir /root/src \
    && cd /root \
    && rm -rf crosstool-ng

ENV PATH="/opt/x-tools/crosstool-ng/bin:${PATH}"
ENV CT_PREFIX=/opt/x-tools

RUN rm -rf build
COPY ct-defconfigs/defconfig-aarch64-linux-gnu build/defconfig
RUN cd build && ct-ng defconfig && ct-ng build > out.log 2> err.log || \
    (echo "=== STDERR ===" && cat err.log && echo "=== STDOUT ===" && cat out.log && exit 1)

RUN rm -rf build
COPY ct-defconfigs/defconfig-armv6-linux-gnueabihf build/defconfig
RUN cd build && ct-ng defconfig && ct-ng build > out.log 2> err.log || \
    (echo "=== STDERR ===" && cat err.log && echo "=== STDOUT ===" && cat out.log && exit 1)

RUN rm -rf build
COPY ct-defconfigs/defconfig-x86_64-linux-gnu build/defconfig
RUN cd build && ct-ng defconfig && ct-ng build > out.log 2> err.log || \
    (echo "=== STDERR ===" && cat err.log && echo "=== STDOUT ===" && cat out.log && exit 1)

RUN rm -rf build
COPY ct-defconfigs/defconfig-x86_64-w64-mingw32 build/defconfig
RUN cd build && ct-ng defconfig && ct-ng build > out.log 2> err.log || \
    (echo "=== STDERR ===" && cat err.log && echo "=== STDOUT ===" && cat out.log && exit 1)

RUN rm -rf build
COPY ct-defconfigs/defconfig-aarch64-linux-musl build/defconfig
RUN cd build && ct-ng defconfig && ct-ng build > out.log 2> err.log || \
    (echo "=== STDERR ===" && cat err.log && echo "=== STDOUT ===" && cat out.log && exit 1)

RUN rm -rf build
COPY ct-defconfigs/defconfig-armv6-linux-musleabihf build/defconfig
RUN cd build && ct-ng defconfig && ct-ng build > out.log 2> err.log || \
    (echo "=== STDERR ===" && cat err.log && echo "=== STDOUT ===" && cat out.log && exit 1)

RUN rm -rf build
COPY ct-defconfigs/defconfig-x86_64-linux-musl build/defconfig
RUN cd build && ct-ng defconfig && ct-ng build > out.log 2> err.log || \
    (echo "=== STDERR ===" && cat err.log && echo "=== STDOUT ===" && cat out.log && exit 1)

RUN rm -rf build
COPY ct-defconfigs/defconfig-i686-linux-gnu build/defconfig
RUN cd build && ct-ng defconfig && ct-ng build > out.log 2> err.log || \
    (echo "=== STDERR ===" && cat err.log && echo "=== STDOUT ===" && cat out.log && exit 1)

RUN rm -rf build
COPY ct-defconfigs/defconfig-i686-w64-mingw32 build/defconfig
RUN cd build && ct-ng defconfig && ct-ng build > out.log 2> err.log || \
    (echo "=== STDERR ===" && cat err.log && echo "=== STDOUT ===" && cat out.log && exit 1)

CMD ["/bin/bash"]

######################################################################
## Stage 2: build toolchain builder image
######################################################################
FROM debian:trixie-slim AS builder

LABEL org.opencontainers.image.source=https://github.com/jvasileff/avr-toolchain

COPY --from=bootstrap /opt/ /opt/

RUN DEBIAN_FRONTEND=noninteractive apt-get update

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates build-essential texinfo help2man automake \
    python3 curl zip unzip git \
    file procps tmux vim

RUN DEBIAN_FRONTEND=noninteractive apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# create symlinks in /usr/local/bin for all executables
RUN for dir in /opt/x-tools/*/bin; do \
        for file in "$dir"/*; do \
            if [ -f "$file" ] && [ -x "$file" ]; then \
                ln -sf "$file" /usr/local/bin/$(basename "$file"); \
            fi; \
        done; \
    done

