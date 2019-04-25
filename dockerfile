FROM ubuntu:16.04

RUN apt-get -y update
RUN apt-get install -y \
    git \
    libmicrohttpd-dev \
    libcurl4-openssl-dev \
    libgoogle-glog-dev \
    libgflags-dev \
    build-essential \
    libx11-dev \
    m4 \
    pkg-config \
    python-pip \
    sudo \
    unzip \
    wget \
    binutils-multiarch \
    clang \
    debianutils \
    libgmp-dev \
    libzip-dev \
    llvm-6.0-dev \
    m4 \
    perl \
    zlib1g-dev \
    python3 \
    python3-pip \
    wget

RUN groupadd -g 999 debinuser && \
    useradd -r -m -d /debinuser -u 999 -g debinuser debinuser

# install bazel
RUN wget https://github.com/bazelbuild/bazel/releases/download/0.19.2/bazel-0.19.2-linux-x86_64
RUN mv bazel-0.19.2-linux-x86_64 /usr/local/bin/bazel
RUN chmod a+x /usr/local/bin/bazel

# install Nice2Predict
WORKDIR /debin

RUN chown -R debinuser:debinuser /debin
USER debinuser
RUN git clone https://github.com/eth-sri/Nice2Predict.git
RUN cd Nice2Predict && \
    bazel build //... && \
    cd ..

# Download opam binary
USER root
RUN mkdir /opam
RUN chown debinuser:debinuser /opam
RUN wget https://github.com/ocaml/opam/releases/download/2.0.4/opam-2.0.4-x86_64-linux
RUN mv opam-2.0.4-x86_64-linux /usr/local/bin/opam
RUN chmod a+x /usr/local/bin/opam

USER debinuser
RUN echo "eval $(opam env)" >> /debinuser/.bashrc
RUN opam init --disable-sandboxing --comp=4.05.0 --yes
RUN eval $(opam env)
run opam install depext --yes
RUN opam depext --install bap --yes
RUN opam install yojson --yes

# copy debin
ADD ./ocaml /debin/ocaml
ADD ./cpp /debin/cpp
ADD ./py /debin/py
ADD ./c_valid_labels /debin/c_valid_labels
ADD ./requirements.txt /debin/requirements.txt

WORKDIR /debin

# install python dependencies
RUN pip3 install -r requirements.txt

USER root
RUN chown -R debinuser:debinuser /debin

# build bap plugin
USER debinuser
WORKDIR /debin/ocaml
RUN rm -rf ocaml/_build loc.plugin && \
    opam config exec -- bapbuild -pkg yojson loc.plugin && \
    opam config exec -- bapbundle install loc.plugin

# compile shared library for producing output binary
WORKDIR /debin/cpp
RUN g++ -c -fPIC modify_elf.cpp -o modify_elf.o -I./ && \
    g++ modify_elf.o -shared -o modify_elf.so

USER root
ADD ./examples /debin/examples
ADD ./models /debin/models
RUN chown -R debinuser:debinuser /debin/examples
RUN chown -R debinuser:debinuser /debin/models

USER debinuser
WORKDIR /debin

ENTRYPOINT [ "/bin/bash" ]
