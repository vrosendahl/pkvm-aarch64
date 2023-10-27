#!/bin/bash -e

export CROSVMDIR=$BASE_DIR/crosvm

cd $CROSVMDIR
git submodule update --init

#
# If you don't have the tools, see './tools/install-deps'
#
cargo build --features=gdb
cp target/debug/crosvm $BASE_DIR/images/guest
