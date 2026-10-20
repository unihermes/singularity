#!/usr/bin/env bash
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { printf '\033[1;34m::\033[0m %s\n'    "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n'    "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n'    "$*" >&2; exit 1; }

# Strip comments and blank lines from a package list.
list() { sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$1"; }

usage() {
  cat <<'EOF'
usage: ./install.sh laptop|desktop

  laptop   everything, with hibernation, the battery helpers and the
           laptop's boot and power fixes
  desktop  the same desktop without the laptop-only packages and fixes
EOF
}

# Laptop or desktop: picks packages/laptop.txt or desktop.txt and the
# `if (( laptop ))` steps. Recorded for update.sh.
case ${1:-} in
  laptop)  laptop=1 ;;
  desktop) laptop=0 ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac
machine=$1
machinefile=${XDG_STATE_HOME:-$HOME/.local/state}/singularity/machine

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

# Reads a package list into an array. Not `| xargs`, which gives the child
# /dev/null as stdin, so any prompt aborts.
read_list() {
  local -n _out=$1
  mapfile -t _out < <(list "$2")
}

mkdir -p "${machinefile%/*}"
echo "$machine" > "$machinefile"

log "installing repo packages for a $machine"
read_list pacman_pkgs packages/pacman.txt
read_list machine_pkgs "packages/$machine.txt"
pacman_pkgs+=("${machine_pkgs[@]}")
if (( ${#pacman_pkgs[@]} > 0 )); then
  sudo pacman -S --needed --noconfirm "${pacman_pkgs[@]}"
fi

# No <name>-debug packages from AUR builds, unless makepkg.conf already
# says something about debug.
makepkg_conf=${XDG_CONFIG_HOME:-$HOME/.config}/pacman/makepkg.conf
if ! grep -qs 'debug' "$makepkg_conf"; then
  log "turning off -debug packages for AUR builds"
  mkdir -p "${makepkg_conf%/*}"
  printf '# singularity: no <name>-debug package next to every AUR build\nOPTIONS+=(!debug)\n' >> "$makepkg_conf"
fi

log "installing AUR packages"
# Not --noconfirm, so PKGBUILD diffs are shown; --sudoloop keeps sudo alive
# through long builds.
aur_failed=0
read_list aur_pkgs packages/aur.txt
if [[ -f packages/aur-$machine.txt ]]; then
  read_list machine_aur packages/aur-$machine.txt
  aur_pkgs+=("${machine_aur[@]}")
fi
if (( ${#aur_pkgs[@]} > 0 )); then
  yay -S --needed --sudoloop --answerclean None "${aur_pkgs[@]}" || aur_failed=1
fi
# An AUR build breaking should not stop dotfiles and services from being set
# up. It gets reported again at the end so it cannot be missed.
if (( aur_failed )); then
  warn "one or more AUR packages failed, continuing"
fi

log "linking dotfiles"
./link.sh

log "building alttab-relay"
# alttab-relay: ALT+Tab's fast path to Quickshell (alttab-relay.cpp). It
# depends on an unversioned wire format and -mno-direct-extern-access, so a
# failure only warns: alttab-ipc.sh falls back to `qs ipc call`.
alttab_dir="dotfiles/hypr/.config/hypr"
if g++ -std=c++20 -O2 -mno-direct-extern-access \
    "$alttab_dir/alttab-relay.cpp" -o "$alttab_dir/alttab-relay" \
    $(pkg-config --cflags --libs Qt6Core Qt6Network); then
  log "alttab-relay built"
else
  warn "alttab-relay failed to build -- alttab-ipc.sh will fall back to \`qs ipc call\` (slower, but works)"
fi

log "building display-curve"
# display-curve: a lifted tone curve for the displays display-fixes.lua lists;
# a failure only warns.
curve_dir="dotfiles/hypr/.config/hypr"
curve_gen=$(mktemp -d)
if wayland-scanner client-header "$curve_dir/wlr-gamma-control-unstable-v1.xml" \
      "$curve_gen/wlr-gamma-control-unstable-v1-client-protocol.h" \
    && wayland-scanner private-code "$curve_dir/wlr-gamma-control-unstable-v1.xml" "$curve_gen/protocol.c" \
    && cc -O2 -I"$curve_gen" "$curve_dir/display-curve.c" "$curve_gen/protocol.c" \
      -o "$curve_dir/display-curve" -lwayland-client -lm; then
  log "display-curve built"
else
  warn "display-curve failed to build -- displays listed in display-fixes.lua keep their own tone curve"
fi
rm -rf "$curve_gen"

log "applying system settings"
fc-cache -f
gtk-update-icon-cache -f /usr/share/icons/kora 2>/dev/null || true
xdg-user-dirs-update || true
xdg-mime default thunar.desktop inode/directory
xdg-mime default org.pwmt.zathura.desktop application/pdf
xdg-settings set default-url-scheme-handler file thunar.desktop || true

# Image and media types are claimed by name (zathura's plugin lists images
# too). A handler is only recorded once its .desktop exists.
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

# structured text inherits from text/plain only, so it's named outright
set_default codium.desktop application/json application/xml application/x-yaml

# The shell sets theme, icons, cursor and fonts via gsettings; this is the
# one key it doesn't: no headerbar buttons (GTK4 reads it from the portal).
# Read back, since with no session bus gsettings writes nowhere.
gsettings set org.gnome.desktop.wm.preferences button-layout ':'
if [[ $(gsettings get org.gnome.desktop.wm.preferences button-layout 2>/dev/null) != "':'" ]]; then
  warn "gsettings did not stick (no session bus?). Rerun ./install.sh from a"
  warn "logged-in session or GTK4 apps will keep their headerbar buttons."
fi

# Claude Code: selects the Singularity theme the shell writes (unless one
# was picked with /theme) and the fullscreen renderer (unless /tui picked one).
python3 - <<'PY' || warn "could not set up Claude Code -- pick Singularity under /theme, then /tui fullscreen"
import json, os
path = os.path.expanduser("~/.claude/settings.json")
try:
    with open(path) as f:
        settings = json.load(f)
except FileNotFoundError:
    settings = {}
before = dict(settings)
if settings.get("theme", "dark") == "dark":
    settings["theme"] = "custom:singularity"
settings.setdefault("tui", "fullscreen")
if settings != before:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path + ".new", "w") as f:
        json.dump(settings, f, indent=2)
        f.write("\n")
    os.replace(path + ".new", path)
PY

# LibreOffice set up like Word: the ribbon, Office save formats, a Normal.ott
# with Word's styles in Carlito, Zotero's add-in. Once per profile.
setup_libreoffice() {
  local user="$HOME/.config/libreoffice/4/user" work oxt
  command -v soffice &>/dev/null || return 0
  [[ -e $user/template/Normal.ott ]] && return 0
  if pgrep -x soffice.bin &>/dev/null; then
    warn "LibreOffice is open, so it was left as it is. Close it and rerun ./install.sh"
    return 0
  fi
  log "setting LibreOffice up like Word"
  work=$(mktemp -d)

  # Word's Normal: 11 pt, 1.08 spacing, 8 pt after, blue headings, Letter
  # with 1 in margins
  cat > "$work/Normal.fodt" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<office:document xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
 xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0"
 xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
 xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0"
 xmlns:svg="urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0"
 office:version="1.3" office:mimetype="application/vnd.oasis.opendocument.text">
 <office:font-face-decls>
  <style:font-face style:name="Carlito" svg:font-family="Carlito" style:font-family-generic="swiss" style:font-pitch="variable"/>
 </office:font-face-decls>
 <office:styles>
  <style:default-style style:family="paragraph">
   <style:paragraph-properties style:tab-stop-distance="0.5in" fo:hyphenation-ladder-count="no-limit" style:writing-mode="page"/>
   <style:text-properties style:font-name="Carlito" fo:font-size="11pt" fo:language="en" fo:country="US" fo:hyphenate="false"
    style:font-name-asian="Carlito" style:font-size-asian="11pt" style:font-name-complex="Carlito" style:font-size-complex="11pt"/>
  </style:default-style>
  <style:style style:name="Standard" style:family="paragraph" style:class="text">
   <style:paragraph-properties fo:margin-top="0pt" fo:margin-bottom="8pt" fo:line-height="108%" fo:orphans="2" fo:widows="2"/>
  </style:style>
  <style:style style:name="Text_20_body" style:display-name="Text Body" style:family="paragraph" style:parent-style-name="Standard" style:class="text"/>
  <style:style style:name="Heading" style:family="paragraph" style:parent-style-name="Standard" style:next-style-name="Standard" style:class="text">
   <style:paragraph-properties fo:margin-bottom="0pt" fo:keep-with-next="always"/>
   <style:text-properties fo:color="#2f5496" style:font-name="Carlito" style:font-name-asian="Carlito" style:font-name-complex="Carlito"/>
  </style:style>
  <style:style style:name="Heading_20_1" style:display-name="Heading 1" style:family="paragraph" style:parent-style-name="Heading" style:next-style-name="Standard" style:default-outline-level="1" style:class="text">
   <style:paragraph-properties fo:margin-top="12pt"/>
   <style:text-properties fo:font-size="16pt" fo:font-weight="normal" style:font-size-asian="16pt" style:font-weight-asian="normal" style:font-size-complex="16pt" style:font-weight-complex="normal"/>
  </style:style>
  <style:style style:name="Heading_20_2" style:display-name="Heading 2" style:family="paragraph" style:parent-style-name="Heading" style:next-style-name="Standard" style:default-outline-level="2" style:class="text">
   <style:paragraph-properties fo:margin-top="2pt"/>
   <style:text-properties fo:font-size="13pt" fo:font-weight="normal" style:font-size-asian="13pt" style:font-weight-asian="normal" style:font-size-complex="13pt" style:font-weight-complex="normal"/>
  </style:style>
  <style:style style:name="Heading_20_3" style:display-name="Heading 3" style:family="paragraph" style:parent-style-name="Heading" style:next-style-name="Standard" style:default-outline-level="3" style:class="text">
   <style:paragraph-properties fo:margin-top="2pt"/>
   <style:text-properties fo:color="#1f3763" fo:font-size="12pt" fo:font-weight="normal" style:font-size-asian="12pt" style:font-weight-asian="normal" style:font-size-complex="12pt" style:font-weight-complex="normal"/>
  </style:style>
  <style:style style:name="Title" style:family="paragraph" style:parent-style-name="Standard" style:next-style-name="Standard" style:class="chapter">
   <style:paragraph-properties fo:margin-bottom="0pt" fo:line-height="100%" fo:text-align="start"/>
   <style:text-properties fo:font-size="28pt" fo:letter-spacing="-0.5pt" style:font-size-asian="28pt" style:font-size-complex="28pt"/>
  </style:style>
  <style:style style:name="Subtitle" style:family="paragraph" style:parent-style-name="Standard" style:next-style-name="Standard" style:class="chapter">
   <style:paragraph-properties fo:margin-top="0pt" fo:text-align="start"/>
   <style:text-properties fo:color="#595959" fo:letter-spacing="0.75pt" style:font-size-asian="11pt" style:font-size-complex="11pt"/>
  </style:style>
 </office:styles>
 <office:automatic-styles>
  <style:page-layout style:name="pm1">
   <style:page-layout-properties fo:page-width="8.5in" fo:page-height="11in" style:print-orientation="portrait"
    fo:margin-top="1in" fo:margin-bottom="1in" fo:margin-left="1in" fo:margin-right="1in"/>
  </style:page-layout>
 </office:automatic-styles>
 <office:master-styles>
  <style:master-page style:name="Standard" style:page-layout-name="pm1"/>
 </office:master-styles>
 <office:body>
  <office:text>
   <text:p text:style-name="Standard"/>
  </office:text>
 </office:body>
</office:document>
EOF

  # A headless run also creates the profile on a machine where LibreOffice
  # has never opened, so the registry below has a file to go into.
  mkdir -p "$user/template"
  if ! soffice --headless --infilter="OpenDocument Text Flat XML" --convert-to ott:writer8_template \
      --outdir "$user/template" "$work/Normal.fodt" >/dev/null 2>&1; then
    rm -rf -- "$work"
    warn "LibreOffice could not write the Normal template, so it was left as it is"
    return 0
  fi
  rm -rf -- "$work"

  python3 -I - "$user/registrymodifications.xcu" <<'EOF'
import sys

TABBED = "notebookbar.ui"
MODES = "/org.openoffice.Office.UI.ToolbarMode"
FACTORY = "/org.openoffice.Setup/Office/Factories/org.openoffice.Setup:Factory['{}']"

settings = [
    (MODES, f"Active{app}", TABBED) for app in ("Writer", "Calc", "Impress", "Draw")
] + [
    (f"{MODES}/Applications/org.openoffice.Office.UI.ToolbarMode:Application['{app}']", "Active", TABBED)
    for app in ("Writer", "Calc", "Impress", "Draw")
] + [
    (f"{MODES}/Applications/org.openoffice.Office.UI.ToolbarMode:Application['{app}']"
     "/Modes/org.openoffice.Office.UI.ToolbarMode:ModeEntry['Tabbed']", "HasMenubar", "false")
    for app in ("Writer", "Calc", "Impress", "Draw")
] + [
    (FACTORY.format("com.sun.star.text.TextDocument"), "ooSetupFactoryDefaultFilter", "MS Word 2007 XML"),
    (FACTORY.format("com.sun.star.sheet.SpreadsheetDocument"), "ooSetupFactoryDefaultFilter", "Calc MS Excel 2007 XML"),
    (FACTORY.format("com.sun.star.presentation.PresentationDocument"), "ooSetupFactoryDefaultFilter", "Impress MS PowerPoint 2007 XML"),
    (FACTORY.format("com.sun.star.text.TextDocument"), "ooSetupFactoryTemplateFile", "$(user)/template/Normal.ott"),
    ("/org.openoffice.Office.Common/Save/Document", "WarnAlienFormat", "false"),
    # Fonts for documents that don't come from the template (HTML, plain text).
    *[("/org.openoffice.Office.Writer/DefaultFont", f, "Carlito")
      for f in ("Standard", "Heading", "List", "Caption", "Index")],
]

path = sys.argv[1]
try:
    lines = open(path, encoding="utf-8").read().splitlines()
except FileNotFoundError:
    lines = ['<?xml version="1.0" encoding="UTF-8"?>',
             '<oor:items xmlns:oor="http://openoffice.org/2001/registry" '
             'xmlns:xs="http://www.w3.org/2001/XMLSchema" '
             'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">',
             '</oor:items>']

keys = {f'<item oor:path="{p}"><prop oor:name="{n}"' for p, n, _ in settings}
lines = [l for l in lines if not any(l.startswith(k) for k in keys)]
end = lines.index("</oor:items>")
lines[end:end] = [
    f'<item oor:path="{p}"><prop oor:name="{n}" oor:op="fuse"><value>{v}</value></prop></item>'
    for p, n, v in settings
]
open(path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
EOF

  # Zotero's add-in ships inside Zotero. Without Zotero now, install it later
  # from Zotero's Settings › Cite › Word Processors.
  oxt=$(compgen -G "/usr/lib/zotero*/integration/libreoffice/Zotero_LibreOffice_Integration.oxt" | head -n1 || true)
  if [[ -n $oxt ]]; then
    unopkg add --force --suppress-license "$oxt" &>/dev/null ||
      warn "could not add Zotero's LibreOffice add-in -- add it from Zotero's Settings › Cite"
  fi
}
setup_libreoffice

# --- kernel command line -------------------------------------------------
# Per boot loader: a UKI's /etc/kernel/cmdline, systemd-boot's options lines,
# or GRUB_CMDLINE_LINUX_DEFAULT. Changes go through edit_cmdline, files are
# backed up first, and the image or grub.cfg is rebuilt once at the end.
cmdline_mode="" cmdline_files=()
if [[ -f /etc/kernel/cmdline ]]; then
  cmdline_mode=plain cmdline_files=(/etc/kernel/cmdline)
elif compgen -G "/boot/loader/entries/*.conf" >/dev/null; then
  cmdline_mode=options
  mapfile -t cmdline_files < <(grep -l '^options' /boot/loader/entries/*.conf || true)
elif [[ -f /etc/default/grub ]] && command -v grub-mkconfig &>/dev/null; then
  cmdline_mode=grub cmdline_files=(/etc/default/grub)
else
  warn "no systemd-boot entry, /etc/kernel/cmdline or GRUB config found, leaving the kernel command line alone"
fi
cmdline_changed=0
rebuild_initramfs=0

# Puts $1 over $2 only when the options differ as a set of words, and never
# an empty one or one without root= (GRUB's has none: grub-mkconfig adds it).
words() { sed -E 's/^GRUB_CMDLINE_LINUX_DEFAULT="(.*)"$/\1/' "$1" | tr -s ' \t' '\n\n' | sort; }
install_cmdline() {
  local tmp=$1 f=$2
  if [[ $(words "$tmp") == "$(words "$f")" ]]; then
    rm -f "$tmp"
    return 1
  fi
  if [[ -s $tmp ]] && { [[ $cmdline_mode == grub ]] || grep -q 'root=' "$tmp"; }; then
    [[ -f $f.singularity.bak ]] || sudo cp "$f" "$f.singularity.bak"
    sudo cp "$tmp" "$f"
    rm -f "$tmp"
    return 0
  fi
  warn "refusing to write $f, the result had no root= in it"
  rm -f "$tmp"
  return 1
}

# edit_cmdline KEY TOKENS -- drop every KEY= token (with an empty KEY every
# verbosity knob) and append TOKENS. Token by token, since a global s///
# loses every other adjacent option.
edit_cmdline() {
  local key=$1 add=$2 f tmp
  for f in "${cmdline_files[@]}"; do
    tmp=$(mktemp)
    awk -v mode="$cmdline_mode" -v key="$key" -v add="$add" '
      function edit(s,   i, n, a, out) {
        n = split(s, a, /[ \t]+/)
        out = ""
        for (i = 1; i <= n; i++) {
          if (a[i] == "") continue
          if (key != "" && index(a[i], key "=") == 1) continue
          if (key == "" && a[i] ~ /^(quiet|splash|loglevel=[0-9]|rd\.udev\.log_level=[0-9]|(rd\.)?systemd\.show_status=.*)$/) continue
          out = out (out == "" ? "" : " ") a[i]
        }
        return out (out == "" ? "" : " ") add
      }
      mode == "options" && /^[[:space:]]*options[[:space:]]/ {
        sub(/^[[:space:]]*options[[:space:]]+/, "")
        print "options " edit($0)
        next
      }
      mode == "plain" && NF { print edit($0); next }
      mode == "grub" && /^GRUB_CMDLINE_LINUX_DEFAULT=/ {
        sub(/^GRUB_CMDLINE_LINUX_DEFAULT=/, "")
        gsub(/^["\047]|["\047]$/, "")
        print "GRUB_CMDLINE_LINUX_DEFAULT=\"" edit($0) "\""
        next
      }
      { print }
    ' "$f" > "$tmp"
    install_cmdline "$tmp" "$f" && cmdline_changed=1
  done
  return 0
}

# --- boot verbosity ------------------------------------------------------
# Quiet by default; BOOT_VERBOSE=1 ./install.sh brings systemd's [ OK ] lines
# back for debugging a hang.
BOOT_VERBOSE=${BOOT_VERBOSE:-0}
if (( BOOT_VERBOSE )); then
  log "making the boot verbose"
  edit_cmdline "" "systemd.show_status=1"
else
  log "making the boot quiet"
  edit_cmdline "" "quiet loglevel=3 rd.udev.log_level=3 systemd.show_status=false"
fi

# --- boot splash and menu ------------------------------------------------
# the UKI's Arch logo (--splash) stays up over the firmware's
for preset in /etc/mkinitcpio.d/*.preset; do
  grep -Eqs '^[^#]*--splash' "$preset" || continue
  log "removing the Arch splash from ${preset##*/}"
  [[ -f $preset.singularity.bak ]] || sudo cp "$preset" "$preset.singularity.bak"
  sudo sed -i -E '/^[^#]/ s/ ?--splash[= ][^ "'\'']*//' "$preset"
  rebuild_initramfs=1
done

# systemd-boot's menu hidden (hold Space to show it); an EFI-variable timeout
# would beat loader.conf, so it's cleared
esp=$(sudo bootctl -p 2>/dev/null || true)
loaderconf=$esp/loader/loader.conf
if [[ -n $esp ]] && sudo test -f "$loaderconf" && ! sudo grep -Eqx 'timeout[[:space:]]+0' "$loaderconf"; then
  log "hiding the boot menu"
  sudo test -f "$loaderconf.singularity.bak" || sudo cp "$loaderconf" "$loaderconf.singularity.bak"
  sudo sed -i -E '/^[[:space:]]*timeout([[:space:]]|$)/d' "$loaderconf"
  echo 'timeout 0' | sudo tee -a "$loaderconf" >/dev/null
fi
if [[ -e /sys/firmware/efi/efivars/LoaderConfigTimeout-4a67b082-0a4c-41cf-b6c7-440b29bb8c4f ]]; then
  sudo bootctl set-timeout "" || true
fi

# singularity-boot: lists systemd-boot's entries and sets the default
# (LoaderEntryDefault) for Settings > Startup, through pkexec with a polkit
# action for the local session. Root-owned in /usr/local/bin.
if [[ -n $esp ]]; then
  log "installing the boot entry helper"
  sudo tee /usr/local/bin/singularity-boot >/dev/null <<'BOOT'
#!/bin/sh
# singularity-boot list            systemd-boot's entries, as bootctl's JSON
# singularity-boot default ENTRY   boot ENTRY when nothing else is picked
set -eu
case ${1:-} in
  list) exec bootctl list --json=short --no-pager ;;
  default)
    id=${2:-}
    case $id in
      ''|*[!A-Za-z0-9._@+-]*) echo "not an entry id: $id" >&2; exit 2 ;;
    esac
    bootctl list --json=short --no-pager | grep -Fq "\"id\":\"$id\"" \
      || { echo "systemd-boot has no entry $id" >&2; exit 1; }
    exec bootctl set-default "$id" ;;
  *) echo "usage: singularity-boot list | default ENTRY" >&2; exit 2 ;;
esac
BOOT
  sudo chmod 755 /usr/local/bin/singularity-boot

  sudo tee /usr/share/polkit-1/actions/org.singularity.boot.policy >/dev/null <<'POLICY'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
  "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
<policyconfig>
  <action id="org.singularity.boot">
    <description>Choose which operating system starts</description>
    <message>Authentication is required to choose which operating system starts</message>
    <defaults>
      <allow_any>auth_admin</allow_any>
      <allow_inactive>auth_admin</allow_inactive>
      <allow_active>yes</allow_active>
    </defaults>
    <annotate key="org.freedesktop.policykit.exec.path">/usr/local/bin/singularity-boot</annotate>
  </action>
</policyconfig>
POLICY
fi

# Shorter deferred-probe timeout (the IPU6 sensor never resolves), and async
# probing for intel_ish_ipc, whose variable firmware handshake otherwise
# froze everything behind it, the touchpad included. Harmless elsewhere.
if (( laptop )); then
  edit_cmdline deferred_probe_timeout "deferred_probe_timeout=1"
  edit_cmdline driver_async_probe "driver_async_probe=intel_ish_ipc"
fi

# --- boot speed ----------------------------------------------------------
# vfat (for /boot) and the pointer helpers from the initramfs, so mounting
# the ESP doesn't wait in the camera's module-loading stall.
mkconf=/etc/mkinitcpio.conf
# early_modules MODULE... -- adds whichever aren't there yet to MODULES=().
early_modules() {
  local m missing=()
  [[ -f $mkconf ]] || return 0
  for m in "$@"; do
    grep -Eq "^MODULES=\(.*\<$m\>" "$mkconf" || missing+=("$m")
  done
  (( ${#missing[@]} )) || return 0
  log "loading ${missing[*]} from the initramfs"
  [[ -f $mkconf.singularity.bak ]] || sudo cp "$mkconf" "$mkconf.singularity.bak"
  if grep -q '^MODULES=(' "$mkconf"; then
    sudo sed -i -E "s/^MODULES=\(([^)]*)\)/MODULES=(\1 ${missing[*]})/; s/^MODULES=\( /MODULES=(/" "$mkconf"
  else
    echo "MODULES=(${missing[*]})" | sudo tee -a "$mkconf" >/dev/null
  fi
  rebuild_initramfs=1
}
if (( laptop )); then
  early_modules vfat mac_hid mousedev joydev
fi

# --- nvidia (desktop) ----------------------------------------------------
# nvidia loaded from the initramfs, so it takes over before the greeter; the
# kms hook is dropped, as it only added a 2s amdgpu wait.
if (( ! laptop )) && pacman -Q nvidia-open &>/dev/null; then
  early_modules nvidia nvidia_modeset nvidia_uvm nvidia_drm
  if grep -Eq '^HOOKS=\(.*\<kms\>' "$mkconf"; then
    log "leaving the integrated GPU out of the initramfs"
    [[ -f $mkconf.singularity.bak ]] || sudo cp "$mkconf" "$mkconf.singularity.bak"
    sudo sed -i -E '/^HOOKS=/ { s/ kms\>//; s/\(kms /(/ }' "$mkconf"
    rebuild_initramfs=1
  fi
fi

# --- SATA probing (desktop) ----------------------------------------------
# The B650's AHCI asks for staggered spin-up (~0.3s per empty port);
# probing in parallel is fine for SSDs.
if (( ! laptop )); then
  edit_cmdline libahci.ignore_sss "libahci.ignore_sss=1"
fi

# --- fans (desktop) ------------------------------------------------------
# it87 for the B650I's fan headers needs ACPI's port claim ignored, or
# CoolerControl sees only the GPU fans. Loaded at boot, not in the initramfs.
fanconf=/etc/modprobe.d/singularity-it87.conf
fanload=/etc/modules-load.d/singularity-it87.conf
if (( ! laptop )) && ! grep -qs 'ignore_resource_conflict=1' "$fanconf"; then
  log "setting up the motherboard fan driver"
  echo 'options it87 ignore_resource_conflict=1' | sudo tee "$fanconf" >/dev/null
  echo 'it87' | sudo tee "$fanload" >/dev/null
  sudo modprobe it87 || warn "it87 did not load -- is it87-dkms-git built? see dkms status"
fi

# --- panel self refresh --------------------------------------------------
# PSR off: this Alder Lake panel stays black after a resume. A modprobe.d
# option, so cmdline rewrites can't drop it.
psrconf=/etc/modprobe.d/singularity-i915.conf
if (( laptop )) && ! grep -qs 'enable_psr=0' "$psrconf"; then
  log "disabling i915 panel self refresh"
  echo 'options i915 enable_psr=0' | sudo tee "$psrconf" >/dev/null
  rebuild_initramfs=1
fi

# --- webcam (off) --------------------------------------------------------
# The IPU6 webcam stack is blacklisted: ~10s of stalled module loading at
# boot, and a kernel oops at shutdown after hibernation.
vscconf=/etc/modprobe.d/singularity-vsc.conf
vscmods=(mei_vsc ivsc_csi ivsc_ace intel_ipu6 ov01a10)
if (( laptop )) && [[ "$(cat "$vscconf" 2>/dev/null)" != "$(printf 'blacklist %s\n' "${vscmods[@]}")" ]]; then
  log "switching the webcam off"
  printf 'blacklist %s\n' "${vscmods[@]}" | sudo tee "$vscconf" >/dev/null
  rebuild_initramfs=1
fi

# --- hibernation ---------------------------------------------------------
# --- hibernation ---------------------------------------------------------
# A swapfile on / sized to RAM (zram can't hold an image; it keeps priority),
# the initramfs resume hook, and resume=/resume_offset= re-read every run.
# A failure only costs hibernation.
setup_hibernation() {
  local swapfile=/swapfile fstype ram_gib uuid offset
  fstype=$(findmnt -no FSTYPE -T /)
  ram_gib=$(awk '/^MemTotal:/ { print int($2 / 1048576) + 1 }' /proc/meminfo)
  if [[ ! -f $swapfile ]]; then
    log "creating a ${ram_gib}G swapfile for hibernation"
    # btrfs needs the file NOCOW and in one extent, which its own tool does
    if [[ $fstype == btrfs ]]; then
      sudo btrfs filesystem mkswapfile --size "${ram_gib}G" --uuid clear "$swapfile" >/dev/null
    else
      sudo mkswap -U clear --size "${ram_gib}G" --file "$swapfile" >/dev/null
    fi || { sudo rm -f "$swapfile"; return 1; }
  fi
  # into fstab only once it has been seen to work, or every boot fails a unit
  swapon --show=NAME --noheadings | grep -qx "$swapfile" || sudo swapon "$swapfile" || return 1
  if ! grep -Eq "^$swapfile[[:space:]]" /etc/fstab; then
    [[ -f /etc/fstab.singularity.bak ]] || sudo cp /etc/fstab /etc/fstab.singularity.bak
    printf '%s none swap defaults 0 0\n' "$swapfile" | sudo tee -a /etc/fstab >/dev/null
  fi

  # With the systemd hook, systemd-hibernate-resume does this job itself and
  # the busybox-only resume hook has nothing to add.
  if [[ -f $mkconf ]] && ! grep -Eq '^HOOKS=\(.*\<(resume|systemd)\>' "$mkconf"; then
    log "adding the resume hook to the initramfs"
    [[ -f $mkconf.singularity.bak ]] || sudo cp "$mkconf" "$mkconf.singularity.bak"
    # after filesystems and before fsck: the image has to be read back before
    # anything checks or mounts the disk it came from
    if grep -Eq '^HOOKS=\(.*\<fsck\>' "$mkconf"; then
      sudo sed -i -E '/^HOOKS=/ s/\<fsck\>/resume fsck/' "$mkconf"
    else
      sudo sed -i -E '/^HOOKS=/ s/\)/ resume)/' "$mkconf"
    fi
    rebuild_initramfs=1
  fi

  uuid=$(findmnt -no UUID -T "$swapfile")
  # filefrag's physical offset is wrong on btrfs, whose own tool gives the
  # one resume_offset wants
  if [[ $fstype == btrfs ]]; then
    offset=$(sudo btrfs inspect-internal map-swapfile -r "$swapfile" 2>/dev/null || true)
  else
    offset=$(sudo filefrag -v "$swapfile" 2>/dev/null | awk '$1 == "0:" { sub(/\.\.$/, "", $4); print $4; exit }' || true)
  fi
  [[ -n $uuid && -n $offset ]] || return 1
  edit_cmdline resume "resume=UUID=$uuid"
  edit_cmdline resume_offset "resume_offset=$offset"
}
if (( laptop )); then
  setup_hibernation || warn "couldn't set up the hibernation swapfile, so hibernation won't resume"
fi

# Everything above that changed what the boot reads, applied once.
if (( cmdline_changed )); then
  case $cmdline_mode in
    plain) rebuild_initramfs=1 ;;
    grub)  log "regenerating grub.cfg"; sudo grub-mkconfig -o /boot/grub/grub.cfg ;;
  esac
fi
if (( rebuild_initramfs )); then
  log "rebuilding the initramfs"
  sudo mkinitcpio -P
fi

# Suspend lasts 55 min before hibernating (lid.sh suspends after 5 min and
# wants 1 h in all; change both together).
sleepconf=/etc/systemd/sleep.conf.d/singularity.conf
if (( laptop )) && ! grep -qsx 'HibernateDelaySec=55min' "$sleepconf"; then
  log "hibernating after 55 min of lid-closed suspend"
  sudo mkdir -p "${sleepconf%/*}"
  printf '[Sleep]\nHibernateDelaySec=55min\n' | sudo tee "$sleepconf" >/dev/null
fi

# The hibernation image capped at 4G, so the kernel drops cache before the
# snapshot and resume (single-threaded LZO; Arch has no LZ4) stays quick.
imageconf=/etc/tmpfiles.d/singularity-hibernate.conf
image_size=4294967296
if (( laptop )) && ! grep -qs "image_size .* $image_size\$" "$imageconf"; then
  log "capping the hibernation image at $((image_size / 1024 ** 3))G"
  printf 'w /sys/power/image_size - - - - %s\n' "$image_size" \
    | sudo tee "$imageconf" >/dev/null
  sudo systemd-tmpfiles --create "$imageconf"
fi

# The touchpad can't wake the machine: its GPIO interrupt kept bouncing
# s2idle back out. lid.sh's stay_dark() catches the strays.
touchpadrule=/etc/udev/rules.d/90-singularity-touchpad-wake.rules
if (( laptop )) && ! grep -qs 'i2c_hid_acpi' "$touchpadrule"; then
  log "disarming the touchpad as a wake source"
  sudo mkdir -p "${touchpadrule%/*}"
  printf '%s\n' \
    'ACTION=="add|change", SUBSYSTEM=="i2c", DRIVER=="i2c_hid_acpi", ATTR{power/wakeup}="disabled"' \
    | sudo tee "$touchpadrule" >/dev/null
  sudo udevadm control --reload
  sudo udevadm trigger --subsystem-match=i2c --action=change
fi

# singularity-charge: the Dell BIOS's charge mode and Custom limits, via
# dell_laptop, for Settings > Power & Idle through pkexec. Takes only a mode
# and two numbers; root-owned in /usr/local/bin.
if (( laptop )) && compgen -G '/sys/class/power_supply/BAT*/charge_types' >/dev/null; then
  log "installing the battery charge helper"
  sudo tee /usr/local/bin/singularity-charge >/dev/null <<'CHARGE'
#!/bin/sh
# singularity-charge Standard|Adaptive|Fast
# singularity-charge Custom START STOP
set -eu
mode=${1:-}
case $mode in
  Standard|Adaptive|Fast) ;;
  Custom)
    case "${2:-}:${3:-}" in
      [0-9]*:[0-9]*) ;;
      *) echo "Custom takes a start and a stop percentage" >&2; exit 2 ;;
    esac
    case "$2$3" in *[!0-9]*) echo "not a number: $2 $3" >&2; exit 2 ;; esac
    start=$2 stop=$3 ;;
  *) echo "usage: singularity-charge Standard|Adaptive|Fast|Custom [START STOP]" >&2; exit 2 ;;
