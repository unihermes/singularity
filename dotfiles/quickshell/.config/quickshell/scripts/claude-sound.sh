#!/usr/bin/env bash
# Claude's notification sound: `claude-sound.sh [done|waiting]` (default done),
# rendered by tools/make-claude-sounds.py. Used by Notifications.qml, the
# sidebar and Claude Code's terminal hooks. Silent while you're looking at
# the terminal it was called from (its window is the focused one).
f="$(dirname "$(readlink -f "$0")")/../sounds/claude-${1:-done}.wav"
[ -r "$f" ] || exit 0
focus=$(hyprctl activewindow -j 2>/dev/null | sed -n 's/.*"pid": *\([0-9]\+\).*/\1/p')
if [ -n "$focus" ] && [ "$focus" -gt 0 ]; then
    p=$$
    while [ "${p:-0}" -gt 1 ]; do
        [ "$p" = "$focus" ] && exit 0
        p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
    done
fi
exec pw-play "$f"
