#!/usr/bin/env bash
# Claude's notification sound: ChatGPT's if installed, else freedesktop's.
# Used by Notifications.qml, the sidebar and Claude Code's terminal hooks.
for f in /usr/lib/chatgpt/resources/codex-notification.wav \
         /usr/share/sounds/freedesktop/stereo/message-new-instant.oga; do
    [ -r "$f" ] && exec pw-play "$f"
done
