# /etc/profile.d/arxguard.sh — activate the ARXOS command guard in interactive shells.
# Picks the right hook for the running shell. Zero cost in non-interactive shells.
case "$-" in *i*) ;; *) return 2>/dev/null || exit 0 ;; esac
ARXGUARD_LIB="${ARXGUARD_LIB:-/usr/share/arxguard}"
if [ -n "$BASH_VERSION" ]; then
  [ -r "$ARXGUARD_LIB/hook.bash" ] && . "$ARXGUARD_LIB/hook.bash"
elif [ -n "$ZSH_VERSION" ]; then
  [ -r "$ARXGUARD_LIB/hook.zsh" ] && . "$ARXGUARD_LIB/hook.zsh"
fi
