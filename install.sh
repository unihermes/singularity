#!/usr/bin/env bash
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { printf '\033[1;34m::\033[0m %s\n'    "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n'    "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n'    "$*" >&2; exit 1; }

# Strip comments and blank lines from a package list.
list() { sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$1"; }

if [[ $EUID -eq 0 ]]; then
  die "run as your user, not root (sudo is called where it is needed)"
fi
command -v pacman &>/dev/null || die "this is an Arch provisioning script"

# Ask for sudo once up front so the rest of the run is unattended.
sudo -v

log "syncing and installing base tooling"
sudo pacman -Syu --needed --noconfirm base-devel git stow

if ! command -v yay &>/dev/null; then
  log "bootstrapping yay"
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
  (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$tmp"
  trap - EXIT
fi
yay --version >/dev/null || die "yay bootstrap failed"

# Read a package list into an array. NOT `| xargs`: xargs points its child's
# stdin at /dev/null, so any package manager that stops to ask a question
# reads EOF and aborts instead. That silently killed the whole AUR step.
read_list() {
  local -n _out=$1
  mapfile -t _out < <(list "$2")
}

log "installing repo packages"
read_list pacman_pkgs packages/pacman.txt
if (( ${#pacman_pkgs[@]} > 0 )); then
  sudo pacman -S --needed --noconfirm "${pacman_pkgs[@]}"
fi

log "installing AUR packages"
# Not --noconfirm: you want to see the PKGBUILD diffs before anything builds.
# --answerclean None only skips the "rebuild from scratch?" prompt; diffs and
# the install confirmation still stop for you.
aur_failed=0
read_list aur_pkgs packages/aur.txt
if (( ${#aur_pkgs[@]} > 0 )); then
  yay -S --needed --answerclean None "${aur_pkgs[@]}" || aur_failed=1
fi
# An AUR build breaking should not stop dotfiles and services from being set
# up. It gets reported again at the end so it cannot be missed.
if (( aur_failed )); then
  warn "one or more AUR packages failed, continuing"
fi

log "linking dotfiles"
./link.sh

log "building alttab-relay"
# The ALT+Tab switcher's fast path (see hyprland.lua and
# dotfiles/hypr/.config/hypr/alttab-relay.cpp for why it exists) talks to
# Quickshell over a private, unversioned wire format, and needs
# -mno-direct-extern-access to work around a protected-symbol linking issue
# between this machine's GCC and its Qt6 build (see the flag in this same
# command -- without it, linking fails with a "copy relocation against
# non-copyable protected symbol" error). Both of those are exactly the kind
# of thing that can stop working on some future toolchain or Quickshell
# update, so a failure here is a warning, not a fatal error: alttab-ipc.sh
# falls back to the slower `qs ipc call` path on their own
# whenever this binary or its socket isn't there, so ALT+Tab still works
# (just without the extra latency cut) if this step fails.
alttab_dir="dotfiles/hypr/.config/hypr"
if g++ -std=c++20 -O2 -mno-direct-extern-access \
    "$alttab_dir/alttab-relay.cpp" -o "$alttab_dir/alttab-relay" \
    $(pkg-config --cflags --libs Qt6Core Qt6Network); then
  log "alttab-relay built"
else
  warn "alttab-relay failed to build -- alttab-ipc.sh will fall back to \`qs ipc call\` (slower, but works)"
fi

log "applying system settings"
fc-cache -f
gtk-update-icon-cache -f /usr/share/icons/kora 2>/dev/null || true
xdg-user-dirs-update || true
xdg-mime default thunar.desktop inode/directory
xdg-mime default org.pwmt.zathura.desktop application/pdf
xdg-settings set default-url-scheme-handler file thunar.desktop || true

# Images and media have to be claimed by name, not left to whoever asks
# first: zathura's mupdf plugin lists the common image types in its own
# .desktop, so without this a screenshot opens in the PDF viewer.
#
# The entry is only written once the .desktop is actually on disk. xdg-mime
# will happily record a handler that doesn't exist, and that reads as a
# working default right up until something tries to open the file, so a
# renamed or missing desktop file should be a warning here rather than a
# mystery later.
set_default() {
  local desktop=$1; shift
  if ! [[ -f /usr/share/applications/$desktop || -f $HOME/.local/share/applications/$desktop ]]; then
    warn "$desktop is not installed -- leaving ${*} to whatever claims them"
    return
  fi
  local type
  for type in "$@"; do xdg-mime default "$desktop" "$type" || true; done
}

set_default imv.desktop image/png image/jpeg image/gif image/webp image/bmp \
  image/tiff image/svg+xml
set_default mpv.desktop video/mp4 video/x-matroska video/webm video/quicktime \
  video/x-msvideo audio/mpeg audio/flac audio/ogg audio/x-wav audio/mp4

# Structured text is only *inherited* from text/plain, so an editor's
# MimeType=text/plain doesn't register it for these and the browser -- which
# does name application/json outright -- wins the mimeinfo.cache fallback.
# Naming them keeps JSON and friends in the editor.
set_default codium.desktop application/json application/xml application/x-yaml

# The theme, dark or light, icons, cursor and fonts are the shell's to set:
# Quickshell's AppearanceSync writes them to gsettings from the Appearance
# page at every start. This is the one key it doesn't manage -- no close,
# minimise or maximise buttons in GTK headerbars. GTK4 and libadwaita apps take
# it from the portal, which reads gsettings, and ignore gtk-decoration-layout
# in settings.ini, so without it they keep drawing an X. With no session bus,
# gsettings silently writes to a throwaway in-memory backend, so read it back
# to catch that.
gsettings set org.gnome.desktop.wm.preferences button-layout ':'
if [[ $(gsettings get org.gnome.desktop.wm.preferences button-layout 2>/dev/null) != "':'" ]]; then
  warn "gsettings did not stick (no session bus?). Rerun ./install.sh from a"
  warn "logged-in session or GTK4 apps will keep their headerbar buttons."
fi

# Claude Code: the shell writes ~/.claude/themes/singularity.json from the
# look (AppearanceSync), and this selects it. settings.json is Claude Code's
# own file, so it's edited in place rather than stowed, and a theme picked
# with /theme since is left alone -- only unset or built-in dark is replaced.
python3 - <<'PY' || warn "could not select the Claude Code theme -- pick Singularity under /theme"
import json, os
path = os.path.expanduser("~/.claude/settings.json")
try:
    with open(path) as f:
        settings = json.load(f)
except FileNotFoundError:
    settings = {}
if settings.get("theme", "dark") == "dark":
    settings["theme"] = "custom:singularity"
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path + ".new", "w") as f:
        json.dump(settings, f, indent=2)
        f.write("\n")
    os.replace(path + ".new", path)
PY

# --- boot verbosity ------------------------------------------------------
# Quiet by default: no kernel or unit output on startup or shutdown. Set
# BOOT_VERBOSE=1 to get systemd's [ OK ] lines back, which is worth doing when
# a boot hangs and you need to see which unit it hung on:
#
#   BOOT_VERBOSE=1 ./install.sh
#
# Every file touched is backed up first. A malformed options line -- a lost
# root= UUID above all -- is an unbootable machine, and systemd-boot will not
# tell you why.
BOOT_VERBOSE=${BOOT_VERBOSE:-0}

set_boot_verbosity() {
  local f=$1 mode=$2 want=$3 tmp
  [[ -f $f ]] || return 1
  [[ -f $f.singularity.bak ]] || sudo cp "$f" "$f.singularity.bak"
  tmp=$(mktemp)
  # Filter the cmdline token by token rather than substituting patterns out of
  # it. Adjacent options share the space between them, so a global s/// can
  # only ever delete every other one: `quiet loglevel=3 splash` loses quiet and
  # splash and keeps loglevel.
  awk -v mode="$mode" -v want="$want" '
    function clean(s,   i, n, a, out) {
      n = split(s, a, /[ \t]+/)
      out = ""
      for (i = 1; i <= n; i++) {
        if (a[i] == "") continue
        # drop every verbosity knob, then add back the ones we want
        if (a[i] ~ /^(quiet|splash|loglevel=[0-9]|rd\.udev\.log_level=[0-9])$/) continue
        if (a[i] ~ /^(rd\.)?systemd\.show_status=/) continue
        out = out (out == "" ? "" : " ") a[i]
      }
      if (want == "verbose")
        return out " systemd.show_status=1"
      return out " quiet loglevel=3 rd.udev.log_level=3 systemd.show_status=false"
    }
    mode == "options" && /^[[:space:]]*options[[:space:]]/ {
      sub(/^[[:space:]]*options[[:space:]]+/, "")
      print "options " clean($0)
      next
    }
    mode == "plain" && NF { print clean($0); next }
    { print }
  ' "$f" > "$tmp"
  # Never install an empty or truncated cmdline: that is an unbootable machine.
  if [[ -s $tmp ]] && grep -q 'root=' "$tmp"; then
    sudo cp "$tmp" "$f"
    rm -f "$tmp"
    return 0
  fi
  warn "refusing to write $f, the result had no root= in it"
  rm -f "$tmp"
  return 1
}

if (( BOOT_VERBOSE )); then
  log "making the boot verbose"
  boot_want=verbose
else
  log "making the boot quiet"
  boot_want=quiet
fi

if [[ -f /etc/kernel/cmdline ]]; then
  # Unified kernel image: the cmdline is baked in, so editing the file alone
  # changes nothing until the image is rebuilt.
  set_boot_verbosity /etc/kernel/cmdline plain "$boot_want" && sudo mkinitcpio -P
elif compgen -G "/boot/loader/entries/*.conf" >/dev/null; then
  for entry in /boot/loader/entries/*.conf; do
    grep -q '^options' "$entry" && set_boot_verbosity "$entry" options "$boot_want"
  done
else
  warn "no systemd-boot entry or /etc/kernel/cmdline found, leaving boot alone"
fi

# set_cmdline_token FILE MODE KEY VALUE -- replace (or append) a single
# key=value kernel cmdline token, leaving every other token untouched.
# Adjacent options share the space between them, so a global s/// can only
# ever delete every other one; splitting into tokens first avoids that.
set_cmdline_token() {
  local f=$1 mode=$2 key=$3 value=$4 tmp
  [[ -f $f ]] || return 1
  grep -Eq "(^|[[:space:]])${key}=${value}([[:space:]]|\$)" "$f" && return 0
  [[ -f $f.singularity.bak ]] || sudo cp "$f" "$f.singularity.bak"
  tmp=$(mktemp)
  awk -v mode="$mode" -v key="$key" -v value="$value" '
    function fix(s,   i, n, a, out) {
      n = split(s, a, /[ \t]+/)
      out = ""
      for (i = 1; i <= n; i++) {
        if (a[i] == "" || a[i] ~ ("^" key "=")) continue
        out = out (out == "" ? "" : " ") a[i]
      }
      return out " " key "=" value
    }
    mode == "options" && /^[[:space:]]*options[[:space:]]/ {
      sub(/^[[:space:]]*options[[:space:]]+/, "")
      print "options " fix($0)
      next
    }
    mode == "plain" && NF { print fix($0); next }
    { print }
  ' "$f" > "$tmp"
  if [[ -s $tmp ]] && grep -q 'root=' "$tmp"; then
    sudo cp "$tmp" "$f"
    rm -f "$tmp"
    return 0
  fi
  warn "refusing to write $f, the result had no root= in it"
  rm -f "$tmp"
  return 1
}

# The IPU6 webcam's sensor never satisfies its firmware dependency (missing
# fwnode graph endpoint), so the kernel spends its default ~10s deferred-probe
# window waiting on it every boot before giving up. Telling it to give up in
# 1s instead shrinks whatever else queues up behind that wait.
#
# Separately, and the bigger one in practice: the Intel Sensor Hub
# (intel_ish_ipc, PCI 00:12.0) does a firmware handshake on every boot that
# takes a genuinely variable few seconds, and the kernel probes devices on a
# single serialized thread by default -- so everything else waiting its turn
# in ACPI enumeration order, including the touchpad's entire i2c controller,
# sits frozen behind it too. That's the actual cursor-freeze-at-startup
# cause: udevadm monitor traced across a boot shows total silence in the
# device tree for ~8s, then the touchpad's i2c bus, the touchscreen, and the
# sensor hub's own clients all burst in together the instant it clears --
# and the freeze length tracks how long that handshake happened to take,
# which is why it varied between boots (5s, 10s, 20s+). Marking just that
# driver for async probing lets the kernel move on to unrelated devices
# while it waits, instead of blocking the whole queue on it.
# (Async probing only hides a slow probe while no other module is loading:
# every module's init ends in async_synchronize_full(), which waits on all
# outstanding async probes system-wide. It doesn't help the webcam controller
# below, which is why that one is deferred instead.)
for kv in "deferred_probe_timeout=1" "driver_async_probe=intel_ish_ipc"; do
  key=${kv%%=*}; value=${kv#*=}
  if [[ -f /etc/kernel/cmdline ]]; then
    log "setting kernel cmdline: $kv"
    set_cmdline_token /etc/kernel/cmdline plain "$key" "$value" && sudo mkinitcpio -P
  elif compgen -G "/boot/loader/entries/*.conf" >/dev/null; then
    log "setting kernel cmdline: $kv"
    for entry in /boot/loader/entries/*.conf; do
      grep -q '^options' "$entry" && set_cmdline_token "$entry" options "$key" "$value"
    done
  fi
done

# --- boot speed ----------------------------------------------------------
# /boot (the ESP) is vfat, and vfat is a module. On this laptop the IPU6 camera
# stack stalls kernel module loading for ~10s at boot, until the kernel gives
# up waiting on the ov01a10 sensor. Mounting /boot has to load vfat, so it sits
# in that stall, and sysinit.target, ly and everything after it wait on the
# mount. Loading vfat from the initramfs means the mount needs no module load.
#
# mac_hid, mousedev and joydev are autoloaded for every pointer device and hit
# the same module-loading queue, so preloading them from the initramfs saves
# a little of that same stall. (The cursor freeze itself turned out to be a
# separate logind race -- see the deferred-probe fix below.)
log "loading vfat and input modules from the initramfs"
mkconf=/etc/mkinitcpio.conf
early_modules=(vfat mac_hid mousedev joydev)
if [[ -f $mkconf ]]; then
  missing=()
  for m in "${early_modules[@]}"; do
    grep -Eq "^MODULES=\(.*\<$m\>" "$mkconf" || missing+=("$m")
  done
  if (( ${#missing[@]} )); then
    [[ -f $mkconf.singularity.bak ]] || sudo cp "$mkconf" "$mkconf.singularity.bak"
    if grep -q '^MODULES=(' "$mkconf"; then
      sudo sed -i -E "s/^MODULES=\(([^)]*)\)/MODULES=(\1 ${missing[*]})/; s/^MODULES=\( /MODULES=(/" "$mkconf"
    else
      echo "MODULES=(${missing[*]})" | sudo tee -a "$mkconf" >/dev/null
    fi
    sudo mkinitcpio -P
  fi
fi

# --- panel self refresh --------------------------------------------------
# With PSR on, this Alder Lake eDP panel stops taking new frames after a
# resume: the machine is awake and hyprlock takes the password, but the
# screen stays black. A modprobe.d option rather than i915.enable_psr=0 on
# the cmdline, so the boot-verbosity rewrite above can never drop it. The
# modconf hook copies it into the initramfs, where i915 loads (kms hook).
psrconf=/etc/modprobe.d/singularity-i915.conf
if ! grep -qs 'enable_psr=0' "$psrconf"; then
  log "disabling i915 panel self refresh"
  echo 'options i915 enable_psr=0' | sudo tee "$psrconf" >/dev/null
  sudo mkinitcpio -P
fi

# --- webcam controller ---------------------------------------------------
# The webcam's Visual Sensing Controller (mei_vsc, platform:intel_vsc) spends
# ~11s in a firmware handshake at boot (5s -> 16s). While it runs, every other
# module load waits on it, udev's workers pile up behind those loads, and udev
# finishes nothing else -- including the touchpad, whose evdev nodes exist at
# 5s but whose udev entries weren't written until 16s. libinput skips a
# device udev hasn't finished ("skip unconfigured input device"), so Hyprland
# came up with the keyboard (configured at 3.7s) but no touchpad, and the
# cursor was dead until the handshake ended. Async probing it doesn't help,
# see above. Instead the alias autoload is blacklisted and a timer loads it
# 30s into boot, after login: the stall still happens, but only delays module
# loads for anything hotplugged in that window.
#
# The camera itself also needs that order. ipu_bridge (in intel_ipu6) wires the
# sensor through the VSC's CSI device only if that device already exists when
# ipu6 probes; otherwise ivsc_csi logs "mei-csi probed without device fwnode!"
# and the sensor never shows up in the media graph. So intel_ipu6 and ivsc_csi
# are held back too and loaded after mei_vsc, in order. (Unloading ipu6 to
# re-probe it later oopses the kernel, so it has to be right the first time.)
vscconf=/etc/modprobe.d/singularity-vsc.conf
if ! grep -qs 'blacklist intel_ipu6' "$vscconf"; then
  log "deferring the webcam controller until after login"
  printf 'blacklist %s\n' mei_vsc intel_ipu6 ivsc_csi | sudo tee "$vscconf" >/dev/null
  sudo tee /etc/systemd/system/singularity-vsc.service >/dev/null <<'UNIT'
[Unit]
Description=Load the webcam's Visual Sensing Controller after login

[Service]
Type=oneshot
ExecStart=/usr/bin/modprobe mei_vsc
ExecStart=/usr/bin/modprobe intel_ipu6
ExecStart=/usr/bin/modprobe ivsc_csi
UNIT
  sudo tee /etc/systemd/system/singularity-vsc.timer >/dev/null <<'UNIT'
[Unit]
Description=Load the webcam's Visual Sensing Controller 30s into boot

[Timer]
OnBootSec=30s

[Install]
WantedBy=timers.target
UNIT
  sudo systemctl daemon-reload
  sudo systemctl enable singularity-vsc.timer
  sudo mkinitcpio -P
fi

# --- hibernation ---------------------------------------------------------
# The only swap here is zram, which lives in RAM and can't hold a hibernation
# image. So hibernation gets a swapfile on / sized to RAM (the image is
# compressed, but a busy machine can still need most of it). zram keeps its
# priority of 100, so the swapfile only takes pages once zram is full, and in
# practice is only written when hibernating.
#
# Resuming needs two things before root is mounted: the initramfs `resume`
# hook, and resume=/resume_offset= on the cmdline to say where the image is. A
# swapfile is found by its filesystem's UUID plus the physical offset of its
# first block, so the offset is re-read every run -- recreating the file
# moves it, and a stale offset means a normal boot instead of a resume.
swapfile=/swapfile
ram_gib=$(awk '/^MemTotal:/ { print int($2 / 1048576) + 1 }' /proc/meminfo)
if [[ ! -f $swapfile ]]; then
  log "creating a ${ram_gib}G swapfile for hibernation"
  sudo mkswap -U clear --size "${ram_gib}G" --file "$swapfile" >/dev/null
fi
if ! grep -Eq "^$swapfile[[:space:]]" /etc/fstab; then
  [[ -f /etc/fstab.singularity.bak ]] || sudo cp /etc/fstab /etc/fstab.singularity.bak
  printf '%s none swap defaults 0 0\n' "$swapfile" | sudo tee -a /etc/fstab >/dev/null
fi
swapon --show=NAME --noheadings | grep -qx "$swapfile" || sudo swapon "$swapfile"

if [[ -f $mkconf ]] && ! grep -Eq '^HOOKS=\(.*\<resume\>' "$mkconf"; then
  log "adding the resume hook to the initramfs"
  [[ -f $mkconf.singularity.bak ]] || sudo cp "$mkconf" "$mkconf.singularity.bak"
  # after filesystems and before fsck: the image has to be read back before
  # anything checks or mounts the disk it came from
  if grep -Eq '^HOOKS=\(.*\<fsck\>' "$mkconf"; then
    sudo sed -i -E '/^HOOKS=/ s/\<fsck\>/resume fsck/' "$mkconf"
  else
    sudo sed -i -E '/^HOOKS=/ s/\)/ resume)/' "$mkconf"
  fi
  sudo mkinitcpio -P
fi

resume_uuid=$(findmnt -no UUID -T "$swapfile")
resume_offset=$(sudo filefrag -v "$swapfile" | awk '$1 == "0:" { sub(/\.\.$/, "", $4); print $4; exit }')
if [[ -n $resume_uuid && -n $resume_offset ]]; then
  for kv in "resume=UUID=$resume_uuid" "resume_offset=$resume_offset"; do
    key=${kv%%=*}; value=${kv#*=}
    if [[ -f /etc/kernel/cmdline ]]; then
      grep -Eq "(^|[[:space:]])$kv([[:space:]]|\$)" /etc/kernel/cmdline && continue
      log "setting kernel cmdline: $kv"
      set_cmdline_token /etc/kernel/cmdline plain "$key" "$value" && sudo mkinitcpio -P
    elif compgen -G "/boot/loader/entries/*.conf" >/dev/null; then
      log "setting kernel cmdline: $kv"
      for entry in /boot/loader/entries/*.conf; do
        grep -q '^options' "$entry" && set_cmdline_token "$entry" options "$key" "$value"
      done
    fi
  done
else
  warn "couldn't locate $swapfile on disk, hibernation won't resume"
fi

# How long a closed lid's suspend lasts before it hibernates. lid.sh suspends
# 5 min after the lid shuts and wants hibernation at 1 h, so 55 min here;
# change both together (close_delay and hibernate_after in lid.sh).
sleepconf=/etc/systemd/sleep.conf.d/singularity.conf
if ! grep -qsx 'HibernateDelaySec=55min' "$sleepconf"; then
  log "hibernating after 55 min of lid-closed suspend"
  sudo mkdir -p "${sleepconf%/*}"
  printf '[Sleep]\nHibernateDelaySec=55min\n' | sudo tee "$sleepconf" >/dev/null
fi

# How much of RAM the hibernation image is allowed to hold. The kernel
# defaults to 2/5 of RAM -- 13G here -- and cheerfully fills it, mostly with
# page cache nobody needs back. Everything in the image is compressed going
# down and decompressed coming up with LZO, single-threaded, before the
# desktop appears; observed images ran 4-13G and the big ones roughly doubled
# the resume. Capping the image makes the kernel drop cache and swap out
# anonymous pages before it snapshots, so those pages fault back in lazily
# from the NVMe once you are already logged in -- on demand and in parallel,
# instead of serialized in front of you.
#
# 4G, not a fraction of RAM: what matters is the live working set, and this
# machine's sits well under that even with a browser and an editor up. Raise
# it if hibernating ever starts taking noticeably longer (the kernel is then
# working to free memory it would rather keep).
#
# LZ4 would decompress about twice as fast, but Arch's kernel is built with
# CONFIG_HIBERNATION_COMP_LZ4 unset, so hibernate.compressor= only takes lzo.
imageconf=/etc/tmpfiles.d/singularity-hibernate.conf
image_size=4294967296
if ! grep -qs "image_size .* $image_size\$" "$imageconf"; then
  log "capping the hibernation image at $((image_size / 1024 ** 3))G"
  printf 'w /sys/power/image_size - - - - %s\n' "$image_size" \
    | sudo tee "$imageconf" >/dev/null
  sudo systemd-tmpfiles --create "$imageconf"
fi

# Keep the touchpad from waking the machine. This laptop only has s2idle and
# the I2C touchpad's GPIO interrupt stays live in it, so every idle suspend
# bounced straight back out within seconds -- the machine never actually
# stayed asleep on battery, and hypridle's ladder restarted from zero on each
# wake, dimming and blanking again every ten minutes forever. The keyboard,
# the lid and the power button are still wake sources; only tapping the
# touchpad no longer wakes it. Matched on the driver rather than this
# machine's VEN_0488:00 so it holds for any I2C-HID touchpad.
# lid.sh's stay_dark() is the in-session net for the strays this stops here.
touchpadrule=/etc/udev/rules.d/90-singularity-touchpad-wake.rules
if ! grep -qs 'i2c_hid_acpi' "$touchpadrule"; then
  log "disarming the touchpad as a wake source"
  sudo mkdir -p "${touchpadrule%/*}"
  printf '%s\n' \
    'ACTION=="add|change", SUBSYSTEM=="i2c", DRIVER=="i2c_hid_acpi", ATTR{power/wakeup}="disabled"' \
    | sudo tee "$touchpadrule" >/dev/null
  sudo udevadm control --reload
  sudo udevadm trigger --subsystem-match=i2c --action=change
fi

# --- camera across hibernation -------------------------------------------
# Resuming from hibernation kills a shutdown. What happens, in order:
#
#   PM: hibernation: hibernation exit
#   ivsc_csi intel_vsc-...: mei-csi probed without device fwnode!
#   Oops: general protection fault ... RIP: subdev_close+0x2a [videodev]
#   Comm: CameraManager
#
# The MEI stack re-enumerates on resume, so ivsc_csi probes again -- and by
# then ipu_bridge has long since run, so the CSI device comes back without its
# fwnode and the v4l2 subdevs behind the fds userspace already holds are gone.
# WirePlumber's libcamera monitor keeps half a dozen /dev/v4l-subdev* fds open
# for the whole session; the oops is its CameraManager thread closing one of
# them, which is why it lands at shutdown, when everything gets terminated.
# (The faulting pointer reads "REASON=0" in ASCII -- freed memory reused for a
# systemd environment string.) The oops leaves the task unkillable and systemd
# waits on it forever, so the machine never powers off.
#
# So the fds are dropped before the image is written and WirePlumber is
# started again afterwards: nothing stale is left to close. Only hibernation
# needs this -- plain s2idle keeps the MEI clients alive and resumes fine.
#
# The camera itself does NOT come back after a resume: ivsc_csi is stuck
# fwnode-less until the modules are reloaded, and reloading intel_ipu6 while
# the machine is up oopses the kernel a different way (see the webcam
# controller step), so this doesn't try. Reboot to get the webcam back.
camhook=/usr/lib/systemd/system-sleep/singularity-camera
if [[ ! -f $camhook ]]; then
  log "installing the hibernation camera hook"
  sudo tee "$camhook" >/dev/null <<'HOOK'
#!/bin/sh
# $1 pre|post, $2 suspend|hibernate|hybrid-sleep|suspend-then-hibernate
set -eu
case "$2" in
  hibernate|hybrid-sleep|suspend-then-hibernate) ;;
  *) exit 0 ;;
esac

# Nothing here is allowed to fail: a sleep hook that exits non-zero delays or
# blocks the sleep itself.
#
# v4l2-relayd only runs while something is watching the loopback device, but
# when it is running it holds camera fds of its own. It is started on demand
# by its device unit, so it only has to be stopped.
if [ "$1" = pre ]; then
  for unit in $(systemctl list-units --state=active --plain --no-legend \
                  'v4l2-relayd*' | awk '{ print $1 }'); do
    systemctl stop "$unit" || true
  done
fi

# Sleep hooks run as root outside any session, so each logged-in user's own
# manager is addressed through the --user -M user@ form.
for uid in $(loginctl list-sessions --no-legend | awk '{ print $2 }' | sort -u); do
  user=$(id -nu "$uid" 2>/dev/null) || continue
  case "$1" in
    pre)  systemctl --user -M "$user@" stop wireplumber.service || true ;;
    post) systemctl --user -M "$user@" start wireplumber.service || true ;;
  esac
done
exit 0
HOOK
  sudo chmod +x "$camhook"
fi

# --- virtual webcam ------------------------------------------------------
# The IPU6 camera only works through libcamera. PipeWire apps (browsers)
# reach it that way, but Discord's voice engine opens /dev/video* directly and
# finds only the IPU6's raw capture nodes, which never deliver a frame (it
# reports the camera as "in use"). v4l2-relayd bridges the gap: it owns a
# v4l2loopback device called "Laptop Webcam" and starts libcamerasrc only
# while some app has that device open, so the camera light is off otherwise.
# The sensor's native 1284x812 is cropped to 1280x720, which every app takes.
#
# The sensor is raw Bayer with no colour controls of its own, so colour is
# corrected by videobalance in the pipeline. Tune the values here, not in
# /etc: a rerun rewrites webcam.conf and restarts the relay when it differs.
webcam_conf='VIDEOSRC="libcamerasrc ! videoconvert ! videobalance brightness=0.0 contrast=1.0 saturation=1.0 hue=0.0 ! videocrop left=2 right=2 top=46 bottom=46 ! videoscale ! videorate"
FORMAT=YUY2
WIDTH=1280
HEIGHT=720
FRAMERATE=30/1
CARD_LABEL="Laptop Webcam"'
if [[ ! -f /etc/modprobe.d/v4l2loopback.conf ]]; then
  log "setting up the virtual webcam"
  echo 'v4l2loopback' | sudo tee /etc/modules-load.d/v4l2loopback.conf >/dev/null
  echo 'options v4l2loopback exclusive_caps=1 card_label="Laptop Webcam"' \
    | sudo tee /etc/modprobe.d/v4l2loopback.conf >/dev/null
  sudo mkdir -p /etc/v4l2-relayd.d /etc/systemd/system/v4l2-relayd@.service.d
  # The unit's device sandbox predates libcamera's software ISP, which
  # allocates its frame buffers from these two.
  sudo tee /etc/systemd/system/v4l2-relayd@.service.d/libcamera.conf >/dev/null <<'UNIT'
[Service]
DeviceAllow=/dev/dma_heap/system rw
DeviceAllow=/dev/udmabuf rw
UNIT
  sudo systemctl daemon-reload
  sudo modprobe v4l2loopback
fi
if [[ "$(cat /etc/v4l2-relayd.d/webcam.conf 2>/dev/null)" != "$webcam_conf" ]]; then
  log "writing the virtual webcam pipeline"
  printf '%s\n' "$webcam_conf" | sudo tee /etc/v4l2-relayd.d/webcam.conf >/dev/null
  sudo systemctl enable v4l2-relayd@webcam.service
  sudo systemctl restart v4l2-relayd@webcam.service
fi

log "enabling services"

# Without seatd running, libseat falls back to talking to logind directly,
# and logind's own device enumeration for a fresh session is not guaranteed
# to be done by the time Hyprland asks for the touchpad/touchscreen: it can
# answer "No such device" for a device that exists but that logind hasn't
# cataloged yet, and Hyprland does not retry -- the cursor stays dead until
# something else happens to re-announce the device, which on this laptop is
# whatever else is still settling ten-plus seconds into boot. seatd hands
# devices over directly with no such race, and Hyprland/aquamarine prefer it
# over logind automatically whenever its socket exists.
sudo systemctl enable --now seatd.service
sudo usermod -aG seat "$USER"

# Network: iwd for Wi-Fi, systemd-networkd for addresses, systemd-resolved for
# DNS. iwd's own DHCP stays off (its default), so it and networkd never fight
# over the interface. networkd does nothing without a .network file and a
# Minimal install may not have one, so DHCP configs are added only when
# /etc/systemd/network has none. Existing configs are left alone.
if ! compgen -G "/etc/systemd/network/*.network" >/dev/null; then
  log "adding DHCP configs for systemd-networkd"
  sudo mkdir -p /etc/systemd/network
  sudo tee /etc/systemd/network/25-wireless.network >/dev/null <<'NET'
[Match]
Type=wlan

[Network]
DHCP=yes
IgnoreCarrierLoss=3s
NET
  # RequiredForOnline=no: an unplugged port would otherwise make
  # systemd-networkd-wait-online sit out its full timeout.
  sudo tee /etc/systemd/network/20-wired.network >/dev/null <<'NET'
[Match]
Type=ether

[Link]
RequiredForOnline=no

[Network]
DHCP=yes
NET
fi
sudo systemctl enable --now iwd systemd-networkd systemd-resolved
# resolved only answers apps that ask it, so resolv.conf has to point at its
# stub. Done after resolved is running so DNS is never pointed at nothing. A
# resolv.conf that is already a symlink is left alone.
if [[ ! -L /etc/resolv.conf ]]; then
  [[ -f /etc/resolv.conf ]] && sudo cp /etc/resolv.conf /etc/resolv.conf.singularity.bak
  sudo ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
fi
systemctl --user enable --now pipewire pipewire-pulse wireplumber

# Nothing enables BlueZ on a Minimal install, and the bar's Bluetooth module
# and the pairing agent below both need its daemon.
sudo systemctl enable --now bluetooth.service
# `systemctl cat` exits non-zero on a missing unit; `list-unit-files` does not,
# so it is the wrong test for "is this installed". The file check is a fallback
# for template units, which some systemd versions will not `cat`.
have_unit() {
  systemctl cat "$1" &>/dev/null     || [[ -f /usr/lib/systemd/system/$1 || -f /etc/systemd/system/$1 ]]
}

# power-profiles-daemon. Nothing was managing the ACPI platform_profile, which
# meant it sat wherever the firmware left it (this laptop boots into "quiet",
# capping performance on AC for no saving worth having). PPD drives that and
# intel_pstate's EPP together, which are the two levers this chip responds to.
# Not TLP: the two fight over the same knobs, and TLP has nothing the bar can
# switch on demand.
if have_unit power-profiles-daemon.service; then
  log "enabling power-profiles-daemon"
  sudo systemctl enable --now power-profiles-daemon.service

  # performance on AC, balanced on battery. PPD has no such rule of its own --
  # it only exposes ActiveProfile for something else to drive, which the bar
  # already does on demand via busctl (see PpdProfile.qml) -- so a udev rule
  # drives the same property on every charger plug/unplug. Its bus policy lets
  # anyone set ActiveProfile with no polkit prompt, so udev running this as
  # root needs nothing extra. Every power_supply device is checked rather than
  # trusting whichever one fired the rule, since a USB-C-only laptop like this
  # one can expose the charger as more than one power_supply.
  #
  # power_supply RUN+= rules fire on far more than plug/unplug -- this
  # machine's USB-C controller reports a "change" uevent roughly once a
  # second even while idle -- so the script only writes ActiveProfile when
  # the computed target actually differs from what it last wrote. Without
  # that guard, any manual profile pick made from the bar or Settings gets
  # overwritten within a second by this script re-asserting the same AC-based
  # value. The stamp lives in /run so a reboot (or AC state actually
  # changing) is what invalidates it, not time.
  log "installing AC-power profile switch"
  sudo tee /usr/local/bin/singularity-power-profile >/dev/null <<'PROFILE'
#!/bin/sh
set -eu
profile=balanced
for f in /sys/class/power_supply/*/online; do
  [ "$(cat "$f" 2>/dev/null)" = "1" ] && { profile=performance; break; }
done
stamp=/run/singularity-power-profile.last
[ "$(cat "$stamp" 2>/dev/null || true)" = "$profile" ] && exit 0
busctl set-property org.freedesktop.UPower.PowerProfiles \
  /org/freedesktop/UPower/PowerProfiles \
  org.freedesktop.UPower.PowerProfiles ActiveProfile s "$profile"
printf %s "$profile" > "$stamp"
PROFILE
  sudo chmod +x /usr/local/bin/singularity-power-profile

  sudo tee /etc/udev/rules.d/99-singularity-power-profile.rules >/dev/null <<'RULES'
SUBSYSTEM=="power_supply", ATTR{type}=="Mains", RUN+="/usr/local/bin/singularity-power-profile"
SUBSYSTEM=="power_supply", ATTR{type}=="USB", RUN+="/usr/local/bin/singularity-power-profile"
RULES
  sudo udevadm control --reload-rules
  sudo /usr/local/bin/singularity-power-profile || true
fi

# Pairing agent. Without one BlueZ cannot complete a pairing at all -- see the
# unit's own comment. It is a user service because it is per-session, and it
# ships in dotfiles/systemd rather than being written here so `systemctl --user
# cat` shows the reasoning next to the unit.
if command -v bt-agent &>/dev/null; then
  log "enabling the bluetooth pairing agent"
  systemctl --user enable --now bt-agent.service
fi

# See the unit's own comment: rfkill, volume and brightness already survive a
# reboot on their own (systemd-rfkill, wireplumber, systemd-backlight); this
# is the missing piece for Bluetooth's own adapter power.
log "enabling Bluetooth power state restore"
systemctl --user enable --now bt-power-restore.service

# Quickshell is the notification daemon. A swaync left from an earlier
# install is D-Bus-activated, and would take the name first when something
# notifies before the shell is up; masking its unit stops the activation.
if systemctl --user cat swaync.service &>/dev/null; then
  log "masking swaync, which the shell replaces"
  systemctl --user mask --now swaync.service
fi


# iwd is Type=dbus, so systemd waits for it to claim its bus name before
# reaching network.target, and ly waits on network.target via
# systemd-user-sessions. iwd needs crypto modules first, and those sit in the
# same camera module-loading stall as vfat, which held the greeter back ~9s.
# Type=exec counts iwd as started once it launches. Wi-Fi comes up the same.
if have_unit iwd.service; then
  log "stopping ly from waiting on iwd"
  sudo mkdir -p /etc/systemd/system/iwd.service.d
  printf '[Service]\nType=exec\n' | sudo tee /etc/systemd/system/iwd.service.d/singularity.conf >/dev/null
  sudo systemctl daemon-reload
fi

# systemd's TPM SRK setup costs ~2s every boot and nothing here uses it: no
# TPM-unlocked LUKS, secure boot off. Masking only stops the setup running; it
# does not touch what is stored in the TPM, so Windows and BitLocker are
# unaffected. Left alone if crypttab asks for a TPM unlock. The setup also
# allocates the NvPCRs, so systemd-pcrproduct, which measures into one, fails
# every boot without it and is masked too.
if ! grep -qs 'tpm2-device' /etc/crypttab; then
  log "masking systemd TPM setup"
  sudo systemctl mask systemd-tpm2-setup-early.service systemd-tpm2-setup.service \
    systemd-pcrproduct.service
fi

systemctl --user enable --now pipewire pipewire-pulse wireplumber ||
  warn "could not enable the pipewire user units"

# Display manager. Deliberately NOT --now: ly takes over a VT, and starting it
# here would pull the terminal out from under this script mid-run. It comes up
# on the next boot instead.
# ly 1.x ships a templated unit that has to be bound to a VT (ly@tty2.service);
# 0.x shipped a plain ly.service. Detect rather than guess.
dm_unit=""
if have_unit ly@.service; then
  dm_unit="ly@tty2.service"
elif have_unit ly.service; then
  dm_unit="ly.service"
fi

if [[ -n $dm_unit ]]; then
  sudo systemctl enable "$dm_unit"
  # ly owns the VT it runs on, so the getty there has to go or the two fight
  # over tty2 and you get a garbled or flickering greeter.
  if [[ $dm_unit == ly@* ]]; then
    sudo systemctl disable getty@tty2.service &>/dev/null || true
  fi
  # Enabling a greeter is not enough on its own. archinstall's Minimal profile
  # leaves the default target at multi-user.target, which never pulls in
  # display-manager.service, so ly stays enabled and never actually starts.
  if [[ $(systemctl get-default) != graphical.target ]]; then
    log "switching default boot target to graphical.target"
    sudo systemctl set-default graphical.target
  fi

  # Theme the greeter as Neutrino. ly draws on a Linux VT, and the VT has no
  # true colour: a 24-bit escape is squashed onto the nearest of its 16 palette
  # slots, so full_color with the ramp's hexes would come out as plain black
  # and white. Instead the palette itself becomes the ramp -- the same slots
  # alacritty uses, except red and green, which carry the shell's alert and
  # good tints so a failed login still reads as one -- and ly picks slots by
  # index. The palette is per-VT and only on the greeter's.
  if [[ -f /etc/ly/config.ini ]]; then
    log "theming ly"
    sudo tee /etc/ly/singularity.sh >/dev/null <<'LY'
#!/bin/sh
# Written by singularity's install.sh. Run by ly (start_cmd) before it takes
# the TTY: loads the Neutrino ramp into the VT palette, slots 0-15.
[ "$TERM" = linux ] || exit 0
i=0
for c in 0b0b0b a87676 7d9b7d 969696 a0a0a0 aeaeae b8b8b8 d4e4f4 \
         303030 a87676 7d9b7d adadad b8b8b8 c8c8c8 d8d8d8 ebebeb; do
  printf '\033]P%x%s' "$i" "$c"
  i=$((i + 1))
done
# repaint with the new slot 0, or the old black shows through until ly draws
clear
LY
    sudo chmod 755 /etc/ly/singularity.sh
    # Edit keys in place rather than shipping a whole config.ini: pacman keeps
    # a modified config and drops upstream's as .pacnew, so a full copy would
    # quietly stop picking up new options. 8-colour ids are 1-based (0x0001
    # black .. 0x0008 white); a 0x01 top byte is bold, which the VT draws from
    # the bright half of the palette, so bold black is slot 8, the border grey.
    set_ly() {
      local key=$1 value=$2 esc
      # the clock format has a | in it, the sed delimiter
      esc=${value//\\/\\\\}; esc=${esc//|/\\|}; esc=${esc//&/\\&}
      if sudo grep -q "^$key = " /etc/ly/config.ini; then
        sudo sed -i "s|^$key = .*|$key = $esc|" /etc/ly/config.ini
      else
        echo "$key = $value" | sudo tee -a /etc/ly/config.ini >/dev/null
      fi
    }
    [[ -f /etc/ly/config.ini.singularity.bak ]] ||
      sudo cp /etc/ly/config.ini /etc/ly/config.ini.singularity.bak
    set_ly start_cmd /etc/ly/singularity.sh
    set_ly full_color false
    set_ly bg 0x00000001            # slot 0, base   #0b0b0b
    set_ly fg 0x00000008            # slot 7, text   #d4e4f4 (pale blue)
    set_ly border_fg 0x01000001     # slot 8, border #303030
    set_ly error_bg 0x00000001
    set_ly error_fg 0x00000002      # slot 1, alert  #a87676
    # the bar clock's format, minus the thin spaces the VT font lacks
    set_ly clock '%H:%M:%S | %m/%d/%y'
    set_ly hide_version_string true
    set_ly animation none
  fi
else
  warn "no ly unit found. Units the package ships:"
  pacman -Ql ly 2>/dev/null | grep '\.service$' || warn "  (none)"
fi

log "verifying font and icon names actually resolve"
fc-match sans-serif
fc-match serif
fc-match monospace
[[ -n $(fc-list "UbuntuMono Nerd Font") ]] || warn "UbuntuMono Nerd Font not found: install ttf-ubuntu-mono-nerd"
[[ -d /usr/share/icons/kora ]] || warn "kora icon theme not found in /usr/share/icons"
if [[ ! -d /usr/share/icons/Bibata-Modern-Classic ]]; then
  warn "Bibata-Modern-Classic not found. Variants actually installed:"
  ls /usr/share/icons 2>/dev/null | grep -i bibata || warn "  (none)"
  warn "pick one under Settings > Appearance > System > Cursor"
fi

if (( aur_failed )); then
  warn "AUR packages did not all install. Rerun ./install.sh, or install the"
  warn "failures one at a time with: yay -S <name>"
fi

cat <<'EOF'

done. reboot, and ly will greet you -- pick Hyprland from the session list
with the left/right arrow keys.

If Hyprland does not start you land back at the greeter with no explanation.
Drop to a TTY with ctrl+alt+F3, log in, and run it by hand to see the error:

    Hyprland
    hyprctl configerrors
EOF
