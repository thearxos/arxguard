# arxguard scanner — ARXOS zero-trust command screen (bash, ZERO forks).
# A minimal, self-owned reimplementation of the essential terminal-threat model
# (homograph/IDN URLs, bidi/invisible chars, base64-decode-exec, pipe-to-shell,
# credential exfil, destructive commands). Inspired by sheeki03/tirith — but we
# vendor only the *ideas*, not the dependency. See `arxguard upstream-check`.
#
# _arxguard_scan "<command>"  → prints reason lines to stdout, returns:
#   0 = allow (clean)   2 = warn (medium)   1 = BLOCK (critical)
# Uses only bash builtins (${c,,}, [[ =~ ]], local LC_ALL=C) → no subprocess,
# safe to call on every interactive command.

_arxguard_scan() {
  local c="$1"
  local lc="${c,,}"          # lowercased copy for command-name matching (no fork)
  local worst=0 why=""       # worst: 0 clean · 1 warn · 2 block
  local LC_ALL=C             # make [[ =~ ]] byte-oriented so non-ASCII bytes match
  _f(){ local s="$1"; shift; (( s > worst )) && worst=$s; why+="${why:+$'\n'}$*"; }

  # ── CRITICAL (block) ──────────────────────────────────────────────────────
  # Non-ASCII byte OR control char present. In a URL command that's a homograph/
  # IDN spoof or a hidden-payload (bidi/zero-width) attack — the headline tirith
  # catch: visually identical, resolves elsewhere.
  if [[ "$c" =~ [^[:print:][:space:]] ]]; then
    if [[ "$c" == *://* || "$lc" == *curl* || "$lc" == *wget* ]]; then
      _f 2 "[CRITICAL] non-ASCII / hidden control character in a network command — homograph/IDN spoof or concealed payload (looks legitimate, resolves elsewhere)"
    else
      _f 1 "[MEDIUM] non-ASCII or control character in command — review for spoofed/hidden content"
    fi
  fi
  # fork bomb  :(){ :|:& };:
  [[ "$c" =~ :[[:space:]]*\(\)[[:space:]]*\{[[:space:]]*:[[:space:]]*\|[[:space:]]*:[[:space:]]*\&[[:space:]]*\}[[:space:]]*\;[[:space:]]*: ]] \
    && _f 2 "[CRITICAL] fork bomb"
  # rm -rf of / ~ . or \$HOME
  [[ "$lc" =~ (^|[\;\&\|[:space:]])rm[[:space:]]+(-[a-z]*r[a-z]*f|-[a-z]*f[a-z]*r|-[rf]+)[a-z]*[[:space:]]+(--[[:space:]]+)?(/|/\*|~|~/|\$home|\.|\.\/\*)([[:space:]]|$) ]] \
    && _f 2 "[CRITICAL] rm -rf targeting / ~ . or \$HOME"
  # raw disk write / format
  [[ "$lc" =~ (dd[[:space:]].*of=/dev/(sd|nvme|vd|mmcblk|disk)|mkfs(\.[a-z0-9]+)?[[:space:]]+/dev/|wipefs[[:space:]]|>[[:space:]]*/dev/(sd|nvme|vd)) ]] \
    && _f 2 "[CRITICAL] raw disk write or format to a block device (dd/mkfs/wipefs)"
  # base64/hex payload decoded straight into a shell
  [[ "$lc" =~ (base64[[:space:]]+(-d|--decode)|xxd[[:space:]]+-r|openssl[[:space:]]+enc[[:space:]]+-d).*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z|da|c|k)?sh([[:space:]]|$) ]] \
    && _f 2 "[CRITICAL] obfuscated (base64/hex) payload piped directly into a shell"
  # remote download piped into a ROOT shell
  [[ "$lc" =~ (curl|wget|fetch|http)[[:space:]].*\|[[:space:]]*sudo[[:space:]]+(ba|z|da|c|k)?sh ]] \
    && _f 2 "[CRITICAL] remote script piped straight into a root shell (… | sudo sh)"
  # reverse shell — interactive shell wired to a raw socket
  [[ "$lc" =~ (bash|sh|zsh)[[:space:]]+-i[[:space:]].*(/dev/tcp/|/dev/udp/) || "$lc" =~ (/dev/tcp/|/dev/udp/)[0-9a-z.:_-]+[[:space:]]*(0?<&1|<&|>&)[[:space:]]*[0-9] ]] \
    && _f 2 "[CRITICAL] reverse shell — interactive shell bound to a raw TCP/UDP socket (/dev/tcp)"
  # nc/ncat/socat/named-pipe wiring a shell to the network
  [[ "$lc" =~ (^|[[:space:]|&;])(nc|ncat)[[:space:]].*-e[[:space:]]+[^[:space:]]*sh || "$lc" =~ socat[[:space:]].*exec[:=] || "$lc" =~ mkfifo[[:space:]].*\|[[:space:]]*(ba|z|c|k)?sh ]] \
    && _f 2 "[CRITICAL] reverse shell — nc/socat/named-pipe binding a shell to the network"
  # interpreter opening a socket back to a shell
  [[ "$lc" =~ (python[0-9]?|perl|ruby|php)[[:space:]].*socket.*(/bin/(ba)?sh|pty\.spawn|exec[lv]) ]] \
    && _f 2 "[CRITICAL] reverse shell — interpreter opening a socket into a shell"

  # ── MEDIUM (warn) ─────────────────────────────────────────────────────────
  # plain download | interpreter
  [[ "$lc" =~ (curl|wget|fetch)[[:space:]].*\|[[:space:]]*(ba|z|da|c|k)?sh([[:space:]]|$) ]] \
    && _f 1 "[MEDIUM] download piped to an interpreter — download, read, then run instead"
  # eval of dynamic/downloaded content
  [[ "$lc" =~ eval[[:space:]]+.*(curl|wget|fetch|\$\() ]] \
    && _f 1 "[MEDIUM] eval of dynamic/downloaded content"
  # network command touching credential/secret files
  if [[ "$lc" =~ (curl|wget|fetch|scp|rsync|[[:space:]]nc[[:space:]]|ncat)([[:space:]]|$) ]]; then
    [[ "$lc" =~ (\.ssh|id_rsa|id_ed25519|\.aws|\.env([[:space:]/\"\':=]|$)|\.netrc|\.git-credentials|\.config/gh|\.kube/config|\.docker/config) ]] \
      && _f 1 "[MEDIUM] a network command references credential/secret files — possible exfiltration"
  fi
  # chmod 777
  [[ "$lc" =~ (^|[\;\&\|[:space:]])chmod[[:space:]]+(-[a-z]+[[:space:]]+)*0?777([[:space:]]|$) ]] \
    && _f 1 "[MEDIUM] chmod 777 — world-writable permissions"
  # fetch from a raw IP (no domain) — common dropper shape
  [[ "$lc" =~ (curl|wget|fetch)[[:space:]].*https?://([0-9]{1,3}\.){3}[0-9]{1,3} ]] \
    && _f 1 "[MEDIUM] fetching from a raw IP address (no domain)"

  [[ -n "$why" ]] && printf '%s\n' "$why"
  case "$worst" in 2) return 1 ;; 1) return 2 ;; *) return 0 ;; esac
}
