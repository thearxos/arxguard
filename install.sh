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

# ARX may provide these when installing a versioned artifact. Defaults keep
# this payload installer usable by the ARX build/test pipeline without inventing
# a second updater or requiring network access.
ARX_CHANNEL="${ARX_CHANNEL:-arx}"
ARX_VERSION="${ARX_VERSION:-unknown}"
ARX_ARTIFACT="${ARX_ARTIFACT:-arxguard}"
ARX_MANAGED=1

case "$ARX_CHANNEL" in
  arx) ;;
  *) echo "error: arxguard must be installed through the ARX distribution channel" >&2; exit 1 ;;
esac

BUILD_DIR="$D/build"

cmake -S "$D" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR" --parallel
ctest --test-dir "$BUILD_DIR" --output-on-failure

# Native installation happens only after the complete test suite succeeds.
$S cmake --install "$BUILD_DIR"

# Record distribution ownership separately from the runtime. The detector does
# not read this file and never performs update/network work during scanning.
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

echo "arxguard installed — ARX-managed native engine built and tests passed."
echo "distribution: ARX ($ARX_VERSION)"
echo "updates: ARX only"
echo "Self-test: arxguard test"
