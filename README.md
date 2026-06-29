# arxguard — ARXOS zero-trust terminal command guard

**Your browser catches homograph URLs. Your terminal doesn't. arxguard does.**

arxguard screens every command you run, *before it executes*, for the threats a
terminal renders without question:

- **Homograph / IDN spoofs** — `curl … | bash` where a hostname hides a Cyrillic
  `і` (U+0456) that resolves to an attacker's server.
- **Hidden payloads** — bidi overrides (U+202E), zero-width / invisible chars.
- **Obfuscated execution** — `base64 -d | sh`, `xxd -r | bash`, `openssl enc -d | sh`.
- **Pipe-to-shell** — `curl … | sh` (warn) and `curl … | sudo sh` (block).
- **Credential exfiltration** — network commands touching `~/.ssh`, `.aws`, `.env`,
  `.git-credentials`, kube/docker configs.
- **Destructive commands** — `rm -rf /`, fork bombs, `dd`/`mkfs`/`wipefs` to a disk.

On **bash** it *blocks* CRITICAL findings and *warns* on MEDIUM. On **zsh** it is
warn-only (zsh's preexec can't abort a command — use bash for blocking).

## Why this exists (and what it is not)
This is a **minimal, self-owned reimplementation** of the threat model pioneered by
[sheeki03/tirith](https://github.com/sheeki03/tirith). ARXOS does **not** vendor
tirith's engine — per our doctrine we reimplement only the essential checks we need,
in dependency-free shell, and keep an **upstream watch** so we notice when the
upstream model advances:

```
arxguard upstream-check     # alerts if sheeki03/tirith has shipped a newer model
arxguard upstream-ack       # accept the current upstream as the new baseline
```

## Design
- **Zero forks on the hot path.** The bash scanner is pure builtins
  (`${c,,}`, `[[ =~ ]]`, byte-oriented matching) — one history read + one
  in-process scan per typed line, no per-command binary. Frugal enough to run on
  every command by default.
- **Fail-open, never wedge your shell.** A bypass is always one keystroke away:
  `ARXGUARD=0 <command>` runs the next command unscreened.

## Use
```
arxguard test               # built-in detection self-test
arxguard check -- '<cmd>'   # screen a command by hand  (exit 0 clean · 2 warn · 1 block)
arxguard status             # live protection state for this shell
arxguard install            # wire it into your shell rc (or it's distro-wide via profile.d)
```

Installed distro-wide by `install.sh` (drops `/etc/profile.d/arxguard.sh`), so every
interactive shell on ARXOS is guarded with zero setup.

`arxguard 0.0.1 — ARXOS`