esac
bat=
for b in /sys/class/power_supply/BAT*; do
  [ -e "$b/charge_types" ] && { bat=$b; break; }
done
[ -n "$bat" ] || { echo "no battery with a charge mode" >&2; exit 1; }
if [ "$mode" = Custom ]; then
  # the firmware refuses a stop at or below the current start, so the
  # start goes first when the stop is coming down past it
  cur=$(cat "$bat/charge_control_start_threshold")
  if [ "$stop" -le "$cur" ]; then
    echo "$start" > "$bat/charge_control_start_threshold"
    echo "$stop" > "$bat/charge_control_end_threshold"
  else
    echo "$stop" > "$bat/charge_control_end_threshold"
    echo "$start" > "$bat/charge_control_start_threshold"
  fi
fi
echo "$mode" > "$bat/charge_types"
CHARGE
  sudo chmod 755 /usr/local/bin/singularity-charge

  sudo tee /usr/share/polkit-1/actions/org.singularity.charge.policy >/dev/null <<'POLICY'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
  "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
<policyconfig>
  <action id="org.singularity.charge">
    <description>Change how the battery charges</description>
    <message>Authentication is required to change how the battery charges</message>
    <defaults>
      <allow_any>auth_admin</allow_any>
      <allow_inactive>auth_admin</allow_inactive>
      <allow_active>yes</allow_active>
    </defaults>
    <annotate key="org.freedesktop.policykit.exec.path">/usr/local/bin/singularity-charge</annotate>
  </action>
