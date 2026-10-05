#!/usr/bin/env bash
# Link the dotfiles into $HOME and nothing else. No packages, no services, no
# sudo. Use this when you only want configs on a machine, or to relink after
# adding a new directory under dotfiles/.
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '\033[1;34m::\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

command -v stow &>/dev/null || die "stow is not installed: sudo pacman -S stow"
[[ -d dotfiles ]] || die "no dotfiles/ directory next to this script"

mkdir -p "$HOME/.config"
# systemd does not follow a drop-in *directory* that is itself a symlink, and
# stow links a whole directory whenever the target doesn't exist yet. Creating
# it first means stow links the .conf inside it instead, which systemd does
# read. Without this the wireplumber/bluez ordering drop-in is silently
# ignored on a fresh machine.
mkdir -p "$HOME/.config/systemd/user/wireplumber.service.d"

# Enumerate the packages explicitly rather than passing a `*/` glob. Two traps
# there: stow collects package names during option parsing, so a `--` before
# them terminates parsing and leaves stow with an empty list ("No packages to
# stow or unstow"), and `*/` hands it names with trailing slashes.
mapfile -t stow_pkgs < <(find dotfiles -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
(( ${#stow_pkgs[@]} > 0 )) || die "no package directories found under dotfiles/"

# Move real files out of the way before stowing. Apps write their own configs
# when none exist -- Hyprland regenerates ~/.config/hypr/hyprland.lua on every
# start without one -- and that file then blocks stow from linking ours, so the
# app keeps reading its own default forever. Nothing is deleted: conflicts go
# to a timestamped backup. This is the safe version of `stow --adopt`, which
# would instead pull the app's file into the repo over what you wrote.
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
        # ...unless it only looks real because a PARENT is a symlink into the
        # repo. stow links a whole directory when the target does not exist, so
        # ~/.config/hypr can be a link to dotfiles/hypr/.config/hypr, and the
        # files "inside" it are the repo's own. Moving one of those empties the
        # repo instead of protecting it. Test where the path really lands.
        # -ef compares device and inode after following every symlink, so this
        # asks exactly the right question: is the thing I am about to "rescue"
        # the very file I am about to link? Cheaper and more reliable than
        # comparing resolved path strings.
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

# One-off fixes for machines set up by an older Singularity, in
# migrations/NNN-name.sh. Each newer than the stamped number runs once, in
# order, in its own bash with $state, log and die; a fresh machine runs
# them all, so each checks before it changes anything. Take the next number
# for a new one and never renumber one that has shipped.
state="$HOME/.local/state/singularity"
stamp="$state/migration"
done_n=$(cat "$stamp" 2>/dev/null || echo 0)
export state
export -f log die
shopt -s nullglob
for m in migrations/[0-9][0-9][0-9]-*.sh; do
  n=$((10#${m:11:3}))
  (( n > done_n )) || continue
  bash -euo pipefail "$m" || die "migration $m failed"
  mkdir -p "$state"
  echo "$n" > "$stamp"
  done_n=$n
done

log "linking: ${stow_pkgs[*]}"
(cd dotfiles && stow -t "$HOME" -R "${stow_pkgs[@]}")

# File-manager bookmarks (GTK's, which Thunar shows in its side pane) for
# the usual folders. Not stowed: the paths hold the home directory, and the
# file manager rewrites the file as bookmarks are added, so it's written
# once, only where there's none yet.
bookmarks="$HOME/.config/gtk-3.0/bookmarks"
if [[ ! -e $bookmarks ]]; then
  mkdir -p "$(dirname "$bookmarks")"
  for d in Downloads Git Documents; do
    printf 'file://%s/%s\n' "$HOME" "$d"
  done > "$bookmarks"
  log "wrote ${bookmarks#"$HOME/"}"
fi

# The repo's own hooks (tools/git-hooks): the pre-commit checks (Settings
# search in step with the pages, nothing declared and never read, the JS
# module tests).
[[ -d .git ]] && git config core.hooksPath tools/git-hooks

log "done. verify a link with: ls -l ~/.config/hypr/hyprland.lua"
