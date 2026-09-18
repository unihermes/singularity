#!/bin/bash
# Singularity - lid
# ~/.config/hypr/lid.sh
#
# Everything the lid does. Closing it turns the screen off, and five minutes
# later suspends if it's still shut. Opening it turns the screen back on and
# calls the suspend off.
#
#   lid.sh event    from hyprland.lua's lid-switch binds, on open and close
#   lid.sh resume   from hypridle's after_sleep_cmd, after every wake-up
#   lid.sh fire     from the suspend timer this script arms
#
# logind would suspend the moment the lid shuts, so hyprland.lua holds its
# lid-switch inhibitor and this handles the lid instead.
#
# Why each piece is shaped the way it is:
#
# - Debounce. This laptop's firmware bounces open/closed a few times within a
#   couple of seconds of a real change ("Unexpected lid state reported by
#   firmware" in dmesg). Each event stamps a token and waits; only the last
#   one to survive a quiet period acts, and it acts on what the lid reads
#   *then*, not on the event that woke it.
# - The suspend is a systemd user timer, not a `sleep 300` here. It survives
#   Hyprland reloading, is cancelled by name when the lid opens, and
#   `systemctl --user list-timers` shows it. Its clock doesn't run while
#   the machine is asleep.
# - The timer ignores idle inhibitors. The idle ladder in hypridle.conf
#   yields to a playing video or Keep Awake; a closed lid shouldn't.
# - Waking with the lid still shut (a charger plugged in, a USB wake, the
#   lid bouncing -- this machine only has s2idle, which wakes easily) leaves
#   the screen off and suspends again after a minute instead of staying
#   awake in the bag.
# - With an external monitor connected the laptop is docked: closing the lid
#   only turns off the built-in panel, and nothing suspends.
#
# Both the lid and the monitors are read from sysfs rather than hyprctl, so
# the timer's check works without Hyprland's environment.
set -u

unit=singularity-lid-suspend
close_delay=300    # lid shut this long -> suspend
rewake_delay=60    # woke up with the lid still shut -> suspend again after this
retry_delay=60     # suspend refused (a blocking inhibitor) -> try again

log() { logger -t singularity-lid -- "$*"; }

lid_closed() {
    local f
    for f in /proc/acpi/button/lid/*/state; do
        [[ -r $f ]] && grep -q closed "$f" && return 0
    done
    return 1
}

# any connected display other than the built-in panel
docked() {
    local s
    for s in /sys/class/drm/card*-*/status; do
        [[ $s == *-eDP-* || $s == *-LVDS-* || $s == *-DSI-* ]] && continue
        [[ $(cat "$s" 2>/dev/null) == connected ]] && return 0
    done
    return 1
}

internal_panel() {
    local s n
    for s in /sys/class/drm/card*-eDP-*/status; do
        [[ -e $s ]] || continue
        n=${s%/status}; n=${n##*/}; echo "${n#card*-}"; return
    done
}

dpms() {  # dpms on|off [monitor]
    local arg="\"$1\""
    [[ -n ${2:-} ]] && arg+=", \"$2\""
    hyprctl eval "hl.dispatch(hl.dsp.dpms($arg))" >/dev/null 2>&1
}

arm() {
    disarm
    systemd-run --user --quiet --collect --unit="$unit" \
        --on-active="$1" --timer-property=AccuracySec=1s \
        "$HOME/.config/hypr/lid.sh" fire \
        && log "suspending in ${1}s unless the lid opens"
}

disarm() {
    systemctl --user stop "$unit.timer" "$unit.service" 2>/dev/null
}

case "${1:-event}" in
event)
    marker="${XDG_RUNTIME_DIR:-/tmp}/singularity-lid-marker"
    token="$$-$RANDOM"
    echo "$token" > "$marker"
    sleep 1.5
    [[ $(cat "$marker" 2>/dev/null) == "$token" ]] || exit 0

    if lid_closed; then
        if docked; then
            dpms off "$(internal_panel)"
            disarm
            log "lid closed while docked: panel off, no suspend"
        else
            dpms off
            arm "$close_delay"
        fi
    else
        disarm
        dpms on
    fi
    ;;
resume)
    if lid_closed && ! docked; then
        dpms off
        arm "$rewake_delay"
    else
        disarm
        dpms on
    fi
    ;;
fire)
    # the timer's own check: the lid may have opened without an event
    # getting through, or a monitor may have been plugged in since
    lid_closed || { log "lid open, not suspending"; exit 0; }
    docked && { log "docked, not suspending"; exit 0; }
    log "lid closed for a while: suspending"
    if ! systemctl suspend; then
        log "suspend refused, retrying in ${retry_delay}s"
        # this runs inside the unit being re-armed, so hand the re-arm to a
        # separate process that outlives it
        systemd-run --user --quiet --collect --on-active=2 \
            "$HOME/.config/hypr/lid.sh" rearm-retry
    fi
    ;;
rearm-retry)
    lid_closed && ! docked && arm "$retry_delay"
    ;;
*)
    echo "usage: lid.sh event|resume|fire" >&2
    exit 2
    ;;
esac