</policyconfig>
POLICY
fi

log "enabling services"

# seatd: through logind, Hyprland could ask for the touchpad before logind
# had it, and never retried.
sudo systemctl enable --now seatd.service
sudo usermod -aG seat "$USER"

# Network: iwd (Wi-Fi), systemd-networkd (addresses, DHCP config only when
# none exists), systemd-resolved (DNS). Both links count towards online, so
# timesyncd works on either.
wired_network='[Match]
Type=ether

[Network]
DHCP=yes'
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
  printf '%s\n' "$wired_network" | sudo tee /etc/systemd/network/20-wired.network >/dev/null
elif [[ $(cat /etc/systemd/network/20-wired.network 2>/dev/null) == $'[Match]\nType=ether\n\n[Link]\nRequiredForOnline=no\n\n[Network]\nDHCP=yes' ]]; then
  # The config an earlier install.sh wrote, unedited: bring it up to date.
  log "letting the wired link count towards being online"
  printf '%s\n' "$wired_network" | sudo tee /etc/systemd/network/20-wired.network >/dev/null
  systemctl is-active -q systemd-networkd && sudo networkctl reload
fi
# --any: one link online is enough, so an unplugged port or idle Wi-Fi never
# makes boot sit out wait-online's full timeout.
sudo mkdir -p /etc/systemd/system/systemd-networkd-wait-online.service.d
printf '[Service]\nExecStart=\nExecStart=/usr/lib/systemd/systemd-networkd-wait-online --any\n' |
  sudo tee /etc/systemd/system/systemd-networkd-wait-online.service.d/singularity.conf >/dev/null
