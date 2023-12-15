include core/vars.mk

DIRS := tools host-kernel target-crosvm hostimage

all: $(DIRS)

clean: host-kernel-clean target-crosvm-clean tools-clean

$(FETCH_SOURCES):
	@echo "Fetching sources.."
	@git submodule update --init

$(BUILD_TOOLS): | $(FETCH_SOURCES)
	@mkdir -p $(TOOLDIR)
	@./scripts/build-tools.sh

tools: $(BUILD_TOOLS)

tools-clean:
	@sudo -E ./scripts/build-tools.sh clean
	@rm -rf $(TOOLDIR)

$(OBJDIR): | $(BUILD_TOOLS)
	@mkdir -p $(OBJDIR)

gdb:
	$(MAKE) CROSS_COMPILE=$(CROSS_COMPILE) KERNEL_DIR=$(HOST_KERNEL_DIR) -Cplatform/$(PLATFORM) gdb

run:
	$(MAKE) CROSS_COMPILE=$(CROSS_COMPILE) KERNEL_DIR=$(HOST_KERNEL_DIR) -Cplatform/$(PLATFORM) run

poorman:
	$(MAKE) CROSS_COMPILE=$(CROSS_COMPILE) KERNEL_DIR=$(HOST_KERNEL_DIR) -Cplatform/$(PLATFORM) poorman

guest-kernel:
	$(MAKE) -C$(GUEST_KERNEL_DIR) CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 -j$(NJOBS) defconfig Image modules

guest-kernel-clean:
	$(MAKE) -C$(GUEST_KERNEL_DIR) CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 mrproper

guest-kernel-distclean:
	cd $(GUEST_KERNEL_DIR); git xlean -xfd

host-kernel:
	$(MAKE) -C$(HOST_KERNEL_DIR) CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 -j$(NJOBS) qemu_defconfig Image modules

host-kernel-clean:
	$(MAKE) -C$(HOST_KERNEL_DIR) -j$(NJOBS) mrproper

host-kernel-distclean:
	cd $(HOST_KERNEL_DIR); git xlean -xfd

qemu:
	@./scripts/build-qemu.sh build

qemu-clean:
	@./scripts/build-qemu.sh clean

qemu-distclean:
	cd $(QEMUDIR); git clean -xfd

target-qemu:
	@./scripts/build-target-qemu.sh

target-qemu-clean:
	@./scripts/build-target-qemu.sh clean

target-qemu-distclean:
	@./scripts/build-target-qemu.sh distclean

target-crosvm:
	@./scripts/build-target-crosvm.sh

target-crosvm-clean:
	@./scripts/build-target-crosvm.sh clean

target-crosvm-distclean:
	@./scripts/build-target-crosvm.sh distclean

guestimage:
	@sudo -E ./scripts/create_guestimg.sh $(USER)

hostimage:
	@sudo -E ./scripts/create_hostimg.sh $(USER)

.PHONY: all clean target-qemu run $(BUILD_TOOLS) $(DIRS)
