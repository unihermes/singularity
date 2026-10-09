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

# What kind of machine this is. Everything marked `if (( laptop ))` below
# is skipped on a desktop, and packages/laptop.txt or packages/desktop.txt
# is installed on top of pacman.txt. Recorded so update.sh installs the same
# package lists.
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

# Read a package list into an array. NOT `| xargs`: xargs points its child's
# stdin at /dev/null, so any package manager that stops to ask a question
# reads EOF and aborts instead. That silently killed the whole AUR step.
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

log "installing AUR packages"
# Not --noconfirm: you want to see the PKGBUILD diffs before anything builds.
# --answerclean None only skips the "rebuild from scratch?" prompt; diffs and
# the install confirmation still stop for you. --sudoloop keeps sudo from
# timing out and asking again partway through a long build.
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
# The ALT+Tab switcher's fast path (see alttab.lua and
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

if (( ! laptop )); then
  log "building display-curve"
  # Holds the lifted tone curve for the desktop's second monitor, which shows
  # shadows too dark (see dotfiles/hypr/.config/hypr/display-curve.c). Only a
  # missing lift if it fails, so a warning.
  curve_dir="dotfiles/hypr/.config/hypr"
  curve_gen=$(mktemp -d)
  if wayland-scanner client-header "$curve_dir/wlr-gamma-control-unstable-v1.xml" \
        "$curve_gen/wlr-gamma-control-unstable-v1-client-protocol.h" \
      && wayland-scanner private-code "$curve_dir/wlr-gamma-control-unstable-v1.xml" "$curve_gen/protocol.c" \
      && cc -O2 -I"$curve_gen" "$curve_dir/display-curve.c" "$curve_gen/protocol.c" \
        -o "$curve_dir/display-curve" -lwayland-client -lm; then
    log "display-curve built"
  else
    warn "display-curve failed to build -- displays listed in autostart.lua keep their own tone curve"
  fi
  rm -rf "$curve_gen"
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
# The fullscreen renderer is set the same way (unless /tui picked one): it is
# the one where highlighting text in Claude copies it.
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

# LibreOffice set up to feel like Word: the ribbon (Tabbed) in every app,
# .docx/.xlsx/.pptx as the save formats, a Normal.ott default template with
# Word's styles in Carlito (Calibri's metric twin), and Zotero's add-in.
# Everything lands in the user profile, so any of it can be changed back in
# LibreOffice afterwards. Done once: a profile that already has the template
# is left alone.
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

  # The template, written flat and converted. Word's Normal: 11 pt, 1.08 line
  # spacing, 8 pt after; headings in its blue, each followed by Normal; Letter
  # with 1 in margins and tab stops every half inch.
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
# Where it lives depends on the boot loader: a unified kernel image bakes in
# /etc/kernel/cmdline, systemd-boot reads the options line of each loader
# entry, and GRUB builds grub.cfg from GRUB_CMDLINE_LINUX_DEFAULT. Every
# change below goes through edit_cmdline, and the image or grub.cfg is
# rebuilt once, at the end of the boot section.
#
# Every file touched is backed up first. A malformed options line -- a lost
# root= UUID above all -- is an unbootable machine, and the boot loader will
# not tell you why.
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

# Puts the rewritten cmdline in $1 over $2, and only when it holds different
# options: a rerun that changes nothing then rebuilds nothing. Compared as a
# sorted set of words, since edit_cmdline always re-appends at the end and the
# tokens would otherwise trade places on every run. Never an empty or
# truncated one either -- that is an unbootable machine. GRUB's defaults have
# no root= (grub-mkconfig adds it), so that check is for the other two, and
# its quoted variable is unwrapped so the first token compares like the rest.
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

# edit_cmdline KEY TOKENS -- drop every KEY= token, or with an empty KEY every
# verbosity knob, and append TOKENS, leaving every other token untouched.
# Filtered token by token rather than substituting patterns out: adjacent
# options share the space between them, so a global s/// can only ever
# delete every other one (`quiet loglevel=3 splash` loses quiet and splash
# and keeps loglevel).
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
# Quiet by default: no kernel or unit output on startup or shutdown. Set
# BOOT_VERBOSE=1 to get systemd's [ OK ] lines back, which is worth doing when
# a boot hangs and you need to see which unit it hung on:
#
#   BOOT_VERBOSE=1 ./install.sh laptop
BOOT_VERBOSE=${BOOT_VERBOSE:-0}
if (( BOOT_VERBOSE )); then
  log "making the boot verbose"
  edit_cmdline "" "systemd.show_status=1"
