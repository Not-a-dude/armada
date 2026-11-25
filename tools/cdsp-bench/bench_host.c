#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <sched.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <time.h>
#include <unistd.h>

#include "bench_common.h"

#define BUFFER_BYTES (64 * 1024)
#define ROUNDS 128
#define SAMPLES 5

struct fastrpc_method {
	uint32_t msg_id;
	uint8_t in_nums;
	uint8_t in_bufs;
	uint8_t out_nums;
	uint8_t out_bufs;
};

struct fastrpc_arg {
	uint64_t ptr;
	uint64_t length;
	int32_t fd;
	uint32_t attr;
};

struct fastrpc_invoke {
	uint32_t handle;
	uint32_t sc;
	uint64_t args;
};

struct bench_request {
	uint32_t count;
	uint32_t rounds;
};

typedef int (*fastrpc2_t)(const struct fastrpc_method *, int, uint32_t, ...);

static uint64_t now_ns(void)
{
	struct timespec now;

	clock_gettime(CLOCK_MONOTONIC_RAW, &now);
	return (uint64_t)now.tv_sec * 1000000000ull + now.tv_nsec;
}

static uint64_t median(uint64_t *samples)
{
	for (int i = 1; i < SAMPLES; i++) {
		uint64_t value = samples[i];
		int j = i;

		while (j > 0 && samples[j - 1] > value) {
			samples[j] = samples[j - 1];
			j--;
		}
		samples[j] = value;
	}
	return samples[SAMPLES / 2];
}

static int dsp_call(int fd, uint32_t handle, uint32_t method,
		    const struct bench_request *request,
		    const void *a, const void *b, uint64_t *result)
{
	struct fastrpc_arg args[4] = {
		{ (uint64_t)(uintptr_t)request, sizeof(*request), -1, 0 },
		{ (uint64_t)(uintptr_t)a, BUFFER_BYTES, -1, 0 },
		{ (uint64_t)(uintptr_t)b, BUFFER_BYTES, -1, 0 },
		{ (uint64_t)(uintptr_t)result, sizeof(*result), -1, 0 },
	};
	struct fastrpc_invoke invoke = {
		.handle = handle,
		.sc = (method << 24) | (3 << 16) | (1 << 8),
		.args = (uint64_t)(uintptr_t)args,
	};

	return ioctl(fd, _IOWR('R', 3, struct fastrpc_invoke), &invoke);
}

static int bench_method(int fd, uint32_t handle, uint32_t method,
			const uint8_t *a, const uint8_t *b)
{
	uint64_t cpu_samples[SAMPLES], rpc_samples[SAMPLES], empty_samples[SAMPLES];
	uint64_t cpu_result = 0, dsp_result = 0;
	uint32_t count = method ? BUFFER_BYTES / sizeof(int16_t) : BUFFER_BYTES;
	struct bench_request request = { count, ROUNDS };
	const char *name = method ? "int16 dot" : "uint8 SAD";

	for (int i = -1; i < SAMPLES; i++) {
		uint64_t start = now_ns();
		__asm__ volatile("" ::: "memory");
		if (method)
			cpu_result = (uint64_t)dot_s16((const int16_t *)a,
				(const int16_t *)b, count, ROUNDS);
		else
			cpu_result = sad_u8(a, b, count, ROUNDS);
		__asm__ volatile("" ::: "memory");
		uint64_t end = now_ns();
		if (i >= 0)
			cpu_samples[i] = end - start;
	}

	request.rounds = 0;
	for (int i = -1; i < SAMPLES; i++) {
		uint64_t start = now_ns();
		int ret = dsp_call(fd, handle, method, &request, a, b, &dsp_result);
		uint64_t end = now_ns();
		if (ret) {
			fprintf(stderr, "%s empty RPC failed: 0x%08x errno=%d\n",
				name, (uint32_t)ret, errno);
			return -1;
		}
		if (i >= 0)
			empty_samples[i] = end - start;
	}

	request.rounds = ROUNDS;
	for (int i = -1; i < SAMPLES; i++) {
		uint64_t start = now_ns();
		int ret = dsp_call(fd, handle, method, &request, a, b, &dsp_result);
		uint64_t end = now_ns();
		if (ret) {
			fprintf(stderr, "%s RPC failed: 0x%08x errno=%d\n",
				name, (uint32_t)ret, errno);
			return -1;
		}
		if (dsp_result != cpu_result) {
			fprintf(stderr, "%s mismatch: A76=%llu CDSP=%llu\n", name,
				(unsigned long long)cpu_result,
				(unsigned long long)dsp_result);
			return -1;
		}
		if (i >= 0)
			rpc_samples[i] = end - start;
	}

	printf("%s: result=%llu A76=%llu us CDSP+RPC=%llu us empty-RPC=%llu us\n",
	       name, (unsigned long long)cpu_result,
	       (unsigned long long)(median(cpu_samples) / 1000),
	       (unsigned long long)(median(rpc_samples) / 1000),
	       (unsigned long long)(median(empty_samples) / 1000));
	fflush(stdout);
	return 0;
}

int main(void)
{
	const struct fastrpc_method open_method = { 0, 0, 1, 2, 1 };
	const char *fd_env = getenv("HEXAGONRPC_FD");
	const char *name = "armada_bench";
	uint8_t *a = NULL, *b = NULL;
	char error[256] = { 0 };
	uint32_t handle = 0;
	int32_t remote_error = 0;
	cpu_set_t cpus;
	void *library;
	fastrpc2_t fastrpc2;
	int fd, ret = 1;

	if (!fd_env) {
		fprintf(stderr, "Run as a hexagonrpcd -p client\n");
		return 1;
	}
	fd = atoi(fd_env);
	CPU_ZERO(&cpus);
	CPU_SET(7, &cpus);
	if (sched_setaffinity(0, sizeof(cpus), &cpus)) {
		perror("Pin to A76 CPU 7");
		return 1;
	}
	if (posix_memalign((void **)&a, 128, BUFFER_BYTES) ||
	    posix_memalign((void **)&b, 128, BUFFER_BYTES))
		goto out;

	uint32_t random = 0x7125;
	for (uint32_t i = 0; i < BUFFER_BYTES; i++) {
		random ^= random << 13;
		random ^= random >> 17;
		random ^= random << 5;
		a[i] = random;
		b[i] = random >> 8;
	}

	library = dlopen("libhexagonrpc.so.0.5", RTLD_NOW);
	if (!library) {
		fprintf(stderr, "libhexagonrpc: %s\n", dlerror());
		goto out;
	}
	fastrpc2 = (fastrpc2_t)dlsym(library, "fastrpc2");
	if (!fastrpc2) {
		fprintf(stderr, "fastrpc2: %s\n", dlerror());
		goto close_library;
	}
	for (int attempt = 0; attempt < 10; attempt++) {
		if (!fastrpc2(&open_method, fd, 0, (uint32_t)strlen(name) + 1,
			      name, &handle, &remote_error,
			      (uint32_t)sizeof(error), error) &&
		    !remote_error)
			break;
		if (attempt == 9) {
			fprintf(stderr, "CDSP module open failed: dsp=0x%08x %s\n",
				(uint32_t)remote_error, error);
			goto close_library;
		}
		usleep(100000);
	}
	printf("CDSP module handle=%u, A76 CPU 7\n", handle);
	fflush(stdout);
	if (!bench_method(fd, handle, 0, a, b) &&
	    !bench_method(fd, handle, 1, a, b))
		ret = 0;

close_library:
	dlclose(library);
out:
	free(a);
	free(b);
	return ret;
}
