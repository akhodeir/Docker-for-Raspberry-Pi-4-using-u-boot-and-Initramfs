# steps from : https://hechao.li/2021/12/20/Boot-Raspberry-Pi-4-Using-uboot-and-Initramfs/


FROM ubuntu:latest

ARG UID=1000
ARG GID=1000

# Set default shell during Docker image build to bash
SHELL ["/bin/bash", "-c"]

# Set non-interactive frontend for apt-get to skip any user confirmations
ENV DEBIAN_FRONTEND=noninteractive

# Install base packages
RUN apt-get -y update && \
	apt-get -y upgrade && \
	apt-get install --no-install-recommends -y \
	   autoconf \
       apt-transport-https \
       build-essential \
       bc \
       bison \
       binfmt-support \
       ca-certificates \
       ccache \
       cdbs \
       cmake \
       cpio \
       curl \
       devscripts \
       dkms \
       dosfstools \
       dpkg-dev \
       e2fsprogs \
       equivs \
       fakeroot \
       flex \
       gawk \
       git \
       gperf \
       help2man \
#       kernel-package \
       kpartx \
       libgpm2 \
       libtool-bin \
       libtool-doc \
       lsof \
       lz4 \
       libc6-arm64-cross \
       libelf-dev \
       libncurses-dev \
       libssl-dev \
       libxdelta2 \
       python3 \
       python3-dev \
       ncurses-dev \
       patch \
       psmisc \
       pv \
       qemu-user-static \
       rsync \
       sudo \
       texinfo \
       u-boot-tools \
       unzip \
       vim \
       vim-common \
       vim-runtime \
       wget \
       xdelta3 \
       xxd \
       xz-utils

# Create 'user' account
RUN groupadd -g $GID -o user
ENV HOME_PATH=/home/user/

RUN useradd -u $UID -m -g user -G plugdev user \
	&& echo 'user ALL = NOPASSWD: ALL' > /etc/sudoers.d/user \
	&& chmod 0440 /etc/sudoers.d/user

USER user

WORKDIR $HOME_PATH

RUN git clone https://github.com/crosstool-ng/crosstool-ng
WORKDIR crosstool-ng

RUN ./bootstrap
RUN ./configure --prefix=${PWD} 
RUN make 
RUN make install 
RUN echo 'export PATH="${HOME}/crosstool-ng/bin:${PATH}"' >> ~/.bashrc
ENV PATH=$HOME_PATH/crosstool-ng/bin:${PATH}
RUN ct-ng show-aarch64-rpi4-linux-gnu
RUN ct-ng aarch64-rpi4-linux-gnu
RUN ct-ng build

WORKDIR $HOME_PATH
RUN git clone git://git.denx.de/u-boot.git
WORKDIR $HOME_PATH/u-boot

RUN export PATH=${HOME}/x-tools/aarch64-rpi4-linux-gnu/bin/:$PATH
RUN export CROSS_COMPILE=aarch64-rpi4-linux-gnu-

RUN echo 'export PATH="${HOME}/x-tools/aarch64-rpi4-linux-gnu/bin/:$PATH"' >> ~/.bashrc
ENV PATH=$HOME_PATH/x-tools/aarch64-rpi4-linux-gnu/bin/:${PATH}
RUN echo 'export CROSS_COMPILE=aarch64-rpi4-linux-gnu-' >> ~/.bashrc
ENV CROSS_COMPILE=aarch64-rpi4-linux-gnu- 


RUN make rpi_4_defconfig
RUN make

WORKDIR $HOME_PATH

RUN git clone --depth=1 -b rpi-5.10.y https://github.com/raspberrypi/linux.git
WORKDIR $HOME_PATH/linux

RUN make ARCH=arm64 CROSS_COMPILE=aarch64-rpi4-linux-gnu- bcm2711_defconfig
RUN make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-rpi4-linux-gnu-




RUN mkdir rootfs && \
	cd rootfs && \
	mkdir {bin,dev,etc,home,lib64,proc,sbin,sys,tmp,usr,var} && \
	mkdir usr/{bin,lib,sbin} && \
	mkdir var/log

# Clean up stale packages
#RUN apt-get -y update && \
#	apt-get -y upgrade && \
#    apt-get clean -y 

WORKDIR $HOME_PATH