else
  log "making the boot quiet"
  edit_cmdline "" "quiet loglevel=3 rd.udev.log_level=3 systemd.show_status=false"
fi

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
# below, which is why that one is blacklisted instead.)
# Both are harmless on hardware without these devices.
if (( laptop )); then
  edit_cmdline deferred_probe_timeout "deferred_probe_timeout=1"
  edit_cmdline driver_async_probe "driver_async_probe=intel_ish_ipc"
fi

# --- boot speed ----------------------------------------------------------
# /boot (the ESP) is vfat, and vfat is a module. With the webcam enabled, the
# IPU6 camera stack stalls kernel module loading for ~10s at boot, until the
# kernel gives up waiting on the ov01a10 sensor. Mounting /boot has to load
# vfat, so it sits in that stall, and sysinit.target, ly and everything after
# it wait on the mount. Loading vfat from the initramfs means the mount needs
# no module load.
#
# mac_hid, mousedev and joydev are autoloaded for every pointer device and hit
# the same module-loading queue, so preloading them from the initramfs saves
# a little of that same stall. (The cursor freeze itself turned out to be a
# separate logind race -- see the deferred-probe fix above.)
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
# The desktop's display hangs off its RTX 4070. nvidia-drm sets modeset and
# fbdev itself these days, so all it needs is loading early: from the
# initramfs it takes the screen over from the firmware framebuffer before the
# greeter starts, instead of the greeter coming up on simpledrm (1024x768,
# no vsync) and Hyprland finding a display it then can't drive properly.
# nvidia-utils already blacklists nouveau, and modconf carries that into the
# initramfs.
if (( ! laptop )) && pacman -Q nvidia-open &>/dev/null; then
  early_modules nvidia nvidia_modeset nvidia_uvm nvidia_drm
fi

# --- fans (desktop) ------------------------------------------------------
# The B650I AORUS ULTRA's fan headers sit on an ITE IT8689E, driven by
# it87-dkms-git (aur-desktop.txt) since the in-tree it87 can't set its fan
# speeds. Gigabyte's ACPI tables also claim the chip's I/O ports, so either
# driver refuses to load ("ACPI: OSL: Resource conflict") unless told to
# ignore that. Without it CoolerControl only sees the GPU fans. Loaded from
# modules-load.d at boot, not the initramfs: nothing needs it that early.
fanconf=/etc/modprobe.d/singularity-it87.conf
fanload=/etc/modules-load.d/singularity-it87.conf
if (( ! laptop )) && ! grep -qs 'ignore_resource_conflict=1' "$fanconf"; then
  log "setting up the motherboard fan driver"
  echo 'options it87 ignore_resource_conflict=1' | sudo tee "$fanconf" >/dev/null
  echo 'it87' | sudo tee "$fanload" >/dev/null
  sudo modprobe it87 || warn "it87 did not load -- is it87-dkms-git built? see dkms status"
fi

# --- panel self refresh --------------------------------------------------
# With PSR on, this Alder Lake eDP panel stops taking new frames after a
# resume: the machine is awake and hyprlock takes the password, but the
# screen stays black. A modprobe.d option rather than i915.enable_psr=0 on
# the cmdline, so the boot-verbosity rewrite above can never drop it. The
# modconf hook copies it into the initramfs, where i915 loads (kms hook).
psrconf=/etc/modprobe.d/singularity-i915.conf
if (( laptop )) && ! grep -qs 'enable_psr=0' "$psrconf"; then
  log "disabling i915 panel self refresh"
  echo 'options i915 enable_psr=0' | sudo tee "$psrconf" >/dev/null
  rebuild_initramfs=1
fi

# --- webcam (off) --------------------------------------------------------
# The IPU6 webcam is switched off until it gets another look. Its stack costs
# ~10s of stalled module loading at boot, and after a hibernation resume the
# Visual Sensing Controller re-enumerates under the v4l2 subdevs WirePlumber
# holds open, so closing them later oopses the kernel in subdev_close and
# hangs shutdown. Blacklisting the whole chain means none of it loads.
vscconf=/etc/modprobe.d/singularity-vsc.conf
vscmods=(mei_vsc ivsc_csi ivsc_ace intel_ipu6 ov01a10)
if (( laptop )) && [[ "$(cat "$vscconf" 2>/dev/null)" != "$(printf 'blacklist %s\n' "${vscmods[@]}")" ]]; then
  log "switching the webcam off"
  printf 'blacklist %s\n' "${vscmods[@]}" | sudo tee "$vscconf" >/dev/null
  rebuild_initramfs=1
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
#
# Any step failing (no room on the disk, a snapshotted btrfs subvolume, ...)
# only costs hibernation, so it warns and the install carries on.
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

