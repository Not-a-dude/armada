#ifndef ARMADA_CDSP_BENCH_COMMON_H
#define ARMADA_CDSP_BENCH_COMMON_H

#include <stdint.h>

static uint64_t sad_u8(const uint8_t *a, const uint8_t *b,
		       uint32_t count, uint32_t rounds)
{
	uint64_t sum = 0;

	for (uint32_t repeat = 0; repeat < rounds; repeat++)
		for (uint32_t i = 0; i < count; i++) {
			int32_t diff = (int32_t)a[i] - (int32_t)b[i];
			sum += (uint32_t)(diff < 0 ? -diff : diff);
		}

	return sum;
}

static int64_t dot_s16(const int16_t *a, const int16_t *b,
		       uint32_t count, uint32_t rounds)
{
	int64_t sum = 0;

	for (uint32_t repeat = 0; repeat < rounds; repeat++)
		for (uint32_t i = 0; i < count; i++)
			sum += (int32_t)a[i] * b[i];

	return sum;
}

#endif
