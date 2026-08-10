# arxguard — ARXOS zero-trust terminal command guard

**Your browser catches dangerous terminal content. arxguard brings that gate to ARXOS.**

arxguard is an independent, dependency-free pre-execution screen for interactive shell commands. Its threat model is informed by public research, including [sheeki03/tirith](https://github.com/sheeki03/tirith), but arxguard does not vendor tirith source code or depend on it at runtime.

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

## Development

The scanner is kept on the hot path without external processes. Regression vectors live under `tests/`, including independent tirith-inspired cases for terminal injection, package-signature bypass, reverse shells, insecure downloads, environment hijacking and cloud metadata access.
