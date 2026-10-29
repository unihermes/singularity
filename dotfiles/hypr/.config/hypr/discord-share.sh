#!/usr/bin/env bash
# Starts or stops sharing the active window on Discord. Bound to ALT+SHIFT+S
# in binds.lua.
#
# Presses Discord's "Toggle Go Live Streaming" keybind, which has to be
# ALT+SHIFT+S in Discord's Keybinds settings, as key events Discord reads
# (Discord runs under XWayland, where it only sees keys sent to an X
# window). In a voice channel that opens the system picker, which
# share-picker.sh answers with the window noted here.
set -euo pipefail

discord=$(hyprctl clients | awk '/^Window /{a=$2} $1 == "class:" && $2 == "discord" {print a; exit}')
[[ -n $discord ]] || exit 0

hyprctl activewindow | awk '/^Window /{print $2; exit}' >"${XDG_RUNTIME_DIR:-/tmp}/singularity-share-window"

# held modifiers ride along, so Discord's text box doesn't take the S
key() {
  hyprctl dispatch "hl.dsp.send_key_state({ mods = \"$1\", key = \"$2\", state = \"$3\", window = \"address:0x$discord\" })" >/dev/null
}
key "" Shift_L down
key SHIFT Alt_L down
key "SHIFT ALT" s down
key "SHIFT ALT" s up
key SHIFT Alt_L up
key "" Shift_L up
