#include "arxguard_simd.h"
#include <stddef.h>
#include <stdatomic.h>
#if defined(__x86_64__) || defined(__i386__)
#include <immintrin.h>
#endif
#if defined(__ARM_NEON) || defined(__ARM_NEON__)
#include <arm_neon.h>
#endif

typedef int (*arxguard_prefilter_fn)(const unsigned char *, size_t);

static int scalar_prefilter(const unsigned char *p, size_t n) {
    for (size_t i = 0; i < n; ++i)
        if (p[i] >= 0x80 || p[i] == 0x1b) return 1;
    return 0;
}

#if defined(__x86_64__) || defined(__i386__)
__attribute__((target("sse2")))
static int sse2_prefilter(const unsigned char *p, size_t n) {
    const __m128i esc = _mm_set1_epi8(0x1b);
    while (n >= 16) {
        __m128i v = _mm_loadu_si128((const __m128i*)p);
        if (_mm_movemask_epi8(v) ||
            _mm_movemask_epi8(_mm_cmpeq_epi8(v, esc))) return 1;
        p += 16; n -= 16;
    }
    return scalar_prefilter(p, n);
}

#if defined(__GNUC__) || defined(__clang__)
__attribute__((target("avx2")))
static int avx2_prefilter(const unsigned char *p, size_t n) {
    const __m256i zero = _mm256_setzero_si256();
    const __m256i esc = _mm256_set1_epi8(0x1b);
    while (n >= 32) {
        __m256i v = _mm256_loadu_si256((const __m256i*)p);
        if (_mm256_movemask_epi8(_mm256_cmpgt_epi8(zero, v)) ||
            _mm256_movemask_epi8(_mm256_cmpeq_epi8(v, esc))) return 1;
        p += 32; n -= 32;
    }
    return sse2_prefilter(p, n);
}
#endif
#endif

#if defined(__ARM_NEON) || defined(__ARM_NEON__)
static int neon_prefilter(const unsigned char *p, size_t n) {
    const uint8x16_t hi = vdupq_n_u8(0x80);
    const uint8x16_t esc = vdupq_n_u8(0x1b);
    while (n >= 16) {
        uint8x16_t v = vld1q_u8(p);
        uint8x16_t flags = vorrq_u8(vcgeq_u8(v, hi), vceqq_u8(v, esc));
        uint64x2_t bits = vreinterpretq_u64_u8(flags);
        if (vgetq_lane_u64(bits, 0) || vgetq_lane_u64(bits, 1)) return 1;
        p += 16; n -= 16;
    }
    return scalar_prefilter(p, n);
}
#endif

static arxguard_prefilter_fn select_prefilter(void) {
#if defined(__x86_64__) || defined(__i386__)
#if defined(__GNUC__) || defined(__clang__)
    if (__builtin_cpu_supports("avx2")) return avx2_prefilter;
#endif
    return sse2_prefilter;
#elif defined(__ARM_NEON) || defined(__ARM_NEON__)
    return neon_prefilter;
#else
    return scalar_prefilter;
#endif
}

static arxguard_prefilter_fn arxguard_prefilter_impl(void) {
    static _Atomic(arxguard_prefilter_fn) fn = ATOMIC_VAR_INIT(NULL);
    arxguard_prefilter_fn selected = atomic_load_explicit(&fn, memory_order_acquire);
    if (selected) return selected;
    selected = select_prefilter();
    arxguard_prefilter_fn expected = NULL;
    if (!atomic_compare_exchange_strong_explicit(&fn, &expected, selected,
            memory_order_release, memory_order_relaxed)) {
        selected = expected;
    }
    return selected;
}

int arxguard_prefilter_bytes(const unsigned char *p, size_t n) {
    if (!p || !n) return 0;
    return arxguard_prefilter_impl()(p, n);
}