sudo systemctl daemon-reload

# NetworkManager and wpa_supplicant disabled (not stopped, so this run keeps
# its connection): they'd fight networkd and iwd.
for unit in NetworkManager.service NetworkManager-wait-online.service wpa_supplicant.service; do
  if systemctl is-enabled -q "$unit" 2>/dev/null; then
    log "disabling $unit (iwd and systemd-networkd manage the network)"
    sudo systemctl disable "$unit"
    if [[ $unit == NetworkManager.service ]]; then
      warn "NetworkManager is off from the next boot: join Wi-Fi again from the bar"
    fi
  fi
done
# LLMNR is a Windows-era name lookup that resolved answers on every interface
# (port 5355). Nothing here uses it; mDNS (.local names) stays on.
sudo mkdir -p /etc/systemd/resolved.conf.d
printf '[Resolve]\nLLMNR=no\n' | sudo tee /etc/systemd/resolved.conf.d/singularity.conf >/dev/null
sudo systemctl enable --now iwd systemd-networkd systemd-resolved
sudo systemctl try-reload-or-restart systemd-resolved
# resolv.conf onto resolved's stub, once it's running (a symlink is left)
if [[ ! -L /etc/resolv.conf ]]; then
  [[ -f /etc/resolv.conf ]] && sudo cp /etc/resolv.conf /etc/resolv.conf.singularity.bak
  sudo ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
