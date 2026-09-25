#!/bin/bash
# Singularity - brightness
# ~/.config/hypr/brightness.sh
#
# The brightness keys, in steps of 5% that always land on a multiple of 5,
# down to 0. A plain `brightnessctl set 5%-` steps from wherever the level
# is, so one odd value (from the slider, or a raw write) kept every later
# step off the grid.
#
#   brightness.sh up | down

read -r cur max < <(brightnessctl -m | awk -F, '{ print $3, $5 }')
pct=$(( (cur * 100 + max / 2) / max ))

case "$1" in
    up)   pct=$(( (pct / 5 + 1) * 5 )) ;;
    down) pct=$(( ((pct + 4) / 5 - 1) * 5 )) ;;
    *)    echo "usage: $0 up|down" >&2; exit 1 ;;
esac

(( pct > 100 )) && pct=100
(( pct < 0 ))   && pct=0
brightnessctl -q set "$pct%"
