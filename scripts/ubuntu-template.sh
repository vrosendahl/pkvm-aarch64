#!/bin/bash

#
# Tested on ubuntu 20+. You need to have qemu-user-static and binfmt-support
# installed.
#

TOOLDIR=$BASE_DIR/buildtools
QEMU_USER=`which qemu-aarch64-static`

#
# Default: dynamic, opengl, spice, virgl, hybris
#

UBUNTU_BASE=http://cdimage.debian.org/mirror/cdimage.ubuntu.com/ubuntu-base/releases/22.04/release/ubuntu-base-22.04-base-arm64.tar.gz
PKGLIST=`cat $BASE_DIR/scripts/package.list.22`

#
# Note: cross-compilation is also possible, these can be passed through.
#
unset CC
unset LD
unset CXX
unset AR
unset CPP
unset CROSS_COMPILE
unset CFLAGS
unset LDFLAGS
unset ASFLAGS
unset INCLUDES
unset WARNINGS
unset DEFINES

export PATH=$TOOLDIR/bin:$TOOLDIR/usr/bin:/bin:/usr/bin
export CHROOTDIR=$BASE_DIR/oss/ubuntu-template

NJOBS_MAX=8
NJOBS=`nproc`
REPO=`which repo`

if [ $NJOBS -gt $NJOBS_MAX ];then
	NJOBS=$NJOBS_MAX
fi

set -e

do_unmount()
{
	if [[ $(findmnt -M "$1") ]]; then
		sudo umount $1
		if [ $? -ne 0 ]; then
			echo "ERROR: failed to umount $1"
			exit 1
		fi
	fi
}

do_unmount_all()
{
	[ -n "$LEAVE_MOUNTS" ] && echo "leaving bind mounts in place." && exit 0

	echo "Unmount all binding dirs"
	do_unmount $CHROOTDIR/build/crosvm
	do_unmount $CHROOTDIR/proc
	do_unmount $CHROOTDIR/dev
	sudo rm -f $CHROOTDIR/var/cache/apt/archives/*.deb || true
	sudo rm -f $CHROOTDIR/var/cache/apt/archives/*.ddeb || true
}

do_clean()
{
	do_unmount_all
}

do_distclean()
{
	do_unmount_all
	sudo rm -rf $CHROOTDIR
}

do_sysroot()
{
	mkdir -p $CHROOTDIR
	if [ -e $CHROOTDIR/bin/bash ]; then
		sudo mount --bind /dev $CHROOTDIR/dev
		sudo mount -t proc none $CHROOTDIR/proc
		DEBIAN_FRONTEND=noninteractive sudo -E chroot $CHROOTDIR apt-get update
		DEBIAN_FRONTEND=noninteractive sudo -E chroot $CHROOTDIR apt-get -y dist-upgrade
		return;
	fi

	cd $CHROOTDIR
	wget -c $UBUNTU_BASE
	sudo tar --numeric-owner -xf `basename $UBUNTU_BASE`
	sudo mount --bind /dev $CHROOTDIR/dev
	sudo mount -t proc none $CHROOTDIR/proc
	echo "nameserver 8.8.8.8"|sudo tee $CHROOTDIR/etc/resolv.conf > /dev/null
	sudo chown 0:0 $CHROOTDIR/etc/resolv.conf
	sudo cp $QEMU_USER usr/bin
	DEBIAN_FRONTEND=noninteractive sudo -E chroot $CHROOTDIR apt-get update
	DEBIAN_FRONTEND=noninteractive sudo -E chroot $CHROOTDIR apt-get -y dist-upgrade
	DEBIAN_FRONTEND=noninteractive sudo -E chroot $CHROOTDIR apt-get -y install $PKGLIST
#	sudo -E chroot $CHROOTDIR update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 10
#	sudo -E chroot $CHROOTDIR update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-10 10
	rm `basename $UBUNTU_BASE`
}


if [[ "$#" -eq 1 ]] && [[ "$1" == "clean" ]]; then
	do_clean
        exit 0
fi
if [[ "$#" -eq 1 ]] && [[ "$1" == "distclean" ]]; then
	do_distclean
        exit 0
fi

trap do_unmount_all SIGHUP SIGINT SIGTERM EXIT

do_sysroot
cd $BASE_DIR

echo "All ok!"
