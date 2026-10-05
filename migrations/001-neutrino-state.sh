# Saved state moves from ~/.local/state/neutrino, its name before the rename.
if [[ -d $HOME/.local/state/neutrino && ! -e $state ]]; then
  mv "$HOME/.local/state/neutrino" "$state"
  log "moved ~/.local/state/neutrino to ${state#"$HOME/"}"
fi
