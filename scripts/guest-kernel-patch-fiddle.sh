#!/bin/bash -e

if [ -z $BASE_DIR ];then
    BASE_DIR=$(pwd)
fi

GUEST_BRANCH="__pkvm_guest"
START_TAG="__pkvm_guest_start"
PATCH_DIR=$BASE_DIR/patches-pkvm-guest-6.5.y
KERNEL_DIR=$BASE_DIR/linux

usage() {
    echo "$0 cmd"
    echo "cmd can be one of:"
    echo ""
    echo "	refresh 	Refreshes the patch series"
    echo "	"
    echo "	patch   	Applies the patches, unless they have already been applied"
    echo "	"
    echo "	forcepatch	Applies the patches, even if a $GUEST_BRANCH branch already exist"
}

__do_patch()
{
    cd $KERNEL_DIR
    git tag -f $START_TAG
    git checkout --detach
    git branch -D $GUEST_BRANCH || true
    git checkout -b $GUEST_BRANCH
    echo "Patching the guest kernel..."
    git am ../patches-pkvm-guest-6.5.y/0*.patch
}

do_patch()
{
    cd $KERNEL_DIR
    curbranch=$(git rev-parse --abbrev-ref HEAD)
    if [ "x$curbranch" = "x$GUEST_BRANCH" ];then
	echo "The branch $GUEST_BRANCH is the current branch in $KERNEL_DIR, not patching anything"
	exit 0
    fi
    force_patch
}

preclean()
{
    cd $KERNEL_DIR
    git reset --hard
    sudo git clean -xfd
    cd $BASE_DIR
    git submodule update linux
}

force_patch()
{
    preclean
    __do_patch
}

clean()
{
    preclean
    cd $KERNEL_DIR
    echo "Trying to remove $START_TAG and $GUEST_BRANCH from $KERNEL_DIR..."
    git tag -d $START_TAG || true
    git branch -D $GUEST_BRANCH || true
}

prune()
{
    clean
    git -c gc.reflogExpireUnreachable=now gc --prune=now
}


refresh()
{
    rm -rf $PATCH_DIR/[0-9]*.patch
    cd $KERNEL_DIR
    echo "Refreshing patches..."
    git format-patch -o $PATCH_DIR $GUEST_BRANCH...$START_TAG
}

#trap do_cleanup SIGHUP SIGINT SIGTERM EXIT

opt=$1

case "$opt" in
    "refresh")		refresh
			exit 0
			;;
    "patch")		do_patch
			exit
			;;
    "force_patch")	force_patch
			exit
			;;
     "clean")		clean
			exit
			;;
     "prune")		prune
			exit
			;;
    *)			usage
			exit
			;;
esac
done