fi
# The user units linked from dotfiles/systemd are new to the user manager.
systemctl --user daemon-reload || true
systemctl --user enable --now pipewire pipewire-pulse wireplumber ||
  warn "could not enable the pipewire user units"

# Weekly paccache (pacman-contrib) keeps the last three versions of each
# package, enough to downgrade from, so the cache stops growing forever.
sudo systemctl enable --now paccache.timer

# Nothing enables BlueZ on a Minimal install, and the bar's Bluetooth module
# and the pairing agent below both need its daemon.
sudo systemctl enable --now bluetooth.service
# a unit is installed if `systemctl cat` finds it, or its file exists
# (templates)
have_unit() {
  systemctl cat "$1" &>/dev/null     || [[ -f /usr/lib/systemd/system/$1 || -f /etc/systemd/system/$1 ]]
}

# power-profiles-daemon drives platform_profile and EPP together (this laptop
# booted into "quiet"); not TLP, which the bar can't switch
if have_unit power-profiles-daemon.service; then
  log "enabling power-profiles-daemon"
  sudo systemctl enable --now power-profiles-daemon.service
fi

# CoolerControl's daemon applies the fan curves, with or without its window
# open.
if (( ! laptop )) && have_unit coolercontrold.service; then
  log "enabling coolercontrold"
  sudo systemctl enable --now coolercontrold.service
