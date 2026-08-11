# arxguard — ARXOS zero-trust terminal command guard

**Your browser catches dangerous terminal content. arxguard brings that gate to ARXOS.**

arxguard is an independent, dependency-free pre-execution screen for interactive shell commands. Its threat model is informed by public research, including [sheeki03/tirith](https://github.com/sheeki03/tirith), but arxguard does not vendor tirith source code or depend on it at runtime.

## Native detection architecture

Detection and classification live in the compiled C engine. Bash and Zsh are integration layers only; there is no Bash detection library to parse, source, or maintain.

```text
Bash interactive hook ──> C loadable builtin ──> native engine ──> verdict
Zsh preexec ────────────> native arxguard_check ─> native engine ─> verdict
CLI arxguard check ─────> native arxguard_check ─> native engine ─> verdict
```

The native engine performs the high-value policy checks without Python, shell regex evaluation, grep/sed/awk detection helpers, network calls, or per-command shell parsing. The Bash builtin is loaded once into the interactive shell; Zsh and non-hook CLI paths use the installed native `arxguard_check` executable.

## Detection layers

- Homograph / non-ASCII URL indicators, bidi and zero-width Unicode
- ANSI/OSC terminal-control injection
- Base64/hex/OpenSSL decode-to-shell chains
- `curl|sh`, `wget|bash`, and root pipe-to-shell patterns
- Suspicious `sh -c` / `bash -c` / `zsh -c` remote execution
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
./build/arxguard_check -- 'command'
./build/arxguard_native_bench
```

The benchmark reports nanoseconds per scan and, on x86, approximate CPU cycles per scan. Benchmark numbers are machine- and load-dependent and should be compared on the same runner. A libFuzzer entry point is provided at `tests/fuzz_engine.c`; it is intentionally not part of the normal production build.

The scanner stays on the native hot path without a Bash detection parser or Python dependency. Regression vectors live under `tests/`, including independent cases for terminal injection, package-signature bypass, reverse shells, insecure downloads, environment hijacking and cloud metadata access.
