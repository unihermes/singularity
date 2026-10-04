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
#   status \t id \t label \t detail \t repairId \t repairLabel [\t repairId \t repairLabel]...
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
#   pacdiff                  pacdiff, in a terminal
#   firmware                 fwupdmgr refresh + update, in a terminal
#   log:<path>               page through the shell log's issues, in a terminal
#   log-fix:<path>           hand those lines to Claude Code in the repo, in a terminal
#   log-dismiss:<path>       hide the lines there are now until new ones appear
set -uo pipefail

emit() {
	local IFS=$'\t'
	printf '%s\n' "$*"
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
fi

# A package upgrade that finds a config edited by hand writes the new one
# beside it as .pacnew; removing a package keeps an edited config as
# .pacsave. Found with find, not pacman's database, which misses .pacsave.
if command -v pacdiff &>/dev/null; then
	mapfile -t pending < <(pacdiff -o -f 2>/dev/null)
	if (( ${#pending[@]} )); then
		names=$(printf '%s\n' "${pending[@]##*/}" | head -n 3 | paste -sd, | sed 's/,/, /g')
		(( ${#pending[@]} > 3 )) && names+=", …"
		emit warn pacnew "Config files to merge" "${#pending[@]}: $names" pacdiff Merge
	else
		emit ok pacnew "Config files to merge" "None"
	fi
fi

# --- firmware ----------------------------------------------------------------
# From fwupd's cached metadata, so this doesn't go to the network; the
# repair refreshes it first. Exit 2 is fwupd's "nothing to do".
#
# A device fwupd won't update yet says why in its Problems: a laptop's
# system firmware wants mains power, for one. Then there's nothing a click
# can do, so the row says what will (plug in) rather than offering an
# Update that fwupdmgr refuses. A UEFI capsule is also staged on the EFI
# system partition first, and a small ESP full of kernels fails that write
# at the last step; that's checked here against the release's size.
#
# Asking starts fwupd if it isn't running, which takes seconds, so while it
# isn't, its last answer is reused for up to six hours. The firmware repair
# deletes that copy.
fwcache=${XDG_CACHE_HOME:-$HOME/.cache}/singularity/fwupd-updates
if command -v fwupdmgr &>/dev/null; then
	if ! systemctl -q is-active fwupd && [[ -n $(find "$fwcache" -mmin -360 2>/dev/null) ]]; then
		{ read -r rc; out=$(cat); } < "$fwcache"
	else
		out=$(timeout 20 fwupdmgr get-updates --json --no-unreported-check \
			--no-metadata-check 2>/dev/null)
		rc=$?
		if (( rc == 0 || rc == 2 )); then
			mkdir -p "${fwcache%/*}"
			printf '%s\n%s' "$rc" "$out" > "$fwcache"
		fi
	fi
	if (( rc == 0 )) && command -v python3 &>/dev/null; then
		# one line per device: name, current, newest, blocking problems,
		# flags, the newest release's size in bytes
		mapfile -t fw < <(python3 -c '
import json, sys
try: d = json.load(sys.stdin)
except Exception: sys.exit()
for dev in d.get("Devices", []):
    rel = dev.get("Releases", [])
    if not rel: continue
    newest = rel[0].get("Version", "")
    print("|".join([dev.get("Name", "?"), dev.get("Version", ""), newest,
                     ",".join(dev.get("Problems", [])), ",".join(dev.get("Flags", [])),
                     str(rel[0].get("Size", 0))]))
' <<<"$out")
	else
		fw=()
	fi
	if (( rc == 0 && ${#fw[@]} > 0 )); then
		# "|" rather than a tab: read collapses runs of whitespace, so an
		# empty Problems would shift every field after it
		IFS='|' read -r name cur new problems flags size <<<"${fw[0]}"
		# the ESP: the first vfat mount of the usual three
		espfree=-1 esp=""
		for d in /efi /boot/efi /boot; do
			if [[ $(findmnt -n -o FSTYPE --target "$d" 2>/dev/null | tail -n1) == vfat ]]; then
				esp=$d
				espfree=$(df -B1 --output=avail "$d" 2>/dev/null | tail -n1 | tr -d ' ')
				break
			fi
		done
		mb() { awk -v b="$1" 'BEGIN { printf "%.0f MB", b / 1048576 }'; }
		more=""
		(( ${#fw[@]} > 1 )) && more=" and $(( ${#fw[@]} - 1 )) more"
		what="$name $cur → $new$more"
		if [[ $problems == *require-ac* ]]; then
			emit warn firmware "Firmware" "$what · plug in the charger to install"
		# the capsule plus a little room for fwupd's own files
		elif [[ $flags == *needs-reboot* ]] && (( espfree >= 0 && size > 0 && espfree < size + 2097152 )); then
			emit bad firmware "Firmware" "$what · needs $(mb $((size + 2097152))) free on $esp, which has $(mb "$espfree")"
		elif [[ -n $problems ]]; then
			emit warn firmware "Firmware" "$what · fwupd won't yet: ${problems//,/, }"
		elif [[ $flags == *needs-reboot* ]]; then
			emit warn firmware "Firmware" "$what · installs on the next restart" firmware Update
		else
			emit warn firmware "Firmware" "$what" firmware Update
		fi
	elif (( rc == 0 || rc == 2 )); then
		emit ok firmware "Firmware" "Up to date" firmware Refresh
	else
		emit ok firmware "Firmware" "fwupd didn't answer" firmware Check
	fi
else
	emit ok firmware "Firmware" "Not checked, fwupd isn't installed" install:fwupd Install
fi

# --- reclaimable space -------------------------------------------------------
# What clean.sh would free, by the same rules, so the row can say how much a
# click is worth. Always carries the button: cleaning up is worth offering on
# a healthy machine too. Tool caches clean.sh purges through the tool itself
# (docker, flatpak, npm, ...) aren't counted, so this is a lower bound.
reclaim=()   # "KiB<TAB>what"
add() { [[ $1 =~ ^[0-9]+$ ]] && (( $1 > 0 )) && reclaim+=("$1"$'\t'"$2"); }
sizeof() { du -skc "$@" 2>/dev/null | awk 'END {print $1}'; }

# paccache's dry run ends in "(disk space saved: 812.3 MiB)"
if command -v paccache &>/dev/null; then
	add "$({ paccache -dk2; paccache -duk0; } 2>/dev/null | awk '
		match($0, /saved: [0-9.]+ [KMGT]?i?B/) {
			split(substr($0, RSTART + 7, RLENGTH - 7), f, " ")
			m = index("KMGT", substr(f[2], 1, 1))
			t += f[1] * (m ? 1024 ^ (m - 1) : 1 / 1024)
		}
		END {printf "%d", t}')" "old packages"
fi
add "$(sizeof /var/cache/pacman/pkg/download-*)" "partial downloads"

if command -v pacman &>/dev/null; then
	mapfile -t orphaned < <(pacman -Qqtd 2>/dev/null)
	(( ${#orphaned[@]} )) && add "$(pacman -Qi "${orphaned[@]}" 2>/dev/null | awk '
		/^Installed Size/ {
			m = index("KMGT", substr($5, 1, 1))
			t += $4 * (m ? 1024 ^ (m - 1) : 1 / 1024)
		}
		END {printf "%d", t}')" "orphans"
fi

add "$(sizeof /var/lib/systemd/coredump)" "core dumps"
running=$(uname -r)
for dir in /usr/lib/modules/*/; do
	dir=${dir%/}
	[[ -d $dir && ${dir##*/} != "$running" && ! -d $dir/kernel ]] || continue
	pacman -Qqo "$dir" &>/dev/null || add "$(sizeof "$dir")" "old kernel modules"
done

add "$(sizeof "$HOME/.cache/yay" "$HOME/.cache/paru")" "AUR builds"
add "$(sizeof "$HOME/.cache/pip" "$HOME/.cargo/registry/cache" "$HOME/.cargo/registry/src" \
	"$HOME/.cargo/git/checkouts" "$HOME/go/pkg/mod" "$HOME/.cache/go-build")" "language caches"
add "$(sizeof "$HOME/.cache/thumbnails")" "thumbnails"
add "$(sizeof "$HOME/.local/share/Trash")" "trash"

# ~/.cache files untouched for 30 days, minus what is already counted above
# and the browsers, which clean.sh only sweeps the HTTP cache of.
skip=()
for d in yay paru pip go-build thumbnails zen floorp mozilla firefox librewolf \
	chromium google-chrome BraveSoftware vivaldi; do
	skip+=(-not -path "$HOME/.cache/$d/*")
done
add "$(find "$HOME/.cache" -type f "${skip[@]}" -atime +30 -printf '%s\n' 2>/dev/null \
	| awk '{t += $1} END {printf "%d", t / 1024}')" "stale cache"

total=0
for r in "${reclaim[@]}"; do (( total += ${r%%$'\t'*} )); done
if (( total < 1024 )); then
	emit ok reclaim "Reclaimable space" "Nothing worth clearing" clean "Clean up"
else
	# the two biggest sources, so the row says where the space is
	detail=$(printf '%s\n' "${reclaim[@]}" \
		| awk -F '\t' '{s[$2] += $1} END {for (k in s) print s[k] "\t" k}' \
		| sort -rn | awk -F '\t' -v total="$total" '
			function size(k) { return k >= 1048576 ? sprintf("%.1f GB", k / 1048576) : sprintf("%d MB", k / 1024) }
			NR <= 2 && $1 >= 1024 { top = top (top ? ", " : "") $2 " " size($1) }
			END { print "About " size(total) ": " top }')
	# 2 GB is where it is worth a click rather than a mention
	if (( total >= 2 * 1024 * 1024 )); then
		emit warn reclaim "Reclaimable space" "$detail" clean "Clean up"
	else
		emit ok reclaim "Reclaimable space" "$detail" clean "Clean up"
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
# enough to be worth surfacing next to the rest. Counted by
# shell-log-issues.sh: since the last reload, without other programs' noise.
log=$HOME/.cache/quickshell.log
if [[ -r $log ]]; then
	errs=$("$(dirname "$0")/shell-log-issues.sh" "$log" | wc -l)
	if (( errs > 0 )); then
		fix=()
		command -v claude >/dev/null && fix=("log-fix:$log" "Fix with Claude")
		emit warn shell-log "Shell log" "$errs $( (( errs == 1 )) && echo line || echo lines) to read since the shell loaded" \
			"log:$log" View "log-dismiss:$log" Dismiss "${fix[@]}"
	else
		emit ok shell-log "Shell log" "Clean"
	fi
fi
