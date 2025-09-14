# This file contains some common functions that are used by the image generation
# and manipulation scripts

# Detect whether udevadm wait is available (systemd >= 251)
udev_has_wait() {
	v=$(udevadm --version 2>/dev/null || echo 0)
	[ "$v" -ge 251 ]
}

udev_blockdev_sync() {
	newdev=$1
	if udev_has_wait; then
		# Precise: wait for actual appearance
		udevadm wait --timeout=30 --settle $newdev || true
	else
		# Portable fallback: loop settle + check until /dev/device appears
		deadline=$((SECONDS + 30))
		while [ ! -e "$newdev" ] && [ $SECONDS -lt $deadline ]; do
			udevadm settle --timeout=5 || true
			# Small pause to avoid busy-waiting
			sleep 1
		done
	fi
	if [ ! -e "$newdev" ]; then
		echo "ERROR: timeout waiting for $newdev"
		return 1
	fi
}

wait4_dev_connect()
{
	device=$1
	deadline=$((SECONDS + 30))
	while [ ! $(blockdev --getsz $device) -gt 0 ] && [ $SECONDS -lt $deadline ]; do
		sleep 0.1
	done
}

wait4_dev_disconnect()
{
	device=$1
	deadline=$((SECONDS + 30))
	while [ $(blockdev --getsz $device) -gt 0 ] && [ $SECONDS -lt $deadline ]; do
		sleep 0.1
	done
}

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

#
# Undo the changes to the binfmt_misc configuration that were made
# in prepare_binfmt(), vide infra.
#
restore_binfmt()
{
	# This removes our custom binfm_misc entry

	if [ -e $BINFMTENTRY ]; then
		echo -1 | sudo tee $BINFMTENTRY > /dev/null
	fi

	# Re-enable the binfmt_misc entries that were disabled.

	for ent in $BINFMT_ENTRIES
	do
		echo 1 | sudo tee $ent > /dev/null
	done
}

#
# N.B.:
# In newwer version of qemu, since
# commit aec338d63b ("linux-user: Adjust brk for load_bias"), which corresponds
# to v8.2 or newer,  the ELF loader in qemu-user is not compatible with the
# initialization of the  GLIBC library in Ubuntu 22.04, especially in
# statically linked PIE binaries. For this reason, we need to use our own
# qemu-user-static and register it with the binfmt_misc system. It is not
# possible to use a wrapper because some programs like dpkg will fork and exec
# and that will use the interpreter that is registered with the binfmt_misc
# system. If our Ubuntu images are upgraded to Ubuntu 24.04 or newer, this is no
# longer necessary because then the GLIBC will be compatible with the new
# QEMU.
#
prepare_binfmt()
{
	sudo modprobe binfmt_misc

	procfiles=$(sudo find /proc/sys/fs/binfmt_misc|grep -v "^/proc/sys/fs/binfmt_misc$"|grep -v "^/proc/sys/fs/binfmt_misc/register$"|grep -v "^/proc/sys/fs/binfmt_misc/status$")

	# If the distro has interpreters registered, check if there are those
	# that are enabled for arm64 ELF binaries

	if echo "$procfiles" | grep -q '[^[:space:]]'; then
		entries=$(sudo fgrep -l 7f454c460201010000000000000000000200b700 $procfiles)
	else
		entries=""
	fi

	# If any of the existing interpreters for ARM64 ELF are enabled,
	# disable then temporarily. We wll save them in BINFMT_ENTRIES and
	# re-enable in restore_binfmt()

	for ent in $entries
	do
		if [ x$(sudo cat $ent|awk 'NR = 1 && /enabled/ {print "FOUND"}') = xFOUND ];then
			BINFMT_ENTRIES="$BINFMT_ENTRIES $ent"
			echo 0 | sudo tee $ent > /dev/null
		fi
	done

	# This is the magic to register our own qemu-user-static with
	# binfmt_misc

	echo ':pkvm-aarch64-build:M::\x7f\x45\x4c\x46\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:replace:OCPF'|sed -e "s|replace|$QEMU_USER|" | sudo tee /proc/sys/fs/binfmt_misc/register > /dev/null
}
