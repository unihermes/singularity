#!/usr/bin/env bash
# Singularity - Quickshell
# ~/.config/quickshell/scripts/shell-log-issues.sh [--dismiss] [log]
#
# The warnings and errors in the shell's log that are worth reading, one a
# line, colours kept. The Health scan counts these and the Shell log row's
# View pages through them.
#
# Only since the configuration last (re)loaded: the log runs from login,
# and an error from a reload that was since fixed and reloaded again isn't
# a problem any more. Lines from outside the shell's code are left out too:
#   - the desktop portal refusing a second app ID (Qt, every launch)
#   - a media player's property failing to update as the player goes away
#     (quickshell's MPRIS polling racing the player's exit)
#   - Qt's Wayland text input disabling a surface after focus has moved on
#     ("Trying to disable ... but ... is focused", on any field losing focus)
#
# --dismiss marks every line there is now as read: later runs skip them
# until the shell starts a new log (each run has its own id, in the
# "Saving logs to" line).
dismiss=0
[[ ${1-} == --dismiss ]] && { dismiss=1; shift; }
log=${1:-$HOME/.cache/quickshell.log}
[[ -r $log ]] || exit 0

mark=${XDG_STATE_HOME:-$HOME/.local/state}/singularity/shell-log-read
run=$(grep -m1 -o 'by-id/[^/"]*' "$log")

if (( dismiss )); then
	[[ -n $run ]] || exit 1
	mkdir -p "${mark%/*}"
	printf '%s %s\n' "$run" "$(wc -l < "$log")" > "$mark"
	exit 0
fi

read -r mrun mline 2>/dev/null < "$mark" || true
[[ -n $run && ${mrun-} == "$run" ]] || mline=0

awk -v skip="${mline:-0}" '
	NR <= skip { next }
	{ plain = $0; gsub(/\033\[[0-9;]*m/, "", plain) }
	plain ~ /INFO: (Reloading configuration|Launching config)/ { n = 0; next }
	plain ~ /(ERROR|WARN)/ {
		if (plain ~ /Failed to register with host portal/) next
		if (plain ~ /qt\.qpa\.wayland\.textinput/) next
		if (plain ~ /Error updating property org\.mpris\.MediaPlayer2/) next
		if (plain ~ /org\.mpris\.MediaPlayer2.*Position/) next
		if (plain ~ /quickshell\.dbus\.properties: QDBusError\(.*ServiceUnknown/) next
		keep[++n] = $0
	}
	END { for (i = 1; i <= n; i++) print keep[i] }
' "$log"
