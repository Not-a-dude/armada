#include <stdint.h>

#include "bench_common.h"

struct remote_buf {
	void *data;
	uint32_t length;
};

union remote_arg {
	struct remote_buf buf;
	uint64_t handle;
};

struct bench_request {
	uint32_t count;
	uint32_t rounds;
};

__attribute__((visibility("default")))
int armada_bench_skel_invoke(uint32_t sc, union remote_arg *args)
{
	const struct bench_request *request;
	uint32_t method = (sc >> 24) & 0x1f;

	if (((sc >> 16) & 0xff) != 3 || ((sc >> 8) & 0xff) != 1)
		return 14;
	if (args[0].buf.length != sizeof(*request) ||
	    args[3].buf.length != sizeof(uint64_t))
		return 14;

	request = args[0].buf.data;
	if (method == 0 && args[1].buf.length >= request->count &&
	    args[2].buf.length >= request->count) {
		*(uint64_t *)args[3].buf.data = sad_u8(args[1].buf.data,
			args[2].buf.data, request->count, request->rounds);
		return 0;
	}
	if (method == 1 &&
	    args[1].buf.length / sizeof(int16_t) >= request->count &&
	    args[2].buf.length / sizeof(int16_t) >= request->count) {
		*(int64_t *)args[3].buf.data = dot_s16(args[1].buf.data,
			args[2].buf.data, request->count, request->rounds);
		return 0;
	}
	return 14;
}
