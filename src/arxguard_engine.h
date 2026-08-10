#ifndef ARXGUARD_ENGINE_H
#define ARXGUARD_ENGINE_H
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif

enum arxguard_severity { ARXGUARD_CLEAN=0, ARXGUARD_BLOCK=1, ARXGUARD_WARN=2 };
struct arxguard_finding { int severity; const char *reason; };
struct arxguard_result { int code; size_t findings; struct arxguard_finding finding[24]; };

/* Hot path: no allocation, I/O, regex, locale, shell, Python or subprocesses. */
int arxguard_scan_bytes(const unsigned char *input, size_t len, struct arxguard_result *out);
int arxguard_scan_cstr(const char *input, struct arxguard_result *out);
const char *arxguard_version(void);
#ifdef __cplusplus
}
#endif
#endif
