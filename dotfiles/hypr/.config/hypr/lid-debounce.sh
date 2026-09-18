#!/bin/bash
# Singularity - lid switch debounce
# ~/.config/hypr/lid-debounce.sh
#
# Hyprland fires this on every switch:on/off Lid Switch event (see the Lid
# section of hyprland.lua). This laptop's firmware sometimes reports a
# spurious lid state, or bounces open/closed a few times within a couple of
# seconds of the real change (the kernel logs "Unexpected lid state
# reported by firmware" when it happens). Reacting to each raw event
# directly turns that into a flickering screen.
#
# Instead: every invocation stamps a fresh token into a marker file and
# waits. If another invocation fires before the wait is up (a bounce), it
# overwrites the marker with its own token and this one just exits quietly
# once it wakes up and sees it's no longer the latest. Only the invocation
# that survives a full quiet period acts -- and it acts on whatever the lid
# ACTUALLY reads at that point, not on the event that triggered it, so a
# closed-then-reopened bounce settles on "open" even though it was the
# close event that last fired this script.
marker="${XDG_RUNTIME_DIR:-/tmp}/lid-debounce-marker"
token="$$-$RANDOM"
echo "$token" > "$marker"

sleep 1.5

[[ "$(cat "$marker" 2>/dev/null)" == "$token" ]] || exit 0

state_file=(/proc/acpi/button/lid/*/state)
if [[ -r "${state_file[0]}" ]] && grep -q closed "${state_file[0]}"; then
    hyprctl eval 'hl.dispatch(hl.dsp.dpms("off"))' >/dev/null
else
    hyprctl eval 'hl.dispatch(hl.dsp.dpms("on"))' >/dev/null
fi
