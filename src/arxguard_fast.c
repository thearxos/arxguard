/* ARXGuard fast path: dependency-light C scanner for terminal and command-line hazards. */
#include <string.h>
static int has(const char *s,const char *n){return s&&n&&strstr(s,n)!=NULL;}
int arxguard_fast_scan(const char *s){
 if(!s)return 0;
 if(has(s,"\033]")||has(s,"\033P")||has(s,"\033_")||has(s,"\xE2\x80\x8E")||has(s,"\xE2\x80\x8F"))return 2;
 if(has(s,"curl ")&&(has(s,"| sh")||has(s,"| bash")||has(s," -k ")||has(s," --insecure")))return 3;
 if(has(s,"wget ")&&(has(s,"| sh")||has(s,"| bash")||has(s," --no-check-certificate")))return 3;
 if(has(s,"/dev/tcp/")||has(s,"/dev/udp/"))return 3;
 if((has(s,"nc ")||has(s,"ncat ")||has(s,"socat "))&&has(s,"-e"))return 3;
 if(has(s,"pacman")&&has(s,"--nogpgcheck"))return 4;
 if(has(s,"apt")&&has(s,"--allow-unauthenticated"))return 4;
 if(has(s,"LD_PRELOAD=")||has(s,"authorized_keys")||has(s,"/etc/cron"))return 4;
 return 0;
}
