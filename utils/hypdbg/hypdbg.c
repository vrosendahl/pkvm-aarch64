#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/sysmacros.h>
#include <sys/ioctl.h>
#include <stdint.h>
#include <errno.h>
#include <sys/syscall.h>
//#include <linux/keyctl.h>
typedef uint64_t u64;
typedef uint32_t u32;

#include "hypdbg-drv.h"

static char *prog_name;
void usage(void)
{
	printf("usage: %s <call nr> [<arg1> ...]\n\n", prog_name);
}


static u64 get_arg(char *str, u64 *dst)
{
	u64 val;

	if (sscanf(str, "%lx", &val) != 1)
		return -1;

	*dst = val;
	return 0;
}

int count_shared(int fd, u32 *len, u64 id, u64 size, u64 lock)
{
	struct count_shared_params params;
	int ret;

	printf("count_shared_\n");
	params.dlen = *len;
	params.id = id;
	params.size = size;
	params.lock = lock;
	ret = ioctl(fd, HYPDBG_COUNT_SHARED_S2_MAPPING, &params);
	if (ret)
		return ret;
	*len = params.dlen;
	printf("ret %x %d\n",ret, *len);
	return 0;
}

int print_s2_mapping(int fd, u32 *len, u64 id, u64 addr, u64 size)
{
	struct s2_mapping_params params;
	int ret;
	printf("print_s2_mappinns\n");
	params.dlen = *len;
	params.id = id;
	params.addr = addr;
	params.size = size;

	ret = ioctl(fd, HYPDBG_PRINT_S2_MAPPING, &params);
	if (ret)
		return ret;
	*len = params.dlen;
	printf("ret %x %d\n",ret, *len);
	return 0;
}

int print_ramlog(int fd)
{
	int ret;
	printf("print_ramlog\n");

	ret = ioctl(fd, HYPDBG_PRINT_RAMLOG);
	if (ret)
		return ret;
	printf("ret %x\n",ret);
	return 0;
}

int do_ioctl(int fd, int call, u32 *len, int argc, char *argv[])
{
	int ret = -1;
	switch (call) {
	case 1:
		if (argc >= 3) {
			u64 id, size, lock;
			ret = get_arg(argv[0], &id);
			ret += get_arg(argv[1], &size);
			ret += get_arg(argv[2], &lock);
			if (!ret)
				ret = count_shared(fd, len, id, size, lock);
		}
		break;
	case 2:
		if (argc >= 3) {
			u64 id, addr, size;
			ret = get_arg(argv[0], &id);
			ret += get_arg(argv[1], &addr);
			ret += get_arg(argv[2], &size);
			if (!ret)
				ret = print_s2_mapping(fd, len, id, addr, size);
		}
		break;
    case 3:
        ret = print_ramlog(fd);
        break;
	default:
		usage();
		return -1;
	}

	if (ret < 0) {
		if (errno)
			perror("ioctl");
		else
			printf("%s %d: invalid arguments.\n", prog_name, call);
		usage();
	}

	return ret;
}

int main(int argc, char *argv[])
{
	int fd = -1, ret = 0;
	int call = -1;
	u32 rlen = 0;
	prog_name = argv[0];
	char *resp = 0;;

	if (argc >= 2)
		call = argv[1][0] - '0';

	if (call > 0) {
		fd = open("/dev/hypdbg", O_RDWR);
		if (fd < 0) {
			perror("open /dev/hypdbg");
			return -1;
		}
	}

	ret = do_ioctl(fd, call, &rlen, argc - 2, &argv[2]);
	if (ret) {
		printf("ioctl err %x\n",ret);
		goto err;
	}

	if (!rlen) {
		printf("no data \n");
		goto err;
	}
	resp = malloc(rlen);
	if (!resp) {
		printf("Malloc error\n");
		goto err;
	}
	read(fd, resp, rlen);
	printf("%s\n",resp);

/*
	do {
		xx = read(fd, resp, rlen);
		printf("%s\n",resp);
	} while (xx);
*/
err:
	if (resp)
		free(resp);

	if (fd >= 0)
		close(fd);


	return ret;
}
