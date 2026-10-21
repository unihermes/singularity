#!/usr/bin/env bash
# Restarts Quickshell (Restart shell in the Control Centre, the bar's menu
# and Settings). Hyprland runs it, so the new shell gets Hyprland's
# environment. Some tray apps (Spotify) open their window when the tray goes
# away with the old shell; a window that comes up for an app that was only
# in the tray is closed again once its icon is back, so it stays there.
set -uo pipefail

log=${XDG_CACHE_HOME:-$HOME/.cache}/quickshell.log

# The session id of a process: an app's windows and tray icon can belong to
# different processes of it, but they share a session.
sid() {
	local stat
	{ stat=$(<"/proc/$1/stat"); } 2>/dev/null || return 1
	stat=${stat##*) }
	read -r _ _ _ sid _ <<<"$stat"
	printf '%s' "$sid"
}

# the sessions of the apps with a tray icon up
tray_sessions() {
	local item bus pid
	# ":1.77/org/ayatana/NotificationItem/spotify_client" -> session
	for item in $(busctl --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher \
		org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems 2>/dev/null | tr -d '"'); do
		bus=${item%%/*}
		[[ $bus == *.* ]] || continue
		pid=$(busctl --user call org.freedesktop.DBus / org.freedesktop.DBus \
			GetConnectionUnixProcessID s "$bus" 2>/dev/null) || continue
		sid "${pid#u }" && echo
	done
}

# "<address> <pid>" per window
windows() {
	hyprctl clients | awk '/^Window /{ a = $2 } /^\tpid:/{ print a, $2 }'
}

declare -A windowed=() tray_only=() iconed=()
while read -r _ pid; do
	s=$(sid "$pid") && windowed[$s]=1
done < <(windows)
for s in $(tray_sessions); do
	[[ -z ${windowed[$s]:-} ]] && tray_only[$s]=1
done

qs kill
sleep 0.5
setsid quickshell >"$log" 2>&1 </dev/null &

# Up to 20 s for the icons to come back; a window still opening 2 s after
# its app's icon is back is the user's, and left alone.
for (( t = 0; t < 40 && ${#tray_only[@]}; t++ )); do
	sleep 0.5
	for s in $(tray_sessions); do
		[[ -n ${tray_only[$s]:-} && -z ${iconed[$s]:-} ]] && iconed[$s]=$t
	done
	while read -r addr pid; do
		s=$(sid "$pid") || continue
		[[ -n ${tray_only[$s]:-} && -n ${iconed[$s]:-} ]] || continue
		hyprctl dispatch "hl.dsp.window.close({ window = \"address:0x$addr\" })" >/dev/null
		unset "tray_only[$s]" "iconed[$s]"
	done < <(windows)
	for s in "${!iconed[@]}"; do
		(( t - iconed[$s] >= 4 )) && unset "tray_only[$s]" "iconed[$s]"
	done
done
