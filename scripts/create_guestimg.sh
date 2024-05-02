#!/bin/bash -e

export PATH=$PATH:/usr/sbin
cd "$(dirname "$0")"
modprobe nbd max_part=8

QEMU_USER=`which qemu-aarch64-static`
CPUS=`nproc`

USERNAME=$1
CURDIR=$PWD
PKGLIST=`cat package.list.22 |grep -v "\-dev"`
EXTRA_PKGLIST=`cat extra_package.list`
OUTFILE=ubuntuguest.qcow2
IMAGESDIR=$BASE_DIR/images
OUTDIR=$IMAGESDIR/guest
UBUNTUTEMPLATE=$BASE_DIR/oss/ubuntu-template
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
	rm -rf tmp
}

usage() {
	echo "$0 -o <output directory> -s <image size> | -u"
}

if [ ! -f $UBUNTUTEMPLATE/bin/bash ];then
	echo "Could not find an Ubuntu system at ${UBUNTUTEMPLATE}!"
	echo "Did you remember to run make ubuntu-template?"
	exit 1
fi

trap do_cleanup SIGHUP SIGINT SIGTERM EXIT

while getopts "h?o:s:" opt; do
	case "$opt" in
	h|\?)	usage
		exit 0
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
sync

echo "Copying ubuntu from template.."
mkdir -p tmp
mount /dev/nbd0p1 tmp
sudo tar -C $UBUNTUTEMPLATE -cf - ./|tar -C tmp -xf -
cp $QEMU_USER tmp/usr/bin

echo "Installing packages.."
mount --bind /dev tmp/dev
mount -t proc none tmp/proc
echo "nameserver 8.8.8.8" > tmp/etc/resolv.conf
export DEBIAN_FRONTEND=noninteractive
sudo -E chroot tmp apt-get update
sudo -E chroot tmp apt-get -y install $EXTRA_PKGLIST
sudo -E chroot tmp apt-get -y purge network-manager network-manager-gnome network-manager-pptp
sudo -E chroot tmp update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo -E chroot tmp adduser --disabled-password --gecos "" ubuntu
sudo -E chroot tmp passwd -d ubuntu
sudo -E chroot tmp usermod -aG sudo ubuntu
rm -f tmp/etc/ssh/ssh_host_*
sudo -E chroot tmp dpkg-reconfigure openssh-server

cat >>  tmp/etc/network/interfaces << EOF
auto lo
iface lo inet loopback

auto enp0s2
iface enp0s2 inet static
address 192.168.10.3
gateway 192.168.10.1
EOF

cat >>  tmp/etc/hosts << EOF
127.0.0.1	localhost
127.0.1.1	pkvm-guest

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters

EOF

echo pkvm-guest > tmp/etc/hostname

sed 's/#DNS=/DNS=8.8.8.8/' -i tmp/etc/systemd/resolved.conf
sed 's/#PermitEmptyPasswords no/PermitEmptyPasswords yes/' -i tmp/etc/ssh/sshd_config

# Because the guest will run so slowly with emulation and nested
# virtualization, we will increase this timeout, so that systemd will wait
# longer for devices. This is especially important for ttyS0, which is used
# as a console and its timeout would cause getty to fail.
echo 'DefaultTimeoutStartSec=600s' >> tmp/etc/systemd/system.conf

# For the same reason, we need to increase the timeout of "udevadm settle" to
# 300 seconds
mkdir tmp/etc/systemd/system/ifupdown-pre.service.d
cat >>  tmp/etc/systemd/system/ifupdown-pre.service.d/override.conf << EOF
[Service]
ExecStart=
# This ExecStart line is copied from /lib/systemd/system/ifupdown-pre.service,
# only added the --timeout 300
ExecStart=/bin/sh -c 'if [ "$CONFIGURE_INTERFACES" != "no" ] && [ -n "$(ifquery --read-environment --list --exclude=lo)" ] && [ -x /bin/udevadm ]; then udevadm settle --timeout 300; fi'
TimeoutStartSec=400
EOF

pwd_dir=$(pwd)
INST_MOD_PATH="$(pwd)/tmp"
echo "Installing guest kernel modules.."
make  -C$GUEST_KERNEL_DIR CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=$INST_MOD_PATH modules_install
echo Done

if [ ! -d $OUTDIR ]; then
	echo "Creating output dir.."
	mkdir -p $OUTDIR
	chown -R $USERNAME.$USERNAME $IMAGESDIR
fi

cp -f $GUEST_KERNEL_DIR/arch/arm64/boot/Image $OUTDIR
chown $USERNAME.$USERNAME $OUTDIR/Image
mv $OUTFILE $OUTDIR
echo "Output saved at $OUTDIR"
sync
