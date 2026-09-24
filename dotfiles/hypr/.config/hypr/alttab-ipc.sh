#!/usr/bin/env bash
# Sends one call to the "alttab" IPC target: `alttab-ipc.sh <function> [arg]`.
#
# Prefers alttab-relay (alttab-relay.cpp, started alongside quickshell in
# hyprland.lua) over `qs ipc call` -- see that file for why: `qs` is ~45ms of
# process-spawn overhead on its own, which alone can be longer than a fast
# ALT+Tab tap-and-release takes start to finish. Falls back to `qs` when the
# relay isn't reachable, so alt-tab still works (just slower) if the relay
# failed to build during install, hasn't started yet this session, or ever
# stops working -- e.g. a Quickshell update changes the private wire format
# the relay speaks. Every caller goes through this one fallback rather than
# each re-implementing it.
set -euo pipefail

function=$1
arg=${2:-}
message=$function${arg:+ $arg}

relay_sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/singularity-alttab-relay.sock"

# -S: only try the relay if its socket actually exists, rather than paying
# for a doomed connection attempt every time it isn't running.
if [[ -S $relay_sock ]] && echo "$message" | socat - "UNIX-CONNECT:$relay_sock" >/dev/null 2>&1; then
    exit 0
fi

# No relay, so no window list: `tab <gen>` from the bind gets it here, from
# hyprctl, in the form the relay would have built. Wrapped in an object
# rather than handed over as the bare array hyprctl prints, because `qs ipc
# call` splits a top-level JSON array argument into one argument per element
# and `tab` takes exactly one.
if [[ $function == tab && $arg != "{"* ]]; then
    clients=$(hyprctl clients -j 2>/dev/null) || exit 0
    arg="{\"gen\":${arg:--1},\"clients\":$clients}"
fi

if [[ -n $arg ]]; then
    qs ipc call alttab "$function" "$arg" >/dev/null 2>&1
else
    qs ipc call alttab "$function" >/dev/null 2>&1
fi