fi

# the BlueZ pairing agent, a user service (see its unit)
if command -v bt-agent &>/dev/null; then
  log "enabling the bluetooth pairing agent"
  systemctl --user enable --now bt-agent.service ||
    warn "could not enable the bluetooth pairing agent"
fi

# restores the Bluetooth adapter's power state (see the unit)
log "enabling Bluetooth power state restore"
systemctl --user enable --now bt-power-restore.service ||
  warn "could not enable Bluetooth power state restore"

# logs Floorp hitches in the background (see the unit)
log "enabling the Floorp hitch monitor"
systemctl --user enable --now floorp-watch.service ||
  warn "could not enable the Floorp hitch monitor"


# iwd as Type=exec, so the greeter doesn't wait out its module stall
if have_unit iwd.service; then
  log "stopping ly from waiting on iwd"
  sudo mkdir -p /etc/systemd/system/iwd.service.d
  printf '[Service]\nType=exec\n' | sudo tee /etc/systemd/system/iwd.service.d/singularity.conf >/dev/null
  sudo systemctl daemon-reload
fi

# TPM SRK setup masked (~2s a boot, unused), with the pcr units that need it,
# unless crypttab asks for a TPM unlock. The TPM's contents are untouched.
if ! grep -qs 'tpm2-device' /etc/crypttab; then
  log "masking systemd TPM setup"
  sudo systemctl mask systemd-tpm2-setup-early.service systemd-tpm2-setup.service \
    systemd-pcrproduct.service systemd-pcrlogin@.service
