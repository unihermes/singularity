#!/usr/bin/env bash
# XDG autostart, for a session that has none.
#
# A desktop environment is what normally runs ~/.config/autostart at login;
# Hyprland doesn't, so an .desktop file dropped there by an application -- or
# by Settings > Startup -- did nothing at all on this machine. This is the
# piece that makes those entries mean something. autostart.lua runs `run` once
# per session; Settings reads `list` and writes the files.
#
# It deliberately differs from the XDG spec in one way. The spec says an entry
# in /etc/xdg/autostart runs unless the user hides it, which would mean
# installing this script silently started four programs that had never run on
# this machine before -- two of them (gnome-keyring's pkcs11 and secrets
# entries) duplicating what a systemd user unit already starts. So a system
# entry here is opt-in: it runs only once Settings has copied it into
# ~/.config/autostart. User entries follow the spec exactly -- they run unless
# Hidden=true.
#
# Everything is launched with setsid so nothing is in the compositor's process
# group: a crashing autostart entry then takes itself down rather than being
# killed along with, or holding up, the session.
#
#   autostart.sh run     launch every enabled entry (called at login)
#   autostart.sh list    one TSV record per entry, for Settings
set -uo pipefail

user_dir=${XDG_CONFIG_HOME:-$HOME/.config}/autostart
system_dir=/etc/xdg/autostart
log=${XDG_CACHE_HOME:-$HOME/.cache}/autostart.log
desktop=${XDG_CURRENT_DESKTOP:-Hyprland}

