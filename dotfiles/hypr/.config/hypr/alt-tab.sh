#!/usr/bin/env bash
# Opens the ALT+Tab switcher (Quickshell, AltTabSwitcher.qml), or steps it if
# it is already up. The switcher takes keyboard focus and catches the ALT
# release itself; see the alt-tab comment in hyprland.lua for why there is no
# submap.
#
# Every Tab of a held ALT+Tab runs this, not just the first: Hyprland matches
# its binds before forwarding keys to any client, so the ALT+Tab bind wins over
# the switcher's own keyboard grab. shell.qml's onAltTabTab decides whether
# that means opening the switcher or just stepping it -- see the `tab()`
# comment on its IpcHandler for why that decision lives there rather than in
# a separate "is it open yet" probe run from here first.
set -euo pipefail

# Wrapped in an object rather than handed over as the bare array `hyprctl`
# prints: `qs ipc call` (alttab-ipc.sh's fallback path) splits a top-level
# JSON array argument into one positional argument per element instead of
# passing it through as one string, so `tab` (which takes exactly one) would
# reject every call with "too many arguments provided". An object isn't an
# array, so it goes through as the single argument it is.
#
# The list still has to be read fresh here rather than trusted to
# Quickshell's own cache of it -- see AltTabSwitcher.begin() for why -- even
# on a repeat Tab where the shell ends up ignoring it because the switcher is
# already open.
clients=$(hyprctl clients -j 2>/dev/null) || exit 0

"$(dirname "$0")/alttab-ipc.sh" tab "{\"clients\":$clients}"
