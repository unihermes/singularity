#!/bin/bash
# Singularity - lid
# ~/.config/hypr/lid.sh
#
# Everything the lid does. Closing it turns the screen off, and five minutes
# later suspends if it's still shut; an hour after it shut, the machine
# hibernates. Opening it turns the screen back on and calls all of that off.
#
#   lid.sh event    from hyprland.lua's lid-switch binds, on open and close
#   lid.sh sleep    from hypridle's before_sleep_cmd, before every suspend
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
# - Hibernating is systemd's suspend-then-hibernate, not a timer here: the
#   user timer's clock stops while asleep, but suspend-then-hibernate sets an
#   RTC alarm that wakes the machine and hibernates it. Its delay is fixed in
#   /etc/systemd/sleep.conf.d/singularity.conf (install.sh writes it) as
#   hibernate_after - close_delay, so the usual close -> suspend -> hibernate
#   lands at an hour. The close time is stamped in wall-clock time, which
#   does run during sleep, so a stray wake an hour or more after the lid
#   shut hibernates straight away instead of restarting that delay.
#   Without hibernation set up (link.sh only), it's plain suspend as before.
# - Blanking the panel means holding misc:key_press_enables_dpms and
#   mouse_move_enables_dpms off for as long as the lid is shut. They are on
#   in hyprland.lua so that any key or mouse movement wakes a wrongly-blanked
#   screen -- but the act of closing the lid presses the keyboard and the
#   touchpad against it, and those events land after the debounce and turn
#   the panel straight back on, so a first close often didn't stay dark.
#   While the lid is shut nothing but opening it should wake the panel
#   anyway. Both go back on when the lid opens; a Hyprland restart also
#   restores them, since they're read from the config.
# - Coming back is a loop too, for the opposite reason: Hyprland restores
#   the DPMS state it had before sleeping, and that restore can land after
#   the dpms on this script issues on resume. See unblank().
# - A stray wake from the idle suspend stays dark. With the lid open,
#   hypridle's 10/20 min suspend often wakes again within seconds (the
#   touchpad's GPIO interrupt fires in s2idle, and it has to stay a wake
#   source so a touch can wake the machine). Resume used to light the panel
#   every time, so an idle laptop blinked on every 10 minutes. Now, if the
#   panel was already off going to sleep with the lid open, resume holds it
#   off for a few seconds unless the pointer really moves; after that any key
#   or touchpad movement turns it on as usual, and hypridle suspends it again.
#   "Really" matters: the same GPIO interrupt that caused the stray wake
#   usually delivers a pixel or two of pointer motion with it, so any movement
#   at all as the test let the screen light straight back up -- the bug this
#   whole branch exists to stop. A resting finger or a knock is a few pixels;
#   a hand actually reaching for the touchpad is tens. cursor_moved wants
#   move_slop px away from where the pointer sat at wake-up.
# - With an external monitor connected the laptop is docked: closing the lid
#   only turns off the built-in panel, and nothing suspends. Input still
#   wakes it there -- an external keyboard is the only way back in.
#
# Both the lid and the monitors are read from sysfs rather than hyprctl, so
# the timer's check works without Hyprland's environment.
set -u

unit=singularity-lid-suspend
close_delay=300    # lid shut this long -> suspend
rewake_delay=60    # woke up with the lid still shut -> suspend again after this
retry_delay=60     # suspend refused (a blocking inhibitor) -> try again
move_slop=40       # px the pointer must travel on a stray wake to count as a person
hibernate_after=3600  # lid shut this long -> hibernate (see sleep.conf.d above)
closed_at="${XDG_RUNTIME_DIR:-/tmp}/singularity-lid-closed-at"
slept_dark="${XDG_RUNTIME_DIR:-/tmp}/singularity-slept-dark"

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

# logind's answer, so a missing swapfile or resume= falls back to suspend
can() {  # can Hibernate|SuspendThenHibernate
    [[ $(busctl call org.freedesktop.login1 /org/freedesktop/login1 \
        org.freedesktop.login1.Manager "Can$1" 2>/dev/null) == 's "yes"' ]]
}

dpms() {  # dpms on|off [monitor]
    local arg="\"$1\""
    [[ -n ${2:-} ]] && arg+=", \"$2\""
    hyprctl eval "hl.dispatch(hl.dsp.dpms($arg))" >/dev/null 2>&1
}

# whether input is allowed to wake a blanked screen. hl.config, not
# `hyprctl keyword`: keyword only works with the legacy parser and refuses
# outright under the Lua config ("keyword can't work with non-legacy
# parsers. Use eval.").
input_wakes() {  # input_wakes true|false
    hyprctl eval "hl.config({ misc = { key_press_enables_dpms = $1,
        mouse_move_enables_dpms = $1 } })" >/dev/null 2>&1
}

