#!/usr/bin/env bash
# One pass over the machine, for the System window's Health page
# (services/Health.qml). Reads only -- nothing here changes anything, so it is
# always safe to run by hand, and safe to paste the output of.
#
# diagnose.sh answers the same question for a human in a terminal and stays
# the thing to run when the shell itself is down. This one answers it for the
# GUI: one record per line, and every finding that has an obvious fix names
# the repair the page should offer as a button. The page never invents a
# repair of its own -- if a check can't be fixed in one command, it says so by
# leaving those fields empty.
#
#   status \t id \t label \t detail \t repairId \t repairLabel
#
# status is ok | warn | bad. Healthy rows are emitted too: a page that only
# listed problems would say nothing at all on a working machine, which is
# indistinguishable from a page that failed to run.
#
# repairId is parsed by Health.qml:
#   restart:<scope>:<unit>   systemctl [--user] restart
#   disable:<scope>:<unit>   systemctl [--user] disable
#   install:<tools>          yay -S, in a terminal
#   clean                    clean.sh, in a terminal
#   relink                   the repo's link.sh, in a terminal
#   log:<path>               tail the file, in a terminal
set -uo pipefail

emit() {
	printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "${5-}" "${6-}"
}

# --- enabled units that aren't running ---------------------------------------
# Enabled is the promise, active is whether it kept it. Oneshots are skipped:
# a succeeded oneshot is inactive by design, and listing those would bury the
# real answer under systemd-tmpfiles and friends on every scan.
for scope in system user; do
	if [[ $scope == user ]]; then sc=(systemctl --user); else sc=(systemctl); fi

	mapfile -t units < <("${sc[@]}" list-unit-files --state=enabled --type=service \
		--plain --no-legend 2>/dev/null | awk '{print $1}')
	(( ${#units[@]} )) || continue

	# One `show` for every unit at once -- forty forks a scan is the
	# difference between a page that opens and a page that hitches.
	"${sc[@]}" show -p Id -p ActiveState -p Type "${units[@]}" 2>/dev/null \
		| awk -v scope="$scope" 'BEGIN { RS = "" ; FS = "\n" }
			{
				id = ""; state = ""; type = ""
				for (i = 1; i <= NF; i++) {
					eq = index($i, "=")
					if (eq == 0) continue
					key = substr($i, 1, eq - 1)
					val = substr($i, eq + 1)
					if (key == "Id") id = val
					else if (key == "ActiveState") state = val
					else if (key == "Type") type = val
				}
				if (id == "" || type == "oneshot") next
				if (state == "active" || state == "activating" || state == "reloading") next
				status = (state == "failed") ? "bad" : "warn"
				printf "%s\tunit:%s:%s\t%s\tEnabled but %s (%s)\trestart:%s:%s\tRestart\n",
					status, scope, id, id, state, scope, scope, id
			}'
done

# --- units in the failed state -----------------------------------------------
# Not the same set as above: a unit started by a dependency, a socket or a
# D-Bus activation is never "enabled", and is exactly the kind that fails
# unnoticed. Health.qml folds a duplicate into whichever row came second.
for scope in system user; do
	if [[ $scope == user ]]; then sc=(systemctl --user); else sc=(systemctl); fi
	while read -r unit; do
		[[ -n $unit ]] || continue
		emit bad "failed:$scope:$unit" "$unit" "Failed ($scope)" "restart:$scope:$unit" Restart
	done < <("${sc[@]}" --failed --plain --no-legend 2>/dev/null | awk '{print $1}')
done

# --- the tools the shell shells out to ---------------------------------------
# A missing one is usually the whole explanation for a single feature being
# dead while everything around it is fine.
missing=()
for tool in hyprctl quickshell grim slurp wl-copy iwctl wpctl brightnessctl \
	notify-send stow cava iw matugen fd; do
	command -v "$tool" &>/dev/null || missing+=("$tool")
done
if (( ${#missing[@]} )); then
	emit bad tools "Missing tools" "${missing[*]}" "install:${missing[*]}" Install
else
	emit ok tools "Required tools" "All present"
fi

# --- disk --------------------------------------------------------------------
# A nearly-full root is the quiet cause of a surprising number of "it just
# stopped working" reports, and the repair is a script this repo already ships.
while read -r target pct; do
	n=${pct%\%}
	[[ $n =~ ^[0-9]+$ ]] || continue
	if   (( n >= 90 )); then emit bad  "disk:$target" "$target" "$pct full" clean "Free space"
	elif (( n >= 80 )); then emit warn "disk:$target" "$target" "$pct full" clean "Free space"
	else                     emit ok   "disk:$target" "$target" "$pct full"
	fi
done < <(df -k --output=source,target,pcent / "$HOME" 2>/dev/null \
	| awk 'NR > 1 && !seen[$1]++ {print $2, $3}')

# --- packages ----------------------------------------------------------------
if command -v pacman &>/dev/null; then
	orphans=$(pacman -Qqtd 2>/dev/null | wc -l)
	if (( orphans > 0 )); then
		emit warn orphans "Orphaned packages" \
			"$orphans installed as a dependency, now unused" clean Remove
	else
		emit ok orphans "Orphaned packages" "None"
	fi

	# pacman keeps every version it ever downloaded; clean.sh trims to the
	# last two. 4 GB is where that is worth a click rather than a mention.
	cache=$(du -sm /var/cache/pacman/pkg 2>/dev/null | awk '{print $1}')
	if [[ $cache =~ ^[0-9]+$ ]]; then
		if (( cache >= 4096 )); then
			emit warn cache "Package cache" "$cache MB of downloaded packages" clean Trim
		else
			emit ok cache "Package cache" "$cache MB"
		fi
	fi
fi

# --- dotfile links -----------------------------------------------------------
# A broken symlink pointing into the repo means the clone moved, or a package
# was added to dotfiles/ without relinking. The app doesn't complain: it just
# falls back to its own defaults, which is why this is worth a check.
#
# Only links into a dotfiles/ path are counted. Electron and Thunderbird both
# keep deliberately dangling symlinks (SingletonLock, lock) naming a host and
# pid that no longer exist, and reporting those as breakage would make this
# check cry wolf on every machine that has ever run Obsidian.
broken=$(find "$HOME/.config" "$HOME/.icons" -maxdepth 4 -xtype l -lname '*/dotfiles/*' 2>/dev/null | wc -l)
if (( broken > 0 )); then
	emit bad links "Broken config links" \
		"$broken dangling symlink(s) into the repo" relink Relink
else
	emit ok links "Config links" "All resolve"
fi

# --- units enabled from a file that is gone ----------------------------------
# systemctl enable leaves a symlink in a .wants directory; removing the
# package it came from leaves that symlink pointing at nothing. systemd logs a
# warning about it on every daemon-reload and nobody ever reads that.
while read -r link; do
	[[ -n $link ]] || continue
	emit warn "stale-unit:${link##*/}" "${link##*/}" \
		"Enabled, but the unit file is gone" "disable:user:${link##*/}" Disable
done < <(find "$HOME/.config/systemd" -xtype l 2>/dev/null)

# --- the shell's own log -----------------------------------------------------
# Where a QML error lands, and a QML error is why a flyout is missing often
# enough to be worth surfacing next to the rest.
log=$HOME/.cache/quickshell.log
if [[ -r $log ]]; then
	errs=$(grep -cE "ERROR|WARN" "$log" 2>/dev/null)
	if (( errs > 0 )); then
		emit warn shell-log "Shell log" "$errs error or warning lines" "log:$log" View
	else
		emit ok shell-log "Shell log" "Clean"
	fi
fi
