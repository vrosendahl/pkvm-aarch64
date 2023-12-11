Our custom fork of pKVM based on the Android tree

What currently works, execute the following make targets in order:

* `make tools`

* `make host-kernel`

* `make target-qemu`

* `make hostimage`

* `make DEBUGGER=1 run`. This will boot the pkvm host kernel in qemu with the gdb server enabled.

* `make gdb`. This will start the gdb and connect it to the qemu gdb server.

The `make host-kernel` and `make target-qemu` targets can be executed in the other order, there it no dependency between them.

What is missing:

* There is no target for cross building crosvm.

* The guestimage target does not work properly.

* There guest-kernel target doest not work properly.
