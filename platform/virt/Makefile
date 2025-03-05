ROGNAME := hyp

PROG := $(OBJDIR)/$(PLATFORM)/$(PROGNAME)
LIBNAME := lib$(PLATFORM).a
QEMU := qemu-system-aarch64
QEMU_DTFILE := qemu_devtree

KERNEL := $(KERNEL_DIR)/arch/arm64/boot/Image
HOST_IMAGE_DIR := $(BASE_DIR)/images/host
IMAGE :=  $(HOST_IMAGE_DIR)/ubuntuhost.qcow2
PVMFW_LOADER := $(HOST_IMAGE_DIR)/ic_loader.bin
PVMFW_ADDRESS := 0x40001000

INITRAMFS := $(HOST_IMAGE_DIR)/initramfs.gz
INITRAMFS_ADDR := 0x7f000000

KERNEL_PKVM_PARAMS := kvm-arm.mode=protected kvm-arm.protected_modules=pkvm-dbg-tools

VMLINUX := $(KERNEL_DIR)/vmlinux
WAYOUT := $(shell exec ip route get 1.1.1.1 | grep -oP 'src \K\S+')
PORT := 10022
#DRIVE := -drive file=$(IMAGE),format=qcow2,if=sd,id=ubu-sd -device virtio-blk-device,drive=ubu-sd
DRIVE := -drive file=$(IMAGE),if=none,format=qcow2,id=hd0 -device virtio-blk-device,drive=hd0
BOOTIMG := $(DRIVE)
USB := -device qemu-xhci -device usb-kbd -device usb-tablet
NETWORK := -device e1000,netdev=net0 -netdev user,id=net0,host=192.168.7.1,net=192.168.7.0/24,restrict=off,hostname=guest,hostfwd=tcp:$(WAYOUT):$(PORT)-192.168.7.2:22
COMP_IMG ?= $(OBJDIR)/$(PLATFORM)/hyp-loader
USE_COMP_IMG ?= 0

KERNEL_OPTS :=  $(KERNEL_PKVM_PARAMS) root=/dev/vda1 console=ttyAMA0 mem=8G nokaslr loglevel=8 rw

SPICESOCK := /tmp/host
VDAGENT := -device virtio-serial-pci -device virtserialport,chardev=spicechannel0,name=spice.0 -chardev spicevmc,id=spicechannel0,name=vdagent
SPICEOPTS := unix=on,addr=$(SPICESOCK),disable-ticketing=on,image-compression=off,streaming-video=all,playback-compression=off,disable-agent-file-xfer=off

ifeq ($(DEBUGMMU),1)
QEMUDEBUGOPTS := guest_errors,unimp,mmu
else
QEMUDEBUGOPTS := guest_errors,unimp
endif
QEMUDEBUGLOG := -D $(BASE_DIR)/qemudebug.log

LINK := -T ld.out -Ttext=0xC0001000
LDFLAGS := $(LDFLAGS) $(LINK)

AS_SOURCES := reset.S
C_SOURCES := host_platform.c

ifeq ($(USE_COMP_IMG),1)
HYP_IMAGE := -device loader,file=$(COMP_IMG).bin,addr=0xC0080000,force-raw=true
else
HYP_IMAGE := -device loader,file=$(PROG).bin,addr=0xC0000000,force-raw=true
endif

QEMUOPTS := --accel tcg,thread=multi -d $(QEMUDEBUGOPTS) $(QEMUDEBUGLOG) $(DEBUGOPTS) \
	    -machine virt,virtualization=on,secure=off,gic-version=3 \
	    -cpu max,sve=off,lpa2=off -smp 4 -m 8G $(NETWORK) $(USB) $(BOOTIMG) \
	    -kernel $(KERNEL) -append '$(KERNEL_OPTS)'

ifneq (,$(filter 1, $(USE_KIC) $(USE_INITRAMFS)))
EXTRAOPTS :=  -dtb $(QEMU_DTFILE).dtb
TMPFILE := $(shell mktemp)

endif

ifeq ($(USE_KIC),1)
EXTRAOPTS += -device loader,file=$(PVMFW_LOADER),addr=$(PVMFW_ADDRESS)
endif

ifeq ($(USE_INITRAMFS),1)
EXTRAOPTS += -device loader,file=$(INITRAMFS),addr=$(INITRAMFS_ADDR)
endif

QEMUOPTS := $(QEMUOPTS) -kernel $(KERNEL) -append '$(KERNEL_OPTS)'

ifeq ($(DEBUGGER),1)
QEMUOPTS := $(QEMUOPTS) -S -s
endif

ifeq ($(QEMUDEBUG),1)
QEMUCMD := gdb $(QEMU)-debug -ex "r $(QEMUOPTS) $(EXTRAOPTS) -serial stdio -display none"
else
QEMUCMD := $(QEMU) $(QEMUOPTS) $(EXTRAOPTS) -nographic
endif

ifeq ($(GRAPHICS),1)
QEMUCMD := $(QEMUCMD) -device virtio-gpu-gl-pci,id=gpu0 -display egl-headless -spice $(SPICEOPTS) $(VDAGENT)
endif

QEMUCMD-DTB :=   $(QEMU) $(QEMUOPTS) -machine dumpdtb=$(QEMU_DTFILE).dtb -nographic

include $(BASE_DIR)/core/common.mk

all: run

run: generate-dtb
	@echo "------------------------------------------------------------------------------------------"
ifeq ($(GRAPHICS),1)
	@echo "Graphics available at 'spice+unix://$(SPICESOCK)'"
endif
ifeq ($(USE_KIC),1)
	@echo "KIC/pVM firmware is loaded by QEMU "
endif
ifeq ($(USE_INITRAMFS),1)
		@echo "Use initramfs"
else
		@echo Dont use initramfs
endif
	@echo "Host ssh login is available via $(WAYOUT):$(PORT)"
	@echo "------------------------------------------------------------------------------------------"
	@rm -f $(SPICESOCK)
	@which  $(QEMU)
	@echo $(QEMUCMD)
	@$(QEMUCMD)

generate-dtb:
	@echo Genetate host dtb file
	@$(QEMUCMD-DTB)
	@dtc -O dts -o $(QEMU_DTFILE).dts -I dtb $(QEMU_DTFILE).dtb
ifeq ($(USE_KIC),1)
	@cp $(QEMU_DTFILE).dts $(TMPFILE)
	$(CURDIR)/fix-qemu-dts.py -i $(TMPFILE) -o $(QEMU_DTFILE).dts  -K \
	-a $(PVMFW_ADDRESS) -s $(shell stat -c %s $(PVMFW_LOADER))
endif
ifeq ($(USE_INITRAMFS),1)
	@cp $(QEMU_DTFILE).dts $(TMPFILE)
	@$(CURDIR)/fix-qemu-dts.py -i $(TMPFILE) -o $(QEMU_DTFILE).dts  -I \
	-a $(INITRAMFS_ADDR) -s $(shell stat -c %s $(INITRAMFS))
endif
	@dtc -I dts -o $(QEMU_DTFILE).dtb -O dtb $(QEMU_DTFILE).dts

poorman:
	@CROSS_COMPILE=$(CROSS_COMPILE) PROG=$(PROG) BASE_DIR=$(BASE_DIR) VMLINUX=$(VMLINUX) \
		$(BASE_DIR)/scripts/poorman.sh

gdb:
	@$(CROSS_COMPILE)gdb -ex "target remote localhost:1234" -ex "set confirm off"   \
		$(VMLINUX)

FORCE:
