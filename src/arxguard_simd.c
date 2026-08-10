#include "arxguard_simd.h"
#include <stddef.h>
#if defined(__x86_64__) || defined(__i386__)
#include <immintrin.h>
#endif
#if defined(__ARM_NEON) || defined(__ARM_NEON__)
#include <arm_neon.h>
#endif

int arxguard_prefilter_bytes(const unsigned char *p, size_t n) {
    if (!p || !n) return 0;
#if defined(__SSE2__)
    const __m128i zero = _mm_setzero_si128();
    const __m128i esc = _mm_set1_epi8(0x1b);
    while (n >= 16) {
        __m128i v = _mm_loadu_si128((const __m128i*)p);
        int high = _mm_movemask_epi8(_mm_cmplt_epi8(v, zero));
        int control = _mm_movemask_epi8(_mm_cmpeq_epi8(v, esc));
        if (high || control) return 1;
        p += 16; n -= 16;
    }
#elif defined(__ARM_NEON) || defined(__ARM_NEON__)
    const uint8x16_t hi = vdupq_n_u8(0x80);
    const uint8x16_t esc = vdupq_n_u8(0x1b);
    while (n >= 16) {
        uint8x16_t v = vld1q_u8(p);
        uint8x16_t high = vcgeq_u8(v, hi);
        uint8x16_t control = vceqq_u8(v, esc);
        uint64x2_t h = vreinterpretq_u64_u8(vorrq_u8(high, control));
        if (vgetq_lane_u64(vreinterpret_u64_u8(vget_low_u8(vreinterpretq_u8_u64(h))), 0) ||
            vgetq_lane_u64(vreinterpret_u64_u8(vget_high_u8(vreinterpretq_u8_u64(h))), 0)) return 1;
        p += 16; n -= 16;
    }
#endif
    for (size_t i = 0; i < n; ++i)
        if (p[i] >= 0x80 || p[i] == 0x1b) return 1;
    return 0;
}
