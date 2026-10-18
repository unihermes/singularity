#!/bin/bash
# Singularity - lock screen info line
# ~/.config/hypr/lock-info.sh
#
# The line under hyprlock's clock: the date if asked, then the shell's
# lock-info state (track, unread count), joined by middle dots.
#
#   lock-info.sh [date]

parts=()
[[ $1 == date ]] && parts+=("$(date +'%A, %B %-d')")
info="${XDG_STATE_HOME:-$HOME/.local/state}/singularity/lock-info"
if [[ -s $info ]]; then
    while IFS= read -r line; do
        [[ -n $line ]] && parts+=("$line")
    done < "$info"
fi

out=""
for p in "${parts[@]}"; do
    out+="${out:+  ·  }$p"
done
printf '%s\n' "$out"