# How long a closed lid's suspend lasts before it hibernates. lid.sh suspends
# 5 min after the lid shuts and wants hibernation at 1 h, so 55 min here;
# change both together (close_delay and hibernate_after in lid.sh).
sleepconf=/etc/systemd/sleep.conf.d/singularity.conf
if (( laptop )) && ! grep -qsx 'HibernateDelaySec=55min' "$sleepconf"; then
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
if (( laptop )) && ! grep -qs "image_size .* $image_size\$" "$imageconf"; then
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
if (( laptop )) && ! grep -qs 'i2c_hid_acpi' "$touchpadrule"; then
  log "disarming the touchpad as a wake source"
  sudo mkdir -p "${touchpadrule%/*}"
  printf '%s\n' \
    'ACTION=="add|change", SUBSYSTEM=="i2c", DRIVER=="i2c_hid_acpi", ATTR{power/wakeup}="disabled"' \
    | sudo tee "$touchpadrule" >/dev/null
  sudo udevadm control --reload
  sudo udevadm trigger --subsystem-match=i2c --action=change
fi

# Battery charging: the helper Settings → Power & Idle uses to pick the
# battery's charge mode and, in Custom, where charging stops and resumes. On
# this Dell those are the BIOS's own "Primary Battery Charge Configuration"
# -- dell_laptop writes them to the firmware through SMBIOS -- so a change
# holds across reboots and in every OS with nothing running at boot.
#
# Writing them needs root, so the page runs the helper through pkexec, and
# the polkit action lets the active local session do that without a
# password. The helper takes nothing but a mode name and two numbers, and
# the driver refuses any value the firmware doesn't take. Root-owned in
# /usr/local/bin rather than linked from the dotfiles, so the user can't
# change what runs as root.
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
# The user units linked from dotfiles/systemd are new to the user manager.
systemctl --user daemon-reload || true
systemctl --user enable --now pipewire pipewire-pulse wireplumber ||
  warn "could not enable the pipewire user units"

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
fi

# CoolerControl's daemon applies the fan curves, with or without its window
# open.
if (( ! laptop )) && have_unit coolercontrold.service; then
  log "enabling coolercontrold"
  sudo systemctl enable --now coolercontrold.service
fi

if (( laptop )) && have_unit power-profiles-daemon.service; then
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
  systemctl --user enable --now bt-agent.service ||
    warn "could not enable the bluetooth pairing agent"
fi

# See the unit's own comment: rfkill, volume and brightness already survive a
# reboot on their own (systemd-rfkill, wireplumber, systemd-backlight); this
# is the missing piece for Bluetooth's own adapter power.
log "enabling Bluetooth power state restore"
systemctl --user enable --now bt-power-restore.service ||
  warn "could not enable Bluetooth power state restore"


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
# allocates the NvPCRs, so systemd-pcrproduct and systemd-pcrlogin@ (one per
# login), which measure into them, fail every boot without it and are masked too.
if ! grep -qs 'tpm2-device' /etc/crypttab; then
  log "masking systemd TPM setup"
  sudo systemctl mask systemd-tpm2-setup-early.service systemd-tpm2-setup.service \
    systemd-pcrproduct.service systemd-pcrlogin@.service
fi

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

  # Theme the greeter as Singularity. ly draws on a Linux VT, and the VT has no
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
# the TTY: loads the Singularity ramp into the VT palette, slots 0-15.
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
    # The status lines in the greeter's bottom-right corner, one [lbl:*] entry
    # each. ly runs these as root before anyone logs in, so they only read
    # sysfs and root-readable tools.
    # A desktop has no battery, so it shows only the last three.
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
    set_ly fg 0x00000008            # slot 7, text   #d0e2fa (pale blue)
    set_ly border_fg 0x01000001     # slot 8, border #303030
    set_ly error_bg 0x00000001
    set_ly error_fg 0x00000002      # slot 1, alert  #a87676
    # Sections run to the end of the file, so set_ly appending a key after one
    # would file it under that section: drop ours before setting keys and add
    # it back last.
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
