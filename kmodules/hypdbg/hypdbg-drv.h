#ifndef __HYP_DBG__
#define __HYP_DBG__


struct count_shared_params {
	u32 dlen;
	u64 id;
	u64 size;
	u64 lock;
};

struct s2_mapping_params {
	u32 dlen;
	u64 id;
	u64 addr;
	u64 size;
};

#define COUNT_SHARED		1
#define PRINT_S2_MAPPING	2


#define MAGIC 0xDE
#define HYPDBG_COUNT_SHARED_S2_MAPPING 	_IOWR(MAGIC, COUNT_SHARED, struct count_shared_params)
#define HYPDBG_PRINT_S2_MAPPING 	_IOWR(MAGIC, PRINT_S2_MAPPING, struct s2_mapping_params)

#endif // __HYP_DRV__
