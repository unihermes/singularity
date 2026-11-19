#!/bin/sh
# Installed by singularity's install.sh. `outputs.sh [off|on]` holds monitors
# off for the greeter, or gives them back to the session. The console mirrors
# every screen at the smallest one's size, so `off` holds off each connected
# monitor whose preferred mode is smaller than the largest monitor's, plus any
# named as video=<connector>:d on the kernel command line. The held names are
# kept in $held for `on`. `off` also grows the console to the main monitor.
held=/run/singularity-ly-held
state=${1:-off}

# connector name from a /sys/class/drm/cardN-<name>/status path
name() { c=${1%/status}; c=${c##*/}; echo "${c#card*-}"; }

if [ "$state" = off ]; then
  cmdline=$(tr ' ' '\n' < /proc/cmdline | sed -n 's/^video=\([^:]*\):d$/\1/p')
  # the largest connected monitor, by its preferred (first) mode's area
  main='' mw=0 mh=0
  for s in /sys/class/drm/card*-*/status; do
    [ "$(cat "$s")" = connected ] || continue
    m=$(head -n1 "${s%status}modes" 2>/dev/null)
    w=${m%%x*} h=${m#*x}; h=${h%%[!0-9]*}
    [ -n "$w" ] && [ -n "$h" ] || continue
    [ $((w * h)) -gt $((mw * mh)) ] && main=$(name "$s") mw=$w mh=$h
  done
  [ -n "$main" ] || exit 0
  names=$cmdline
  for s in /sys/class/drm/card*-*/status; do
    [ "$(cat "$s")" = connected ] || continue
    n=$(name "$s")
    [ "$n" = "$main" ] && continue
    m=$(head -n1 "${s%status}modes" 2>/dev/null)
    w=${m%%x*} h=${m#*x}; h=${h%%[!0-9]*}
    { [ "${w:-0}" -lt "$mw" ] || [ "${h:-0}" -lt "$mh" ]; } && names="$names $n"
  done
  names=$(echo $names | tr ' ' '\n' | grep -vx "$main" | sort -u)
  printf '%s\n' $names > "$held"
  chmod 644 "$held"
else
  names=$(cat "$held" 2>/dev/null)
  rm -f "$held"
fi

for n in $names; do
  for s in /sys/class/drm/card*-"$n"/status; do
    [ -w "$s" ] || continue
    if [ "$state" = off ]; then echo off; else echo detect; fi > "$s"
  done
done

# The console's text area stays at the smallest screen lit at boot, inside a
# surface the size of the largest; with the smaller ones held off, grow every
# VT to the whole surface so the greeter fills the main monitor.
[ "$state" = off ] && [ -c /dev/fb0 ] && python3 -I - <<'EOF'
import fcntl, struct
GET, PUT, ACTIVATE_ALL = 0x4600, 0x4601, 64
try:
    with open('/dev/fb0', 'r+b', buffering=0) as fb:
        var = bytearray(fcntl.ioctl(fb, GET, bytes(160)))
        xres, yres, vx, vy = struct.unpack_from('4I', var)
        if (xres, yres) != (vx, vy):
            struct.pack_into('6I', var, 0, vx, vy, vx, vy, 0, 0)
            struct.pack_into('I', var, 84, ACTIVATE_ALL)
            fcntl.ioctl(fb, PUT, bytes(var))
except OSError:
    pass
EOF
exit 0
