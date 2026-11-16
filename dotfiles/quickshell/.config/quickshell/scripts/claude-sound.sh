#!/usr/bin/env bash
# Claude's notification sound: `claude-sound.sh [done|waiting]` (default done),
# rendered by tools/make-claude-sounds.py. Used by Notifications.qml, the
# sidebar and Claude Code's terminal hooks.
f="$(dirname "$(readlink -f "$0")")/../sounds/claude-${1:-done}.wav"
[ -r "$f" ] && exec pw-play "$f"
