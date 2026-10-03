# One line of config.jsonc's info block:
#   . row.sh LABEL [VALUE]    an icon, the label and its value
#   . row.sh --title          user@host in an accent capsule, the look's
#                             ramp and accent as swatches at the right
#   . row.sh --head NAME      a section name over a rule that fades out
#
# No outline: sections are set apart by their headings and a blank line
# (config.jsonc's "break" modules). Memory and Disk show a meter.
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
# The block is W columns: with the 64-column logo and its 1-column gap the
# whole thing is 115, which fits a half-screen terminal (about 116).
N_SURFACE='26;26;26' N_OVERLAY='36;36;36' N_BORDER='48;48;48'
N_MUTED='77;77;77' N_SUBTEXT='122;122;122' N_TEXT='208;226;250'
N_BRIGHT='235;235;235' N_ACCENT='85;85;200' N_ON_ACCENT='235;235;235'
T_ROUND=1 T_UPPER=1
. "$HOME/.local/state/singularity/term-colors.sh" 2>/dev/null
W=50

# a capsule: ground, foreground, text; round caps only when the look has a radius
cap() {
  if (( T_ROUND )); then
    printf '\033[38;2;%sm\033[1;38;2;%s;48;2;%sm%s\033[0;38;2;%sm\033[0m' "$1" "$2" "$1" "$3" "$1"
  else
    printf '\033[1;38;2;%s;48;2;%sm %s \033[0m' "$2" "$1" "$3"
  fi
}

# a W-34-cell meter for "USED UNIT / TOTAL UNIT (PCT%)": the figures, rounded to
# 3 significant digits and sharing the unit when both have it, then the bar
meter() {
  [[ $1 =~ ^([0-9.]+)\ ([A-Za-z]+)\ /\ ([0-9.]+)\ ([A-Za-z]+)\ \(([0-9]+)%\) ]] || { printf '\033[38;2;%sm%s' "$N_TEXT" "$1"; return; }
  local u=${BASH_REMATCH[1]} uu=${BASH_REMATCH[2]} t=${BASH_REMATCH[3]} tu=${BASH_REMATCH[4]} p=${BASH_REMATCH[5]} f d
  d=1; [[ ${t%.*} -ge 100 ]] && d=0
  if [[ $uu == "$tu" ]]; then
    printf -v f '%.*f / %.*f %s' $d "$u" $d "$t" "$tu"
  else
    printf -v f '%.*f %s / %.*f %s' $d "$u" "$uu" $d "$t" "$tu"
  fi
  local n=$(( W - 34 )) on=$(( (p * (W - 34) + 50) / 100 ))
  printf '\033[38;2;%sm%-15s\033[38;2;%sm%s\033[38;2;%sm%s\033[38;2;%sm%4s%%' \
    "$N_TEXT" "$f" "$N_ACCENT" "$(printf -- '━%.0s' $(seq 1 $on))" \
    "$N_BORDER" "$( (( on < n )) && printf -- '━%.0s' $(seq 1 $(( n - on ))))" "$N_SUBTEXT" "$p"
}

case $1 in
  --title)
    t=$' '"$(whoami)@$(uname -n)"
    cap "$N_ACCENT" "$N_ON_ACCENT" "$t"
    # 16 columns of swatches, flush with the block's right edge
    printf '%*s' $(( W - ${#t} - 2 - 16 )) ''
    for c in "$N_SURFACE" "$N_OVERLAY" "$N_BORDER" "$N_MUTED" "$N_SUBTEXT" "$N_TEXT" "$N_BRIGHT" "$N_ACCENT"; do
      printf '\033[38;2;%sm██' "$c"
    done
    printf '\033[0m'
    ;;
  --head)
    h=$2
    (( T_UPPER )) || { h=${h,,}; h=${h^}; }
    printf '\033[1;38;2;%sm%s\033[0;38;2;%sm %s\033[38;2;%sm ─ ─ ·\033[0m' \
      "$N_ACCENT" "$h" "$N_MUTED" "$(printf -- '─%.0s' $(seq 1 $(( W - ${#h} - 7 ))))" "$N_BORDER"
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
    # "7 (flatpak-user), 950 (pacman)" -> "950 pacman · 7 flatpak", biggest first
    if [[ $label == Packages ]]; then
      v=$(sed 's/, /\n/g' <<<"$v" | sed -E 's/^([0-9]+) \(([^)-]+)[^)]*\)$/\1 \2/' | sort -rn | awk 'NR > 1 { printf " · " } { printf "%s", $0 }')
    fi
    case $label in
      CPU) i=$'';; GPU) i=$'\U000f08ae';; Memory) i=$'\U000f035b';; Disk) i=$'\U000f02ca';;
      OS) i=$'';; Kernel) i=$'';; Shell) i=$'';; WM) i=$'';;
      Terminal) i=$'';; Icons) i=$'\U000f003b';; Uptime) i=$'\U000f0150';; Packages) i=$'\U000f03d6';;
      Processes) i=$'';; Age) i=$'\U000f00ed';; *) i=' ';;
    esac
    printf ' \033[38;2;%sm%s \033[38;2;%sm%-10s' "$N_ACCENT" "$i" "$N_SUBTEXT" "$label"
    if [[ $label == Memory || $label == Disk ]]; then
      meter "$v"
    else
      max=$(( W - 13 ))
      (( ${#v} > max )) && v="${v:0:max-1}…"
      printf '\033[38;2;%sm%s' "$N_TEXT" "$v"
    fi
    printf '\033[0m'
    ;;
esac
