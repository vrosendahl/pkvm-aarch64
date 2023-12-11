include core/vars.mk

DIRS := tools kernel-host kernel-guest qemu

all: $(DIRS)

clean: qemu-clean kernel-clean

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

kernel-guest:
	$(MAKE) -C$(GUEST_KERNEL_DIR) CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 -j$(NJOBS) defconfig Image modules

kernel-guest-clean:
	$(MAKE) -C$(GUEST_KERNEL_DIR) CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 mrproper

kernel-guest-distclean:
	cd $(GUEST_KERNEL_DIR); git xlean -xfd

kernel-host:
	$(MAKE) -C$(HOST_KERNEL_DIR) CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 -j$(NJOBS) frankenstein_defconfig Image modules

kernel-host-clean:
	$(MAKE) -C$(HOST_KERNEL_DIR) -j$(NJOBS) mrproper

kernel-host-distclean:
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

guestimage:
	@sudo -E ./scripts/create_guestimg.sh $(USER)

hostimage:
	@sudo -E ./scripts/create_hostimg.sh $(USER)

.PHONY: all clean target-qemu run $(BUILD_TOOLS) $(DIRS)
