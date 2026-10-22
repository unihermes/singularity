#!/bin/sh
# Installed by singularity's install.sh. ly runs `info.sh <line>` for each
# status line at the greeter's bottom-right: @LINES@.
# ly right-aligns each line by its length in bytes but draws it by
# characters, so the lines are kept to ASCII, where the two agree, and each
# is padded to the longest of them: the stack lines up on its left edge
# and the longest line ends at the screen's right edge.
export LC_ALL=C
out() { printf '%-12s%s' "$1" "$2"; }
read_num() { v=$(cat "$1" 2>/dev/null); echo "${v:-0}"; }
dur() { [ "$1" -ge 60 ] && printf '%dh %02dm' $(($1 / 60)) $(($1 % 60)) || printf '%dm' "$1"; }

# now/full/rate in µAh and µA, or µWh and µW, depending on what the battery reports
battery_state() {
  for b in /sys/class/power_supply/BAT*; do [ -r "$b/capacity" ] && break; done
  [ -r "$b/capacity" ] || return 1
  pct=$(read_num "$b/capacity")
  status=$(cat "$b/status" 2>/dev/null)
  if [ -r "$b/charge_now" ]; then
    now=$(read_num "$b/charge_now"); full=$(read_num "$b/charge_full")
    design=$(read_num "$b/charge_full_design"); rate=$(read_num "$b/current_now")
    watts=$(awk -v i="$rate" -v v="$(read_num "$b/voltage_now")" 'BEGIN { printf "%.1f", (i < 0 ? -i : i) * v / 1e12 }')
  else
    now=$(read_num "$b/energy_now"); full=$(read_num "$b/energy_full")
    design=$(read_num "$b/energy_full_design"); rate=$(read_num "$b/power_now")
    watts=$(awk -v p="$rate" 'BEGIN { printf "%.1f", (p < 0 ? -p : p) / 1e6 }')
  fi
  rate=${rate#-}
}

# one status line, unpadded
line() {
case $1 in
battery)
  battery_state || { out battery 'none'; exit; }
  filled=$(((pct + 5) / 10)) bar='' i=0
  while [ $i -lt 10 ]; do
    [ $i -lt $filled ] && bar="$bar=" || bar="$bar-"
    i=$((i + 1))
  done
  case $status in
    Discharging)
      text=''
      [ "$rate" -gt 0 ] && text="$(dur $((now * 60 / rate))) left"
      [ "$pct" -le 15 ] && text="low${text:+, $text}" ;;
    Charging)
      text='charging'
      [ "$rate" -gt 0 ] && [ "$full" -gt "$now" ] &&
        text="charging, full in $(dur $(((full - now) * 60 / rate)))" ;;
    Full) text='plugged in, full' ;;
    *) text='plugged in' ;;
  esac
  out battery "$bar $pct%  $text" ;;
power)
  battery_state || { out power 'on AC'; exit; }
  case $status in
    Discharging) text="$watts W" ;;
    Charging) text="charging at $watts W" ;;
    *) text='idle' ;;
  esac
  [ "$design" -gt 0 ] && text="$text, health $((full * 100 / design))%"
  out power "$text" ;;
wifi)
  for w in /sys/class/net/*/wireless; do [ -d "$w" ] && break; done
  [ -d "$w" ] || { out wifi 'none'; exit; }
  dev=${w%/wireless}; dev=${dev##*/}
  link=$(iw dev "$dev" link 2>/dev/null)
  ssid=$(printf '%s\n' "$link" | sed -n 's/^[[:space:]]*SSID: //p' | tr -c ' -~\n' '?')
  signal=$(printf '%s\n' "$link" | sed -n 's/^[[:space:]]*signal: //p')
  if [ -n "$ssid" ]; then out wifi "$ssid${signal:+, signal $signal}"
  else out wifi 'not connected'; fi ;;
kernel)
  out kernel "linux $(uname -r)" ;;
last)
  # newest entry across users; lastlog2's Latest column is the last six fields
  best=0 text='never'
  while read -r port when; do
    t=$(date -d "$when" +%s 2>/dev/null) || continue
    [ "$t" -gt "$best" ] && best=$t text="$(date -d "@$t" '+%a %-d %b %H:%M') on $port"
  done <<EOF
$(lastlog2 2>/dev/null | awk 'NR > 1 && $NF ~ /^[0-9][0-9][0-9][0-9]$/ {
    print $2, $(NF-5), $(NF-4), $(NF-3), $(NF-2), $(NF-1), $NF }')
EOF
  out 'last login' "$text" ;;
esac
}

# the longest line sets the width every line is padded to
width=0
for l in @LINES@; do
  t=$(line $l)
  [ ${#t} -gt $width ] && width=${#t}
done
printf '%-*s' "$width" "$(line "$1")"
