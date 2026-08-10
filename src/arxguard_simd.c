#include "arxguard_simd.h"
#include <stddef.h>
#if defined(__x86_64__) || defined(__i386__)
#include <immintrin.h>
#endif

int arxguard_prefilter_bytes(const unsigned char *p, size_t n) {
    if (!p || !n) return 0;
#if defined(__SSE2__)
    const __m128i hi = _mm_set1_epi8((char)0x80);
    const __m128i esc = _mm_set1_epi8(0x1b);
    while (n >= 16) {
        __m128i v = _mm_loadu_si128((const __m128i*)p);
        int high = _mm_movemask_epi8(_mm_cmplt_epi8(v, _mm_setzero_si128()));
        int control = _mm_movemask_epi8(_mm_cmpeq_epi8(v, esc));
        if (high || control) return 1;
        p += 16; n -= 16;
    }
#endif
    for (size_t i=0; i<n; ++i) if (p[i] >= 0x80 || p[i] == 0x1b) return 1;
    return 0;
}
