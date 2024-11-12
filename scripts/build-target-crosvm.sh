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
export CHROOTDIR=$BASE_DIR/oss/ubuntu
export UBUNTUTEMPLATE=$BASE_DIR/oss/ubuntu-template
export BINFMTENTRY=/proc/sys/fs/binfmt_misc/pkvm-aarch64-build

NJOBS_MAX=8
NJOBS=`nproc`
REPO=`which repo`
BINFMT_ENTRIES=""

if [ -z "${BUILD_QEMU_USER+x}" ]; then
	BUILD_QEMU_USER=1
fi

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

#
# Undo the changes to the binfmt_misc configuration that were made
# in prepare_binfmt(), vide infra.
#
restore_binfmt()
{
	# This removes our custom binfm_misc entry

	if [ -e $BINFMTENTRY ]; then
		echo -1 | sudo tee $BINFMTENTRY > /dev/null
	fi

	# Re-enable the binfmt_misc entries that were disabled.

	for ent in $BINFMT_ENTRIES
	do
		echo 1 | sudo tee $ent > /dev/null
	done
}

do_unmount_all()
{
	[ -n "$LEAVE_MOUNTS" ] && echo "leaving bind mounts in place." && exit 0

	echo "Unmount all binding dirs"
	do_unmount $CHROOTDIR/build/crosvm
	do_unmount $CHROOTDIR/proc
	do_unmount $CHROOTDIR/dev
	restore_binfmt
}

do_clean()
{
	do_unmount_all
	cd $BASE_DIR/crosvm; sudo git clean -xfd || true
	$BASE_DIR/scripts/build-qemu-user.sh clean
}

do_distclean()
{
	do_unmount_all
	cd $BASE_DIR/crosvm; sudo git clean -xfd || true
	sudo rm -rf $CHROOTDIR
	$BASE_DIR/scripts/build-qemu-user.sh distclean
}

#
# N.B.:
# In newwer version of qemu, since
# commit aec338d63b ("linux-user: Adjust brk for load_bias"), which corresponds
# to v8.2 or newer,  the ELF loader in qemu-user is not compatible with the
# initialization of the  GLIBC library in Ubuntu 22.04, especially in
# statically linked PIE binaries. For this reason, we need to use our own
# qemu-user-static and register it with the binfmt_misc system. It is not
# possible to use a wrapper because some programs like dpkg will fork and exec
# and that will use the interpreter that is registered with the binfmt_misc
# system. If our Ubuntu images are upgraded to Ubuntu 24.04 or newer, this is no
# longer necessary because then the GLIBC will be compatible with the new
# QEMU.
#
prepare_binfmt()
{
	sudo modprobe binfmt_misc

	procfiles=$(sudo find /proc/sys/fs/binfmt_misc|grep -v "^/proc/sys/fs/binfmt_misc$"|grep -v "^/proc/sys/fs/binfmt_misc/register$"|grep -v "^/proc/sys/fs/binfmt_misc/status$")

	# If the distro has interpreters registered, check if there are those
	# that are enabled for arm64 ELF binaries

	if echo "$procfiles" | grep -q '[^[:space:]]'; then
		entries=$(sudo fgrep -l 7f454c460201010000000000000000000200b700 $procfiles)
	else
		entries=""
	fi

	# If any of the existing interpreters for ARM64 ELF are enabled,
	# disable then temporarily. We wll save them in BINFMT_ENTRIES and
	# re-enable in restore_binfmt()

	for ent in $entries
	do
		if [ x$(sudo cat $ent|awk 'NR = 1 && /enabled/ {print "FOUND"}') = xFOUND ];then
			BINFMT_ENTRIES="$BINFMT_ENTRIES $ent"
			echo 0 | sudo tee $ent > /dev/null
		fi
	done

	# This is the magic to register our own qemu-user-static with
	# binfmt_misc

	echo ':pkvm-aarch64-build:M::\x7f\x45\x4c\x46\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:replace:OCPF'|sed -e "s|replace|$QEMU_USER|" | sudo tee /proc/sys/fs/binfmt_misc/register > /dev/null
}

do_sysroot()
{
	mkdir -p $CHROOTDIR/build
	if [ -e $CHROOTDIR/bin/bash ]; then
		sudo mount --bind /dev $CHROOTDIR/dev
		sudo mount -t proc none $CHROOTDIR/proc
		return;
	fi

	sudo tar -C $UBUNTUTEMPLATE -cf - ./|tar -C $CHROOTDIR -xf -
	cd $CHROOTDIR
	sudo mount --bind /dev $CHROOTDIR/dev
	sudo mount -t proc none $CHROOTDIR/proc
}

do_crosvm()
{
	#
	# Build always
	#
	mkdir -p $CHROOTDIR/build/crosvm
	sudo mount --bind $BASE_DIR/crosvm $CHROOTDIR/build/crosvm
	cd $CHROOTDIR/build/crosvm

	sudo -E chroot $CHROOTDIR sh -c "cd /build/crosvm; cargo build --verbose -j $NJOBS --features=gdb; install target/debug/crosvm /usr/bin"
}


if [[ "$#" -eq 1 ]] && [[ "$1" == "clean" ]]; then
	do_clean
	exit 0
fi
if [[ "$#" -eq 1 ]] && [[ "$1" == "distclean" ]]; then
	do_distclean
	exit 0
fi

if [ -f $CHROOTDIR/usr/bin/crosvm ];then
	echo "Skipping the building of crosvm, since it already exists!"
	exit 0
fi

trap do_unmount_all SIGHUP SIGINT SIGTERM EXIT

if [ $BUILD_QEMU_USER = 1 ];then
	QEMU_USER=$TOOLDIR/usr/bin/qemu-aarch64-static
	if [ ! -f $QEMU_USER ];then
		echo "Could not find $QEMU_USER. Did you forget to run make qemu-user!!!??!!"
		exit 1
	fi
	prepare_binfmt
fi

do_sysroot
do_crosvm
cd $BASE_DIR

echo "All ok!"
