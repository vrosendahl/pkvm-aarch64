include core/vars.mk

DIRS := tools host-kernel target-crosvm hostimage guest-kernel guestimage

all: $(DIRS)

clean: host-kernel-clean guest-kernel-clean target-crosvm-clean tools-clean

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
	@./scripts/guest-kernel-patch-fiddle.sh patch
	$(MAKE) -C$(GUEST_KERNEL_DIR) CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 -j$(NJOBS) defconfig Image modules

guest-kernel-clean:
	$(MAKE) -C$(GUEST_KERNEL_DIR) CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 mrproper

guest-kernel-distclean:
	@./scripts/guest-kernel-patch-fiddle.sh clean
	cd $(GUEST_KERNEL_DIR); git xlean -xfd

host-kernel:
	$(MAKE) -C$(HOST_KERNEL_DIR) CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 -j$(NJOBS) qemu_defconfig Image modules

host-kernel-clean:
	$(MAKE) -C$(HOST_KERNEL_DIR) -j$(NJOBS) mrproper
	@rm -f $(HOST_KERNEL_DIR)/arch/arm64/kvm/hyp/nvhe/gen-hyprel
	@rm -f $(HOST_KERNEL_DIR)/arch/arm64/kvm/hyp/nvhe/hyp-reloc.S
	@rm -rf $(HOST_KERNEL_DIR)/drivers/video/tegra

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

guestimage2:
	@sudo -E ./scripts/create_guestimg2.sh $(USER) 192.168.11. pkvm-guest-2

guestimage3:
	@sudo -E ./scripts/create_guestimg2.sh $(USER) 192.168.12. pkvm-guest-3

guestimage4:
	@sudo -E ./scripts/create_guestimg2.sh $(USER) 192.168.13. pkvm-guest-4

hostimage:
	@sudo -E ./scripts/create_hostimg.sh $(USER)

.PHONY: all clean target-qemu run $(BUILD_TOOLS) $(DIRS)
