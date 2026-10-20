#!/bin/bash
# Singularity - lid
# ~/.config/hypr/lid.sh
#
# Everything the lid does: closing turns the screen off and suspends after
# close_delay (unless close_action is screen-off), hibernating an hour after
# it shut; opening turns the screen on and cancels that, then off again
# after open_hold if untouched.
#
#   lid.sh event    binds.lua's lid-switch binds
#   lid.sh sleep    hypridle's before_sleep_cmd
#   lid.sh resume   hypridle's after_sleep_cmd
#   lid.sh fire     the suspend timer this script arms
#   lid.sh displays displays.lua, when a display comes or goes
#
# autostart.lua holds logind's lid inhibitor so this handles the lid.
#
# - Debounced: the firmware bounces; only the last event after a quiet
#   period acts, on what the lid reads then.
# - The suspend is a systemd user timer (survives reloads, cancelled by
#   name), and ignores idle inhibitors.
# - Waking with the lid shut stays dark and suspends again after a minute.
# - Hibernation is systemd's suspend-then-hibernate (an RTC alarm), delay
#   in sleep.conf.d (install.sh); the close time is wall-clock, so a wake
#   past the hour hibernates at once. Plain suspend without hibernation.
# - While shut, key/mouse DPMS wake is off (the lid presses on them); back
#   on at open.
# - blank()/unblank() assert DPMS for a couple of seconds, since Hyprland's
#   own post-resume restore can land after them.
# - A stray wake from idle suspend stays dark unless the pointer moves more
#   than move_slop px (the waking interrupt brings a pixel or two).
# - Docked (an external display), closing switches the panel off via
#   $docked_file and displays.lua, and nothing suspends.
# - Opening holds the panel on for open_hold, then off unless there was
#   input, seen through hypridle.conf's first listener ($input_seen,
#   $idle_seen).
# The lid and monitors are read from sysfs, so the timer needs no Hyprland.
set -u

unit=singularity-lid-suspend
# Settings -> Lock Screen's four, overridden from lid.conf below
close_action=suspend  # suspend | screen-off (never suspends on its own)
lock_on_close=0    # 1: lock as soon as the lid shuts, not just before sleep
close_delay=300    # lid shut this long -> suspend
hibernate=1        # 0: a shut lid only ever suspends, never hibernates
rewake_delay=60    # woke up with the lid still shut -> suspend again after this
retry_delay=60     # suspend refused (a blocking inhibitor) -> try again
move_slop=40       # px the pointer must travel on a stray wake to count as a person
open_hold=60       # lid opened and left untouched -> screen off after this
hibernate_after=3600  # lid shut this long -> hibernate (see sleep.conf.d above)
closed_at="${XDG_RUNTIME_DIR:-/tmp}/singularity-lid-closed-at"
slept_dark="${XDG_RUNTIME_DIR:-/tmp}/singularity-slept-dark"
docked_file="${XDG_RUNTIME_DIR:-/tmp}/singularity-lid-docked"
hibernating="${XDG_RUNTIME_DIR:-/tmp}/singularity-hibernating"
hold_marker="${XDG_RUNTIME_DIR:-/tmp}/singularity-lid-hold"
input_seen="${XDG_RUNTIME_DIR:-/tmp}/singularity-input"
idle_seen="${XDG_RUNTIME_DIR:-/tmp}/singularity-idle"

# Settings > Lock Screen's choices, name=value lines (only those four names)
lid_conf="${XDG_STATE_HOME:-$HOME/.local/state}/singularity/lid.conf"
if [[ -r $lid_conf ]]; then
    while IFS='=' read -r key value; do
        case $key in
            close_action|lock_on_close|close_delay|hibernate)
                [[ $value =~ ^[A-Za-z0-9-]+$ ]] && printf -v "$key" '%s' "$value" ;;
        esac
    done < "$lid_conf"
fi

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

# A table, not hl.dsp.dpms("on"): a bare string is read as toggle, so every
# repeat in the loops below flipped the screens rather than holding them.
dpms() {  # dpms on|off [monitor]
    local arg="action = \"$1\""
    [[ -n ${2:-} ]] && arg+=", monitor = \"$2\""
    hyprctl eval "hl.dispatch(hl.dsp.dpms({ $arg }))" >/dev/null 2>&1
}

# whether input may wake a blanked screen (hl.config: `hyprctl keyword`
# refuses under the Lua config)
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

# blanks the panel and re-checks for a couple of seconds, as input from the
# lid shutting can still land
blank() {
    local i
    unhold
    input_wakes false
    for i in 1 2 3 4; do
        dpms off
        sleep 0.5
        panel_on || return 0
    done
    log "panel would not stay blanked"
}

# The mirror of blank(): Hyprland's restore of the pre-sleep "off" can land
# after this, so dpms on is asserted for a couple of seconds, to the end.
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

# The lid just opened: the panel on for open_hold, then off unless there was
# input ($input_seen newer than the marker, or input that hasn't paused). The
# marker is the hold's start and token: a later hold, blank or stay_dark
# removes it. The first three seconds hold regardless.
hold() {
    local token="$$-$RANDOM" i
    echo "$token" > "$hold_marker"
    input_wakes true
    dpms on
    for (( i = 1; i <= open_hold * 2; i++ )); do
        sleep 0.5
        [[ $(cat "$hold_marker" 2>/dev/null) == "$token" ]] || return 0
        if (( i > 6 )) && present; then
            rm -f "$hold_marker"
            return 0
        fi
        panel_on || dpms on
    done
    rm -f "$hold_marker"
    log "lid open and untouched for ${open_hold}s: screen off"
    dpms off
}

