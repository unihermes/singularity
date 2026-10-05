# The Keybinds editor's undo copy, a whole hyprland.lua from before the
# config was split into modules. It now keeps binds.lua.bak, and undoing
# into binds.lua from the old copy would write the whole config there.
if [[ -f $state/hyprland.lua.bak ]]; then
  rm -- "$state/hyprland.lua.bak"
  log "removed ${state#"$HOME/"}/hyprland.lua.bak"
fi
