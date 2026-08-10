#include <stddef.h>
#include "../src/arxguard_engine.h"
int LLVMFuzzerTestOneInput(const unsigned char *data, size_t size) {
    struct arxguard_result result;
    (void)arxguard_scan_bytes(data, size, &result);
    return 0;
}
