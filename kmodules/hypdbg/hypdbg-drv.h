#ifndef __HYP_DBG__
#define __HYP_DBG__

struct ioctl_params {
    u32 dlen;
    u32 id;
    u64 addr;
    u64 size;
    u8  lock;
    u8  dump;
};

#define PRINT_S2_MAPPING	2
#define COUNT_SHARED		3
#define PRINT_RAMLOG        4


#define MAGIC 0xDE
#define HYPDBG_COUNT_SHARED_S2_MAPPING 	_IOWR(MAGIC, COUNT_SHARED, struct ioctl_params)
#define HYPDBG_PRINT_S2_MAPPING 	_IOWR(MAGIC, PRINT_S2_MAPPING, struct ioctl_params)
#define HYPDBG_PRINT_RAMLOG 	    _IOWR(MAGIC, PRINT_RAMLOG, struct ioctl_params)

#endif // __HYP_DRV__