# Read one key out of a .desktop file's [Desktop Entry] group. Later groups
# ([Desktop Action ...]) are ignored: they hold their own Name and Exec, and
# taking the first match in the file would sometimes return an action's.
field() {
	awk -F= -v key="$2" '
		/^\[/ { group = ($0 == "[Desktop Entry]") ; next }
		!group { next }
		index($0, key "=") == 1 { sub(/^[^=]*=/, ""); print; exit }
	' "$1" 2>/dev/null
}

# Whether an entry would run if it were enabled: the desktop has to be one it
# wants, and the binary it names has to exist.
runnable() {
	local file=$1 only not try

	only=$(field "$file" OnlyShowIn)
	[[ -n $only && ";$only;" != *";$desktop;"* ]] && return 1

	not=$(field "$file" NotShowIn)
	[[ -n $not && ";$not;" == *";$desktop;"* ]] && return 1

	try=$(field "$file" TryExec)
	if [[ -n $try ]]; then
		[[ $try == /* ]] && { [[ -x $try ]] || return 1; } \
			|| command -v "$try" &>/dev/null || return 1
	fi
	return 0
}

# An entry counts as on unless it says otherwise. GNOME's own key is honoured
# because half the entries in the wild carry it instead of Hidden.
enabled() {
	local file=$1
	[[ $(field "$file" Hidden) == true ]] && return 1
	[[ $(field "$file" X-GNOME-Autostart-enabled) == false ]] && return 1
	return 0
}

# Field codes are for a file manager passing arguments to an application;
# nothing is being passed here, and left in place they arrive as a literal
# "%u" argument that some programs then try to open. %% is a literal %.
exec_line() {
	field "$1" Exec | sed -E 's/%%/\x01/g; s/%[fFuUdDnNickvm]//g; s/\x01/%/g; s/[[:space:]]+$//'
}

# The session id of a process: setsid made each entry's launcher the leader of
# its own session, and everything the app forks stays in it.
sid() {
	local stat
	{ stat=$(<"/proc/$1/stat"); } 2>/dev/null || return 1
	stat=${stat##*) }
	read -r _ _ _ sid _ <<<"$stat"
	printf '%s' "$sid"
}

# Start entries in the tray. Not every app can be asked to: Steam (-silent),
# Discord (--start-minimized) and CoolerControl (its own setting) can, but
# Spotify's --minimized is Windows-only and it always opens its window. So an
# entry's window is closed for it -- only once the app has its tray icon up,
# because closing the window of an app with no tray quits it, and because the
# splash and updater windows some apps show first (Discord, Steam) come before
# the icon and closing one of those aborts the start. An app that has had its
# icon up for 5 s without opening a window started hidden by itself, and is
# dropped from the watch, so a window the user then opens from the tray is
# theirs. Nothing is watched past 60 s.
to_tray() {
	local -A watching=() iconed=()
	local s item bus pid addr t
	for s; do watching[$s]=1; done

	for (( t = 0; t < 120 && ${#watching[@]}; t++ )); do
		sleep 0.5

		# ":1.77/org/ayatana/NotificationItem/spotify_client" -> session
		for item in $(busctl --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher \
			org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems 2>/dev/null | tr -d '"'); do
			bus=${item%%/*}
			[[ $bus == *.* ]] || continue
			pid=$(busctl --user call org.freedesktop.DBus / org.freedesktop.DBus \
				GetConnectionUnixProcessID s "$bus" 2>/dev/null) || continue
			s=$(sid "${pid#u }") || continue
			[[ -n ${watching[$s]:-} && -z ${iconed[$s]:-} ]] && iconed[$s]=$t
		done

		while read -r addr pid; do
			s=$(sid "$pid") || continue
			[[ -n ${watching[$s]:-} && -n ${iconed[$s]:-} ]] || continue
			printf 'tray %s: closing its window\n' "$(</proc/"$pid"/comm)"
			hyprctl dispatch "hl.dsp.window.close({ window = \"address:0x$addr\" })" >/dev/null
			unset "watching[$s]"
		done < <(hyprctl clients | awk '/^Window /{ a = $2 } /^\tpid:/{ print a, $2 }')

		for s in "${!iconed[@]}"; do
			(( t - iconed[$s] >= 10 )) && unset "watching[$s]" "iconed[$s]"
		done
	done
}

case ${1:-run} in
run)
	mkdir -p "$(dirname "$log")"
	printf '=== %s ===\n' "$(date '+%Y-%m-%d %H:%M:%S')" >>"$log"

	# Hold the entries until the bar's tray is up. Quickshell starts in the
	# same breath as this script and takes a moment to claim the
	# StatusNotifierWatcher name, and an app that looks for a tray before
	# then doesn't always look again: Qt and Electron apps (CoolerControl,
	# Discord) settle on having no tray icon at all. 20 s at most, so a
	# session without the bar still gets its autostart.
	for (( i = 0; i < 100; i++ )); do
		busctl --user status org.kde.StatusNotifierWatcher &>/dev/null && break
		sleep 0.2
	done
	(( i == 100 )) && printf 'no tray after 20 s; starting entries anyway\n' >>"$log"

	shopt -s nullglob
	sessions=()
	for file in "$user_dir"/*.desktop; do
		name=${file##*/}
		enabled "$file" || { printf 'skip %s (disabled)\n' "$name" >>"$log"; continue; }
		runnable "$file" || { printf 'skip %s (not for this session)\n' "$name" >>"$log"; continue; }

		cmd=$(exec_line "$file")
		[[ -n $cmd ]] || { printf 'skip %s (no Exec)\n' "$name" >>"$log"; continue; }

		printf 'run  %s: %s\n' "$name" "$cmd" >>"$log"
		setsid sh -c "$cmd" >>"$log" 2>&1 &
		sessions+=($!)
	done

	(( ${#sessions[@]} )) && to_tray "${sessions[@]}" >>"$log" 2>&1 &
	;;

list)
	# scope \t file \t name \t exec \t enabled \t runnable \t comment \t icon \t OnlyShowIn
	#
	# System entries are listed after the user's, and one that has been
	# copied into ~/.config/autostart is left out of the system list -- the
	# user's copy is the one that decides, and showing both would be two
	# rows for one program disagreeing about whether it starts.
	shopt -s nullglob
	for file in "$user_dir"/*.desktop; do
		name=${file##*/}
		on=no; enabled "$file" && on=yes
		ok=no; runnable "$file" && ok=yes
		printf 'user\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
			"$name" "$(field "$file" Name)" "$(exec_line "$file")" \
			"$on" "$ok" "$(field "$file" Comment)" "$(field "$file" Icon)" "$(field "$file" OnlyShowIn)"
	done
	for file in "$system_dir"/*.desktop; do
		name=${file##*/}
		[[ -e $user_dir/$name ]] && continue
		ok=no; runnable "$file" && ok=yes
		printf 'system\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
			"$name" "$(field "$file" Name)" "$(exec_line "$file")" \
			no "$ok" "$(field "$file" Comment)" "$(field "$file" Icon)" "$(field "$file" OnlyShowIn)"
	done
	;;

*)
	printf 'usage: autostart.sh [run|list]\n' >&2
	exit 2
	;;
esac
