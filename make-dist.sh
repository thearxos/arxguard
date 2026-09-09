#!/usr/bin/env bash
# make-dist.sh [outdir] — build arxguard and assemble the over-the-air dist tree.
#
# Produces a self-contained dist/ (prebuilt binaries + a regular install.sh) that arxpush packs
# to R2 and `arx update` installs with no compiler on the target. The layout matches what
# dist-install.sh expects: bin/, lib/, share/, install.sh, SHA256SUMS.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
OUT="${1:-$HERE/dist}"

echo ">> build + test"
cmake -S "$HERE" -B "$HERE/build" -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$HERE/build" --parallel >/dev/null
ctest --test-dir "$HERE/build" --output-on-failure >/dev/null

echo ">> assemble $OUT"
rm -rf "$OUT"; mkdir -p "$OUT/bin" "$OUT/lib" "$OUT/share"
install -Dm755 "$HERE/build/arxguard_check" "$OUT/bin/arxguard_check"
install -Dm755 "$HERE/arxguard"             "$OUT/bin/arxguard"
# The loadable bash builtin ships when it was built (bash headers present); it is optional —
# the bash hook falls back to the arxguard_check exe, and zsh uses the exe by design.
if [ -f "$HERE/build/arxguard_native.so" ]; then
  install -Dm755 "$HERE/build/arxguard_native.so" "$OUT/lib/arxguard_native.so"
fi
install -Dm644 "$HERE/hook.bash"   "$OUT/share/hook.bash"
install -Dm644 "$HERE/hook.zsh"    "$OUT/share/hook.zsh"
install -Dm644 "$HERE/arxguard.sh" "$OUT/share/arxguard.sh"
install -Dm755 "$HERE/dist-install.sh" "$OUT/install.sh"    # arxpush/arx require a regular install.sh

( cd "$OUT" && find bin lib share install.sh -type f | sort | xargs sha256sum > SHA256SUMS )
echo ">> dist ready: $OUT"
ls -R "$OUT"
