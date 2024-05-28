// SPDX-License-Identifier: GPL-2.0-only

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/mm.h>
#include <asm-generic/ioctls.h>
#include <linux/slab.h>
#include <asm/kvm_host.h>

//#include "hvccall-defines.h"
#include "hypdbg-drv.h"
#include <asm/uaccess.h>
MODULE_DESCRIPTION("Hypervisor debugger module for userspace");
MODULE_LICENSE("GPL v2");

#define DBG_BUFF_SIZE (0x20000)
#define DEVICE_NAME "hypdbg"

static int major;
static int dopen;

struct shared_buf {
	u64 size;
	u64 datalen;
	u8 data[];
};

static u8 *buffer;
int hyp_dbg(u64 buf, u32 *size, u64 param1, u64 param2, u64 param3, u64 param4);
static char *readp;

static int do_count_shared_mappings(void __user *argp)
{

	struct  count_shared_params *p = 0;
	uint64_t ret = -ENODATA;

	p = kmalloc(sizeof(struct count_shared_params), GFP_KERNEL);
	if (!p)
		return -ENOMEM;
	ret = copy_from_user(p, argp, sizeof(struct count_shared_params));
	if (ret) {
		ret = -EIO;
		goto err;
	}


	ret = kvm_call_hyp_nvhe(__hyp_dbg, 3, p->id, p->size, p->lock, 0);

	readp = ((struct shared_buf *) buffer)->data;
	p->dlen = ((struct shared_buf *) buffer)->datalen;

	ret = copy_to_user(argp, p,  sizeof(struct count_shared_params));
err:
	if (p)
		kfree(p);

	return ret;
}
static int do_print_s2_mappings(void __user *argp)
{

	struct s2_mapping_params *p;
	uint64_t ret = -ENODATA;

	p = kmalloc(sizeof(struct s2_mapping_params), GFP_KERNEL);
	if (!p)
		return -ENOMEM;

	ret = copy_from_user(p, argp, sizeof(struct s2_mapping_params));
	if (ret) {
		ret = -EIO;
		goto err;
	}
	/* TODO fis the call IDs */
	ret = kvm_call_hyp_nvhe(__hyp_dbg, 2,
				p->id, p->addr, p->size, 0);

	readp = ((struct shared_buf *) buffer)->data;
	p->dlen = ((struct shared_buf *) buffer)->datalen;

	ret = copy_to_user(argp, p,  sizeof(struct count_shared_params));
err:
	if (p)
		kfree(p);

	return ret;
}

static int device_open(struct inode *inode, struct file *filp)
{

	int ret;
	int i;

	if (dopen)
		return -EBUSY;

	dopen = 1;
	for (i = 0; i < DBG_BUFF_SIZE / 0x1000; i++ ) {
		ret = kvm_call_hyp_nvhe(__pkvm_host_share_hyp,
				virt_to_pfn(&buffer[i * 0x1000]), 1);
		/* TODO; make add cleanup if the call fails */
	}
	if (ret)
		return ret;
	ret = kvm_call_hyp_nvhe(__hyp_dbg, 0,
				virt_to_pfn(buffer), DBG_BUFF_SIZE, 0, 0);
	return ret;
}

static int device_release(struct inode *inode, struct file *filp)
{

	int ret;
	int i;
	ret = kvm_call_hyp_nvhe(__hyp_dbg, 1, 0, 0, 0, 0);
	for (i = 0; i < DBG_BUFF_SIZE / 0x1000; i++ ) {
		ret = kvm_call_hyp_nvhe(__pkvm_host_unshare_hyp,
				virt_to_pfn(&buffer[i * 0x1000]), 1);
	}
	dopen = 0;
	return ret;
}

static ssize_t
device_read(struct file *filp, char *obuf, size_t length, loff_t *off)
{
	int ret;

	struct shared_buf *p = (struct shared_buf *) buffer;

	if (p->datalen < length)
		length = p->datalen;

	ret = copy_to_user(obuf, readp, length);
	if (p->datalen)
		p->datalen -= length;
	readp += length;

	return p->datalen;
}

static long
device_ioctl(struct file *filp, unsigned int cmd, unsigned long arg)
{
	void __user *argp = (void __user *) arg;
	int ret = -ENOTSUPP;

	switch (cmd) {
	case HYPDBG_COUNT_SHARED_S2_MAPPING:
		ret = do_count_shared_mappings(argp);
		break;
	case HYPDBG_PRINT_S2_MAPPING:
		ret = do_print_s2_mappings(argp);
		break;
	default:
		WARN(1, "HYPDRV: unknown ioctl: 0x%x\n", cmd);
	}

	return ret;
}

static const struct file_operations fops = {
	.read = device_read,
	.open = device_open,
	.release = device_release,
	.unlocked_ioctl = device_ioctl,
};

int init_module(void)
{
	pr_info("HYPDBG hypervisor debugger driver\n");

	major = register_chrdev(0, DEVICE_NAME, &fops);

	if (major < 0) {
		pr_err("HYPDBG: register_chrdev failed with %d\n", major);
		return major;
	}
	pr_info("HYPDBG mknod /dev/%s c %d 0\n", DEVICE_NAME, major);
	buffer = alloc_pages_exact(DBG_BUFF_SIZE, GFP_KERNEL);
	if (!buffer)
		return -ENOMEM;

	return 0;
}

void cleanup_module(void)
{
	pr_info("hyp cleanup\n");
	if (buffer) {

		free_pages_exact(buffer, DBG_BUFF_SIZE);
	}

	buffer = 0;
	if (major > 0)
		unregister_chrdev(major, DEVICE_NAME);
	major = 0;
}
