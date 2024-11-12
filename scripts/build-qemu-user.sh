#!/bin/bash

TOOLDIR=$BASE_DIR/buildtools

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

NJOBS_MAX=8
NJOBS=`nproc`

if [ -z "${BUILD_QEMU_USER+x}" ]; then
	BUILD_QEMU_USER=1
fi

do_clean()
{
	cd $BASE_DIR/qemu; git clean -xfd || true
}

do_distclean()
{
	do_clean
	sudo rm -rf $TOOLDIR/usr/bin/qemu-aarch64-static
}

do_build_qemu_user()
{
	if [ -e $TOOLDIR/usr/bin/qemu-aarch64-static ];then
		return
	fi
	OLDPATH=$PATH
	export PATH=:/bin:/usr/bin:/sbin:/usr/sbin
	unset LD_LIBRARY_PATH
	sudo rm -rf $BASE_DIR/qemu/build-static
	mkdir -p $BASE_DIR/qemu/build-static
	cd $BASE_DIR/qemu/build-static
	../configure --prefix=$TOOLDIR/usr --target-list=aarch64-linux-user --static
	make -j$NJOBS
	# We do not run make install because it installs a lot of gunk not
	# needed or wanted
	mkdir -p $TOOLDIR/usr/bin
	install -m 755 qemu-aarch64 $TOOLDIR/usr/bin/qemu-aarch64-static
	export PATH=$OLDPATH
}

if [[ "$#" -eq 1 ]] && [[ "$1" == "clean" ]]; then
	do_clean
	exit 0
fi
if [[ "$#" -eq 1 ]] && [[ "$1" == "distclean" ]]; then
	do_distclean
	exit 0
fi
if [[ "$#" -eq 1 ]] && [[ "$1" == "build" ]]; then
	if [ ! $BUILD_QEMU_USER = 1 ];then
		echo "Skipping build of qemu-user because BUILD_QEMU_USER="$BUILD_QEMU_USER
		exit 0
	fi
	echo "Building qemu-user!"
	do_build_qemu_user
	cd $BASE_DIR
	echo "All ok!"
	exit 0
fi

