# Saved state copied from Quickshell's per-shell state directory, which is
# keyed by a hash of the shell's path (the newest copy wins).
for f in appearance.json app-usage.json; do
  [[ -e $state/$f ]] && continue
  old=$(ls -t "$HOME"/.local/state/quickshell/by-shell/*/"$f" 2>/dev/null | head -1 || true)
  if [[ -n $old ]]; then
    mkdir -p "$state"
    cp -- "$old" "$state/$f"
    log "copied Quickshell's $f to ${state#"$HOME/"}"
  fi
done
