#!/usr/bin/env bash
# Screenshot, saved to disk and copied to the clipboard. Bound to Print and
# its modifiers in hyprland.lua.
#
#   screenshot.sh [area]   drag out a region with slurp
#   screenshot.sh window   the active window
#   screenshot.sh screen   the focused monitor
#
# The notification offers Annotate when satty is installed; it edits the
# saved file in place.
set -euo pipefail

dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
file="$dir/screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"

# hyprctl's plain output, so this needs no jq
focused_monitor() {
  hyprctl monitors | awk '/^Monitor /{name=$2} /focused: yes/{print name; exit}'
}

window_geometry() {
  hyprctl activewindow | awk '
    $1 == "at:"   { split($2, a, ",") }
    $1 == "size:" { split($2, s, ",") }
    END { if (s[1] > 0) printf "%d,%d %dx%d\n", a[1], a[2], s[1], s[2] }'
}

case "${1:-area}" in
  area)
    geometry=$(slurp) || exit 0   # empty on Esc/cancel -- nothing to capture
    [[ -n $geometry ]] || exit 0
    grim -g "$geometry" "$file" ;;
  window)
    geometry=$(window_geometry)
    # no window focused: the monitor is the closest thing to what was asked
    if [[ -n $geometry ]]; then grim -g "$geometry" "$file"
    else grim -o "$(focused_monitor)" "$file"; fi ;;
  screen)
    grim -o "$(focused_monitor)" "$file" ;;
  *)
    echo "usage: ${0##*/} [area|window|screen]" >&2
    exit 2 ;;
esac
wl-copy --type image/png < "$file"

actions=()
command -v satty &>/dev/null && actions=(-A annotate=Annotate)

# -A makes notify-send wait for the notification to close, and print the
# action's key if one was clicked
choice=$(notify-send -a Screenshot -i "$file" "${actions[@]}" \
  "Screenshot saved" "$(basename "$file")" 2>/dev/null) || true

if [[ $choice == annotate ]]; then
  satty --filename "$file" --output-filename "$file" --copy-command wl-copy
fi
