#!/bin/bash -e

export PATH=$PATH:/usr/sbin
cd "$(dirname "$0")"
modprobe nbd max_part=8

QEMU_USER=`which qemu-aarch64-static`
CPUS=`nproc`

USERNAME=$1
CURDIR=$PWD
UBUNTU_BASE=$UBUNTU_STABLE
PKGLIST=`cat package.list.22 |grep -v "\-dev"`
EXTRA_PKGLIST=`cat extra_package.list`
FIRSTFILE=ubuntuguest.qcow2
OUTDIR=$BASE_DIR/images/guest
SIZE=10G

NEW_IP="192.168.11."
NEW_HOSTNAME="pkvm-guest-2"

if [ $# -ge 2 ];then
    NEW_IP=$2
fi

if [ $# -ge 3 ];then
    NEW_HOSTNAME=$3
fi

OUTFILE=ubuntuguest.${NEW_IP}qcow2

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

do_rmmod()
{
	if grep -w nbd /proc/modules &> /dev/null; then
		for i in $(seq 100)
		do
			set +e
			rmmod nbd
			local status=$?
			set -e
			if [ $status -eq 0 ]; then
				if [ $i -eq 1 ]; then
					echo "Succeed in unloading kernel module on first attempt"
				else
					echo "Succeded in unloading kernel module on retry $i"
				fi
				return 0
			fi
			echo "Failed to unload kernel module nbd, retry $i out of max 100"
			sleep 0.1
		done
	else
		echo "Module nbd is not loaded!"
	fi
}

do_cleanup()
{
	cd $CURDIR
	do_unmount tmp/proc || true
	do_unmount tmp/dev || true
	do_unmount tmp || true
	qemu-nbd --disconnect /dev/nbd0 || true
	sync || true

	do_rmmod
	rm -rf tmp
}

do_cleanup_rm()
{
	do_cleanup
	rm -rf $OUTFILE
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
	s)	SIZE=$OPTARG
		;;
  esac
done

echo "Duplicating image.."

if [ ! -f $OUTDIR/$FIRSTFILE ];then
	if [ -e $OUTDIR/$FIRSTFILE ];then
		echo "$OUTDIR/$FIRSTFILE is not a regular file"
	else
		echo "$OUTDIR/$FIRSTFILE Does not exist!!?? You need to build the guestimage target first!"
	fi
	do_cleanup
	exit 0
fi

cp $OUTDIR/$FIRSTFILE $OUTFILE
sync
qemu-nbd --connect=/dev/nbd0 $OUTFILE
sync

echo "Mounting new image.."
mkdir -p tmp
mount /dev/nbd0p1 tmp

echo "Modifying network configuration.."
mount --bind /dev tmp/dev
mount -t proc none tmp/proc

export DEBIAN_FRONTEND=noninteractive
rm -f tmp/etc/ssh/ssh_host_*
sudo -E chroot tmp dpkg-reconfigure openssh-server

# We must replace the subnet 192.168.10.x in the original file with
# 192.168.11.x because the two guests can't use the same subnet
sed -i "s/192.168.10./${NEW_IP}/g" tmp/etc/network/interfaces

sed -i "s/pkvm-guest/${NEW_HOSTNAME}/g" tmp/etc/hosts
echo $NEW_HOSTNAME > tmp/etc/hostname

echo Done

do_cleanup

mv $OUTFILE $OUTDIR

if [ -f $OUTDIR/$OUTFILE ]; then
	chown $USERNAME.$USERNAME $OUTDIR/$OUTFILE
fi

echo "Output saved at $OUTDIR"
sync
