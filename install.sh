#!/usr/bin/env bash
# arxguard installer — ARX-managed payload installer.
# ARX is the sole distribution/update authority. This script only builds,
# validates, and installs the payload supplied by ARX; it never self-updates.
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

ARX_CHANNEL="${ARX_CHANNEL:-arx}"
ARX_VERSION="${ARX_VERSION:-unknown}"
ARX_ARTIFACT="${ARX_ARTIFACT:-arxguard}"

case "$ARX_CHANNEL" in
  arx) ;;
  *) echo "error: arxguard must be installed through the ARX distribution channel" >&2; exit 1 ;;
esac

BUILD_DIR="$D/build"

cmake -S "$D" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR" --parallel
ctest --test-dir "$BUILD_DIR" --output-on-failure

$S cmake --install "$BUILD_DIR"

$S install -d /usr/share/arxos/arxguard
$S sh -c 'cat > /usr/share/arxos/arxguard/manifest <<EOF
managed_by=arx
channel=$ARX_CHANNEL
artifact=$ARX_ARTIFACT
version=$ARX_VERSION
updates=arx-only
runtime_network=disabled
EOF'

$S install -Dm644 "$D/scan.bash" /usr/share/arxguard/scan.bash
$S install -Dm644 "$D/hook.bash" /usr/share/arxguard/hook.bash
$S install -Dm644 "$D/hook.zsh" /usr/share/arxguard/hook.zsh
$S install -Dm755 "$D/arxguard" /usr/local/bin/arxguard

if [ -x "$BUILD_DIR/arxguard_check" ]; then
  $S install -Dm755 "$BUILD_DIR/arxguard_check" /usr/local/bin/arxguard_check
fi

# Ensure ARXGuard is loaded automatically for interactive Bash and Zsh.
# Login shells use /etc/profile.d; non-login Bash uses /etc/bash.bashrc;
# Zsh uses /etc/zsh/zshrc. Detection remains local/native at runtime.
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

echo "arxguard installed — ARX-managed native engine built and tests passed."
echo "distribution: ARX ($ARX_VERSION)"
echo "interactive shells: Bash + Zsh enabled"
echo "updates: ARX only"
echo "Self-test: arxguard test"
