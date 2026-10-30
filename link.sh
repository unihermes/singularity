#!/usr/bin/env bash
# Links the dotfiles into $HOME, nothing else (no packages, services or
# sudo); rerun after adding a directory under dotfiles/.
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '\033[1;34m::\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

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

# the idle ladder's default per machine type (laptop's when unknown)
machine=$(cat "${XDG_STATE_HOME:-$HOME/.local/state}/singularity/machine" 2>/dev/null || true)
[[ $machine == desktop ]] || machine=laptop
seed "hypridle-$machine.defaults.conf" "$HOME/.config/hypr/hypridle.conf" "$machine default"
# a ladder from before the Hibernate step: its suspends go through
# idle-suspend.sh and the step is added, off
idle=$HOME/.config/hypr/hypridle.conf
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
