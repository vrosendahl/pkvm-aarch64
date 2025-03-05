Our custom fork of pKVM based on the Android tree

What currently works, execute the following make targets in order:

* `make tools`

* `make host-kernel`

* `make ubuntu-template`. This creates an Ubuntu system that is reused by the
  hostimage and guestimae targets.

* `make target-crosvm`

* `make hostimage`

* `make guest-kernel`

* `make guestimage`

* `make guestimage2`. This is optional. It provides a second guest image with different IP address and hostname. It depends on the guestimage target.

* `make guestimage3`. This is optional. It provides a third guest image with different IP address and hostname. It depends on the guestimage target.

* `make guestimage4`. This is optional. It provides a fourth guest image with different IP address and hostname. It depends on the guestimage target.

* `make pkvm-debug-tools`. This is optional. Build pkvm-debug-tools module.

* `make host-initramfs`. This is optional. Needed if pkvm-debug-tools is in use. Build host initramfs file.

* `make run`. This will boot the pkvm host image with the host kernel in qemu.

* `make USE_INITRAMFS=1 run`. This will boot the pkvm host image with the host kernel in qemu. Qemu loads initramfs file.

* `make USE_KIC=1 run`. This will boot the pkvm host image with the host kernel in qemu. Qemu loads KIC/pVM firmware.
 
* `make DEBUGGER=1 run`. This will boot the pkvm host image with the host kernel in qemu with the gdb server enabled.

* `make gdb`. This will start the gdb and connect it to the qemu gdb server. This should be executed in another terminal window.

The `make host-kernel` and `make target-crosvm` targets can be executed in any order, there is no dependency between them. Also `make guestkernel` only needs depend on `make tools`, while `make guestimage` depends on `make guestkernel`

The default user is `ubuntu`. No password is required. The hostimage has a script, `run-crosvm.sh`, which can be used to run the guestimage with crosvm, also doing the necessary configuration of networking.

There is also a `make all` target that will build everything in the right order. However, it will only build the first guestimage. If the additional guest images are wanted, then they must be built by adding an extra `make guestimage2', `make guestimage3`, or `make guestimage4`.

What is missing:

* The builds are not necessarily 100% reliable.

* Building has only been tested on Ubuntu 22.04.

* The build dependencies are not fully analyzed. On ubuntu 22.04, you can try installing the following:

```
sudo apt-get update
sudo apt-get dist-upgrade
(reboot if necessary)
sudo apt-get install -y gcc-multilib g++-multilib
sudo apt-get install -y git-core gnupg flex bison \
build-essential zip curl zlib1g-dev libc6-dev-i386 lib32ncurses5-dev \
x11proto-core-dev libx11-dev lib32z1-dev libgl1-mesa-dev libxml2-utils \
xsltproc unzip fontconfig pip crossbuild-essential-arm64 \
gcc-aarch64-linux-gnu g++-aarch64-linux-gnu make ninja-build \
bsdmainutils libdrm-dev libegl-dev libegl1-mesa-dev libelf-dev \
libexpat1-dev libgl-dev libgles-dev libglib2.0-dev libglib2.0-dev-bin \
libglu1-mesa-dev libglvnd-core-dev libglx-dev libgmp-dev libice-dev \
libmagic-dev libmpc-dev libmpfr-dev libpcre3-dev libpcre2-dev \
libpixman-1-dev libpng-dev libpopt-dev libpulse-dev libsdl1.2-dev \
libsdl2-dev libspice-protocol-dev libspice-server-dev libwayland-dev \
libxau-dev libxinerama-dev libxrandr-dev linux-libc-dev xtrans-dev \
libssl-dev git texi2html texinfo rsync gawk bc python2 sudo wget qemu \
binfmt-support qemu-user-static libx11-xcb1 libx11-6 libxkbcommon0 \
libxkbcommon-x11-0 libvulkan-dev libvulkan1 libvdeplug2 libepoxy0 \
libvirglrenderer1 meson python3-mako python-is-python3 libxdamage-dev \
libxcb-glx0-dev libx11-xcb-dev libxcb-dri2-0-dev libxcb-dri3-dev \
libxcb-present-dev libxshmfence-dev llvm libvirglrenderer-dev \
libaio-dev libepoxy-dev wayland-protocols libwayland-egl-backend-dev \
net-tools iputils-ping iproute2 gdb-multiarch sshpass \
device-tree-compiler glslang-tools libxcb-shm0-dev doxygen graphviz \
texlive-latex-base texlive-fonts-recommended texlive-latex-extra kmod \
qemu-utils parted cpio xxd zstd udev
```

* There are no target for building anything for the Nvidia hardware target.
