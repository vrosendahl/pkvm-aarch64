#!/bin/sh

usage()
{
    echo "Usage $0 -d diskimage -k kernelimage -m mem_size"
    exit 0
}

[ -z "$IMAGE" ] && IMAGE="./ubuntuguest.qcow2"
[ -z "$KERNEL" ] && KERNEL="./Image"
[ -z "$MEMSIZE" ] && MEMSIZE=4096

while [ $# -gt 0 ]
do
    case $1 in
	-d)
	    if [ $# -lt 2 ];then
		usage
	    fi
	    IMAGE=$2
	    shift; shift
	    ;;
	-k)
	    if [ $# -lt 2 ];then
		usage
	    fi
	    KERNEL=$2
	    shift; shift
	    ;;
	-m)
	    if [ $# -lt 2 ];then
		usage
	    fi
	    MEMSIZE=$2
	    shift; shift
	    ;;
	*)
	    usage;
	    ;;
    esac
done

# Check if crosvm_tap exists
if ip link show crosvm_tap > /dev/null 2>&1; then
    # Delete the existing crosvm_tap device
    ip link del crosvm_tap
fi

# Add the crosvm_tap device
ip tuntap add mode tap user $USER vnet_hdr crosvm_tap
ip addr add 192.168.10.1/24 dev crosvm_tap
ip link set crosvm_tap up

# Enable IP forwarding
sysctl net.ipv4.ip_forward=1

# Network interface used to connect to the internet.
HOST_DEV=$(ip route get 8.8.8.8 | awk '$1=="8.8.8.8" {printf $5}')
iptables -t nat -A POSTROUTING -o "${HOST_DEV}" -j MASQUERADE
iptables -A FORWARD -i "${HOST_DEV}" -o crosvm_tap -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i crosvm_tap -o "${HOST_DEV}" -j ACCEPT

crosvm --log-level=debug run --no-balloon --no-rng --protected-vm-without-firmware --unmap-guest-memory-on-fork --disable-sandbox --mem size=$MEMSIZE  --cpus num-cores=4 --net tap-name=crosvm_tap -s /run/crosvm.sock --block $IMAGE -p "root=/dev/vda1 rw" $KERNEL
