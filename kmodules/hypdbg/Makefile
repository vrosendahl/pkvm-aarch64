ifeq ($(DEBUG),1)
export OPTS := -g -O1 -DDEBUG
endif
CROSS_COMPILE=../buildtools/usr/bin/aarch64-linux-gnu-
KERNEL_DIR=../../linux-host/

obj-m += hypdbg-drv.o

all: hypdbg-drv.ko


hypdbg-drv.ko:
	make ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) -C $(KERNEL_DIR) M=$(PWD) \
	"KCFLAGS=$(OPTS)" modules


clean:
	make ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) -C $(KERNEL_DIR) M=$(PWD) clean
