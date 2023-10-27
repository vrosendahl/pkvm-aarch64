#!/bin/sh

export PATH=$PWD:$PATH
export IMAGE=ubuntuguest.qcow2
export KERNEL=bzImage
export RAM=4096
export CORECOUNT=4

[ ! -d /var/empty ] && mkdir /var/empty

crosvm run $KERNEL --cpus num-cores=$CORECOUNT --mem size=$RAM \
	--block path=$IMAGE,root --net tap-name=crosvm_tap \
	--serial type=stdout,hardware=virtio-console,console,stdin \
	--core-scheduling false
