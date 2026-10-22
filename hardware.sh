# Singularity - what this machine has
#
# Sourced by install.sh and update.sh (and tools/check-hardware.sh).
# `has CAP` answers from sysfs, so it holds for any machine and is asked
# again on every run: hardware added later is picked up by the next
# update.sh. packages/hardware/CAP.txt is installed where `has CAP`.
#
# The machine type (laptop or desktop) is a choice about how the machine is
# used (hibernation, CoolerControl, the idle ladder); a capability is whether
# a package or fix can do anything here. Gate on the capability wherever one
# exists, on the machine type only for what is a matter of use.

# the capabilities `has` knows, one per packages/hardware/*.txt and more
hw_caps=(battery lid backlight wifi bluetooth fingerprint nvidia intel-gpu
  intel-panel ahci ite-superio ipu6-webcam intel-ish i2c-touchpad charge-modes)

# any PCI device whose class starts with $1 (0x03 display, 0x0106 AHCI),
# from vendor $2 when given
hw_pci() {
  local d class vendor
  for d in /sys/bus/pci/devices/*; do
    read -r class < "$d/class" || continue
    [[ $class == "$1"* ]] || continue
    read -r vendor < "$d/vendor" || continue
    [[ -z ${2:-} || $vendor == "$2" ]] && return 0
  done
  return 1
}

# a PCI device the kernel module $1 claims, by its aliases, whether or not
# the module is loaded (or blacklisted)
hw_pci_driver() {
  local -a aliases
  local d alias modalias
  mapfile -t aliases < <(modinfo -F alias "$1" 2>/dev/null | grep '^pci:')
  (( ${#aliases[@]} )) || return 1
  for d in /sys/bus/pci/devices/*; do
    read -r modalias < "$d/modalias" || continue
    for alias in "${aliases[@]}"; do
      # shellcheck disable=SC2053  # the alias is a glob
      [[ $modalias == $alias ]] && return 0
    done
  done
  return 1
}

has() {
  local f v p
  case $1 in
    battery)
      # the machine's own, not a mouse's or headset's (scope Device)
      for f in /sys/class/power_supply/*; do
        [[ $(cat "$f/type" 2>/dev/null) == Battery ]] || continue
        [[ $(cat "$f/scope" 2>/dev/null) == Device ]] || return 0
      done
      return 1 ;;
    lid)          compgen -G '/proc/acpi/button/lid/*/state' >/dev/null ;;
    backlight)    compgen -G '/sys/class/backlight/*' >/dev/null ;;
    # by the PCI class too, for a card whose firmware isn't loaded yet
    wifi)         compgen -G '/sys/class/ieee80211/*' >/dev/null || hw_pci 0x0280 ;;
    bluetooth)
      compgen -G '/sys/class/bluetooth/hci*' >/dev/null && return 0
      # a USB adapter btusb hasn't bound: interface class e0/01/01
      for f in /sys/bus/usb/devices/*:*; do
        [[ $(cat "$f/bInterfaceClass" "$f/bInterfaceSubClass" "$f/bInterfaceProtocol" 2>/dev/null | tr -d '\n') == e00101 ]] && return 0
      done
      return 1 ;;
    fingerprint)
      # USB readers by vendor: Goodix, Synaptics, Validity, EgisTec, FPC,
      # FocalTech, Next, Upek, AuthenTec, and Elan's 0c** fingerprint line
      for f in /sys/bus/usb/devices/*; do
        v=$(cat "$f/idVendor" 2>/dev/null) || continue
        p=$(cat "$f/idProduct" 2>/dev/null)
        case $v in
          27c6|06cb|138a|1c7a|10a5|2808|298d|147e|08ff) return 0 ;;
          04f3) [[ $p == 0c* ]] && return 0 ;;
        esac
      done
      return 1 ;;
    nvidia)       hw_pci 0x03 0x10de ;;
    intel-gpu)    hw_pci 0x03 0x8086 ;;
    # an Intel GPU driving a built-in panel, where i915's PSR applies
    intel-panel)  has intel-gpu && compgen -G '/sys/class/drm/card*-eDP-*' >/dev/null ;;
    ahci)         hw_pci 0x0106 ;;
    # a desktop board's ITE Super I/O for the fan headers: it87 already sees
    # it, or a Gigabyte board, which all carry one
    ite-superio)
      has battery && return 1
      grep -qs '^it8' /sys/class/hwmon/hwmon*/name && return 0
      grep -qs 'Gigabyte' /sys/class/dmi/id/board_vendor ;;
    ipu6-webcam)  hw_pci_driver intel_ipu6 ;;
    intel-ish)    hw_pci_driver intel_ish_ipc ;;
    i2c-touchpad) compgen -G '/sys/bus/i2c/drivers/i2c_hid_acpi/*-*' >/dev/null ;;
    # the firmware's charge modes (Dell's dell_laptop, for singularity-charge)
    charge-modes) compgen -G '/sys/class/power_supply/BAT*/charge_types' >/dev/null ;;
    *) echo "has: no capability called '$1' (hardware.sh)" >&2; return 2 ;;
  esac
}

# laptop or desktop from the firmware's chassis type, else from a battery
detect_machine() {
  local chassis
  chassis=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || true)
  case $chassis in
    8|9|10|11|14|30|31|32) echo laptop ;;
    3|4|5|6|7|13|15|16|17|23|24|35|36) echo desktop ;;
    *) if has battery; then echo laptop; else echo desktop; fi ;;
  esac
}

# the package lists that apply here: packages/hardware/CAP.txt for each CAP
# this machine has, then packages/MACHINE.txt when there is one
machine_lists() {
  local f cap
  for f in packages/hardware/*.txt; do
    [[ -e $f ]] || continue
    cap=${f##*/}; cap=${cap%.txt}
    if has "$cap"; then echo "$f"; fi
  done
  [[ -f packages/$1.txt ]] && echo "packages/$1.txt"
  return 0
}

# Splits package names into repo_pkgs (in a sync database, for pacman) and
# aur_pkgs (the rest, for yay), so one list can hold both.
split_repo_aur() {
  local p
  local -A repo
  repo_pkgs=() aur_pkgs=()
  while read -r p; do repo[$p]=1; done < <(pacman -Slq 2>/dev/null)
  for p in "$@"; do
    if [[ -n ${repo[$p]:-} ]]; then repo_pkgs+=("$p"); else aur_pkgs+=("$p"); fi
  done
}
