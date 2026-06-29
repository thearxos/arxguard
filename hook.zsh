# arxguard zsh hook — pre-execution zero-trust screen for interactive zsh.
# zsh's preexec runs before a command but cannot abort it, so on zsh arxguard is
# WARN-ONLY (it shows CRITICAL findings prominently but cannot block). For
# guaranteed blocking, use bash as the interactive shell. Calls `arxguard check`
# (one cheap call per typed line) so the zsh path reuses the exact same scanner.

[[ -o interactive ]] || return 0
[[ -n "$_ARXGUARD_ZSH_LOADED" ]] && return 0
_ARXGUARD_ZSH_LOADED=1

_arxguard_zsh_preexec() {
  [[ "${ARXGUARD:-1}" == "0" ]] && return 0
  local line="$1" reason rc
  reason="$(command arxguard check -- "$line" 2>/dev/null)"; rc=$?
  if (( rc == 1 )); then
    print -u2 -P "%F{red}%B  arxguard: CRITICAL (zsh cannot block — review before it runs)%b%f"
    print -u2 -- "$reason" | sed 's/^/    /'
    print -u2 -P "%F{8}  bypass the warning with:%f ARXGUARD=0 <command>"
  elif (( rc == 2 )); then
    print -u2 -P "%F{yellow}%B  arxguard: warning%b%f"
    print -u2 -- "$reason" | sed 's/^/    /'
  fi
  return 0
}
typeset -ga preexec_functions
preexec_functions+=(_arxguard_zsh_preexec)
export ARXGUARD_ACTIVE=zsh
