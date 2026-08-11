#!/usr/bin/env bash
# arxguard installer — ARXOS zero-trust command guard.
# Builds and validates the native engine before installing shell integration.
set -euo pipefail

D="$(cd "$(dirname "$0")" && pwd)"
S=""
[ "$(id -u)" -ne 0 ] && S=sudo

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: required command not found: $1" >&2
    exit 1
  }
}

need_cmd cmake
need_cmd cc
need_cmd ctest

BUILD_DIR="$D/build"

cmake -S "$D" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR" --parallel
ctest --test-dir "$BUILD_DIR" --output-on-failure

# Install the native shared engine and headers through CMake. Keep this
# separate from shell integration so a native build/test failure never leaves
# an apparently installed but unvalidated guard.
$S cmake --install "$BUILD_DIR"

$S install -Dm644 "$D/scan.bash" /usr/share/arxguard/scan.bash
$S install -Dm644 "$D/hook.bash" /usr/share/arxguard/hook.bash
$S install -Dm644 "$D/hook.zsh"  /usr/share/arxguard/hook.zsh
$S install -Dm755 "$D/arxguard"  /usr/local/bin/arxguard

# Install the native VM/test helper when it was built by the current tree.
if [ -x "$BUILD_DIR/arxguard_check" ]; then
  $S install -Dm755 "$BUILD_DIR/arxguard_check" /usr/local/bin/arxguard_check
fi

# Activate for every interactive shell. profile.d covers login shells;
# bash/zsh rc files cover non-login interactive shells.
$S install -Dm644 "$D/arxguard.sh" /etc/profile.d/arxguard.sh

_wire() {
  local rc="$1" hk="$2"
  grep -qF "$hk" "$rc" 2>/dev/null && return 0
  printf '\n# ARXOS arxguard — zero-trust command screen\ncase $- in *i*) [ -r %s ] && . %s ;; esac\n' "$hk" "$hk" | $S tee -a "$rc" >/dev/null
}

[ -f /etc/bash.bashrc ] || $S touch /etc/bash.bashrc
_wire /etc/bash.bashrc /usr/share/arxguard/hook.bash

if [ -d /etc/zsh ]; then
  [ -f /etc/zsh/zshrc ] || $S touch /etc/zsh/zshrc
  _wire /etc/zsh/zshrc /usr/share/arxguard/hook.zsh
fi

echo "arxguard installed — native engine built and tests passed."
echo "Self-test: arxguard test"
