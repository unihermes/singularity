#!/usr/bin/env bash
# XDG autostart, which Hyprland doesn't run: autostart.lua calls `run` once
# per session, Settings > Startup reads `list` and writes the files. Unlike
# the spec, a system entry (/etc/xdg/autostart) is opt-in: it runs only once
# Settings copies it into ~/.config/autostart. User entries run unless
# Hidden=true. Launched with setsid, out of the compositor's process group.
#   autostart.sh run     launch every enabled entry (called at login)
#   autostart.sh list    one TSV record per entry, for Settings
set -uo pipefail

user_dir=${XDG_CONFIG_HOME:-$HOME/.config}/autostart
system_dir=/etc/xdg/autostart
log=${XDG_CACHE_HOME:-$HOME/.cache}/autostart.log
desktop=${XDG_CURRENT_DESKTOP:-Hyprland}

# one key from the [Desktop Entry] group only (actions have their own)
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

# strips field codes (they'd arrive as a literal "%u"); %% is a literal %
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

# Starts an entry in the tray by closing its window once its tray icon is up
# (closing earlier would quit it or abort a splash). An app with its icon up
# 5 s and no window started hidden itself; nothing is watched past 60 s.
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

	# wait (20 s at most) for the bar's tray: Qt and Electron apps that find
	# no StatusNotifierWatcher don't look again
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
	# System entries after the user's, minus those the user has copied.
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
