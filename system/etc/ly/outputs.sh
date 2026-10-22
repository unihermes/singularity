#!/bin/sh
# Installed by singularity's install.sh. `outputs.sh [off|on]` holds the monitors
# named as video=<connector>:d on the kernel command line off for the
# greeter, or gives them back to the session.
names=$(tr ' ' '\n' < /proc/cmdline | sed -n 's/^video=\([^:]*\):d$/\1/p')
[ -n "$names" ] || exit 0
state=${1:-off}
if [ "$state" = off ]; then
  state=on
  for s in /sys/class/drm/card*-*/status; do
    c=${s%/status}; c=${c##*/}; c=${c#card*-}
    case " $(echo $names) " in *" $c "*) continue ;; esac
    [ "$(cat "$s")" = connected ] && state=off && break
  done
fi
for n in $names; do
  for s in /sys/class/drm/card*-"$n"/status; do
    [ -w "$s" ] || continue
    if [ "$state" = off ]; then echo off; else echo detect; fi > "$s"
  done
done
