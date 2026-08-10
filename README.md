# arxguard — ARXOS zero-trust terminal command guard

**Your browser catches dangerous terminal content. arxguard brings that gate to ARXOS.**

arxguard is an independent, dependency-free pre-execution screen for interactive shell commands. Its threat model is informed by public research, including [sheeki03/tirith](https://github.com/sheeki03/tirith), but arxguard does not vendor tirith source code or depend on it at runtime.

## Native detection architecture

The hot path is native and staged so ordinary commands avoid expensive analysis:

```text
Bash
  -> C Tier-0 byte prefilter (SIMD where available)
  -> C Tier-1 command/policy scanner
  -> optional Rust Tier-2 deep analysis
  -> verdict
```

Tier-0 is conservative: it only identifies inputs containing bytes that warrant deeper inspection, such as non-ASCII or terminal escape bytes. The SSE2 implementation has a scalar fallback for portability. Tier-1 performs the high-value policy checks without Python, subprocesses, regex engines, network calls, or heap allocation. Rust Tier-2 is reserved for URL/Unicode, obfuscation, and shell-structure signals.

## Detection layers

- Homograph / non-ASCII URL indicators, bidi and zero-width Unicode
- ANSI/OSC terminal-control injection
- Base64/hex/OpenSSL decode-to-shell chains
- `curl|sh`, `wget|bash`, and root pipe-to-shell patterns
- Reverse shells via `/dev/tcp`, `nc`, `socat`, interpreters and FIFOs
- Credential/secret references in network commands
- Package signature bypasses such as `pacman --nogpgcheck`, `apt --allow-unauthenticated`, and equivalent patterns
- Insecure TLS downloads (`curl -k` / `--insecure`)
- Direct URL package/tool installation
- Remote Kubernetes/Helm manifests
- Cloud metadata endpoint access
- Proxy/PATH/LD_PRELOAD environment manipulation
- Persistence changes to shell startup, cron, and `authorized_keys`
- Destructive disk operations and recursive deletion

Bash blocks CRITICAL findings and warns on MEDIUM findings. The scanner is a pre-execution gate, not a runtime sandbox or antivirus.

## Commands

```bash
arxguard test
arxguard check -- 'command'
arxguard status
arxguard install
arxguard upstream-check
arxguard upstream-ack
```

The upstream watch is intentionally advisory: a new tirith release is a prompt for ARXOS to review new threat categories, not an automatic code import.

Per-command emergency bypass remains explicit:

```bash
ARXGUARD=0 <command>
```

## Native development

Build and run the native regression suite:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
ctest --test-dir build --output-on-failure
./build/arxguard_native_bench
```

The benchmark reports nanoseconds per scan and, on x86, approximate CPU cycles per scan. Benchmark numbers are machine- and load-dependent and should be compared on the same runner. A libFuzzer entry point is provided at `tests/fuzz_engine.c`; it is intentionally not part of the normal production build.

The scanner is kept on the hot path without external processes. Regression vectors live under `tests/`, including independent tirith-inspired cases for terminal injection, package-signature bypass, reverse shells, insecure downloads, environment hijacking and cloud metadata access.
