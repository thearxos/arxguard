#include "arxguard_engine.h"
#include <stdio.h>
#include <string.h>

static const char *name(int code) {
    return code == ARXGUARD_BLOCK ? "BLOCK" : code == ARXGUARD_WARN ? "WARN" : "CLEAN";
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s -- <command>\n", argv[0]);
        return 2;
    }
    int first = !strcmp(argv[1], "--") ? 2 : 1;
    if (first >= argc) return 2;

    struct arxguard_result r;
    int code = arxguard_scan_bytes(
        (const unsigned char *)argv[first], strlen(argv[first]), &r);

    printf("%s findings=%zu\n", name(code), r.findings);
    for (size_t i = 0; i < r.findings; ++i)
        printf("%s\n", r.finding[i].reason);

    if (code == ARXGUARD_BLOCK) return 1;
    if (code == ARXGUARD_WARN) return 2;
    return 0;
}
