#!/usr/bin/env bash
# Bring this clone up to date and apply it: pull, relink, then install what
# packages/*.txt lists that isn't installed yet. Settings › Software Update
# runs it from its Singularity row.
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# log, warn, die, list
source ./scripts/lib.sh

# Everything sits in main so bash has read the whole script before the pull
# can rewrite it.
main() {
  local upstream before
  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null) \
    || die "this branch tracks no remote branch"
  before=$(git rev-parse HEAD)

  log "pulling $upstream"
  git pull --ff-only || die "can't fast-forward: commit or stash your changes, or merge by hand"
  if [[ $(git rev-parse HEAD) == "$before" ]]; then
    log "already up to date"
  else
    git -P log --format='   %h %s' "$before..HEAD"
  fi

  ./link.sh

  # Relinking records or reuses the profile; all consumers use its resolver.
  source ./scripts/hardware.sh
  local machine
  select_machine || return
  enable_multilib
  local -a lists extra=() more
  local f
  mapfile -t lists < <(machine_lists "$machine")
  for f in "${lists[@]}"; do
    mapfile -t more < <(list "$f")
    extra+=("${more[@]}")
  done
  split_repo_aur "${extra[@]}"

  local -a want new
  mapfile -t want < <(list packages/pacman.txt)
  want+=("${repo_pkgs[@]}")
  mapfile -t new < <(pacman -T "${want[@]}" || true)
  if (( ${#new[@]} > 0 )); then
    log "installing ${new[*]}"
    sudo pacman -S --needed "${new[@]}"
  fi

  # Not --noconfirm: the PKGBUILD diffs are worth reading, as in install.sh.
  mapfile -t want < <(list packages/aur.txt)
  want+=("${aur_pkgs[@]}")
  mapfile -t new < <(pacman -T "${want[@]}" || true)
  if (( ${#new[@]} > 0 )); then
    log "installing ${new[*]} from the AUR"
    yay -S --needed --answerclean None "${new[@]}"
  fi

  log "done"
}

main "$@"; exit
