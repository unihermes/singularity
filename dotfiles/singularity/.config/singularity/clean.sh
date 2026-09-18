#!/usr/bin/env bash
# Free disk space: package caches, orphaned packages, old journals, stale user
# caches. Everything removed here is regenerated on demand -- nothing is a
# config or a document. Orphaned packages and the trash go too. After the sudo
# prompt at the start it runs to the end without asking anything.
set -uo pipefail

log()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
have() { command -v "$1" &>/dev/null; }

# Used space on / and $HOME, in KiB, so the summary can report what was freed.
# Keyed on the device so a single filesystem holding both is counted once.
used() { df -k --output=source,used / "$HOME" | awk 'NR>1 && !seen[$1]++ {t+=$2} END {print t}'; }
before=$(used)

# Ask for the password once up front rather than in the middle of the run.
sudo -v || exit 1
# Keep the credential fresh so a slow step can't outlast sudo's timeout and
# prompt again halfway through.
while sleep 50; do sudo -n true; kill -0 $$ 2>/dev/null || exit; done &>/dev/null &
trap 'kill $! 2>/dev/null' EXIT

# Pacman keeps every version it ever downloaded. Keep the last two of each
# installed package so a bad upgrade can still be rolled back, and drop all
# of them for packages that are no longer installed.
if have paccache; then
  log "Trimming pacman cache"
  sudo paccache -rk2 -q
  sudo paccache -ruk0 -q
else
  warn "paccache missing (pacman-contrib), skipping pacman cache"
fi

# yay leaves full git clones and build trees for every AUR package it has
# built. They are only a head start for the next rebuild.
if [[ -d $HOME/.cache/yay ]]; then
  log "Clearing yay build cache"
  rm -rf "$HOME/.cache/yay"
fi

# Dependencies nothing depends on any more. Named in the output because an
# optional dependency you use directly can show up here too; reinstall it with
# `pacman -S --asexplicit` to keep it off this list.
mapfile -t orphans < <(pacman -Qdtq 2>/dev/null)
if (( ${#orphans[@]} )); then
  log "Removing orphaned packages: ${orphans[*]}"
  sudo pacman -Rns --noconfirm "${orphans[@]}"
fi

log "Vacuuming journal to 2 weeks / 200M"
sudo journalctl --vacuum-time=2weeks --vacuum-size=200M -q

if [[ -d /var/lib/systemd/coredump ]]; then
  log "Removing core dumps"
  sudo find /var/lib/systemd/coredump -type f -delete
fi

# Language package manager caches: downloads kept only to speed up the next
# install.
have pip   && { log "Purging pip cache";  pip cache purge &>/dev/null; }
have npm   && { log "Cleaning npm cache"; npm cache clean --force &>/dev/null; }
have pnpm  && { log "Pruning pnpm store"; pnpm store prune &>/dev/null; }
have cargo && [[ -d $HOME/.cargo/registry/cache ]] && {
  log "Clearing cargo download cache"; rm -rf "$HOME/.cargo/registry/cache"; }
have go    && { log "Cleaning go module cache"; go clean -modcache &>/dev/null; }

have flatpak && { log "Removing unused flatpak runtimes"; flatpak uninstall --unused -y --noninteractive; }
# prune only ever touches stopped containers, dangling images and unused
# networks.
have docker  && { log "Pruning docker"; docker system prune -f; }

log "Clearing thumbnails"
rm -rf "$HOME/.cache/thumbnails"

# Anything in ~/.cache nobody has read in a month. Covers Spotify, shader and
# similar caches without wiping what running apps are actively using.
#
# Browsers are handled separately. Cookies, logins, extensions and site storage
# live in the profile (~/.config/zen, ~/.mozilla, ...), which this never goes
# near, but the ~/.cache side still holds safebrowsing lists and remote
# settings. Of that, only the HTTP cache (cache2) is swept.
browsers=(zen floorp mozilla firefox librewolf chromium google-chrome BraveSoftware vivaldi)
skip=()
# -not -path rather than -prune: -delete implies -depth, which disables -prune.
for b in "${browsers[@]}"; do skip+=(-not -path "$HOME/.cache/$b" -not -path "$HOME/.cache/$b/*"); done

log "Removing ~/.cache files unused for 30+ days"
find "$HOME/.cache" -type f "${skip[@]}" -atime +30 -delete 2>/dev/null
for b in "${browsers[@]}"; do
  [[ -d $HOME/.cache/$b ]] || continue
  find "$HOME/.cache/$b" -type d -name cache2 -prune \
    -exec find {} -type f -atime +30 -delete \; 2>/dev/null
done
find "$HOME/.cache" -mindepth 1 -type d "${skip[@]}" -empty -delete 2>/dev/null

trash=$HOME/.local/share/Trash
if [[ -n $(ls -A "$trash/files" 2>/dev/null) ]]; then
  log "Emptying trash ($(du -sh "$trash" | cut -f1))"
  rm -rf "$trash/files" "$trash/info" && mkdir -p "$trash/files" "$trash/info"
fi

freed=$(( before - $(used) ))
(( freed < 0 )) && freed=0
log "Done, freed $(numfmt --to=iec --from-unit=1024 "$freed")"
