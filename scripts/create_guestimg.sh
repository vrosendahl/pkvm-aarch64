#!/bin/bash -e

export PATH=$PATH:/usr/sbin
cd "$(dirname "$0")"
modprobe nbd max_part=8

UBUNTU_STABLE=http://cdimage.debian.org/mirror/cdimage.ubuntu.com/ubuntu-base/releases/22.04/release/ubuntu-base-22.04-base-arm64.tar.gz
UBUNTU_UNSTABLE=https://cdimage.debian.org/mirror/cdimage.ubuntu.com/ubuntu-base/releases/22.10/release/ubuntu-base-22.10-base-arm64.tar.gz
QEMU_USER=`which qemu-aarch64-static`
CPUS=`nproc`

USERNAME=$1
CURDIR=$PWD
UBUNTU_BASE=$UBUNTU_STABLE
PKGLIST=`cat package.list.22 |grep -v "\-dev"`
EXTRA_PKGLIST=`cat extra_package.list`
OUTFILE=ubuntuguest.qcow2
OUTDIR=$BASE_DIR/images/guest
SIZE=10G

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

do_cleanup()
{
	cd $CURDIR
	do_unmount tmp/proc || true
	do_unmount tmp/dev || true
	do_unmount tmp || true
	qemu-nbd --disconnect /dev/nbd0 || true
	sync || true
	if [ -f $OUTDIR/$OUTFILE ]; then
		chown $USERNAME.$USERNAME $OUTDIR/$OUTFILE
	fi

	rmmod nbd
	rm -rf tmp linux `basename $UBUNTU_BASE`
}

usage() {
	echo "$0 -o <output directory> -s <image size> | -u"
}

trap do_cleanup SIGHUP SIGINT SIGTERM EXIT

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

echo "Creating image.."
qemu-img create -f qcow2 $OUTFILE $SIZE
qemu-nbd --connect=/dev/nbd0 $OUTFILE
parted -a optimal /dev/nbd0 mklabel gpt mkpart primary ext4 0% 100%
sync

echo "Formatting & downloading.."
mkfs.ext4 /dev/nbd0p1
wget -c $UBUNTU_BASE
sync

echo "Extracting ubuntu.."
mkdir -p tmp
mount /dev/nbd0p1 tmp
tar xf `basename $UBUNTU_BASE` -C tmp
cp $QEMU_USER tmp/usr/bin

echo "Installing packages.."
mount --bind /dev tmp/dev
mount -t proc none tmp/proc
echo "nameserver 8.8.8.8" > tmp/etc/resolv.conf
export DEBIAN_FRONTEND=noninteractive
sudo -E chroot tmp apt-get update
sudo -E chroot tmp apt-get -y install $PKGLIST
sudo -E chroot tmp apt-get -y install $EXTRA_PKGLIST
sudo -E chroot tmp apt-get -y purge network-manager network-manager-gnome network-manager-pptp
sudo -E chroot tmp update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo -E chroot tmp adduser --disabled-password --gecos "" ubuntu
sudo -E chroot tmp passwd -d ubuntu
sudo -E chroot tmp usermod -aG sudo ubuntu

# The first resolv.conf may have been deleted by the operations above let's make
# sure that it's there and not some symbolic link
rm -f tmp/etc/resolv.conf
echo "nameserver 8.8.8.8" > tmp/etc/resolv.conf

cat >>  tmp/etc/network/interfaces << EOF
auto lo
iface lo inet loopback

auto enp0s2
iface enp0s2 inet static
address 192.168.10.3
gateway 192.168.10.1
EOF

sed 's/#DNS=/DNS=8.8.8.8/' -i tmp/etc/systemd/resolved.conf
sed 's/#PermitEmptyPasswords no/PermitEmptyPasswords yes/' -i tmp/etc/ssh/sshd_config

pwd_dir=$(pwd)
INST_MOD_PATH="$(pwd)/tmp"
echo "Installing guest kernel modules.."
make  -C$GUEST_KERNEL_DIR CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=$INST_MOD_PATH modules_install
echo Done

if [ ! -d $OUTDIR ]; then
	echo "Creating output dir.."
	mkdir -p $OUTDIR
	chown $USERNAME.$USERNAME $OUTDIR
fi

cp -f $GUEST_KERNEL_DIR/arch/arm64/boot/Image $OUTDIR
chown $USERNAME.$USERNAME $OUTDIR/Image
mv $OUTFILE $OUTDIR
echo "Output saved at $OUTDIR"
sync
