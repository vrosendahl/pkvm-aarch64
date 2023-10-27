include core/vars.mk

DIRS := kernel qemu

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
	$(MAKE) KERNEL_DIR=$(KERNEL_DIR) -Cplatform/$(PLATFORM) gdb

run:
	$(MAKE) KERNEL_DIR=$(KERNEL_DIR) -Cplatform/$(PLATFORM) run

poorman:
	$(MAKE) KERNEL_DIR=$(KERNEL_DIR) -Cplatform/$(PLATFORM) poorman

kernel:
	$(MAKE) -C$(KERNEL_DIR) -j$(NJOBS) nixos_defconfig bzImage modules

kernel-clean:
	$(MAKE) -C$(KERNEL_DIR) -j$(NJOBS) mrproper

kernel-distclean:
	cd $(KERNEL_DIR); git xlean -xfd

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

guestimage:
	@sudo -E ./scripts/create_guestimg.sh $(USER)

hostimage: $(BUILD_TOOLS)
	@sudo -E ./scripts/create_hostimg.sh $(USER)

.PHONY: all clean target-qemu run $(BUILD_TOOLS) $(DIRS)
