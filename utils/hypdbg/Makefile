WORK_DIR=$(shell realpath ../..)
CROSS_COMPILE=$(WORK_DIR)/buildtools/usr/bin/aarch64-linux-gnu-

all: hypdbg

hypdbg: hypdbg.c
	echo $(WORK_DIR)
	$(CROSS_COMPILE)gcc -I$(WORK_DIR)/kmodules/hypdbg \
		--sysroot=$(WORK_DIR)/buildtools \
		--no-sysroot-suffix  hypdbg.c -o hypdbg

clean:
	rm -f hypdbg
