#include "arxguard_engine.h"

/* Compatibility entry point. The detector stays in-process and allocation-free. */
int arxguard_fast_scan(const char *s){
 struct arxguard_result r;
 return arxguard_scan_cstr(s,&r);
}
