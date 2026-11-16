#!/usr/bin/env bash
# Claude's notification sound (freedesktop's "complete"). Used by
# Notifications.qml, the sidebar and Claude Code's terminal hooks.
f=/usr/share/sounds/freedesktop/stereo/complete.oga
[ -r "$f" ] && exec pw-play "$f"
