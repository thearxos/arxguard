# arxguard bash hook — pre-execution zero-trust screen for interactive bash.
# Sourced once per interactive shell (by /etc/profile.d/arxguard.sh). Installs a
# DEBUG-trap that scans the whole typed line BEFORE it runs: CRITICAL findings
# are blocked (extdebug return 1), MEDIUM findings warn and continue.
#
# The scan is deduped on the history index, which advances once per typed line
# and is shared by every simple command of that line (so a pipeline is scanned
# once, and a block cannot wedge later lines — each new line has a new index).
# Cost: one history read + one in-process scan per typed line, no per-command
# binary. Bypass one command with:  ARXGUARD=0 <command>.

[[ $- == *i* ]] || return 0                       # interactive shells only
[[ -n "$_ARXGUARD_BASH_LOADED" ]] && return 0
_ARXGUARD_BASH_LOADED=1

: "${ARXGUARD_LIB:=/usr/share/arxguard}"
# shellcheck source=/dev/null
source "$ARXGUARD_LIB/scan.bash" 2>/dev/null || return 0

shopt -s extdebug 2>/dev/null                     # lets the DEBUG trap block (return 1)

_arxguard_preexec() {
  [[ -n "${ARXGUARD_INTERNAL:-}" ]] && return 0
  [[ "${ARXGUARD:-1}" == "0" ]] && return 0        # user bypass

  local raw idx line
  raw="$(HISTTIMEFORMAT='' builtin history 1 2>/dev/null)"
  [[ "$raw" =~ ^[[:space:]]*([0-9]+)[[:space:]]+(.*)$ ]] || return 0
  idx="${BASH_REMATCH[1]}"; line="${BASH_REMATCH[2]}"

  # Same typed line (pipeline stage, or already-decided): reuse the verdict.
  [[ "$idx" == "${_ARXGUARD_IDX:-}" ]] && return "${_ARXGUARD_RC:-0}"
  _ARXGUARD_IDX="$idx"; _ARXGUARD_RC=0

  local reason rc
  ARXGUARD_INTERNAL=1; reason="$(_arxguard_scan "$line")"; rc=$?; unset ARXGUARD_INTERNAL

  if (( rc == 1 )); then
    { printf '\n\033[1;31m  arxguard: BLOCKED\033[0m\n'
      local l; while IFS= read -r l; do printf '    %s\n' "$l"; done <<<"$reason"
      printf '\033[90m  not what you meant? run it anyway with:\033[0m ARXGUARD=0 <command>\n\n'
    } >&2
    _ARXGUARD_RC=1
    return 1
  elif (( rc == 2 )); then
    { printf '\n\033[1;33m  arxguard: warning\033[0m\n'
      local l; while IFS= read -r l; do printf '    %s\n' "$l"; done <<<"$reason"
      printf '\n'
    } >&2
  fi
  return 0
}

# Chain our DEBUG trap after any existing one.
_arxguard_prev_debug="$(trap -p DEBUG 2>/dev/null | sed "s/^trap -- '//;s/' DEBUG\$//")"
if [[ -n "$_arxguard_prev_debug" && "$_arxguard_prev_debug" != *_arxguard_preexec* ]]; then
  trap "${_arxguard_prev_debug}; _arxguard_preexec" DEBUG
else
  trap '_arxguard_preexec' DEBUG
fi
unset _arxguard_prev_debug

export ARXGUARD_ACTIVE=bash
