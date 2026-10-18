#!/usr/bin/env bash
# What state is this desktop in? Read-only, for when the shell is down (the
# System window's Health page covers it otherwise); needs only coreutils.
# Run as `diagnose`; -v adds the shell log and every failed unit.
set -uo pipefail

verbose=0
[[ ${1-} == -v || ${1-} == --verbose ]] && verbose=1

bold=$'\033[1m'; dim=$'\033[2m'; red=$'\033[1;31m'; yellow=$'\033[1;33m'
green=$'\033[1;32m'; blue=$'\033[1;34m'; off=$'\033[0m'

sect()  { printf '\n%s== %s%s\n' "$blue" "$*" "$off"; }
row()   { printf '  %-18s %s\n' "$1" "${2:-$dim(unknown)$off}"; }
ok()    { printf '  %-18s %s%s%s\n' "$1" "$green" "$2" "$off"; }
bad()   { printf '  %-18s %s%s%s\n' "$1" "$red" "$2" "$off"; }
warn()  { printf '  %-18s %s%s%s\n' "$1" "$yellow" "$2" "$off"; }
have()  { command -v "$1" &>/dev/null; }

# each tool's version, asked its own way, first line; missing is a finding
ver() {
  local tool=$1; shift
  have "$tool" || { printf '%snot installed%s' "$red" "$off"; return; }
  "$@" 2>/dev/null | head -1 | tr -d '\r'
}

printf '%sSingularity diagnostics%s  %s%s%s\n' \
  "$bold" "$off" "$dim" "$(date '+%Y-%m-%d %H:%M:%S')" "$off"

# --- session -----------------------------------------------------------------
sect "Session"
row  "User"        "$(id -un)@${HOSTNAME:-$(uname -n)}"
row  "Session type" "${XDG_SESSION_TYPE:-$dim unset$off}"
row  "Desktop"     "${XDG_CURRENT_DESKTOP:-$dim unset$off}"
row  "Uptime"      "$(uptime -p 2>/dev/null | sed 's/^up //')"

if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE-} ]]; then
  # `hyprctl version` leads with the whole build banner (branch, commit,
  # dirty flag); only the version number belongs on one line.
  ok  "Hyprland" "running  $(ver hyprctl hyprctl version | awk '{print $2}')"
else
  # Not an error on a tty -- but it is the answer if the bar is missing.
  warn "Hyprland" "no instance signature in this shell"
fi

if pgrep -x quickshell &>/dev/null; then
  ok  "Quickshell" "running (pid $(pgrep -x quickshell | tr '\n' ' ' | sed 's/ $//'))"
else
  bad "Quickshell" "not running -- the bar and Settings come from this"
fi
row  "quickshell ver" "$(ver quickshell quickshell --version)"

# --- graphics ----------------------------------------------------------------
sect "Graphics"
if have lspci; then
  # -mm quotes each field, so a model name with spaces survives; the device
  # name is field 4 whatever the vendor calls itself.
  while IFS= read -r line; do
    [[ -n $line ]] && row "GPU" "$line"
  done < <(lspci -mm 2>/dev/null | awk -F'"' '/VGA|3D|Display/ {print $6 " " $8}')
  row "Driver" "$(lspci -k 2>/dev/null | awk '/VGA|3D|Display/{f=1} f&&/Kernel driver in use/{print $NF; exit}')"
else
  row "GPU" "$red lspci missing (pciutils)$off"
fi
row "Monitors" "$(have hyprctl && hyprctl monitors -j 2>/dev/null \
  | grep -c '"name"' || echo "$dim n/a$off")"

# --- audio -------------------------------------------------------------------
# wireplumber routes everything; pipewire alone up means silence
sect "Audio"
for svc in pipewire pipewire-pulse wireplumber; do
  if systemctl --user is-active "$svc" &>/dev/null; then
    ok  "$svc" "active"
  else
    bad "$svc" "$(systemctl --user is-active "$svc" 2>/dev/null || echo inactive)"
  fi
done
if have wpctl; then
  # wpctl draws a tree: strip the branch characters and the index, then the
  # trailing [vol: …] and the whitespace it leaves behind.
  row "Default sink" "$(wpctl status 2>/dev/null \
    | awk '/Sinks:/{f=1;next} f&&/\*/{sub(/^[^*]*\*[ \t]*[0-9]+\.[ \t]*/,""); sub(/[ \t]*\[vol.*/,""); print; exit}')"
fi