panel_on() {  # anything eDP-1 reports off
    local line panel=0
    while read -r line; do
        [[ $line == Monitor*eDP* ]] && panel=1
        [[ $panel == 1 && $line == *dpmsStatus:* ]] && { [[ $line == *1 ]]; return; }
    done < <(hyprctl monitors 2>/dev/null)
    return 1
}

# Blank the panel and keep it blank: a key or touchpad event from the lid
# shutting on them can still be in flight after input_wakes false, and the
# one that lands first wins. Re-checking for a couple of seconds costs
# nothing and is what makes a first close reliable.
blank() {
    local i
    input_wakes false
    for i in 1 2 3 4; do
        dpms off
        sleep 0.5
        panel_on || return 0
    done
    log "panel would not stay blanked"
}

# The mirror of blank(), for the way back. On a resume Hyprland re-applies
# the DPMS state it held before sleeping -- which is the "off" blank() set
# when the lid shut -- and that restore can land *after* this dpms on.
# hypridle's after_sleep_cmd fires within a tenth of a second of the kernel
# restarting tasks, so it usually does: the panel lights up, goes dark again
# and stays dark until a key or the touchpad wakes it. Asserting dpms on for
# a couple of seconds, rather than once, is what wins that race. The loop
# runs to the end instead of stopping at the first "it's on" -- the restore
# that undoes it has not necessarily happened yet.
unblank() {
    local i
    input_wakes true
    dpms on
    for i in 1 2 3 4 5 6; do
        sleep 0.5
        panel_on || dpms on
    done
    panel_on || log "panel would not come back on"
}

# has the pointer moved more than move_slop px from "$1" ("x, y")? An
# unreadable position (hyprctl not answering yet, right after a resume)
# counts as no movement rather than as a person.
cursor_moved() {
    local from=$1 now dx dy
    now=$(hyprctl cursorpos 2>/dev/null)
    [[ $from =~ ^-?[0-9]+,\ *-?[0-9]+$ && $now =~ ^-?[0-9]+,\ *-?[0-9]+$ ]] || return 1
    dx=$(( ${now%,*} - ${from%,*} ))
    dy=$(( ${now##*, } - ${from##*, } ))
    (( dx < 0 )) && dx=$(( -dx ))
    (( dy < 0 )) && dy=$(( -dy ))
    (( dx + dy > move_slop ))
}

# After a wake into a panel that was already off: keep it off -- hypridle's
# own on-resume turns it on at the same moment -- unless someone is actually
# there. Two ways to say so, because input_wakes stays true throughout and
# the loop would otherwise fight a real person for its full three seconds:
# the pointer travelling (cursor_moved), or the panel coming back on under
# us, which is key_press_enables_dpms answering a keystroke. The second test
# only counts from the second onwards -- hypridle's on-resume dpms on lands
# within a tenth of a second of the resume and is exactly what this function
# exists to undo, so before then "the panel is on" says nothing.
stay_dark() {
    local i start
    input_wakes true
    start=$(hyprctl cursorpos 2>/dev/null)
    for i in 1 2 3 4 5 6; do
        dpms off
        sleep 0.5
        if cursor_moved "$start" || { (( i > 2 )) && panel_on; }; then
            unblank
            return
        fi
    done
    log "woke with the screen off and nobody there: leaving it off"
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
            date +%s > "$closed_at"
            arm "$close_delay"
            blank
        fi
    else
        disarm
        rm -f "$closed_at"
        unblank
    fi
    ;;
sleep)
    rm -f "$slept_dark"
    lid_closed || panel_on || touch "$slept_dark"
    ;;
resume)
    if lid_closed && ! docked; then
        rm -f "$slept_dark"
        arm "$rewake_delay"
        blank
    elif [[ -e $slept_dark ]] && ! docked; then
        rm -f "$slept_dark"
        disarm
        stay_dark
    else
        disarm
        rm -f "$closed_at"
        unblank
    fi
    ;;
fire)
    # the timer's own check: the lid may have opened without an event
    # getting through, or a monitor may have been plugged in since
    lid_closed || { log "lid open, not suspending"; exit 0; }
    docked && { log "docked, not suspending"; exit 0; }
    # no stamp (the shell restarted with the lid shut): count from now
    [[ -s $closed_at ]] || date -d "-$close_delay sec" +%s > "$closed_at"
    shut_for=$(( $(date +%s) - $(cat "$closed_at") ))
    if (( shut_for >= hibernate_after )) && can Hibernate; then
        log "lid closed for ${shut_for}s: hibernating"
        action=hibernate
    elif can SuspendThenHibernate; then
        log "lid closed for ${shut_for}s: suspending, then hibernating"
        action=suspend-then-hibernate
    else
        log "lid closed for ${shut_for}s: suspending"
        action=suspend
    fi
    if ! systemctl "$action"; then
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
    echo "usage: lid.sh event|sleep|resume|fire" >&2
    exit 2
    ;;
esac
