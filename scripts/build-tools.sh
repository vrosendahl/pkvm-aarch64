#!/bin/bash -x

#
# Tested on ubuntu 20.n with no other cross tools installed other than
# 'gcc-aarch64-linux-gnu g++-aarch64-linux-gnu'. These are used for
# bootstrapping a bit faster
#

TOOLDIR=$BASE_DIR/buildtools

unset CROSS_COMPILE
unset CC
unset CXX
unset LD
unset AR
unset AS
unset OBJCOPY
unset RANLIB
unset CFLAGS
unset LDFLAGS
unset ASFLAGS
unset INCLUDES
unset WARNINGS
unset DEFINES

export PATH=$TOOLDIR/bin:$TOOLDIR/usr/bin:/bin:/usr/bin
export PKG_CONFIG_PATH=$TOOLDIR/usr/local/lib/x86_64-linux-gnu/pkgconfig
export LD_LIBRARY_PATH=$TOOLDIR/lib:$TOOLDIR/usr/lib
export LD_RUN_PATH=$TOOLDIR/lib:$TOOLDIR/usr/lib

MESA_VER=mesa-22.3.2
TTRIPLET="aarch64-linux-gnu"
HTRIPLET="x86_64-unknown-linux-gnu"
NJOBS=`nproc`

[ $PLATFORM == "virt" ] && VIRTOOLS=1

clean()
{
	cd $BASE_DIR/oss/binutils-gdb; git clean -xfd || true
	cd $BASE_DIR/oss/gcc; git clean -xfd || true
	cd $BASE_DIR/oss/glibc; git clean -xfd || true
	cd $BASE_DIR/oss/qemu; git clean -xfd || true
#	cd $BASE_DIR/linux-host; git clean -xfd || true
#	cd $BASE_DIR/linux-guest; git clean -xfd || true
	cd $BASE_DIR/oss; rm -rf $MESA_VER* || true
}

binutils-gdb()
{
	mkdir -p $BASE_DIR/oss/binutils-gdb/build
	cd $BASE_DIR/oss/binutils-gdb/build
	# Disable gprofng since it doesn't build correctly for aarch64. It is
	# probably not difficult to fix but not spending time on it now because
	# gprofng is an obscure tool in this project
	 ../configure --prefix=/usr --target=$TTRIPLET --host=$HTRIPLET --build=$HTRIPLET \
		      --disable-nls --disable-multilib --disable-gprofng --with-sysroot=$TOOLDIR
	make -j$NJOBS
	make DESTDIR=$TOOLDIR install
}

kernel_headers_host()
{
	cd $BASE_DIR/linux-host
	make CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 INSTALL_HDR_PATH=$TOOLDIR/usr headers_install
}

kernel_host()
{
	cd $BASE_DIR/linux-host
	make CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 -j$NJOBS defconfig Image modules
}

kernel_guest()
{
	cd $BASE_DIR/linux-guest
	make CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 -j$NJOBS defconfig Image modules
}

glibc()
{
	mkdir -p $BASE_DIR/oss/glibc/build
	cd $BASE_DIR/oss/glibc/build
	../configure --prefix=/usr --host=$TTRIPLET --build=$HTRIPLET -without-cvs --disable-nls \
		     --disable-sanity-checks --enable-obsolete-rpc --disable-profile --disable-debug \
		     --without-selinux --without-tls --with-arch=armv8-a --enable-threads=posix \
		     --with-headers=$TOOLDIR/usr/include --disable-werror
	make -j$NJOBS
	make DESTDIR=$TOOLDIR install
	make DESTDIR=$TOOLDIR install-headers
}

gcc()
{
	mkdir -p $BASE_DIR/oss/gcc/build
	cd $BASE_DIR/oss/gcc/build
	../configure --prefix=/usr --target=$TTRIPLET --host=$HTRIPLET --build=$HTRIPLET \
		     --disable-nls --enable-threads --disable-plugins --disable-multilib \
		     --disable-bootstrap --disable-libsanitizer --enable-languages=c,c++ \
		     --with-sysroot=/
	make -j$NJOBS
	make DESTDIR=$TOOLDIR install
}

mesa()
{
	cd $BASE_DIR/oss
	wget -c https://archive.mesa3d.org//$MESA_VER.tar.xz
	tar xf $MESA_VER.tar.xz
	cd $MESA_VER
	meson build --prefix $TOOLDIR/usr/local -Dopengl=true -Dosmesa=true -Dgallium-drivers=auto,swrast -Dshared-glapi=enabled
	cd build
	meson install
}

qemu()
{
	mkdir -p $BASE_DIR/oss/qemu/build
	cd $BASE_DIR/oss/qemu/build
	#
	# Qemu build bug: it never passes GBM_LIBS and GBM_CFLAGS to make regardless of
	# the fact that pkg-config finds valid arguments ok. So, pass as extra.
	#
	../configure --prefix=$TOOLDIR/usr --extra-cflags="-I$TOOLDIR/usr/local/include" --extra-ldflags="-L$TOOLDIR/usr/local/lib/x86_64-linux-gnu -lgbm" --target-list=aarch64-softmmu --enable-modules --enable-spice --enable-opengl --enable-virglrenderer --enable-slirp
	make -j$NJOBS
	make install
}

if [ "x$1" = "xclean" ]; then
	clean
	exit 0
fi

binutils-gdb
kernel_headers_host
glibc
gcc
if [ -n "$VIRTOOLS" ]; then
mesa
qemu
#kernel_host
#kernel_guest
fi
