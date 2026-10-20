#!/usr/bin/env bash
# Sends one call to the "alttab" IPC target: `alttab-ipc.sh <function> [arg]`.
#
# Prefers alttab-relay (`qs` costs ~45ms, longer than a fast tap); falls
# back to `qs ipc call` when the relay isn't reachable.
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

# Without the relay, `tab` gets the window list from hyprctl here, wrapped in
# an object (`qs ipc call` splits a top-level array).
if [[ $function == tab && $arg != "{"* ]]; then
    clients=$(hyprctl clients -j 2>/dev/null) || exit 0
    arg="{\"gen\":${arg:--1},\"clients\":$clients}"
fi

if [[ -n $arg ]]; then
    qs ipc call alttab "$function" "$arg" >/dev/null 2>&1
else
    qs ipc call alttab "$function" >/dev/null 2>&1
fi
