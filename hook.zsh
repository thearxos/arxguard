# arxguard zsh hook — pre-execution zero-trust screen for interactive zsh.
#
# zsh's preexec runs before a command but cannot abort it. So instead of preexec, arxguard hooks
# the ZLE accept-line widget: when you press Enter, the buffer is scanned FIRST. A CRITICAL finding
# BLOCKS — the line is kept in the buffer and never run; a MEDIUM finding warns, then runs. This
# gives zsh the same blocking guarantee as bash. Detection reuses the exact same native engine.
#
# Fail-OPEN by design: only a confirmed CRITICAL verdict (exit 1) refuses the line. A missing or
# broken scanner, or any unexpected exit code, still lets the command run — the guard can warn or
# block, but it can never brick the shell by swallowing Enter.

[[ -o interactive ]] || return 0
[[ -n "$_ARXGUARD_ZSH_LOADED" ]] && return 0
_ARXGUARD_ZSH_LOADED=1

# Resolve the scanner once: the wrapper if present, else the raw native exe (same engine either way).
if command -v arxguard >/dev/null 2>&1; then
  _arxguard_zsh_scan() { command arxguard check -- "$1" 2>/dev/null; }
elif [[ -x /usr/local/bin/arxguard_check ]]; then
  _arxguard_zsh_scan() { /usr/local/bin/arxguard_check -- "$1" 2>/dev/null; }
elif [[ -x /usr/bin/arxguard_check ]]; then
  _arxguard_zsh_scan() { /usr/bin/arxguard_check -- "$1" 2>/dev/null; }
else
  print -u2 -P "%F{red}  arxguard: scanner not found; zsh guard not loaded%f"
  return 0
fi

_arxguard_accept_line() {
  emulate -L zsh
  # Explicit bypass: env ARXGUARD=0, or an inline "ARXGUARD=0 " prefix on this command.
  if [[ "${ARXGUARD:-1}" == "0" || "$BUFFER" == ARXGUARD=0\ * ]]; then
    zle "$_arxguard_next"; return
  fi
  local out reason rc
  out="$(_arxguard_zsh_scan "$BUFFER")"; rc=$?
  reason="${out#*$'\n'}"   # drop the "STATUS findings=N" header line; keep only the reasons
  if (( rc == 1 )); then
    # BLOCK: do not accept the line — it stays in the buffer to edit or clear.
    print -u2 -P "%F{red}%B  arxguard: BLOCKED — command not run%b%f"
    print -u2 -- "$reason" | sed 's/^/    /'
    print -u2 -P "%F{8}  run it anyway:%f prefix the line with  ARXGUARD=0"
    zle reset-prompt 2>/dev/null
    return 1
  elif (( rc == 2 )); then
    print -u2 -P "%F{yellow}%B  arxguard: warning%b%f"
    print -u2 -- "$reason" | sed 's/^/    /'
  fi
  # CLEAN, WARN, or any unexpected/error code: run the command (fail-open).
  zle "$_arxguard_next"
}

# Install our accept-line in front of whatever is currently bound — chain-safe and idempotent, so
# it coexists with other plugins' accept-line widgets and never wraps itself twice.
if [[ "${widgets[accept-line]:-}" != "user:_arxguard_accept_line" ]]; then
  if zle -A accept-line _arxguard_orig_accept 2>/dev/null; then
    _arxguard_next=_arxguard_orig_accept
  else
    _arxguard_next=.accept-line
  fi
  zle -N accept-line _arxguard_accept_line
fi
export ARXGUARD_ACTIVE=zsh
