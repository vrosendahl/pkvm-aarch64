#!/bin/sh

usage()
{
    echo "Usage $0 -i instance_nr -s socket -n subnet -d diskimage -k kernelimage -m mem_size"
    echo "There are three new arguments:\n" \
"-i NR           This is a convenience. By giving a number in the range 0..3\n"\
"                 You can modify the default values for disk image, subnet,\n"\
"                 tap device, and socket. 0 is the value for the first\n"\
"                 guest, 1 is the second, 2 is the third, and 3 for the\n"\
"                 fourth. The network will be between, 192.168.10 and\n"\
"                 192.168.13. The default disk image will be\n"\
"                 ubuntuguest.\${network}.qcow2,\n"\
"\n"\
"-s socket        Specifies the socket to be used by crosvm.\n"\
"\n"\
"-n subnet        Specifies the subnet to be used.\n"\
"\n"\
"-d diskimage     Specifies the diskimage to be used.\n"\
"\n"\
"-k kernelimage   Specifies the kernel image to be used.\n"\
"\n"\
"-m mem_size      Specifies the memory size of the guest.\n"\
"\n"\
"-h               Display this message.\n"
    exit 0
}

[ -z "$NR" ] && NR=0

while [ $# -gt 0 ]
do
    case $1 in
	-i)
	    if [ $# -lt 2 ];then
		usage
	    fi
	    NR=$2
	    shift; shift
	    ;;
	-s)
	    if [ $# -lt 2 ];then
		usage
	    fi
	    SOCKET=$2
	    shift; shift
	    ;;
	-n)
	    if [ $# -lt 2 ];then
		usage
	    fi
	    NET=$2
	    NET="${NET%\.}"
	    shift; shift
	    ;;
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
	-h)
	    usage;
	    ;;
	*)
	    usage;
	    ;;
    esac
done

case $NR in
    0)
	[ -z "$IMAGE" ] && IMAGE="./ubuntuguest.qcow2"
	[ -z "$NET" ] && NET="192.168.10"
	[ -z "$SOCKET" ] && SOCKET="/run/crosvm.sock"
	[ -z "$TAP" ] && TAP="crosvm_tap"
	;;
    1)
	[ -z "$IMAGE" ] && IMAGE="./ubuntuguest.192.168.11.qcow2"
	[ -z "$NET" ] && NET="192.168.11"
	[ -z "$SOCKET" ] && SOCKET="/run/crosvm2.sock"
	[ -z "$TAP" ] && TAP="crosvm_tap2"
	;;
    2)
	[ -z "$IMAGE" ] && IMAGE="./ubuntuguest.192.168.12.qcow2"
	[ -z "$NET" ] && NET="192.168.12"
	[ -z "$SOCKET" ] && SOCKET="/run/crosvm3.sock"
	[ -z "$TAP" ] && TAP="crosvm_tap3"
	;;
    3)
	[ -z "$IMAGE" ] && IMAGE="./ubuntuguest.192.168.13.qcow2"
	[ -z "$NET" ] && NET="192.168.13"
	[ -z "$SOCKET" ] && SOCKET="/run/crosvm4.sock"
	[ -z "$TAP" ] && TAP="crosvm_tap4"
	;;
    *)
	usage;
	;;
esac

[ -z "$IMAGE" ] && IMAGE="./ubuntuguest.qcow2"
[ -z "$KERNEL" ] && KERNEL="./Image"
[ -z "$MEMSIZE" ] && MEMSIZE=4096
[ -z "$NET" ] && NET="192.168.10"
[ -z "$SOCKET" ] && SOCKET="/run/crosvm.sock"
[ -z "$TAP" ] && SOCKET="crosvm_tap"

# Check if the tap device exists
if ip link show $TAP > /dev/null 2>&1; then
    # Delete the existing $TAP device
    ip link del $TAP
fi

# Add the $TAP device
ip tuntap add mode tap user $USER vnet_hdr $TAP
ip addr add ${NET}".1/24" dev $TAP
ip link set $TAP up

# Enable IP forwarding
sysctl net.ipv4.ip_forward=1

# Network interface used to connect to the internet.
HOST_DEV=$(ip route get 8.8.8.8 | awk '$1=="8.8.8.8" {printf $5}')
iptables -t nat -A POSTROUTING -o "${HOST_DEV}" -j MASQUERADE
iptables -A FORWARD -i "${HOST_DEV}" -o $TAP -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $TAP -o "${HOST_DEV}" -j ACCEPT

crosvm --log-level=debug run --no-balloon --no-rng --protected-vm-without-firmware --unmap-guest-memory-on-fork --disable-sandbox --mem size=$MEMSIZE  --cpus num-cores=4 --net tap-name=$TAP -s $SOCKET --block $IMAGE -p "root=/dev/vda1 rw" $KERNEL
