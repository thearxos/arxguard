# arxguard scanner — independent, dependency-free terminal threat screen.
# Threat categories are informed by public research including tirith; no tirith
# source code is vendored. 0=clean, 2=warn, 1=block.
_arxguard_scan(){
 local c="$1" lc="${1,,}" worst=0 why="" LC_ALL=C
 _f(){ local s="$1";shift;((s>worst))&&worst=$s;why+="${why:+$'\n'}$*"; }
 # Terminal injection, Unicode cloaking and homographs.
 [[ "$c" == *$'\e['* || "$c" == *$'\e]'* || "$c" == *$'\eP'* ]]&&_f 2 "[CRITICAL] terminal control sequence detected (ANSI/OSC)"
 [[ "$c" =~ [$'\u200b\u200c\u200d\u200e\u200f\u202a\u202b\u202c\u202d\u202e\u2060\u2066\u2067\u2068\u2069\ufeff'] ]]&&_f 2 "[CRITICAL] invisible/bidi Unicode control detected"
 [[ "$c" =~ [$'\u2800\u3164\u115f\u1160'] ]]&&_f 1 "[MEDIUM] invisible filler character detected"
 [[ "$lc" =~ (https?://|www\.)[^[:space:]/]*[[:space:]] ]]&& [[ "$c" =~ [^[:ascii:]] ]]&&_f 2 "[CRITICAL] non-ASCII hostname/text in a network command (possible homograph)"
 # Destructive and code-execution patterns.
 [[ "$c" =~ :[[:space:]]*\(\)[[:space:]]*\{[[:space:]]*:[[:space:]]*\|[[:space:]]*:[[:space:]]*\&[[:space:]]*\}[[:space:]]*\;[[:space:]]*: ]]&&_f 2 "[CRITICAL] fork bomb"
 [[ "$lc" =~ (^|[\;\&\|[:space:]])rm[[:space:]]+(-[a-z]*r[a-z]*f|-[a-z]*f[a-z]*r|-[rf]+)[a-z]*[[:space:]]+(--[[:space:]]+)?(/|/\*|~|~/|\$home|\.|\.\/\*)([[:space:]]|$) ]]&&_f 2 "[CRITICAL] recursive force deletion targets /, home, or current tree"
 [[ "$lc" =~ (dd[[:space:]].*of=/dev/(sd|nvme|vd|mmcblk|disk)|mkfs(\.[a-z0-9]+)?[[:space:]]+/dev/|wipefs[[:space:]]|>[[:space:]]*/dev/(sd|nvme|vd)) ]]&&_f 2 "[CRITICAL] raw disk write or format"
 [[ "$lc" =~ (base64[[:space:]]+(-d|--decode)|xxd[[:space:]]+-r|openssl[[:space:]]+enc[[:space:]]+-d).*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z|da|c|k)?sh([[:space:]]|$) ]]&&_f 2 "[CRITICAL] decoded payload piped into a shell"
 [[ "$lc" =~ (curl|wget|fetch|http)[[:space:]].*\|[[:space:]]*sudo[[:space:]]+(ba|z|da|c|k)?sh ]]&&_f 2 "[CRITICAL] remote script piped into root shell"
 [[ "$lc" =~ (bash|sh|zsh)[[:space:]]+-i[[:space:]].*(/dev/tcp/|/dev/udp/) || "$lc" =~ (/dev/tcp/|/dev/udp/)[0-9a-z.:_-]+[[:space:]]*(0?<&1|<&|>&)[[:space:]]*[0-9] ]]&&_f 2 "[CRITICAL] reverse shell via raw socket"
 [[ "$lc" =~ (^|[[:space:]\|\&;])(nc|ncat)[[:space:]].*-e[[:space:]]+[^[:space:]]*sh || "$lc" =~ socat[[:space:]].*exec[:=] || "$lc" =~ mkfifo[[:space:]].*\|[[:space:]]*(ba|z|c|k)?sh ]]&&_f 2 "[CRITICAL] network-to-shell reverse shell pattern"
 [[ "$lc" =~ (python[0-9]?|perl|ruby|php)[[:space:]].*socket.*(/bin/(ba)?sh|pty\.spawn|exec[lv]) ]]&&_f 2 "[CRITICAL] interpreter opens socket into shell"
 # Transport, package and supply-chain safety.
 [[ "$lc" =~ (curl|wget|fetch)[[:space:]].*\|[[:space:]]*(ba|z|da|c|k)?sh([[:space:]]|$) ]]&&_f 1 "[MEDIUM] download piped to interpreter"
 [[ "$lc" =~ (curl|wget|fetch)[[:space:]].*(-k|--insecure)([[:space:]]|$) ]]&&_f 1 "[MEDIUM] TLS verification disabled"
 [[ "$lc" =~ (apt|apt-get|dnf|yum|pacman)[[:space:]].*(--allow-unauthenticated|--nogpgcheck|SigLevel[[:space:]]*=[[:space:]]*Never|trusted=yes) ]]&&_f 2 "[CRITICAL] package signature/authentication verification disabled"
 [[ "$lc" =~ (git[[:space:]]+clone|pip[[:space:]]+install|npm[[:space:]]+(install|i))[[:space:]].*https?:// ]]&&_f 1 "[MEDIUM] dependency/tool installed directly from a URL"
 [[ "$lc" =~ (kubectl|helm)[[:space:]].*(apply|install).*(https?://[^[:space:]]+) ]]&&_f 1 "[MEDIUM] remote cluster manifest/chart"
 # Secrets, persistence and environment hijacking.
 [[ "$lc" =~ (curl|wget|fetch|scp|rsync|[[:space:]]nc[[:space:]]|ncat)([[:space:]]|$) ]]&& [[ "$lc" =~ (\.ssh|id_rsa|id_ed25519|\.aws|\.env([[:space:]/\"\':=]|$)|\.netrc|\.git-credentials|\.config/gh|\.kube/config|\.docker/config|aws_secret_access_key|github_token) ]]&&_f 2 "[CRITICAL] network command references credential/secret material"
 [[ "$lc" =~ (export[[:space:]]+|env[[:space:]]+|set[[:space:]]+)(http_proxy|https_proxy|all_proxy|ld_preload|path)= ]]&&_f 1 "[MEDIUM] proxy/PATH/loader environment manipulation"
 [[ "$lc" =~ (crontab|/etc/cron|authorized_keys|\.bashrc|\.zshrc|/etc/profile|/etc/profile\.d/)[[:space:]].*(>>|>|tee|cat[[:space:]]*>) ]]&&_f 1 "[MEDIUM] persistence or SSH authorization modification"
 [[ "$lc" =~ chmod[[:space:]]+(-[a-z]+[[:space:]]+)*0?777([[:space:]]|$) ]]&&_f 1 "[MEDIUM] chmod 777"
 [[ "$lc" =~ eval[[:space:]]+.*(curl|wget|fetch|\$\() ]]&&_f 1 "[MEDIUM] eval of dynamic/downloaded content"
 [[ "$lc" =~ (169\.254\.169\.254|metadata\.google\.internal|100\.100\.100\.200) ]]&&_f 1 "[MEDIUM] cloud metadata endpoint referenced"
 [[ "$lc" =~ (curl|wget|fetch)[[:space:]].*https?://([0-9]{1,3}\.){3}[0-9]{1,3} ]]&&_f 1 "[MEDIUM] download from raw IP address"
 [[ -n "$why" ]]&&printf '%s\n' "$why"
 case "$worst" in 2)return 1;;1)return 2;;*)return 0;;esac
}

_arxguard_scan_file(){
 local file="$1" line n=0 rc=0 rc_line out
 [ -f "$file" ]||{ printf '[ERROR] file not found: %s\n' "$file";return 2; }
 while IFS= read -r line||[ -n "$line" ];do n=$((n+1));out="$(_arxguard_scan "$line")";rc_line=$?;[ -n "$out" ]&&printf 'line %d: %s\n' "$n" "$out";[ "$rc_line" -gt "$rc" ]&&rc=$rc_line;done<"$file"
 return "$rc"
}
