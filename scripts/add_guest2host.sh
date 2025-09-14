#!/bin/bash -e

. "$BASE_DIR/scripts/img_util.sh"

export PATH=$PATH:/usr/sbin
cd "$(dirname "$0")"
modprobe nbd max_part=8

QEMU_USER=`which qemu-aarch64-static`
CPUS=`nproc`

USERNAME=$1
CURDIR=$PWD
UBUNTU_BASE=$UBUNTU_STABLE
PKGLIST=`cat package.list.22 |grep -v "\-dev"`
OUTDIR=$BASE_DIR/images/host
HOSTIMG=$OUTDIR/ubuntuhost.qcow2
INPUTDIR=$BASE_DIR/images/guest
GUESTIMG=$INPUTDIR/ubuntuguest.qcow2
GUESTIMG2=$INPUTDIR/ubuntuguest.192.168.11.qcow2
GUESTKERNEL=$INPUTDIR/Image

NEW_IP="192.168.11."
NEW_HOSTNAME="pkvm-guest-2"

if [ $# -ge 2 ];then
    NEW_IP=$2
fi

if [ $# -ge 3 ];then
    NEW_HOSTNAME=$3
fi

do_cleanup()
{
	cd $CURDIR
	do_unmount tmp/proc || true
	do_unmount tmp/dev || true
	do_unmount tmp || true
	blockdev --flushbufs /dev/nbd0 || true
	qemu-nbd --disconnect /dev/nbd0 || true
	sync || true
	wait4_dev_disconnect /dev/nbd0 || true
	rmmod nbd
	rm -rf tmp
}

do_cleanup_rm()
{
	do_cleanup
}

usage() {
	echo "$0 -o <output directory> -s <image size> | -u"
}

trap do_cleanup_rm SIGHUP SIGINT SIGTERM

while getopts "h?u:o:s:" opt; do
	case "$opt" in
	h|\?)	usage
		exit 0
		;;
	u)	UBUNTU_BASE=$UBUNTU_UNSTABLE
		;;
	o)	OUTDIR=$OPTARG
		;;
  esac
done

echo "Modifying host image.."

if [ ! -f $HOSTIMG ];then
	if [ -e $HOSTIMG ];then
		echo "${HOSTIMG} is not a regular file"
	else
		echo "{$HOSTIMG} Does not exist!!?? You need to build the hostimage target first!"
	fi
	do_cleanup
	exit 0
fi

if [ ! -f $GUESTIMG ];then
	if [ -e $GUESTIMG ];then
		echo "${GUESTIMG} is not a regular file"
	else
		echo "{$GUESTIMG} Does not exist!!?? You need to build the hostimage target first!"
	fi
	do_cleanup
	exit 0
fi

if [ ! -f $GUESTKERNEL ];then
	if [ -e $GUESTKERNEL ];then
		echo "${GUESTKERNEL} is not a regular file"
	else
		echo "{$GUESTKERNEL} Does not exist!!?? You need to build the hostimage target first!"
	fi
	do_cleanup
	exit 0
fi


udev_blockdev_sync /dev/nbd0 || true
qemu-nbd --connect=/dev/nbd0 $HOSTIMG

echo "Mounting host image.."
mkdir -p tmp

# Wait for /dev/nbd0p1 to appear and poke the kernel if it has not, then wait
# again
udev_blockdev_sync /dev/nbd0p1 || true
if [ ! -e /dev/nbd0p1 ]; then
	partx -u /dev/nbd0 || true
	udev_blockdev_sync /dev/nbd0p1
fi

mount /dev/nbd0p1 tmp

echo "Adding guest image to host image.."
mount --bind /dev tmp/dev
mount -t proc none tmp/proc

rm -rf tmp/home/ubuntu/guest
mkdir tmp/home/ubuntu/guest
cp $GUESTIMG tmp/home/ubuntu/guest
if [ -f $GUESTIMG2 ];then
	cp $GUESTIMG2 tmp/home/ubuntu/guest
fi
cp $GUESTKERNEL tmp/home/ubuntu/guest

sudo -E chroot tmp chown -R ubuntu:ubuntu /home/ubuntu/guest

do_cleanup

echo "Done modifying ${HOSTIMG}"
sync
