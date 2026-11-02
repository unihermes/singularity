# Provisioning entry point. Runtime and installer share the same detector.
source "$(dirname "${BASH_SOURCE[0]}")/dotfiles/singularity/.config/singularity/platform.sh"

# the package lists that apply here: packages/hardware/CAP.txt for each CAP
# this machine has, then packages/MACHINE.txt when there is one
machine_lists() {
  local f cap
  for f in packages/hardware/*.txt; do
    [[ -e $f ]] || continue
    cap=${f##*/}; cap=${cap%.txt}
    if has "$cap"; then echo "$f"; fi
  done
  [[ -f packages/$1.txt ]] && echo "packages/$1.txt"
  return 0
}

# Splits package names into repo_pkgs (in a sync database, for pacman) and
# aur_pkgs (the rest, for yay), so one list can hold both.
split_repo_aur() {
  local p
  local -A repo
  repo_pkgs=() aur_pkgs=()
  while read -r p; do repo[$p]=1; done < <(pacman -Slq 2>/dev/null)
  for p in "$@"; do
    if [[ -n ${repo[$p]:-} ]]; then repo_pkgs+=("$p"); else aur_pkgs+=("$p"); fi
  done
}

# First interactive install offers the detected profile; updates reuse it.
select_machine() {
  local requested=${1:-} interactive=${2:-false} detected answer
  case $requested in
    laptop|desktop) machine=$requested ;;
    auto) machine=$(detect_machine) ;;
    "")
      machine=$(machine_type) || return
      if [[ ! -f ${XDG_STATE_HOME:-$HOME/.local/state}/singularity/machine && $interactive == true && -t 0 ]]; then
        detected=$machine
        while true; do
          read -r -p "Machine profile [desktop/laptop] ($detected): " answer || return 1
          case ${answer:-$detected} in
            laptop|desktop) machine=${answer:-$detected}; break ;;
            *) echo 'Choose desktop or laptop.' >&2 ;;
          esac
        done
      fi ;;
    *) echo "Unknown machine profile: $requested" >&2; return 2 ;;
  esac
}

save_machine() {
  local path=${XDG_STATE_HOME:-$HOME/.local/state}/singularity/machine
  mkdir -p "${path%/*}"
  local temporary
  temporary=$(mktemp "$path.XXXXXX")
  printf '%s\n' "$machine" > "$temporary"
  mv "$temporary" "$path"
}

machine_plan() {
  local cap
  printf 'Profile: %s\nHardware:' "$machine"
  for cap in "${hw_caps[@]}"; do if has "$cap"; then printf ' %s' "$cap"; fi; done
  printf '\nPolicies:'
  for cap in "${platform_features[@]}"; do
    if feature "$cap"; then printf ' %s' "$cap"; fi
  done
  printf '\nPackage lists:\n  packages/pacman.txt\n  packages/aur.txt\n'
  machine_lists "$machine" | sed 's/^/  /'
  printf 'Idle defaults: hypridle-%s.defaults.conf\n' "$machine"
}
