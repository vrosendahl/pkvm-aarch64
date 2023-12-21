Our custom fork of pKVM based on the Android tree

What currently works, execute the following make targets in order:

* `make tools`

* `make host-kernel`

* `make target-crosvm`

* `make hostimage`

* `make guest-kernel`

* `make guestimage`

* `make DEBUGGER=1 run`. This will boot the pkvm host image with the host kernel in qemu with the gdb server enabled.

* `make gdb`. This will start the gdb and connect it to the qemu gdb server. This should be executed in another terminal window.

The `make host-kernel` and `make target-crosvm` targets can be executed in any order, there is no dependency between them. Also `make guestkernel` only needs depend on `make tools`, while `make guestimage` depends on `make guestkernel`

The default user is `ubuntu`. No password required. The hostimage has a script, `run-crosvm.sh`, which can be used to run the guestimage with crosvm, also doing the necessary configuration of networking.

There is also a `make all` target that will bild everything in the right order.

What is missing:

* The builds are not necessarily 100% reliable.

* Building has only been tested on Ubuntu 22.04.

* The build dependencies are not documented. If an unknown build dependency is not installed, then the gdb will segfault.

* There are no target for building anything for the Nvidia hardware target.
