#!/bin/bash
# Singularity - the terminal
# ~/.config/singularity/terminal.sh
#
# Starts the terminal Settings > Terminal picked (Alacritty or Ghostty);
# everything that opens a terminal goes through here. One set of flags:
#   terminal.sh [--class NAME] [--dir PATH] [-e|--] [COMMAND ARGS…]
#
#   --class   the window's class (its Wayland app id). Ghostty only takes a
#             valid GTK application id, so it has to contain a dot:
#             singularity.scratch, not singularity-scratch.
#   --dir     the working directory
#   COMMAND   run instead of the shell; everything after it is its own.
#             -e or -- before it is optional (wofi passes --).
set -u

state=${XDG_STATE_HOME:-$HOME/.local/state}/singularity/appearance.json
app=$(sed -n 's/^ *"terminalApp": *"\([a-z]*\)".*/\1/p' "$state" 2>/dev/null)
command -v "$app" >/dev/null 2>&1 || app=alacritty

class="" dir=""
while (($#)); do
    case $1 in
        --class) class=$2; shift 2 ;;
        --dir)   dir=$2; shift 2 ;;
        -e|--)   shift; break ;;
        *)       break ;;
    esac
done

args=()
case $app in
    ghostty)
        [[ -n $class ]] && args+=("--class=$class")
        [[ -n $dir ]] && args+=("--working-directory=$dir")
        ;;
    *)
        [[ -n $class ]] && args+=(--class "$class")
        [[ -n $dir ]] && args+=(--working-directory "$dir")
        ;;
esac
(($#)) && args+=(-e "$@")
exec "$app" "${args[@]}"
