#!/usr/bin/env bash
# Singularity - wallpaper
# ~/.config/hypr/wallpaper.sh
#
#   wallpaper.sh            at login: the saved wallpaper, or a random one when
#                           shuffle is on or nothing is saved yet
#   wallpaper.sh set PATH [MODE]  show PATH now, fitted by MODE (swaybg's
#                           fill, fit, center or tile; the saved one if left out)
#   wallpaper.sh list       every image in wallpapers/, one per line
#   wallpaper.sh current    the image swaybg is showing
#
# The choice is in wallpaper.state (key=value, no jq needed), written by
# Wallpaper.qml.
set -euo pipefail

# relative to this script's real location, so the repo can live anywhere
wallpaper_dir="$(realpath -m "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../../../wallpapers")"
state="${XDG_STATE_HOME:-$HOME/.local/state}/singularity/wallpaper.state"
# the image on screen, for hyprlock.conf's background
current_link="${XDG_STATE_HOME:-$HOME/.local/state}/singularity/current-wallpaper"

list() {
  find "$wallpaper_dir" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort
}

# the saved fit, "fill" until one is saved
saved_mode() {
  local m=fill k v
  if [[ -r $state ]]; then
    while IFS='=' read -r k v; do [[ $k == mode ]] && m=$v; done < "$state"
  fi
  echo "$m"
}

fade_secs=1.7

# Keep the old surface until the new one is mapped and fully faded in on
# every monitor, then for the fade-in to finish. Image decoding can take longer
# than a fixed delay, especially when several wallpaper changes arrive together.
show() {
  local old pid mode=${2:-$(saved_mode)} ready=0
  case $mode in fill|fit|center|tile) ;; *) mode=fill ;; esac
  mkdir -p "${current_link%/*}"
  exec 9>"${XDG_RUNTIME_DIR:-/tmp}/singularity-wallpaper-${UID}.lock"
  flock 9
  old=$(pgrep -x swaybg || true)
  swaybg -i "$1" -m "$mode" 9>&- &>/dev/null &
  pid=$!
  disown
  for ((attempt = 0; attempt < 100; attempt++)); do
    kill -0 "$pid" 2>/dev/null || break
    if hyprctl -j monitors > "${current_link%/*}/wallpaper-monitors.$$.tmp" 2>/dev/null &&
       hyprctl -j layers > "${current_link%/*}/wallpaper-layers.$$.tmp" 2>/dev/null &&
       python3 - "$pid" "${current_link%/*}/wallpaper-monitors.$$.tmp" "${current_link%/*}/wallpaper-layers.$$.tmp" <<'PY'
import json, sys
try:
    pid = int(sys.argv[1])
    with open(sys.argv[2]) as f:
        monitors = json.load(f)
    with open(sys.argv[3]) as f:
        layers = json.load(f)
    names = [m['name'] for m in monitors if not m.get('disabled', False)]
    ready = bool(names) and all(any(layer.get('pid') == pid and layer.get('namespace') == 'wallpaper'
                                    and layer.get('alpha', 0) >= 0.99
                                    for level in layers.get(name, {}).get('levels', {}).values()
                                    for layer in level) for name in names)
    sys.exit(0 if ready else 1)
except (OSError, ValueError, KeyError, TypeError):
    sys.exit(1)
PY
    then
      ready=1
      break
    fi
    sleep 0.1
  done
  rm -f "${current_link%/*}/wallpaper-monitors.$$.tmp" "${current_link%/*}/wallpaper-layers.$$.tmp"
  if (( ! ready )); then
    kill "$pid" 2>/dev/null || true
    echo "wallpaper failed to appear on every monitor: $1" >&2
    return 1
  fi
  ln -sfn "$1" "$current_link"
  if [[ -n $old ]]; then
    # the layer's reported alpha is 1 from the first frame, so wait out the
    # fade-in (looks.lua's fadeLayersIn, 1.5s) before removing the old one
    sleep "$fade_secs"
    kill $old 2>/dev/null || true
  fi
}

case "${1:-login}" in
  list) list ;;
  current)
    pid=$(pgrep -xn swaybg) || exit 0
    tr '\0' '\n' < "/proc/$pid/cmdline" | sed -n '/^-i$/{n;p;q}'
    ;;
  set)
    [[ -f ${2:-} ]] || { echo "no such image: ${2:-}" >&2; exit 1; }
    show "$2" "${3:-}"
    ;;
  login)
    shuffle=1 saved=""
    if [[ -r $state ]]; then
      while IFS='=' read -r k v; do
        case $k in
          shuffle) shuffle=$v ;;
          wallpaper) saved=$v ;;
        esac
      done < "$state"
    fi
    if [[ $shuffle != 1 && -f $saved ]]; then
      show "$saved"
    else
      mapfile -t images < <(list)
      (( ${#images[@]} > 0 )) || exit 0
      show "${images[RANDOM % ${#images[@]}]}"
    fi
    ;;
  *) echo "usage: wallpaper.sh [login | set PATH [MODE] | list | current]" >&2; exit 2 ;;
esac
