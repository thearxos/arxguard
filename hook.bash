# arxguard bash hook — native in-process pre-execution screen.
# The preferred scanner is the compiled Bash loadable builtin: no Python,
# grep, sed, awk, regex process, or per-command executable is spawned on the hot path.
# scan.bash remains only as a compatibility fallback when the native module is absent.

[[ $- == *i* ]] || return 0
[[ -n "$_ARXGUARD_BASH_LOADED" ]] && return 0
_ARXGUARD_BASH_LOADED=1

: "${ARXGUARD_LIB:=/usr/share/arxguard}"
_ARXGUARD_NATIVE_LOADED=0

# CMake installs the Bash loadable module under /usr/local/lib/arxguard.
# ARX-managed installations may override ARXGUARD_NATIVE explicitly.
if [[ -n "${ARXGUARD_NATIVE:-}" ]]; then
  _ARXGUARD_NATIVE="$ARXGUARD_NATIVE"
elif [[ -r /usr/local/lib/arxguard/arxguard_native.so ]]; then
  _ARXGUARD_NATIVE=/usr/local/lib/arxguard/arxguard_native.so
elif [[ -r /usr/lib/arxguard/arxguard_native.so ]]; then
  _ARXGUARD_NATIVE=/usr/lib/arxguard/arxguard_native.so
elif [[ -r "$ARXGUARD_LIB/arxguard_native.so" ]]; then
  _ARXGUARD_NATIVE="$ARXGUARD_LIB/arxguard_native.so"
fi

# Load the native engine once into the current Bash process.
if [[ -n "${_ARXGUARD_NATIVE:-}" ]] && [[ -r "$_ARXGUARD_NATIVE" ]] && enable -f "$_ARXGUARD_NATIVE" arxguard_native 2>/dev/null; then
  _ARXGUARD_NATIVE_LOADED=1
else
  # Compatibility fallback for installations that have not built the native module.
  source "$ARXGUARD_LIB/scan.bash" 2>/dev/null || return 0
fi

_arxguard_scan_native() {
  local c="$1"
  if (( _ARXGUARD_NATIVE_LOADED )); then
    arxguard_native "$c"
    return $?
  fi
  _arxguard_scan "$c"
}

_arxguard_preexec() {
  [[ -n "${ARXGUARD_INTERNAL:-}" ]] && return 0
  [[ "${ARXGUARD:-1}" == "0" ]] && return 0

  local raw idx line
  raw="$(HISTTIMEFORMAT='' builtin history 1 2>/dev/null)"
  [[ "$raw" =~ ^[[:space:]]*([0-9]+)[[:space:]]+(.*)$ ]] || return 0
  idx="${BASH_REMATCH[1]}"; line="${BASH_REMATCH[2]}"

  [[ "$idx" == "${_ARXGUARD_IDX:-}" ]] && return "${_ARXGUARD_RC:-0}"
  _ARXGUARD_IDX="$idx"; _ARXGUARD_RC=0

  local reason rc
  ARXGUARD_INTERNAL=1; reason="$(_arxguard_scan_native "$line")"; rc=$?; unset ARXGUARD_INTERNAL

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

_arxguard_prev_debug="$(trap -p DEBUG 2>/dev/null | sed "s/^trap -- '//;s/' DEBUG\$//")"
if [[ -n "$_arxguard_prev_debug" && "$_arxguard_prev_debug" != *_arxguard_preexec* ]]; then
  trap "${_arxguard_prev_debug}; _arxguard_preexec" DEBUG
else
  trap '_arxguard_preexec' DEBUG
fi
unset _arxguard_prev_debug

export ARXGUARD_ACTIVE=bash
