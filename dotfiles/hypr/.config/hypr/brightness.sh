#!/bin/bash
# Singularity - brightness
# ~/.config/hypr/brightness.sh
#
# The brightness keys, in 5% steps snapped to the grid (finer below 5%:
# 5 -> 1 -> 0).
#
#   brightness.sh up | down

read -r cur max < <(brightnessctl -m | awk -F, '{ print $3, $5 }')
pct=$(( (cur * 100 + max / 2) / max ))

case "$1" in
    up)
        if   (( pct < 1 )); then pct=1
        elif (( pct < 5 )); then pct=5
        else pct=$(( (pct / 5 + 1) * 5 ))
        fi ;;
    down)
        if   (( pct <= 1 )); then pct=0
        elif (( pct <= 5 )); then pct=1
        else pct=$(( ((pct + 4) / 5 - 1) * 5 ))
        fi ;;
    *)    echo "usage: $0 up|down" >&2; exit 1 ;;
esac

(( pct > 100 )) && pct=100
(( pct < 0 ))   && pct=0
brightnessctl -q set "$pct%"
