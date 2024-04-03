#!/bin/bash -e

export PATH=../buildtools/usr/bin:../buildtools/usr/sbin:$PATH:/usr/sbin
cd "$(dirname "$0")"
modprobe nbd max_part=8

UBUNTU_STABLE=http://cdimage.debian.org/mirror/cdimage.ubuntu.com/ubuntu-base/releases/22.04/release/ubuntu-base-22.04-base-arm64.tar.gz
UBUNTU_UNSTABLE=https://cdimage.debian.org/mirror/cdimage.ubuntu.com/ubuntu-base/releases/22.10/release/ubuntu-base-22.10-base-arm64.tar.gz
QEMU_USER=$BASE_DIR/oss/ubuntu/usr/bin/qemu-aarch64-static
QEMU_HOST=$BASE_DIR/oss/ubuntu/usr/bin/qemu-system-aarch64
QEMU_VIRTIO_ROM=$BASE_DIR/oss/ubuntu/usr/share/qemu/efi-virtio.rom
CROSVM=$BASE_DIR/oss/ubuntu/usr/bin/crosvm
CPUS=`nproc`

USERNAME=$1
CURDIR=$PWD
UBUNTU_BASE=$UBUNTU_STABLE
PKGLIST=`cat package.list.22`
EXTRA_PKGLIST=`cat extra_package.list`
OUTFILE=ubuntuhost.qcow2
OUTDIR=$BASE_DIR/images/host
SIZE=20G

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
	rm -rf tmp `basename $UBUNTU_BASE`
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

if [ ! -f $QEMU_USER ] || [ ! -f $QEMU_HOST ] || [ ! -f $QEMU_VIRTIO_ROM ];then
	if [ ! -f $CROSVM ];then
		echo "ERROR: can't find a VMM"
		echo "ERROR: please run 'make target-qemu' or 'make target-crosvm"
		exit 1
	fi
fi

if [ -f $QEMU_USER ]; then
	cp $QEMU_USER tmp/usr/bin
fi

if [ -f $QEMU_HOST ]; then
	cp $QEMU_HOST tmp/usr/bin
fi

if [ -f $QEMU_VIRTIO_ROM ]; then
	mkdir -p tmp/usr/share/qemu
	install --mode=0644 $QEMU_VIRTIO_ROM tmp/usr/share/qemu
fi

if [ -f $CROSVM ]; then
	cp $CROSVM tmp/usr/bin
fi

echo "Installing packages.."
mount --bind /dev tmp/dev
mount -t proc none tmp/proc
echo "nameserver 8.8.8.8" > tmp/etc/resolv.conf
export DEBIAN_FRONTEND=noninteractive
sudo -E chroot tmp apt-get update
sudo -E chroot tmp apt-get -y dist-upgrade
sudo -E chroot tmp apt-get -y install $PKGLIST
sudo -E chroot tmp apt-get -y install $EXTRA_PKGLIST
sudo -E chroot tmp update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo -E chroot tmp adduser --disabled-password --gecos "" ubuntu
sudo -E chroot tmp passwd -d ubuntu
sudo -E chroot tmp usermod -aG sudo ubuntu

cat >>  tmp/etc/network/interfaces << EOF
auto lo
iface lo inet loopback

auto enp0s1
iface enp0s1 inet static
address 192.168.7.2
gateway 192.168.7.1
EOF

cat >>  tmp/etc/hosts << EOF
127.0.0.1	localhost
127.0.1.1	pkvm-host

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters

EOF

echo pkvm-host > tmp/etc/hostname

sed 's/#DNS=/DNS=8.8.8.8/' -i tmp/etc/systemd/resolved.conf
sed 's/#PermitEmptyPasswords no/PermitEmptyPasswords yes/' -i tmp/etc/ssh/sshd_config

echo "Installing modules.."
make -C$CURDIR/../linux-host CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=$CURDIR/tmp modules_install

install --mode=0755 $BASE_DIR/scripts/run-crosvm.sh tmp/usr/bin
sudo -E chroot tmp chown root:root /usr/bin/run-crosvm.sh
install --mode=0755 $BASE_DIR/scripts/run-crosvm.sh tmp/home/ubuntu
sudo -E chroot tmp chown ubuntu:ubuntu /home/ubuntu/run-crosvm.sh

if [ ! -d $OUTDIR ]; then
	echo "Creating output dir.."
	mkdir -p $OUTDIR
fi

mv $OUTFILE $OUTDIR
echo "Output saved at $OUTDIR/$OUTFILE"
sync
