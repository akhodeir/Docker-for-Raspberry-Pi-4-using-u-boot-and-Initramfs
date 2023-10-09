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
       tree \
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


#==========Toolchain==========#

#Download crosstool-NG source
RUN git clone --depth=1 https://github.com/crosstool-ng/crosstool-ng
WORKDIR crosstool-ng
# Switch to the private branch
RUN git checkout -b crosstool-ng

#Build and Install crosstool-NG
RUN ./bootstrap
RUN ./configure --prefix=${PWD} 
RUN make 
RUN make install 
RUN echo 'export PATH="${HOME}/crosstool-ng/bin:${PATH}"' >> ~/.bashrc
ENV PATH=$HOME_PATH/crosstool-ng/bin:${PATH}

#Configure crosstool-NG
RUN ct-ng show-aarch64-rpi4-linux-gnu
RUN ct-ng aarch64-rpi4-linux-gnu
#Build the toolchain
RUN ct-ng build

WORKDIR $HOME_PATH
#==========Bootloader==========#
#Download u-boot source
RUN git clone --depth=1 git://git.denx.de/u-boot.git
WORKDIR $HOME_PATH/u-boot
# Switch to the private branch
RUN git checkout -b u-boot
#Configure u-boot
RUN export PATH=${HOME}/x-tools/aarch64-rpi4-linux-gnu/bin/:$PATH
RUN export CROSS_COMPILE=aarch64-rpi4-linux-gnu-

RUN echo 'export PATH="${HOME}/x-tools/aarch64-rpi4-linux-gnu/bin/:$PATH"' >> ~/.bashrc
ENV PATH=$HOME_PATH/x-tools/aarch64-rpi4-linux-gnu/bin/:${PATH}
RUN echo 'export CROSS_COMPILE=aarch64-rpi4-linux-gnu-' >> ~/.bashrc
ENV CROSS_COMPILE=aarch64-rpi4-linux-gnu- 
RUN make rpi_4_defconfig
#Build u-boot
RUN make
#Install u-boot
#copy the files to SD-Card
#sudo cp u-boot.bin /mnt/boot

WORKDIR $HOME_PATH
#==========Kernel==========#
#Download the Kernel Source
RUN git clone --depth=1 https://github.com/raspberrypi/linux.git
WORKDIR $HOME_PATH/linux
#Config and Build the Kernel
RUN make ARCH=arm64 CROSS_COMPILE=aarch64-rpi4-linux-gnu- bcm2711_defconfig
RUN make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-rpi4-linux-gnu-
#Install the kernel and device tree
#sudo cp arch/arm64/boot/Image /mnt/boot
#sudo cp arch/arm64/boot/dts/broadcom/bcm2711-rpi-4-b.dtb /mnt/boot/

WORKDIR $HOME_PATH
#==========Root filesystem==========#
RUN mkdir rootfs && \
	cd rootfs && \
	mkdir {bin,dev,etc,home,lib64,proc,sbin,sys,tmp,usr,var} && \
	mkdir usr/{bin,lib,sbin} && \
	mkdir var/log


# Download the source code
RUN git clone --depth=1 git://busybox.net/busybox.git 
WORKDIR $HOME_PATH/busybox
# Config
RUN CROSS_COMPILE="${HOME}/x-tools/aarch64-rpi4-linux-gnu/bin/aarch64-rpi4-linux-gnu-"
ENV CROSS_COMPILE=$HOME_PATH/x-tools/aarch64-rpi4-linux-gnu/bin/aarch64-rpi4-linux-gnu-
RUN make CROSS_COMPILE="$CROSS_COMPILE" defconfig

# Change the install directory to be the one just created
RUN sed -i 's%^CONFIG_PREFIX=.*$%CONFIG_PREFIX="/home/hechaol/rootfs"%' .config

# Build
RUN make -j$(nproc) CROSS_COMPILE="$CROSS_COMPILE"

# Install
# Use sudo because the directory is now owned by root
RUN sudo make CROSS_COMPILE="$CROSS_COMPILE" install



# Clean up stale packages
#RUN apt-get -y update && \
#	apt-get -y upgrade && \
#    apt-get clean -y 

WORKDIR $HOME_PATH