# --- network -----------------------------------------------------------------
sect "Network"
if systemctl is-active iwd &>/dev/null; then ok "iwd" "active"; else bad "iwd" "inactive"; fi
dev=$(iwctl device list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' \
  | awk 'NR>4 && $5=="station" {print $1; exit}')
row "Wi-Fi device" "${dev:-$dim none$off}"
if [[ -n $dev ]]; then
  ssid=$(iwctl station "$dev" show 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' \
    | awk -F'  +' '/Connected network/ {print $3}')
  [[ -n $ssid ]] && ok "SSID" "$ssid" || warn "SSID" "not connected"
  row "IPv4" "$(ip -4 -o addr show dev "$dev" 2>/dev/null | awk '{print $4; exit}')"
fi
# One ping, one second: this is a reachability check, not a latency benchmark.
if ping -c1 -W1 1.1.1.1 &>/dev/null; then ok "Internet" "reachable"
else warn "Internet" "no reply from 1.1.1.1"; fi

# --- storage -----------------------------------------------------------------
sect "Storage"
while read -r target size used pct; do
  # A nearly-full root is the quiet cause of a surprising number of "it just
  # stopped working" reports, so it is called out rather than merely printed.
  n=${pct%\%}
  if   (( n >= 95 )); then bad  "$target" "$used / $size ($pct)"
  elif (( n >= 85 )); then warn "$target" "$used / $size ($pct)"
  else                     row  "$target" "$used / $size ($pct)"; fi
done < <(df -h --output=target,size,used,pcent / "$HOME" 2>/dev/null \
  | awk 'NR>1 && !seen[$1]++ {print $1, $2, $3, $4}')

# --- packages ----------------------------------------------------------------
sect "Packages"
have pacman && {
  row "Installed" "$(pacman -Qq 2>/dev/null | wc -l) ($(pacman -Qqm 2>/dev/null | wc -l) foreign)"
  row "Orphans"   "$(pacman -Qqtd 2>/dev/null | wc -l)"
  have pacdiff && {
    n=$(pacdiff -o -f 2>/dev/null | wc -l)
    if (( n > 0 )); then warn "Config to merge" "$n .pacnew/.pacsave (pacdiff -f --sudo)"
    else                 ok   "Config to merge" "none"; fi
  }
  row "Last upgrade" "$(awk -F'[][]' '/starting full system upgrade/{t=$2} END{print t}' \
    /var/log/pacman.log 2>/dev/null)"
}
have checkupdates && row "Updates" "$(checkupdates 2>/dev/null | wc -l) pending"

# --- services ----------------------------------------------------------------
sect "Failed units"
sys_failed=$(systemctl --failed --plain --no-legend 2>/dev/null | awk '{print $1}')
usr_failed=$(systemctl --user --failed --plain --no-legend 2>/dev/null | awk '{print $1}')
if [[ -z $sys_failed && -z $usr_failed ]]; then
  ok "All units" "none failed"
else
  # The short form names a few and counts the rest; -v lists every one.
  for u in $sys_failed; do bad "system" "$u"; done
  for u in $usr_failed; do bad "user"   "$u"; done
fi

# --- tools -------------------------------------------------------------------
sect "Required tools"
missing=()
for t in hyprctl quickshell grim slurp wl-copy iwctl wpctl brightnessctl \
         notify-send stow cava iw; do
  have "$t" || missing+=("$t")
done
if (( ${#missing[@]} == 0 )); then
  ok "All present" "${off}nothing missing"
else
  bad "Missing" "${missing[*]}"
fi

# --- logs --------------------------------------------------------------------
log=$HOME/.cache/quickshell.log
sect "Shell log"
if [[ -r $log ]]; then
  errs=$(grep -cE "ERROR|WARN" "$log" 2>/dev/null)
  if (( errs == 0 )); then ok "$(basename "$log")" "no errors or warnings"
  else warn "$(basename "$log")" "$errs error/warning lines"; fi
  if (( verbose )) || (( errs > 0 )); then
    printf '%s' "$dim"
    grep -E "ERROR|WARN" "$log" 2>/dev/null | tail -n $(( verbose ? 40 : 10 )) | sed 's/^/    /'
    printf '%s' "$off"
  fi
else
  row "$(basename "$log")" "$dim not written yet$off"
fi

if (( verbose )); then
  sect "Recent session journal"
  printf '%s' "$dim"
  # coredump frames dropped and lines cut to width
  journalctl --user -p warning -n 60 --no-pager 2>/dev/null \
    | grep -vE '^\s+#[0-9]+ +0x|ELF object binary architecture|Stack trace of|^\s*$' \
    | tail -n 30 | cut -c1-150 | sed 's/^/    /'
  printf '%s' "$off"
fi

printf '\n%sdone%s  %srun with -v for logs and detail%s\n' \
  "$bold" "$off" "$dim" "$off"
