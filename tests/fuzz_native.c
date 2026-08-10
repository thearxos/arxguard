#include "arxguard_engine.h"
#include <stddef.h>
#include <stdint.h>

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    struct arxguard_result result;
    (void)arxguard_scan_bytes(data, size, &result);
    return 0;
}
