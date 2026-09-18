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
# update, so a failure here is a warning, not a fatal error: alt-tab.sh and
# alttab-ipc.sh both fall back to the slower `qs ipc call` path on their own
# whenever this binary or its socket isn't there, so ALT+Tab still works
# (just without the extra latency cut) if this step fails.
alttab_dir="dotfiles/hypr/.config/hypr"
if g++ -std=c++20 -O2 -mno-direct-extern-access \
    "$alttab_dir/alttab-relay.cpp" -o "$alttab_dir/alttab-relay" \
    $(pkg-config --cflags --libs Qt6Core Qt6Network); then
  log "alttab-relay built"
else
  warn "alttab-relay failed to build -- alt-tab.sh will fall back to \`qs ipc call\` (slower, but works)"
fi

log "applying system settings"
fc-cache -f
gtk-update-icon-cache -f /usr/share/icons/kora 2>/dev/null || true
xdg-user-dirs-update || true
xdg-mime default thunar.desktop inode/directory
xdg-mime default org.pwmt.zathura.desktop application/pdf
xdg-settings set default-url-scheme-handler file thunar.desktop || true

# On Wayland, GTK3 apps (Thunar included) read their theme, icons and fonts from
# gsettings and ignore settings.ini, which only GTK4 and tools like fastfetch
# go by. Keep both in step with gtk/.config/gtk-3.0/settings.ini. With no
# session bus, gsettings silently writes to a throwaway in-memory backend, so
# read one key back to catch that.
iface=org.gnome.desktop.interface
gsettings set $iface icon-theme          'kora'
gsettings set $iface gtk-theme           'Adwaita-dark'
gsettings set $iface color-scheme        'prefer-dark'
gsettings set $iface cursor-theme        'Bibata-Modern-Classic'
gsettings set $iface font-name           'Ubuntu Nerd Font 11'
gsettings set $iface document-font-name  'Ubuntu Nerd Font 11'
gsettings set $iface monospace-font-name 'UbuntuMono Nerd Font Mono 11'
if [[ $(gsettings get $iface icon-theme 2>/dev/null) != "'kora'" ]]; then
  warn "gsettings did not stick (no session bus?). Rerun ./install.sh from a"
  warn "logged-in session or Thunar will ignore the icon theme and fonts."
fi

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
# unaffected. Left alone if crypttab asks for a TPM unlock.
if ! grep -qs 'tpm2-device' /etc/crypttab; then
  log "masking systemd TPM setup"
  sudo systemctl mask systemd-tpm2-setup-early.service systemd-tpm2-setup.service
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
  warn "correct the name in hyprland.lua, gtk settings.ini and .icons/default"
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