fi

# Display manager, enabled for next boot (not --now, which would take the
# VT). ly 1.x's unit is a template (ly@tty2), 0.x's plain.
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
  # Minimal leaves the default target at multi-user, where ly never starts
  if [[ $(systemctl get-default) != graphical.target ]]; then
    log "switching default boot target to graphical.target"
    sudo systemctl set-default graphical.target
  fi

  # The greeter in Singularity: the VT has no true colour, so its 16-slot
  # palette becomes the ramp (red and green as alert and good) and ly picks
  # slots by index.
  if [[ -f /etc/ly/config.ini ]]; then
    log "theming ly"
    sudo tee /etc/ly/singularity.sh >/dev/null <<'LY'
#!/bin/sh
# Written by singularity's install.sh. Run by ly (start_cmd) before it takes
# the TTY: keeps the greeter off held-off monitors (outputs.sh) and loads the
# Singularity ramp into the VT palette, slots 0-15.
/etc/ly/outputs.sh
[ "$TERM" = linux ] || exit 0
i=0
for c in 0b0b0b a87676 7d9b7d 969696 a0a0a0 aeaeae b8b8b8 d0e2fa \
         303030 a87676 7d9b7d adadad b8b8b8 c8c8c8 d8d8d8 ebebeb; do
  printf '\033]P%x%s' "$i" "$c"
  i=$((i + 1))
done
# repaint with the new slot 0, or the old black shows through until ly draws
clear
LY
    sudo chmod 755 /etc/ly/singularity.sh
    # A monitor named video=<connector>:d on the cmdline is held off the
    # console (which sizes to its smallest screen); outputs.sh hands it to
    # the session at login and back at logout.
    sudo tee /etc/ly/outputs.sh >/dev/null <<'LY'
#!/bin/sh
# Written by singularity's install.sh. `outputs.sh [off|on]` holds the monitors
# named as video=<connector>:d on the kernel command line off for the
# greeter, or gives them back to the session.
names=$(tr ' ' '\n' < /proc/cmdline | sed -n 's/^video=\([^:]*\):d$/\1/p')
[ -n "$names" ] || exit 0
state=${1:-off}
if [ "$state" = off ]; then
  state=on
  for s in /sys/class/drm/card*-*/status; do
    c=${s%/status}; c=${c##*/}; c=${c#card*-}
    case " $(echo $names) " in *" $c "*) continue ;; esac
    [ "$(cat "$s")" = connected ] && state=off && break
  done
fi
for n in $names; do
  for s in /sys/class/drm/card*-"$n"/status; do
    [ -w "$s" ] || continue
    if [ "$state" = off ]; then echo off; else echo detect; fi > "$s"
  done
done
LY
    sudo tee /etc/ly/login.sh >/dev/null <<'LY'
#!/bin/sh
# Written by singularity's install.sh. ly's login_cmd, run as the user: gives
# the session back the monitors outputs.sh held off for the greeter.
grep -q 'video=[^ ]*:d\( \|$\)' /proc/cmdline && sudo -n /etc/ly/outputs.sh on
exec "$@"
LY
    sudo chmod 755 /etc/ly/outputs.sh /etc/ly/login.sh
    tmp=$(mktemp)
    echo '%wheel ALL=(root) NOPASSWD: /etc/ly/outputs.sh on' > "$tmp"
    if sudo visudo -cqf "$tmp"; then
      sudo install -m 440 "$tmp" /etc/sudoers.d/singularity-ly
    else
      warn "sudoers rule for /etc/ly/outputs.sh did not validate, held-off monitors stay off after login"
    fi
    rm -f "$tmp"
    # the greeter's status lines (root, before login; a desktop has no battery)
    if (( laptop )); then
      ly_lines="battery power wifi kernel last"
    else
      ly_lines="wifi kernel last"
    fi
    sed "s/@LINES@/$ly_lines/" <<'LY' | sudo tee /etc/ly/info.sh >/dev/null
#!/bin/sh
# Written by singularity's install.sh. ly runs `info.sh <line>` for each
# status line at the greeter's bottom-right: @LINES@.
# ly right-aligns each line by its length in bytes but draws it by
# characters, so the lines are kept to ASCII, where the two agree, and each
# is padded to the longest of them: the stack lines up on its left edge
# and the longest line ends at the screen's right edge.
export LC_ALL=C
out() { printf '%-12s%s' "$1" "$2"; }
read_num() { v=$(cat "$1" 2>/dev/null); echo "${v:-0}"; }
dur() { [ "$1" -ge 60 ] && printf '%dh %02dm' $(($1 / 60)) $(($1 % 60)) || printf '%dm' "$1"; }

