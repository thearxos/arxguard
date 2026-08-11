# arxguard scanner — dependency-free terminal threat screen.
# 0=clean, 2=warn, 1=block. No external process is used by the scanner hot path.
_arxguard_scan(){
  local c="${1-}" lc="${1-}" worst=0 why=""
  lc="${lc,,}"
  _f(){ local s="$1"; shift; ((s>worst)) && worst=$s; why+="${why:+$'\n'}$*"; }
  local nonascii=0
  # Bash cannot prefix the [[ keyword with an environment assignment. Use an
  # ASCII range instead; it keeps this test in-process and avoids subprocesses.
  [[ "$c" =~ [^ -~] ]] && nonascii=1

  [[ "$c" == *$'\e['* || "$c" == *$'\e]'* || "$c" == *$'\eP'* ]] && _f 2 "[CRITICAL] terminal control sequence detected (ANSI/OSC)"
  [[ "$c" == *$'\u200b'* || "$c" == *$'\u200c'* || "$c" == *$'\u200d'* || "$c" == *$'\u200e'* || "$c" == *$'\u200f'* || "$c" == *$'\u202a'* || "$c" == *$'\u202b'* || "$c" == *$'\u202c'* || "$c" == *$'\u202d'* || "$c" == *$'\u202e'* || "$c" == *$'\u2060'* || "$c" == *$'\u2066'* || "$c" == *$'\u2067'* || "$c" == *$'\u2068'* || "$c" == *$'\u2069'* || "$c" == *$'\ufeff'* ]] && _f 2 "[CRITICAL] invisible/bidi Unicode control detected"
  [[ "$c" == *$'\u2800'* || "$c" == *$'\u3164'* || "$c" == *$'\u115f'* || "$c" == *$'\u1160'* ]] && _f 1 "[MEDIUM] invisible filler character detected"

  if (( nonascii )) && [[ "$lc" == *"http://"* || "$lc" == *"https://"* || "$lc" == *"www."* ]]; then
    _f 2 "[CRITICAL] non-ASCII hostname/text in a network command (possible homograph)"
  fi

  [[ "$lc" == *':(){ :|:& };:'* ]] && _f 2 "[CRITICAL] fork bomb"
  if [[ "$lc" == rm\ *-rf\ /* || "$lc" == rm\ *-rf\ ~* || "$lc" == *"rm -rf /"* || "$lc" == *"rm -fr /"* ]]; then
    _f 2 "[CRITICAL] recursive force deletion targets /, home, or current tree"
  fi
  [[ "$lc" == *"dd "*"of=/dev/sd"* || "$lc" == *"dd "*"of=/dev/nvme"* || "$lc" == *"dd "*"of=/dev/vd"* || "$lc" == *"mkfs"*" /dev/"* || "$lc" == *"wipefs "* ]] && _f 2 "[CRITICAL] raw disk write or format"

  if [[ "$lc" == *"base64 -d"*"|"*"sh"* || "$lc" == *"base64 --decode"*"|"*"sh"* || "$lc" == *"xxd -r"*"|"*"sh"* || "$lc" == *"openssl enc -d"*"|"*"sh"* ]]; then
    _f 2 "[CRITICAL] decoded payload piped into a shell"
  fi
  if [[ "$lc" == curl* || "$lc" == wget* || "$lc" == fetch* ]] && [[ "$lc" == *"| sudo bash"* || "$lc" == *"| sudo sh"* || "$lc" == *"| sudo zsh"* ]]; then
    _f 2 "[CRITICAL] remote script piped into root shell"
  fi

  if [[ "$lc" == curl* || "$lc" == wget* || "$lc" == fetch* ]] && [[ "$lc" == *"http://"* || "$lc" == *"https://"* ]]; then
    if [[ "$lc" == *"| sh -c "* || "$lc" == *"| bash -c "* || "$lc" == *"| zsh -c "* || "$lc" == *"| dash -c "* || "$lc" == *"| ksh -c "*" || "$lc" == *" -O- | sh"* || "$lc" == *" -O- | bash"* || "$lc" == *" -O- | zsh"* || "$lc" == *" -O- | dash"* || "$lc" == *" -O- | ksh"* || "$lc" == *" --output-document=- | sh"* || "$lc" == *" --output-document=- | bash"* || "$lc" == *" --output-document=- | zsh"* ]]; then
      _f 2 "[CRITICAL] suspicious remote content piped into shell"
    fi
  fi

  [[ "$lc" == *"/dev/tcp/"* || "$lc" == *"/dev/udp/"* ]] && _f 2 "[CRITICAL] reverse shell via raw socket"
  [[ "$lc" == *"nc "*" -e "*"sh"* || "$lc" == *"ncat "*" -e "*"sh"* || "$lc" == *"socat "*"exec:"* || "$lc" == *"mkfifo "*"|"*"sh"* ]] && _f 2 "[CRITICAL] network-to-shell reverse shell pattern"
  [[ "$lc" == *"python"*"socket"*"/bin/sh"* || "$lc" == *"python"*"socket"*"/bin/bash"* || "$lc" == *"perl"*"socket"*"/bin/sh"* || "$lc" == *"ruby"*"socket"*"/bin/sh"* || "$lc" == *"php"*"socket"*"/bin/sh"* ]] && _f 2 "[CRITICAL] interpreter opens socket into shell"

  if [[ "$lc" == curl* || "$lc" == wget* || "$lc" == fetch* ]]; then
    [[ "$lc" == *"| bash"* || "$lc" == *"| sh"* || "$lc" == *"| zsh"* || "$lc" == *"| dash"* || "$lc" == *"| ksh"* ]] && _f 1 "[MEDIUM] download piped to interpreter"
    [[ "$lc" == *" -k"* || "$lc" == *" --insecure"* ]] && _f 1 "[MEDIUM] TLS verification disabled"
    [[ "$lc" =~ https?://[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]] && _f 1 "[MEDIUM] download from raw IP address"
  fi
  [[ "$lc" == *"--allow-unauthenticated"* || "$lc" == *"--nogpgcheck"* || "$lc" == *"trusted=yes"* ]] && _f 2 "[CRITICAL] package signature/authentication verification disabled"
  [[ "$lc" == git\ clone*https://* || "$lc" == pip\ install*https://* || "$lc" == npm\ install*https://* ]] && _f 1 "[MEDIUM] dependency/tool installed directly from a URL"
  [[ "$lc" == kubectl*apply*https://* || "$lc" == helm*install*https://* ]] && _f 1 "[MEDIUM] remote cluster manifest/chart"

  if [[ "$lc" == curl* || "$lc" == wget* || "$lc" == fetch* || "$lc" == scp* || "$lc" == rsync* || "$lc" == *" nc "* || "$lc" == ncat* ]]; then
    [[ "$lc" == *".ssh"* || "$lc" == *"id_rsa"* || "$lc" == *"id_ed25519"* || "$lc" == *".aws"* || "$lc" == *".env"* || "$lc" == *".netrc"* || "$lc" == *".git-credentials"* || "$lc" == *"github_token"* || "$lc" == *"aws_secret_access_key"* ]] && _f 2 "[CRITICAL] network command references credential/secret material"
  fi
  [[ "$lc" == *"export http_proxy="* || "$lc" == *"export https_proxy="* || "$lc" == *"export all_proxy="* || "$lc" == *"export ld_preload="* || "$lc" == *"export path="* ]] && _f 1 "[MEDIUM] proxy/PATH/loader environment manipulation"
  [[ "$lc" == *".bashrc"*">>"* || "$lc" == *".zshrc"*">>"* || "$lc" == *"authorized_keys"*">>"* || "$lc" == *"/etc/cron"*">"* ]] && _f 1 "[MEDIUM] persistence or SSH authorization modification"
  [[ "$lc" == *"chmod 777"* ]] && _f 1 "[MEDIUM] chmod 777"
  [[ "$lc" == *"eval "*"curl"* || "$lc" == *"eval "*"wget"* || "$lc" == *"eval "*\$\("* ]] && _f 1 "[MEDIUM] eval of dynamic/downloaded content"
  [[ "$lc" == *"169.254.169.254"* || "$lc" == *"metadata.google.internal"* || "$lc" == *"100.100.100.200"* ]] && _f 1 "[MEDIUM] cloud metadata endpoint referenced"

  [[ -n "$why" ]] && printf '%s\n' "$why"
  case "$worst" in 2) return 1;; 1) return 2;; *) return 0;; esac
}

_arxguard_scan_file(){
  local file="$1" line n=0 rc=0 rc_line out
  [ -f "$file" ] || { printf '[ERROR] file not found: %s\n' "$file"; return 2; }
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n+1)); out="$(_arxguard_scan "$line")"; rc_line=$?
    [ -n "$out" ] && printf 'line %d: %s\n' "$n" "$out"
    [ "$rc_line" -gt "$rc" ] && rc=$rc_line
  done <"$file"
  return "$rc"
}