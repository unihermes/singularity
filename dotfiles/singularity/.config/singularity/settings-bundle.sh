#!/usr/bin/env bash
# Carry the shell's settings to another machine.
#
#   settings-bundle export [FILE] [--calendars]
#   settings-bundle import FILE [--no-apply]
#
# The bundle holds what ~/.local/state/singularity keeps per user rather than
# per machine: appearance.json (every file generated from it is rebuilt when
# the shell starts), app usage, sticky notes, window rules, workspace layout
# pins and the wallpaper, with the image itself when it isn't one of the
# repo's own, and the looks removed from the Appearance page. Monitor layout,
# the primary display, the lid and Bluetooth state are left behind, as are
# the copies link.sh makes of the repo's defaults (keybinds, hypridle,
# hyprlock, alacritty, aliases): copy those by hand if you want them.
#
# calendars.conf holds secret feed addresses, so it only goes in with
# --calendars. Import backs up every file it replaces, then restarts the
# shell and reapplies the wallpaper unless --no-apply is given.
set -euo pipefail

state="$HOME/.local/state/singularity"
# relative to this script's real location, so the repo can live anywhere
repo="$(realpath -m "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../../..")"
files=(appearance.json app-usage.json notes.json window-rules.json workspace-layouts.json wallpaper.state looks-removed.json)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

log()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m!!\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  sed -n '4,5s/^#  //p' "${BASH_SOURCE[0]}" >&2
  exit 2
}

# a key from wallpaper.state's key=value lines
state_value() { sed -n "s/^$2=//p" "$1" 2>/dev/null | head -n 1; }

export_bundle() {
  local out="" calendars=0 arg
  for arg in "$@"; do
    case $arg in
      --calendars) calendars=1 ;;
      -*) usage ;;
      *) [[ -z $out ]] || usage; out=$arg ;;
    esac
  done
  out=${out:-$PWD/singularity-settings-$(date +%Y-%m-%d).tar.gz}

  mkdir -p "$tmp/state"

  local f
  for f in "${files[@]}"; do
    [[ -e $state/$f ]] && cp "$state/$f" "$tmp/state/" && log "Added $f"
  done
  if (( calendars )) && [[ -e $state/calendars.conf ]]; then
    cp "$state/calendars.conf" "$tmp/state/"
    warn "Added calendars.conf -- it holds secret feed addresses, keep the bundle private"
  fi

  # A wallpaper outside the repo won't exist on the other machine, so the
  # image travels with the bundle
  local wp; wp=$(state_value "$state/wallpaper.state" wallpaper)
  if [[ -n $wp && -f $wp && $wp != "$repo"/* ]]; then
    mkdir -p "$tmp/wallpaper"
    cp "$wp" "$tmp/wallpaper/"
    log "Added the wallpaper image, $(basename "$wp")"
  fi

  printf 'home=%s\nrepo=%s\n' "$HOME" "$repo" > "$tmp/bundle.info"
  tar -czf "$out" -C "$tmp" .
  log "Wrote $out"
}

import_bundle() {
  local in="" apply=1 arg
  for arg in "$@"; do
    case $arg in
      --no-apply) apply=0 ;;
      -*) usage ;;
      *) [[ -z $in ]] || usage; in=$arg ;;
    esac
  done
  [[ -n $in ]] || usage
  [[ -f $in ]] || die "No such file: $in"

  tar -xzf "$in" -C "$tmp"
  [[ -f $tmp/bundle.info ]] || die "$in is not a settings bundle"

  mkdir -p "$state"
  local backup
  backup="$state/backup-$(date +%Y-%m-%d_%H-%M-%S)"

  local f
  for f in "$tmp"/state/*; do
    [[ -e $f ]] || continue
    f=${f##*/}
    if [[ -e $state/$f ]]; then
      mkdir -p "$backup"
      cp -p "$state/$f" "$backup/"
    fi
    cp "$tmp/state/$f" "$state/$f"
    [[ $f == calendars.conf ]] && chmod 600 "$state/$f"
    log "Imported $f"
  done
  [[ -d $backup ]] && log "Replaced files are in $backup"

  # Point the wallpaper at this machine's copy: the repo's own images under
  # this repo, anything else at the image that came in the bundle
  if [[ -f $state/wallpaper.state ]]; then
    local wp old_repo old_home new=""
    wp=$(state_value "$state/wallpaper.state" wallpaper)
    old_repo=$(state_value "$tmp/bundle.info" repo)
    old_home=$(state_value "$tmp/bundle.info" home)
    if [[ -n $wp && -n $old_repo && $wp == "$old_repo"/* ]]; then
      new=$repo${wp#"$old_repo"}
    elif [[ -n $wp && -f $tmp/wallpaper/${wp##*/} ]]; then
      new="$HOME/.local/share/singularity/wallpapers/${wp##*/}"
      mkdir -p "${new%/*}"
      cp "$tmp/wallpaper/${wp##*/}" "$new"
    elif [[ -n $wp && -n $old_home && $wp == "$old_home"/* ]]; then
      new=$HOME${wp#"$old_home"}
    fi
    if [[ -n $new && $new != "$wp" ]]; then
      local line
      line=$(printf 'wallpaper=%s' "$new" | sed 's/[&|\\]/\\&/g')
      sed -i "s|^wallpaper=.*|$line|" "$state/wallpaper.state"
      wp=$new
    fi
    [[ -z $wp || -f $wp ]] || warn "The wallpaper, $wp, isn't on this machine"
  fi

  (( apply )) || return 0
  if pgrep -x quickshell >/dev/null; then
    # Settings reads appearance.json once, at start
    log "Restarting the shell"
    qs kill >/dev/null 2>&1 || true
    sleep 0.3
    setsid quickshell > "$HOME/.cache/quickshell.log" 2>&1 < /dev/null &
  fi
  if pgrep -x Hyprland >/dev/null; then
    log "Reapplying the wallpaper"
    "$HOME/.config/hypr/wallpaper.sh" >/dev/null 2>&1 || warn "wallpaper.sh failed"
  fi
}

case "${1:-}" in
  export) shift; export_bundle "$@" ;;
  import) shift; import_bundle "$@" ;;
  *) usage ;;
esac
