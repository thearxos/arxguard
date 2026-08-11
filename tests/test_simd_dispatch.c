#include "arxguard_simd.h"
#include <assert.h>
#include <string.h>

int main(void) {
    const char *clean = "git status --short";
    const unsigned char escape[] = "echo \033[2J";
    const unsigned char utf8[] = "echo \xE2\x80\x8B";
    assert(arxguard_prefilter_bytes((const unsigned char *)clean, strlen(clean)) == 0);
    assert(arxguard_prefilter_bytes(escape, sizeof(escape)-1) == 1);
    assert(arxguard_prefilter_bytes(utf8, sizeof(utf8)-1) == 1);
    assert(arxguard_prefilter_bytes(NULL, 0) == 0);
    return 0;
}
