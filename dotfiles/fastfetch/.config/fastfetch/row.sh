# One line of config.jsonc's info block:
#   . row.sh LABEL [VALUE]    an icon, the label and its value
#   . row.sh --title          user@host in an accent capsule
#   . row.sh --head NAME      a section name in a capsule, ruled to the width
#   . row.sh --swatches       the look's ramp and accent
#
# Sourced, not run: fastfetch finds the terminal by walking up the process
# tree, and a shell of its own between the two fastfetch processes makes the
# Terminal row report "fastfetch".
#
# With no VALUE, LABEL is also the fastfetch module to ask. The nested call
# runs with `-c none` so it doesn't load config.jsonc again and recurse.
#
# Colours, capsule shape and heading case come from term-colors.sh, which
# Quickshell (AppearanceSync.qml) writes for the current look. The block is
# 46 columns so logo and block together fit a half-screen terminal.
N_SURFACE='26;26;26' N_OVERLAY='36;36;36' N_BORDER='48;48;48'
N_MUTED='77;77;77' N_SUBTEXT='122;122;122' N_TEXT='208;226;250'
N_BRIGHT='235;235;235' N_ACCENT='85;85;200' N_ON_ACCENT='235;235;235'
N_HEADING=$N_BRIGHT T_ROUND=1 T_UPPER=1
. "$HOME/.local/state/singularity/term-colors.sh" 2>/dev/null
W=46

# a capsule: ground, foreground, text; round caps only when the look has a radius
cap() {
  if (( T_ROUND )); then
    printf '\033[38;2;%sm\ue0b6\033[1;38;2;%s;48;2;%sm%s\033[0;38;2;%sm\ue0b4\033[0m' "$1" "$2" "$1" "$3" "$1"
  else
    printf '\033[1;38;2;%s;48;2;%sm %s \033[0m' "$2" "$1" "$3"
  fi
}

case $1 in
  --title)
    cap "$N_ACCENT" "$N_ON_ACCENT" $'\uf007 '"$(whoami)@$(uname -n)"
    ;;
  --head)
    h=$2
    (( T_UPPER )) || { h=${h,,}; h=${h^}; }
    rule=$(printf -- '─%.0s' $(seq 1 $(( W - ${#h} - 3 ))))
    cap "$N_OVERLAY" "$N_HEADING" "$h"
    printf ' \033[38;2;%sm%s\033[0m' "$N_BORDER" "$rule"
    ;;
  --swatches)
    for c in "$N_SURFACE" "$N_OVERLAY" "$N_BORDER" "$N_MUTED" "$N_SUBTEXT" "$N_TEXT" "$N_BRIGHT" "$N_ACCENT"; do
      printf '\033[38;2;%sm██' "$c"
    done
    printf '\033[0m'
    ;;
  *)
    label=$1
    if (( $# > 1 )); then
      v=$2
    else
      v=$(fastfetch -c none -s "$label" --logo none --separator $'\x1f' 2>/dev/null)
      v=${v#*$'\x1f'}
    fi
    # vendor noise that costs width and says nothing
    v=${v//(R)/}; v=${v//(TM)/}; v=${v/ \[Integrated\]/}; v=${v/ Graphics/}
    [[ $v =~ ^[0-9]+th\ Gen\ (.*) ]] && v=${BASH_REMATCH[1]}
    [[ $label == Disk ]] && v=${v% - *}
    [[ $label == Icons ]] && v=${v%% \[*}
    [[ $v =~ ^(.*)\ \([0-9]+\+[0-9]+\)(.*)$ ]] && v=${BASH_REMATCH[1]}${BASH_REMATCH[2]}
    case $label in
      CPU) i=$'\uf4bc';; GPU) i=$'\U000f08ae';; Memory) i=$'\U000f035b';; Disk) i=$'\U000f02ca';;
      OS) i=$'\uf303';; Kernel) i=$'\uf17c';; Shell) i=$'\uf489';; WM) i=$'\uf2d2';;
      Terminal) i=$'\ue795';; Icons) i=$'\U000f003b';; Uptime) i=$'\U000f0150';; Packages) i=$'\U000f03d6';;
      Processes) i=$'\uf085';; Age) i=$'\U000f00ed';; *) i=' ';;
    esac
    max=$(( W - 14 ))
    (( ${#v} > max )) && v="${v:0:max-1}…"
    printf '  \033[38;2;%sm%s %-10s\033[38;2;%sm%s\033[0m' "$N_SUBTEXT" "$i" "$label" "$N_TEXT" "$v"
    ;;
esac
