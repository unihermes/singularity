#!/usr/bin/env bash
# Singularity - Quickshell
# ~/.config/quickshell/scripts/shell-log-issues.sh [--dismiss] [log]
#
# The shell log's warnings and errors worth reading, one a line, colours
# kept, for the Health scan. Only since the last config load, minus noise
# from outside the shell (portal app ID, MPRIS races, Qt text input).
# --dismiss marks the current lines read until the next log (per-run id).
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
