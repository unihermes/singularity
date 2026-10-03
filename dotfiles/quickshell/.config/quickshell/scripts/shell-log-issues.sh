#!/usr/bin/env bash
# Singularity - Quickshell
# ~/.config/quickshell/scripts/shell-log-issues.sh
#
# The warnings and errors in the shell's log that are worth reading, one a
# line, colours kept. The Health scan counts these and the Shell log row's
# View pages through them.
#
# Only since the configuration last (re)loaded: the log runs from login,
# and an error from a reload that was since fixed and reloaded again isn't
# a problem any more. Lines from outside the shell's code are left out too:
#   - the desktop portal refusing a second app ID (Qt, every launch)
#   - a media player's Position property failing as the player goes away
#     (quickshell's MPRIS polling racing the player's exit)
log=${1:-$HOME/.cache/quickshell.log}
[[ -r $log ]] || exit 0

awk '
	{ plain = $0; gsub(/\033\[[0-9;]*m/, "", plain) }
	plain ~ /INFO: (Reloading configuration|Launching config)/ { n = 0; next }
	plain ~ /(ERROR|WARN)/ {
		if (plain ~ /Failed to register with host portal/) next
		if (plain ~ /org\.mpris\.MediaPlayer2.*Position/) next
		if (plain ~ /quickshell\.dbus\.properties: QDBusError\(.*ServiceUnknown/) next
		keep[++n] = $0
	}
	END { for (i = 1; i <= n; i++) print keep[i] }
' "$log"
