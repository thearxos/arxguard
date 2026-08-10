#ifndef ARXGUARD_SIMD_H
#define ARXGUARD_SIMD_H
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
/* Fast conservative prefilter. Returns non-zero only when a byte requiring deeper inspection exists. */
int arxguard_prefilter_bytes(const unsigned char *input, size_t len);
#ifdef __cplusplus
}
#endif
#endif
