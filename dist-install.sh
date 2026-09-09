#!/usr/bin/env bash
# arxguard OTA installer — installs PREBUILT binaries, no compiler required.
#
# This is the installer that ships INSIDE the over-the-air archive (arxpush -> R2, or the
# -dist release). `arx update` extracts the archive and runs this as root; it is also safe to
# run standalone. It is idempotent and wires BOTH interactive shells — zsh (the ArxOS default)
# and bash — so the guard is active whichever shell the user runs.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)

# --- prebuilt payload into place ---
install -Dm755 "$HERE/bin/arxguard_check" /usr/local/bin/arxguard_check
install -Dm755 "$HERE/bin/arxguard"       /usr/local/bin/arxguard
if [ -f "$HERE/lib/arxguard_native.so" ]; then
  install -Dm755 "$HERE/lib/arxguard_native.so" /usr/lib/arxguard/arxguard_native.so
fi
install -Dm644 "$HERE/share/hook.bash"   /usr/share/arxguard/hook.bash
install -Dm644 "$HERE/share/hook.zsh"    /usr/share/arxguard/hook.zsh
install -Dm644 "$HERE/share/arxguard.sh" /etc/profile.d/arxguard.sh

# --- activate for interactive shells, idempotently, for BOTH bash and zsh ---
# profile.d covers login shells; the rc files cover non-login interactive shells. The hooks
# self-guard against double-loading, so sourcing from both paths is safe.
_wire() {
  local rc="$1" hk="$2"
  grep -qF "$hk" "$rc" 2>/dev/null && return 0
  printf '\n# ARXOS arxguard — zero-trust command screen\ncase $- in *i*) [ -r %s ] && . %s ;; esac\n' "$hk" "$hk" >> "$rc"
}
[ -f /etc/bash.bashrc ] || touch /etc/bash.bashrc
_wire /etc/bash.bashrc /usr/share/arxguard/hook.bash
if [ -d /etc/zsh ]; then
  [ -f /etc/zsh/zshrc ] || touch /etc/zsh/zshrc
  _wire /etc/zsh/zshrc /usr/share/arxguard/hook.zsh
fi

# --- prove the installed engine actually screens a command (fail the update if it does not) ---
# arxguard_check returns 1 for a CRITICAL verdict; capture it without tripping set -e.
_sc=0; /usr/local/bin/arxguard_check -- 'rm -rf /' >/dev/null 2>&1 || _sc=$?
if [ "$_sc" != 1 ]; then
  echo "arxguard: post-install self-check failed (engine did not block a critical command)" >&2
  exit 1
fi
echo "arxguard installed/updated (prebuilt; bash + zsh guards active)."
