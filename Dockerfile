FROM jupyter/pyspark-notebook:spark-3.2.0
USER root

RUN apt-get update
RUN apt-get install -y \
  btrfs-progs \
  git \
  build-essential \
  go-md2man \
  iptables \
  libassuan-dev \
  libc6-dev \
  libdevmapper-dev \
  libglib2.0-dev \
  libgpgme-dev \
  libgpg-error-dev \
  libostree-dev \
  libprotobuf-dev \
  libprotobuf-c-dev \
  libseccomp-dev \
  libselinux1-dev \
  libsystemd-dev \
  pkg-config \
  runc \
  uidmap \
  curl \
  wget

# install golang
RUN mkdir -p /Downloads
WORKDIR /Downloads
RUN wget https://dl.google.com/go/go1.12.5.linux-amd64.tar.gz
RUN tar -zxvf go1.12.5.linux-amd64.tar.gz
RUN mv go /usr/local
RUN ln -s /usr/local/go/bin/* /usr/local/bin
RUN mkdir /go
RUN rm -rf /Downloads
ENV GOPATH=/go

# build ostree
RUN git clone https://github.com/ostreedev/ostree /ostree
WORKDIR /ostree
RUN git submodule update --init
RUN apt-get install -y automake bison e2fsprogs fuse liblzma-dev libtool zlib1g
#RUN ./autogen.sh --prefix=/usr --libdir=/usr/lib64 --sysconfdir=/etc
# remove --nonet option due to https:/github.com/ostreedev/ostree/issues/1374
#RUN sed -i '/.*--nonet.*/d' ./Makefile-man.am
#RUN make
#RUN make install
WORKDIR /

# build conmon
RUN git clone https://github.com/containers/conmon
WORKDIR /conmon
RUN make
RUN install -D -m 755 bin/conmon /usr/libexec/podman/conmon
WORKDIR /

# build runc
RUN git clone https://github.com/opencontainers/runc.git $GOPATH/src/github.com/opencontainers/runc
WORKDIR $GOPATH/src/github.com/opencontainers/runc
RUN make BUILDTAGS="selinux seccomp"
RUN cp runc /usr/bin/runc
WORKDIR /

# build network plugins
RUN git clone https://github.com/containernetworking/plugins.git $GOPATH/src/github.com/containernetworking/plugins
WORKDIR $GOPATH/src/github.com/containernetworking/plugins
RUN ./build_linux.sh
RUN mkdir -p /usr/libexec/cni
RUN cp bin/* /usr/libexec/cni
WORKDIR /

# network configs
RUN mkdir -p /etc/cni/net.d
RUN curl -qsSL -o 99-loopback.conf https://raw.githubusercontent.com/containers/libpod/master/cni/87-podman-bridge.conflist
RUN cp 99-loopback.conf /etc/cni/net.d/99-loopback.conf
WORKDIR /

# registries and policies
RUN mkdir -p /etc/containers
RUN curl https://raw.githubusercontent.com/projectatomic/registries/master/registries.fedora -o /etc/containers/registries.conf
RUN curl https://raw.githubusercontent.com/containers/skopeo/master/default-policy.json -o /etc/containers/policy.json
WORKDIR /

# build libpod
RUN git clone https://github.com/containers/libpod/ $GOPATH/src/github.com/containers/libpod
WORKDIR $GOPATH/src/github.com/containers/libpod
RUN make BUILDTAGS="selinux seccomp"
RUN make install PREFIX=
WORKDIR /
