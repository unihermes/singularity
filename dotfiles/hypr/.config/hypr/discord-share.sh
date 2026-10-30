#!/usr/bin/env bash
# Starts or stops sharing the active window on Discord. Bound to ALT+SHIFT+S
# in binds.lua.
#
# Presses Discord's "Toggle Go Live Streaming" keybind, which has to be
# ALT+SHIFT+S in Discord's Keybinds settings, as key events Discord reads
# (Discord runs under XWayland, where it only sees keys sent to an X
# window, and Chromium drops them unless its window has focus). Discord is
# focused for the press and the active window gets focus back after. In a
# voice channel that opens the system picker, which share-picker.sh answers
# with the window noted here.
set -euo pipefail

discord=$(hyprctl clients | awk '/^Window /{a=$2} $1 == "class:" && $2 == "discord" {print a; exit}')
[[ -n $discord ]] || exit 0

active=$(hyprctl activewindow | awk '/^Window /{print $2; exit}')
printf '%s\n' "$active" >"${XDG_RUNTIME_DIR:-/tmp}/singularity-share-window"
focus() { hyprctl dispatch "hl.dsp.focus({ window = \"address:0x$1\" })" >/dev/null; }
[[ $active == "$discord" ]] || { focus "$discord"; sleep 0.05; }

# held modifiers ride along, so Discord's text box doesn't take the S. A
# separate "up" never reaches an X window (each send enters it afresh, with
# no keys down), so every release goes with a press through send_shortcut.
target="window = \"address:0x$discord\""
down() { hyprctl dispatch "hl.dsp.send_key_state({ mods = \"$1\", key = \"$2\", state = \"down\", $target })" >/dev/null; }
tap() { hyprctl dispatch "hl.dsp.send_shortcut({ mods = \"$1\", key = \"$2\", $target })" >/dev/null; }
down "" Shift_L
down SHIFT Alt_L
tap "SHIFT ALT" s
tap "SHIFT ALT" Alt_L
tap SHIFT Shift_L
[[ -z $active || $active == "$discord" ]] || { sleep 0.05; focus "$active"; }
