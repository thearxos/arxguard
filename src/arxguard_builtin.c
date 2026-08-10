#include <stdio.h>
#include "builtins.h"
#include "shell.h"
#include "arxguard_engine.h"

static char *arxguard_native_builtin(WORD_LIST *list){
 const char *s=(list&&list->word)?list->word->word:"";
 struct arxguard_result r;
 arxguard_scan_cstr(s,&r);
 for(size_t i=0;i<r.findings;i++) printf("%s\n",r.finding[i].reason);
 return r.code==ARXGUARD_BLOCK ? EXECUTION_FAILURE : (r.code==ARXGUARD_WARN ? 2 : EXECUTION_SUCCESS);
}

char *arxguard_native_doc[]={"arxguard_native command", "scan one command using the native ARXGuard engine", (char *)0};
struct builtin arxguard_native_struct={
 .name="arxguard_native",
 .function=arxguard_native_builtin,
 .flags=BUILTIN_ENABLED,
 .long_doc=arxguard_native_doc,
 .short_doc="arxguard_native command",
 .handle=0
};