# now/full/rate in µAh and µA, or µWh and µW, depending on what the battery reports
battery_state() {
  for b in /sys/class/power_supply/BAT*; do [ -r "$b/capacity" ] && break; done
  [ -r "$b/capacity" ] || return 1
  pct=$(read_num "$b/capacity")
  status=$(cat "$b/status" 2>/dev/null)
  if [ -r "$b/charge_now" ]; then
    now=$(read_num "$b/charge_now"); full=$(read_num "$b/charge_full")
    design=$(read_num "$b/charge_full_design"); rate=$(read_num "$b/current_now")
    watts=$(awk -v i="$rate" -v v="$(read_num "$b/voltage_now")" 'BEGIN { printf "%.1f", (i < 0 ? -i : i) * v / 1e12 }')
  else
    now=$(read_num "$b/energy_now"); full=$(read_num "$b/energy_full")
    design=$(read_num "$b/energy_full_design"); rate=$(read_num "$b/power_now")
    watts=$(awk -v p="$rate" 'BEGIN { printf "%.1f", (p < 0 ? -p : p) / 1e6 }')
  fi
  rate=${rate#-}
}

# one status line, unpadded
line() {
case $1 in
battery)
  battery_state || { out battery 'none'; exit; }
  filled=$(((pct + 5) / 10)) bar='' i=0
  while [ $i -lt 10 ]; do
    [ $i -lt $filled ] && bar="$bar=" || bar="$bar-"
    i=$((i + 1))
  done
  case $status in
    Discharging)
      text=''
      [ "$rate" -gt 0 ] && text="$(dur $((now * 60 / rate))) left"
      [ "$pct" -le 15 ] && text="low${text:+, $text}" ;;
    Charging)
      text='charging'
      [ "$rate" -gt 0 ] && [ "$full" -gt "$now" ] &&
        text="charging, full in $(dur $(((full - now) * 60 / rate)))" ;;
    Full) text='plugged in, full' ;;
    *) text='plugged in' ;;
  esac
  out battery "$bar $pct%  $text" ;;
power)
  battery_state || { out power 'on AC'; exit; }
  case $status in
    Discharging) text="$watts W" ;;
    Charging) text="charging at $watts W" ;;
    *) text='idle' ;;
  esac
  [ "$design" -gt 0 ] && text="$text, health $((full * 100 / design))%"
  out power "$text" ;;
wifi)
  for w in /sys/class/net/*/wireless; do [ -d "$w" ] && break; done
  [ -d "$w" ] || { out wifi 'none'; exit; }
  dev=${w%/wireless}; dev=${dev##*/}
  link=$(iw dev "$dev" link 2>/dev/null)
  ssid=$(printf '%s\n' "$link" | sed -n 's/^[[:space:]]*SSID: //p' | tr -c ' -~\n' '?')
  signal=$(printf '%s\n' "$link" | sed -n 's/^[[:space:]]*signal: //p')
  if [ -n "$ssid" ]; then out wifi "$ssid${signal:+, signal $signal}"
  else out wifi 'not connected'; fi ;;
kernel)
  out kernel "linux $(uname -r)" ;;
last)
  # newest entry across users; lastlog2's Latest column is the last six fields
  best=0 text='never'
  while read -r port when; do
    t=$(date -d "$when" +%s 2>/dev/null) || continue
    [ "$t" -gt "$best" ] && best=$t text="$(date -d "@$t" '+%a %-d %b %H:%M') on $port"
  done <<EOF
$(lastlog2 2>/dev/null | awk 'NR > 1 && $NF ~ /^[0-9][0-9][0-9][0-9]$/ {
    print $2, $(NF-5), $(NF-4), $(NF-3), $(NF-2), $(NF-1), $NF }')
EOF
  out 'last login' "$text" ;;
esac
}

# the longest line sets the width every line is padded to
width=0
for l in @LINES@; do
  t=$(line $l)
  [ ${#t} -gt $width ] && width=${#t}
done
printf '%-*s' "$width" "$(line "$1")"
LY
    sudo chmod 755 /etc/ly/info.sh
    # Keys edited in place, so pacman keeps taking upstream's new options.
    # Colour ids are 1-based; a 0x01 top byte is bold (the bright half).
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
    set_ly login_cmd /etc/ly/login.sh
    set_ly logout_cmd /etc/ly/outputs.sh
    set_ly full_color false
    set_ly bg 0x00000001            # slot 0, base   #0b0b0b
    set_ly fg 0x00000008            # slot 7, text   #d0e2fa (pale blue)
    set_ly border_fg 0x01000001     # slot 8, border #303030
    set_ly error_bg 0x00000001
    set_ly error_fg 0x00000002      # slot 1, alert  #a87676
    # our section goes last: set_ly would file new keys under it
    sudo sed -i '/^# singularity status lines/,$d' /etc/ly/config.ini
    set_ly clock '%a %-d %b  %H:%M'
    set_ly hide_version_string true
    set_ly animation none
    set_ly edge_margin 1
    set_ly asterisk 0x2022          # •
    # ly trims plain spaces off values, so the title is padded with no-break
    # spaces to keep it off the box's corner
    set_ly box_title $' singularity '
    {
      echo '# singularity status lines, bottom-right; refresh is in clock ticks (seconds)'
      for line in $ly_lines; do
        case $line in battery) refresh=30 ;; power|wifi) refresh=10 ;; *) refresh=0 ;; esac
        printf '[lbl:%s]\ncmd = /etc/ly/info.sh %s\nrefresh = %s\n' "$line" "$line" "$refresh"
      done
    } | sudo tee -a /etc/ly/config.ini >/dev/null

    # singularity-autologin: ly's autologin on/off for Settings > Startup,
    # for the pkexec caller only (PKEXEC_UID), never an argument.
    sudo tee /usr/local/bin/singularity-autologin >/dev/null <<'AUTOLOGIN'
#!/bin/sh
# singularity-autologin on    boot straight into Hyprland as the pkexec caller
# singularity-autologin off   ask for the password at the greeter again
set -eu
conf=/etc/ly/config.ini
set_key() {
  grep -q "^$1 = " "$conf" || { echo "ly's config has no $1" >&2; exit 1; }
  sed -i "s|^$1 = .*|$1 = $2|" "$conf"
}
case ${1:-} in
  on)
    user=$(id -nu "${PKEXEC_UID:?run this through pkexec}")
    [ "$PKEXEC_UID" -ne 0 ] || { echo "not for root" >&2; exit 1; }
    set_key auto_login_user "$user"
    set_key auto_login_session hyprland ;;
  off)
    set_key auto_login_user null
    set_key auto_login_session null ;;
  *) echo "usage: singularity-autologin on | off" >&2; exit 2 ;;
esac
AUTOLOGIN
    sudo chmod 755 /usr/local/bin/singularity-autologin

    sudo tee /usr/share/polkit-1/actions/org.singularity.autologin.policy >/dev/null <<'POLICY'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
  "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
<policyconfig>
  <action id="org.singularity.autologin">
    <description>Choose whether signing in is needed at boot</description>
    <message>Authentication is required to change signing in at boot</message>
    <defaults>
      <allow_any>auth_admin</allow_any>
      <allow_inactive>auth_admin</allow_inactive>
      <allow_active>auth_admin_keep</allow_active>
    </defaults>
    <annotate key="org.freedesktop.policykit.exec.path">/usr/local/bin/singularity-autologin</annotate>
  </action>
</policyconfig>
POLICY
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
