# Links into packages since removed from dotfiles/. stow only touches the
# packages it's handed, so it never clears these, and they're left dangling.
#   ~/.icons  the XCursor fallback, now written by the shell (AppearanceSync)
#   ~/.config/swaync  notifications, now the shell's own
for old in "$HOME/.icons" "$HOME/.config/swaync"; do
  if [[ -L $old && ! -e $old && $(readlink -- "$old") == *dotfiles/* ]]; then
    rm -- "$old"
    log "  removed stale link ${old#"$HOME/"}"
  fi
done
