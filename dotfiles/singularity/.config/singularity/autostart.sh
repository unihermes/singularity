#!/usr/bin/env bash
# XDG autostart, for a session that has none.
#
# A desktop environment is what normally runs ~/.config/autostart at login;
# Hyprland doesn't, so an .desktop file dropped there by an application -- or
# by Settings > Startup -- did nothing at all on this machine. This is the
# piece that makes those entries mean something. hyprland.lua runs `run` once
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
# "%u" argument that some programs then try to open.
exec_line() {
	field "$1" Exec | sed -E 's/%[fFuUdDnNickvm]//g; s/[[:space:]]+$//'
}

case ${1:-run} in
run)
	mkdir -p "$(dirname "$log")"
	printf '=== %s ===\n' "$(date '+%Y-%m-%d %H:%M:%S')" >>"$log"

	shopt -s nullglob
	for file in "$user_dir"/*.desktop; do
		name=${file##*/}
		enabled "$file" || { printf 'skip %s (disabled)\n' "$name" >>"$log"; continue; }
		runnable "$file" || { printf 'skip %s (not for this session)\n' "$name" >>"$log"; continue; }

		cmd=$(exec_line "$file")
		[[ -n $cmd ]] || { printf 'skip %s (no Exec)\n' "$name" >>"$log"; continue; }

		printf 'run  %s: %s\n' "$name" "$cmd" >>"$log"
		setsid sh -c "$cmd" >>"$log" 2>&1 &
	done
	;;

list)
	# scope \t file \t name \t exec \t enabled \t runnable \t comment
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
		printf 'user\t%s\t%s\t%s\t%s\t%s\t%s\n' \
			"$name" "$(field "$file" Name)" "$(exec_line "$file")" \
			"$on" "$ok" "$(field "$file" Comment)"
	done
	for file in "$system_dir"/*.desktop; do
		name=${file##*/}
		[[ -e $user_dir/$name ]] && continue
		ok=no; runnable "$file" && ok=yes
		printf 'system\t%s\t%s\t%s\t%s\t%s\t%s\n' \
			"$name" "$(field "$file" Name)" "$(exec_line "$file")" \
			no "$ok" "$(field "$file" Comment)"
	done
	;;

*)
	printf 'usage: autostart.sh [run|list]\n' >&2
	exit 2
	;;
esac
