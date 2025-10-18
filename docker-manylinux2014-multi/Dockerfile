FROM quay.io/pypa/manylinux2014 AS builder

RUN yum -y update

RUN yum -y install \
        texinfo help2man automake autoconf \
        python3 curl zip unzip \
        tmux vim

CMD ["/bin/bash"]
