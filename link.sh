#!/usr/bin/env bash
# Links the dotfiles into $HOME, nothing else (no packages, services or
# sudo); rerun after adding a directory under dotfiles/.
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source ./scripts/lib.sh
source ./scripts/hardware.sh

(( $# <= 1 )) || die "usage: ./link.sh [laptop|desktop|auto]"
select_machine "${1:-}" || exit $?
save_machine

command -v stow &>/dev/null || die "stow is not installed: sudo pacman -S stow"
[[ -d dotfiles ]] || die "no dotfiles/ directory next to this script"

mkdir -p "$HOME/.config"
# systemd won't follow a symlinked drop-in directory, so it's created and
# stow links the .conf inside
mkdir -p "$HOME/.config/systemd/user/wireplumber.service.d"

# packages listed explicitly: stow with `--` or a `*/` glob gets no packages
mapfile -t stow_pkgs < <(find dotfiles -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
(( ${#stow_pkgs[@]} > 0 )) || die "no package directories found under dotfiles/"

# Real files in the way (an app's self-written default) are moved to a
# timestamped backup before stowing; the safe version of `stow --adopt`.
backup_conflicts() {
  local backup="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
  local repo="$PWD"
  local pkg src rel target real moved=0
  for pkg in "${stow_pkgs[@]}"; do
    while IFS= read -r -d "" src; do
      rel=${src#"dotfiles/$pkg/"}
      target="$HOME/$rel"
      # A symlink is either already ours or stow's to replace. Only a real
      # file is a genuine conflict.
      if [[ -f $target && ! -L $target ]]; then
        # ...unless it's the repo's own file through a parent link (-ef
        # compares inodes after following links)
        if [[ $target -ef $src ]]; then
          continue
        fi
        real=$(readlink -f "$target" 2>/dev/null || true)
        if [[ -n $real && $real == "$repo"/* ]]; then
          continue
        fi
        mkdir -p "$backup/$(dirname "$rel")"
        mv "$target" "$backup/$rel"
        log "  displaced $rel"
        moved=1
      fi
    done < <(find "dotfiles/$pkg" -type f -print0)
  done
  (( moved )) && log "originals saved in $backup"
  return 0
}

backup_conflicts

log "linking: ${stow_pkgs[*]}"
(cd dotfiles && stow -t "$HOME" -R "${stow_pkgs[@]}")

# The files Settings rewrites are this machine's own: copied once from
# ~/.config/singularity defaults where missing, git-ignored. A dangling link
# from an older checkout goes first.
defaults=dotfiles/singularity/.config/singularity
seed() {
  local src=$defaults/$1 dst=$2 dir
  dir=$(dirname "$dst")
  [[ -L $dir && ! -e $dir ]] && rm -f "$dir"
  [[ -L $dst && ! -e $dst ]] && rm -f "$dst"
  [[ -e $dst ]] && return 0
  mkdir -p "$dir"
  cp "$src" "$dst"
  log "wrote ${dst#"$HOME/"}${3:+ ($3)}"
}

# Track which profile supplied the idle ladder. A deliberate profile change
# keeps a backup of custom timings before seeding the new policy.
idle_profile=${XDG_STATE_HOME:-$HOME/.local/state}/singularity/idle-profile
previous=$(cat "$idle_profile" 2>/dev/null || true)
idle=$HOME/.config/hypr/hypridle.conf
if [[ -z $previous && -f $idle ]]; then
  if grep -q "desktop's default" "$idle"; then previous=desktop
  elif grep -q "laptop's default" "$idle"; then previous=laptop; fi
fi
if [[ -n $previous && $previous != "$machine" && -f $idle ]]; then
  mv "$idle" "$idle.$previous.$(date +%Y%m%d-%H%M%S).bak"
fi
seed "hypridle-$machine.defaults.conf" "$HOME/.config/hypr/hypridle.conf" "$machine default"
printf '%s\n' "$machine" > "$idle_profile"
# Keep existing timings and enabled steps while routing sleep by hardware.
sed -i -e 's#~/.config/hypr/lid.sh sleep#~/.config/hypr/sleep.sh sleep#g' \
  -e 's#~/.config/hypr/lid.sh resume#~/.config/hypr/sleep.sh resume#g' \
  -e 's#= brightnessctl -s set 1%#= [ -n "$(ls -A /sys/class/backlight)" ] \&\& brightnessctl -c backlight -s set 1%#' \
  -e 's#= brightnessctl -r#= [ -n "$(ls -A /sys/class/backlight)" ] \&\& brightnessctl -c backlight -r#' "$idle"
sed -i 's#= grep -qsx 1 /sys/class/power_supply/\*/online || ~/.config/hypr/idle-suspend.sh$#= ~/.config/singularity/platform.sh has battery \&\& { grep -qsx 1 /sys/class/power_supply/*/online || ~/.config/hypr/idle-suspend.sh; }#' "$idle"
if ! grep -q 'systemctl hibernate' "$idle"; then
  sed -i -E 's#^([[:space:]]*(\#~ ?)?[[:space:]]*on-timeout[[:space:]]*=.*)systemctl suspend$#\1~/.config/hypr/idle-suspend.sh#' "$idle"
  sed -n '/^# 1 h: hibernate/,$p' "$defaults/hypridle-$machine.defaults.conf" | sed '1i\\' >> "$idle"
  log "hypridle.conf: added the Hibernate step (off)"
fi
seed binds.defaults.lua          "$HOME/.config/hypr/binds.lua"
# binds added to the defaults since the last run go into binds.lua too
if command -v node &>/dev/null; then
  node tools/merge-binds.mjs "$defaults/binds.defaults.lua" "$HOME/.config/hypr/binds.lua" \
    "${XDG_STATE_HOME:-$HOME/.local/state}/singularity/binds.seen.lua" | while IFS= read -r line; do log "binds.lua: $line"; done \
    || log "binds.lua: the new defaults couldn't be merged in"
fi
seed hyprlock.defaults.conf      "$HOME/.config/hypr/hyprlock.conf"
if ! has fingerprint; then
  sed -i -E 's/^( *fingerprint:enabled *= *)true/\1false/' "$HOME/.config/hypr/hyprlock.conf"
fi
# the Discord share bind and its picker are gone: drop the bind from
# binds.lua and the xdph.conf that pointed the portal at the picker
binds=$HOME/.config/hypr/binds.lua
if grep -q 'discord-share\.sh' "$binds" 2>/dev/null; then
  sed -i -e '/^-- --- Discord ---$/d' -e '/Toggle Go Live Streaming keybind/d' -e '/discord-share\.sh/d' "$binds"
  log "removed the Discord share bind from ${binds#"$HOME/"}"
fi
xdph=$HOME/.config/hypr/xdph.conf
if grep -q 'share-picker\.sh' "$xdph" 2>/dev/null; then
  rm -f "$xdph"
  log "removed ${xdph#"$HOME/"}"
  systemctl --user try-restart xdg-desktop-portal-hyprland.service 2>/dev/null || true
fi
seed alacritty.defaults.toml     "$HOME/.config/alacritty/alacritty.toml"
seed ghostty.defaults.ghostty    "$HOME/.config/ghostty/config.ghostty"
seed bash_aliases.defaults.sh    "$HOME/.bash_aliases"

# GTK bookmarks for the usual folders, written once (holds $HOME, and the
# file manager rewrites it)
bookmarks="$HOME/.config/gtk-3.0/bookmarks"
if [[ ! -e $bookmarks ]]; then
  mkdir -p "$(dirname "$bookmarks")"
  for d in Downloads Git Documents; do
    printf 'file://%s/%s\n' "$HOME" "$d"
  done > "$bookmarks"
  log "wrote ${bookmarks#"$HOME/"}"
fi

# the repo's pre-commit hooks, and pulls that rebase onto the other
# machine's commits instead of merging (local changes stashed round it,
# fixup! commits folded in, deleted remote branches pruned)
if [[ -d .git ]]; then
  git config core.hooksPath tools/git-hooks
  git config pull.rebase true
  git config rebase.autoStash true
  git config rebase.autoSquash true
  git config fetch.prune true
fi

log "done. verify a link with: ls -l ~/.config/hypr/hyprland.lua"