unhold() { rm -f "$hold_marker"; }

# someone has used the machine since the hold began, or is using it now
present() {
    [[ $input_seen -nt $hold_marker || $input_seen -nt $idle_seen ]]
}

# the lid is open again: docked, the panel just comes back beside the other
# displays, which were on all along -- no hold, and nothing to turn off after
opened() {
    if docked; then unblank; else hold; fi
}

# has the pointer moved more than move_slop px from "$1" ("x, y")? An
# unreadable position counts as no movement.
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

# After a wake into a panel already off: keep it off unless someone is there
# (the pointer travelling, or the panel turned on by a keystroke, which
# counts only after the first second, when hypridle's own dpms on lands).
stay_dark() {
    local i start
    unhold
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

# Whether any layer surface (the bar, the wallpaper) sticks out of the
# display it belongs to -- left behind where the display used to be.
stale_layers() {
    { hyprctl monitors; echo "--layers"; hyprctl layers; } 2>/dev/null | awk '
        /^--layers/ { layers = 1; next }
        !layers && /^Monitor / { name = $2 }
        !layers && / at [-0-9]+x[-0-9]+/ {
            split($1, res, "[x@]"); split($3, pos, "x")
            mx[name] = pos[1]; my[name] = pos[2]; mw[name] = res[1]; mh[name] = res[2]
        }
        !layers && /scale:/ { mw[name] /= $2; mh[name] /= $2 }
        layers && /^Monitor / { name = $2; sub(":", "", name) }
        layers && /xywh:/ && (name in mx) {
            split($0, a, "xywh: "); split(a[2], v, "[ ,]")
            if (v[1] < mx[name] || v[2] < my[name] || v[1] + v[3] > mx[name] + mw[name] || v[2] + v[4] > my[name] + mh[name]) bad = 1
        }
        END { exit !bad }'
}

# displays with no layer surface (not even the wallpaper); mirrors don't count
bare_displays() {
    { hyprctl monitors; echo "--layers"; hyprctl layers; } 2>/dev/null | awk '
        /^--layers/ { layers = 1; next }
        !layers && /^Monitor / { name = $2 }
        !layers && /mirrorOf:/ && $2 != "none" { mirror[name] = 1 }
        layers && /^Monitor / { name = $2; sub(":", "", name); if (!(name in mirror)) seen[name] = 0 }
        layers && /xywh:/ && (name in seen) { seen[name] = 1 }
        END { for (n in seen) if (!seen[n]) print n }'
}

# switches the panel off or on through displays.lua; a no-op when it already is
panel_off() {
    unhold
    [[ -e $docked_file ]] && return
    internal_panel > "$docked_file"
    hyprctl reload config-only >/dev/null
    log "lid closed while docked: panel off"
}

panel_back() {
    [[ -e $docked_file ]] || return 0
    rm -f "$docked_file"
    hyprctl reload config-only >/dev/null
    log "panel back on"
}

# The lid shut with nothing docked: blank, and suspend after close_delay.
closed_undocked() {
    date +%s > "$closed_at"
    arm "$close_delay"
    (( lock_on_close )) && { pidof hyprlock >/dev/null || loginctl lock-session; }
    blank
}

# the shell's lid toast, on whichever display has focus -- the external one
# once a docked close has switched the panel off
toast() {  # toast closed|open
    qs ipc call lid changed "$1" >/dev/null 2>&1 &
}

arm() {
    disarm
    [[ $close_action == suspend ]] || return 0
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
            disarm
            panel_off
        else
            panel_back
            closed_undocked
        fi
        toast closed
    else
        disarm
        rm -f "$closed_at"
        panel_back
        toast open
        opened
    fi
    ;;
displays)
    # one pass for a burst of display events: switching the panel off or on
    # sends its own, and so does the reload below
    marker="${XDG_RUNTIME_DIR:-/tmp}/singularity-displays-marker"
    token="$$-$RANDOM"
    echo "$token" > "$marker"
    sleep 1
    [[ $(cat "$marker" 2>/dev/null) == "$token" ]] || exit 0

    if ! lid_closed; then
        panel_back
    elif docked; then
        disarm
        panel_off
    elif [[ -e $docked_file ]]; then
        # the last external display went with the lid shut
        panel_back
        closed_undocked
    fi
    # Hyprland leaves layer surfaces where displays used to be
    # (singularityNudgeDisplays); retried while they settle
    for _ in 1 2 3; do
        hyprctl eval 'singularityNudgeDisplays()' >/dev/null
        hyprctl reload config-only >/dev/null
        sleep 1
        stale_layers || break
    done
    stale_layers && log "bar or wallpaper still out of place after nudging the displays"
    # a display Hyprland never announced to clients gets toggled off and on
    if [[ -n $(bare_displays) ]]; then
        sleep 2
        for m in $(bare_displays); do
            log "$m has no bar or wallpaper: switching it off and on"
            hyprctl eval "hl.monitor({ output = \"$m\", disabled = true })" >/dev/null
        done
        sleep 1
        hyprctl reload config-only >/dev/null
    fi
    ;;
sleep)
    rm -f "$slept_dark"
    # the power menu's Hibernate blanks the panel itself (see Session.qml)
    if [[ -e $hibernating ]]; then
        rm -f "$hibernating"
    else
        lid_closed || panel_on || touch "$slept_dark"
    fi
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
        opened
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
    if (( ! hibernate )); then
        log "lid closed for ${shut_for}s: suspending (hibernation off)"
        action=suspend
    elif (( shut_for >= hibernate_after )) && can Hibernate; then
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
    echo "usage: lid.sh event|sleep|resume|fire|displays" >&2
    exit 2
    ;;
esac
