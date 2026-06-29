#!/usr/bin/env bash
# arxguard installer — ARXOS zero-trust command guard. Hands-off, idempotent.
set -e
D="$(cd "$(dirname "$0")" && pwd)"; S=""; [ "$(id -u)" -ne 0 ] && S=sudo
$S install -Dm644 "$D/scan.bash" /usr/share/arxguard/scan.bash
$S install -Dm644 "$D/hook.bash" /usr/share/arxguard/hook.bash
$S install -Dm644 "$D/hook.zsh"  /usr/share/arxguard/hook.zsh
$S install -Dm755 "$D/arxguard"  /usr/local/bin/arxguard
# activate for every interactive shell, distro-wide. profile.d covers login
# shells; /etc/bash.bashrc + /etc/zsh/zshrc cover the non-login interactive
# shells that terminal emulators spawn (the loader guard makes re-source safe).
$S install -Dm644 "$D/arxguard.sh" /etc/profile.d/arxguard.sh
_wire(){ # rcfile  hookfile
  local rc="$1" hk="$2"
  grep -qF "$hk" "$rc" 2>/dev/null && return 0
  printf '\n# ARXOS arxguard — zero-trust command screen\ncase $- in *i*) [ -r %s ] && . %s ;; esac\n' "$hk" "$hk" | $S tee -a "$rc" >/dev/null
}
[ -f /etc/bash.bashrc ] || $S touch /etc/bash.bashrc
_wire /etc/bash.bashrc /usr/share/arxguard/hook.bash
[ -d /etc/zsh ] && { [ -f /etc/zsh/zshrc ] || $S touch /etc/zsh/zshrc; _wire /etc/zsh/zshrc /usr/share/arxguard/hook.zsh; }
echo "arxguard installed — active in new interactive shells. Self-test: arxguard test"
