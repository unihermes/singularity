#!/bin/bash
# Singularity - keeps Equicord in a Discord that updated itself
# ~/.config/singularity/equicord-repatch.sh, run by equicord-repatch.path
#
# Discord installs an update into a new ~/.config/discord/app-<version> folder
# and restarts from it with none of its arguments. /usr/bin/equicord patches
# only the folder it starts, so that Discord runs without Equicord and without
# the launcher's flags. This patches the current folder the way
# /usr/bin/equicord does, and restarts Discord through it if it started before
# the patch, or with no arguments when the launcher has some.
set -u

config=${XDG_CONFIG_HOME:-$HOME/.config}/discord
pkg=/usr/share/equicord
[[ -f $pkg/app.asar ]] || exit 0
host=$(readlink -f "$config/Discord") || exit 0
res=${host%/*}/resources
[[ -f $res/app.asar ]] || exit 0

patched_at=0
if ! cmp -s "$res/app.asar" "$pkg/app.asar"; then
    [[ -f $res/_app.asar ]] || mv "$res/app.asar" "$res/_app.asar"
    cp "$pkg"/*.asar "$res/" || exit 1
    patched_at=$(date +%s)
fi

# every process of this folder's Discord
pids() {
    local pid
    for pid in $(pgrep -x Discord); do
        [[ $(readlink "/proc/$pid/exe" 2>/dev/null) == "$host" ]] && echo "$pid"
    done
}

# a process's words; Chromium rewrites its command line as one string, so
# this splits on spaces as well as NULs
words() {
    tr '\0' ' ' <"/proc/$1/cmdline" 2>/dev/null
}

# its main process (the helpers carry --type=)
main_pid() {
    local pid
    for pid in $(pids); do
        [[ " $(words "$pid") " == *" --type="* ]] && continue
        echo "$pid"
        return 0
    done
    return 1
}

# the launcher's arguments, field codes dropped; the user's entry wins
launcher_args() {
    local f
    for f in "${XDG_DATA_HOME:-$HOME/.local/share}/applications/equicord.desktop" \
             /usr/share/applications/equicord.desktop; do
        [[ -f $f ]] || continue
        sed -n 's/^Exec=//p' "$f" | head -n1 | sed -E 's/%[fFuUdDnNickvm]//g' | cut -s -d' ' -f2-
        return
    done
}

# a fresh patch is usually the update itself, with Discord's restart on the way
pid=$(main_pid)
if [[ -z $pid ]] && (( patched_at )); then
    for _ in {1..40}; do
        sleep 0.5
        pid=$(main_pid) && break
    done
fi
[[ -n $pid ]] || exit 0

read -ra args <<<"$(launcher_args)"
started=$(( $(date +%s) - $(ps -o etimes= -p "$pid") ))
read -ra own <<<"$(words "$pid")"
nargs=${#own[@]}
if (( patched_at && started <= patched_at )) || (( nargs <= 1 && ${#args[@]} )); then
    kill $(pids) 2>/dev/null
    for _ in {1..20}; do
        [[ -z $(pids) ]] && break
        sleep 0.5
    done
    kill -9 $(pids) 2>/dev/null
    rm -f "$config"/Singleton{Lock,Socket,Cookie}
    systemd-run --user --quiet --collect --scope --unit="app-equicord-$$" \
        setsid -f /usr/bin/equicord "${args[@]}" >/dev/null 2>&1
fi
