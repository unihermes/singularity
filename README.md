# Singularity

Provisions a full Arch Linux desktop — Hyprland, theme, fonts, services, the
lot — from a fresh Minimal install with one command.

![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?logo=arch-linux&logoColor=white)
![Hyprland](https://img.shields.io/badge/Hyprland-58E1FF?logo=wayland&logoColor=black)
![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnu-bash&logoColor=white)
![Idempotent](https://img.shields.io/badge/Idempotent-yes-brightgreen)

## Install

```bash
git clone https://github.com/unihermes/singularity.git && cd singularity && ./install.sh
```

Clone it somewhere you intend to keep — dotfiles are symlinked from this
location, so moving the folder afterward leaves everything in `~/.config`
dangling. Every step is idempotent; rerun `./install.sh` any time.

## Table of contents

- [What it does](#what-it-does)
- [Dotfiles only](#dotfiles-only)
- [Layout](#layout)
- [Starting a session](#starting-a-session)
- [Boot output](#boot-output)
- [Boot speed](#boot-speed)
- [Launcher](#launcher)
- [Theme](#theme)
- [Editor](#editor)
- [Regenerating the package lists](#regenerating-the-package-lists)
- [Verifying names before trusting them](#verifying-names-before-trusting-them)
- [Notes](#notes)
- [Testing from zero](#testing-from-zero)

## What it does

1. Full system sync, installs `base-devel git stow`
2. Bootstraps `yay` from `yay-bin` if it is not already present
3. Installs everything in `packages/pacman.txt` and `packages/aur.txt`
4. Symlinks `dotfiles/` into `$HOME` with GNU stow, and builds the
   `alttab-relay` helper from its C++ source
5. Rebuilds font and icon caches, sets Thunar as the directory handler,
   strips the GTK headerbar buttons through gsettings, and quiets the kernel
   command line
6. Applies the boot speed fixes: vfat in the initramfs, iwd no longer blocking
   the greeter, the webcam controller deferred until after login, and
   systemd's unused TPM setup masked; then sets up a virtual webcam for apps
   that bypass PipeWire (Discord)
7. Enables iwd, systemd-networkd, systemd-resolved, pipewire, bluetooth,
   power-profiles-daemon, the Bluetooth pairing agent, Bluetooth power
   restore, the AC-power profile switch, and the ly greeter

Every step is idempotent. `--needed` skips installed packages, `stow -R`
restows cleanly, `enable --now` is a no-op on an already-running unit. Safe to
rerun as many times as you like.

## Dotfiles only

`link.sh` does step 4 and nothing else — no packages, no services, no sudo.
Use it on a machine where you only want the configs, or to relink after adding
a new directory under `dotfiles/`.

```bash
./link.sh
```

`install.sh` calls it rather than duplicating the logic.

Apps write their own config when none exists — Hyprland regenerates
`~/.config/hypr/hyprland.lua` on every start without one — and that real file
then blocks stow from linking yours, so the app goes on reading its own default
and your repo config is never used. `link.sh` moves such files into a
timestamped `~/.config-backup-*` first. Nothing is deleted. This is the safe
inverse of `stow --adopt`, which would pull the app's file into the repo over
what you wrote.

## Layout

```
singularity/
├── install.sh
├── link.sh              # dotfiles only, no packages or services
├── wallpapers/          # what wallpaper.sh picks from
├── packages/
│   ├── pacman.txt        # native, one per line, # comments allowed
│   └── aur.txt
└── dotfiles/
    ├── hypr/.config/hypr/       # hyprland.lua, hypridle, hyprlock, helper scripts
    ├── quickshell/.config/quickshell/  # the bar, flyouts, Settings/System windows
    ├── singularity/.config/singularity/  # window-rules.json (edited from Settings), clean.sh, diagnose.sh, autostart.sh
    ├── swaync/.config/swaync/{config.json,style.css}
    ├── systemd/.config/systemd/user/   # bt-agent, bt-power-restore, wireplumber drop-in
    ├── fastfetch/.config/fastfetch/
    ├── nvim/.config/nvim/       # LazyVim: lua/config/, lua/plugins/, colors/neutrino.lua
    ├── alacritty/.config/alacritty/alacritty.toml
    ├── zathura/.config/zathura/zathurarc
    ├── gtk/.config/gtk-3.0/settings.ini
    ├── gtk/.config/gtk-4.0/settings.ini
    ├── fontconfig/.config/fontconfig/fonts.conf
    ├── bash/.bashrc
    └── starship/.config/{starship.toml,starship-path.sh}
```

Each directory under `dotfiles/` mirrors its own path relative to `$HOME`, and
`link.sh` stows every one of them into place. Because they are symlinks,
editing a config on the live system edits the repo.

## Starting a session

The Minimal archinstall profile ships no display manager, so this repo installs
`ly`, a TUI greeter. `install.sh` enables it but does not start it, because ly
seizes a VT and would kill the install mid-run. Reboot and it greets you; pick
Hyprland from the session list with the arrow keys.

If ly never appears at boot, check the usual causes: it isn't installed, the
unit name is wrong (`ly@tty2.service` on ly 1.x), another display manager
already owns `display-manager.service`, or the default boot target isn't
`graphical.target`.

If Hyprland dies you get dumped back at the greeter with no error shown. Switch
to a TTY with `ctrl+alt+F3` and run it by hand to see what happened:

```bash
Hyprland
hyprctl configerrors
```

## Boot output

Boot and shutdown are quiet by default. To see systemd's `[ OK ]` lines —
worth it when a boot hangs and you need to know which unit it hung on:

```bash
BOOT_VERBOSE=1 ./install.sh
```

Run it again without the variable to go back to quiet. Either way the
bootloader entry is backed up to `*.singularity.bak` first, and a result that
has lost its `root=` is refused rather than written.

## Boot speed

On the XPS 13 the IPU6 camera stack stalls kernel module loading for about 10s
at boot, until the kernel gives up waiting on the `ov01a10` sensor. Anything
that needs a module in that window waits with it. `install.sh` routes the two
things the greeter was waiting on around the stall:

- **`/boot` mount.** The ESP is vfat, and vfat is a module, so the mount sat in
  the stall and held up `sysinit.target`. `vfat` is now in `MODULES=()` in
  `/etc/mkinitcpio.conf` (backed up to `*.singularity.bak`).
- **iwd.** It is `Type=dbus` and needs crypto modules before it claims its bus
  name, and ly waits on `network.target`. A drop-in at
  `/etc/systemd/system/iwd.service.d/singularity.conf` sets `Type=exec`.

It also masks `systemd-tpm2-setup-early` and `systemd-tpm2-setup`, about 2s,
unless `/etc/crypttab` asks for a TPM unlock. That stops the setup running and
leaves the TPM's contents alone, so Windows and BitLocker are unaffected.

The stall itself comes from the webcam's controller (`mei_vsc`), so that is
blacklisted from autoloading and `singularity-vsc.timer` loads it 30s after
boot, followed by `intel_ipu6` and `ivsc_csi` — the camera only appears if
they load in that order.

Wi-Fi, Bluetooth and audio still finish loading about 10s in, after the greeter
is up. To see where time goes:

```bash
systemd-analyze
systemd-analyze blame | head
systemd-analyze critical-chain ly@tty2.service
```

## Launcher

One box, four modes, cycled with Tab (Shift+Tab goes back). Each has its own
way in:

| Mode | Key | What it does |
|---|---|---|
| Applications | `CTRL+SPACE` | Desktop entries; Enter launches |
| Files | `SUPER+S` | Recent files, or names under `~` via `fd`; Enter opens, `Shift+Enter` opens the folder |
| Clipboard | `SUPER+H` | cliphist history; Enter copies, `Shift+Del` removes |
| Calculator | `SUPER+/` | Arithmetic; Enter copies the result, the box stays open |

The calculator is `services/Calc.js`: its own tokeniser and parser, not
`eval()`, which would run whatever was typed into a box that is one hotkey
away at all times. It handles `+ - * / ^`, parentheses, `mod`, a trailing `%`
(just `/100`), `pi`/`e`/`tau`, hex and binary literals, `_` digit separators,
and the usual functions — `sqrt`, `ln`, `log`, `sin`, `min`, `max` and so on.
Anything else is an error rather than something executed. The list under the
result is that syntax, filtered to whatever is being typed — `sq` narrows it
to `sqrt` — so Enter on a row inserts it into the expression and the list
doubles as completion.

File search (`services/Files.qml`) searches hidden files too, since half of
what is worth finding lives in `~/.config`, but skips the application data
dumps (`.steam`, `.mozilla`, `.cargo`, caches, `node_modules`, …). It asks
`fd` for many more matches than it shows and ranks them itself — prefix
matches first, then paths not buried in a dot directory, then the shallowest
— because `fd` walks in directory order, so a small cap would just return
whatever sorts first alphabetically.

With nothing typed it lists recent files instead, read from
`~/.local/share/recently-used.xbel` — the XDG recent-files list Thunar and
every other GTK app already maintains, so there is no second log to keep and
it agrees with those apps' own Recent views.

## Theme

The default look, **Neutrino**, is one grayscale ramp with pale blue text. No
other hues: emphasis is carried by lightness and weight instead.

| | | | |
|---|---|---|---|
| `#0b0b0b` base | `#121212` bar | `#141414` panel | `#1a1a1a` surface |
| `#242424` overlay | `#303030` border | `#4d4d4d` muted | `#7a7a7a` subtext |
| `#d4e4f4` text | `#ebebeb` bright | | |

The shell (bar, flyouts, windows, settings, the launcher), swaync and Alacritty
all draw from one stylesheet, `quickshell/services/Theme.qml`, which reads the active look from
`services/LookStore.qml`. A look sets the palette and accent colour, corner
radius, stroke weight, frame style (double, single, bevel or none), module
style (outline, filled, flat or pill), bar style (full width or floating),
panel translucency, heading style, density, font and bar geometry.

Neutrino is built into `services/Looks.js` and is what everything falls back
to. The other shipped looks are data in `services/looks.json`: Soft, Paper,
Frost, Win95 Dark, Platinum, NeXTSTEP, Phosphor, E-ink, Braun, Blueprint,
Gruvbox, Kanagawa, Tokyo Night and Nord Light. Pick one from the carousel under
Settings → Appearance or in the Control Centre, where each value can then be
adjusted, or from a keybind with `qs ipc call look cycle` / `qs ipc call look
set <name>`. To add a look, copy an entry in `looks.json`. Removing one from
the Appearance page deletes it from that file; `git checkout --
services/looks.json` brings it back.

Alacritty follows the shell too: `AppearanceSync.qml` writes its colours to
`~/.local/state/neutrino/alacritty.toml`, which `alacritty.toml` imports, and
open terminals recolour live when the look changes. The 16 ANSI slots are a
lightness ramp in the look's own tones rather than hues, so coloured output
stays legible but monochrome — you lose red-for-error in `git diff`, compiler
output and `ls`. `renderAlacritty()` is the only place to change if that trade
is not worth it.

ly, the greeter, runs on a Linux VT, which can't show true colour, so it gets
Neutrino by other means. `install.sh` writes `/etc/ly/singularity.sh`, which
loads the ramp into the VT's 16-colour palette before ly draws, and points
ly's colours at those palette slots. Red and green become the shell's muted
alert and good tints, so a failed login still stands out. It always uses
Neutrino, whichever look the shell has, because it runs before anyone logs in.

nvim follows the shell the same way. `AppearanceSync.qml` writes the look's
ten roles plus its accent, good and alert hues to
`~/.local/state/neutrino/nvim.lua`, and `colors/neutrino.lua` builds every
highlight from them, plugins included: file tree, tabs, statusline,
completion menu and git signs. Open editors watch the file and recolour
live. Syntax stays in lightness and weight; the accent marks the current
line number, tab, search hit and editing modes, and good/alert colour added
and removed lines and errors. Without the file, nvim uses Neutrino's ramp.

Claude Code gets a theme from the shell as well: `AppearanceSync.qml` writes
`~/.claude/themes/singularity.json` over Claude's dark or light base, with the
look's ramp for text and chrome, the accent for Claude's own marks, and good
and alert for success and error. `install.sh` selects it in
`~/.claude/settings.json` (`"theme": "custom:singularity"`) unless another
theme has been picked; `/theme` switches between it and the built-ins.
Claude Code reads new theme files at start, so restart a running session
the first time.

## Editor

nvim is [LazyVim](https://lazyvim.org), copied from its official starter,
with the shell's look on top: a file tree, tabs, fuzzy finder, completion,
language servers, a problems panel, lazygit and a start screen. Press
`Space` and wait to see every binding. Shortcuts from other editors are added
on top of LazyVim's own (`lua/config/keymaps.lua`): `Ctrl+P` find a file,
`Ctrl+Shift+F` search text, `Ctrl+B` file tree, `Ctrl+/` comment,
`` Ctrl+` `` terminal, `F2` rename, `F12` go to definition, `Alt+Shift+F`
format.

The first start clones lazy.nvim and every plugin; `lazy-lock.json` pins
them and `:Lazy` updates them. Language support comes from LazyVim's extras,
listed in `lua/config/lazy.lua` (Python, C/C++, TypeScript, JSON, YAML, TOML,
Markdown); `:LazyExtras` adds more, and Mason installs their servers on
first use. QML uses the `qmlls` that ships with Qt (`lua/plugins/lsp.lua`).
LazyVim's bundled themes are disabled in favour of `colors/neutrino.lua`
(see Theme above).

## Regenerating the package lists

Once the system is in a state worth keeping:

```bash
pacman -Qqen > packages/pacman.txt   # explicit native
pacman -Qqem > packages/aur.txt      # foreign, meaning AUR
```

This flattens the comments in the current files. Keep a copy if you want them.

## Verifying names before trusting them

Nerd Font and icon theme names are inconsistent. Check the real strings:

```bash
fc-list : family | grep -i ubuntu | sort -u
ls /usr/share/icons | grep -i kora
fc-match sans-serif
fc-match monospace
```

## Notes

- **AUR safety.** Read the PKGBUILD diffs yay shows you. The legitimate Zen
  package is `zen-browser-bin`; `zen-browser-PATCHED-bin` was malware. This is
  why `install.sh` does not pass `--noconfirm` to the AUR step.
- **Thunar needs its extras.** No `gvfs` means no trash or mounting, no
  `tumbler` means no thumbnails. Both are in `pacman.txt`.
- **Networking is iwd plus systemd-networkd**, not NetworkManager. iwd joins
  the network, networkd runs DHCP, resolved does DNS. Connect with
  `iwctl station wlan0 connect <SSID>` (`iwctl device list` if the interface
  has another name). `install.sh` writes DHCP configs to
  `/etc/systemd/network` only when that directory has none.
- **The theme, icons, cursor and fonts live in gsettings, set by the shell.**
  The Appearance page's System section (and Shade, for dark or light) writes
  them through AppearanceSync every time it starts, along with qt6ct's config
  and the XCursor fallback in `~/.local/share/icons/default`. GTK3 on Wayland
  reads gsettings directly, and GTK4 through the settings portal, so
  `settings.ini` keeps only what the shell doesn't manage. Change them on the
  page rather than by hand: a hand edit is overwritten at the next start.
- **Kora 2.0.0** dropped upstream symlinks and icons half-resolve in some
  panels. Check the AUR comments if theming looks wrong.
- **State that survives a reboot.** rfkill (Wi-Fi/Bluetooth radio block),
  volume and brightness already persist on their own, via systemd-rfkill,
  wireplumber and systemd-backlight respectively. The one gap was BlueZ's own
  adapter power, which always comes back on powered off; `bt-power-restore.service`
  saves it at logout and restores it at login.
- **Closing the lid** turns the screen off, and suspends after 5 minutes if it
  stays shut, even with a video playing or Keep Awake on. An hour after it
  shut, the machine wakes itself and hibernates (once hibernation is set up;
  see below). A wake-up with the
  lid still shut goes back to sleep after a minute. With an external monitor
  connected only the laptop's panel turns off and nothing suspends. All of it
  is `~/.config/hypr/lid.sh`; `journalctl -t singularity-lid` shows what it did.
- **Hibernate** is in the Control Centre's Power menu. zram can't hold a
  hibernation image, so `install.sh` creates a RAM-sized `/swapfile` (below
  zram in priority, so it's only really written when hibernating), adds the
  `resume` hook to the initramfs and points `resume=`/`resume_offset=` at the
  file. The menu entry only appears once logind reports hibernation as
  possible, so a `link.sh`-only machine won't offer it. Deleting and
  recreating the swapfile moves it on disk; rerun `./install.sh` afterwards.
- **Resume speed.** The image is capped at 4G via `/sys/power/image_size`
  (a `tmpfiles.d` drop-in). The kernel's own default is 2/5 of RAM and it
  fills it, mostly with page cache, and all of it is decompressed
  single-threaded with LZO before the desktop appears. Capping it makes the
  kernel drop that cache up front instead, so those pages fault back in from
  the NVMe once you're already logged in. Raise the cap if hibernating starts
  taking longer than resuming saves.
- **Camera across hibernation.** The MEI stack re-enumerates on resume, so
  `ivsc_csi` probes again *after* `ipu_bridge` has run and comes back without
  its fwnode — the v4l2 subdevs behind the fds userspace still holds are gone.
  WirePlumber's libcamera monitor keeps `/dev/v4l-subdev*` open all session,
  and closing one of those stale fds is a general protection fault in
  `subdev_close`, which leaves the task unkillable and hangs the next
  shutdown. `/usr/lib/systemd/system-sleep/singularity-camera` stops
  WirePlumber (and any running `v4l2-relayd`) before the image is written and
  starts WirePlumber again after, so there is nothing stale left to close.
  Suspend is unaffected and isn't touched. The camera itself stays dead until
  you reboot: reloading `intel_ipu6` on a running machine oopses the kernel,
  so the hook doesn't try.
- **Webcam colour.** The sensor is raw Bayer with no colour controls, so the
  virtual webcam (`v4l2-relayd`, what Discord sees) corrects it with a
  `videobalance` stage in its GStreamer pipeline. Tune brightness, contrast,
  saturation and hue in `install.sh`'s `webcam_conf` and rerun it; it
  rewrites `/etc/v4l2-relayd.d/webcam.conf` and restarts the relay only when
  the result differs. Browsers read the camera through PipeWire and are not
  affected.
- **System > Health** runs the checks in
  `~/.config/quickshell/scripts/health-scan.sh` and puts the fix next to the
  finding: a restart for an enabled unit that isn't running, a disable for one
  whose unit file is gone, `clean.sh` for a full disk or a pile of orphans,
  `link.sh` for a dotfile symlink that no longer resolves, an install for a
  missing tool. systemctl repairs run directly, prompting through the polkit
  agent for system units; the ones that ask questions or print a lot open a
  terminal so you can see what runs. The script only reads, so it is safe to
  run by hand, and it is the machine-readable half of what `diagnose` prints.
  Nothing scans in the background: opening the page is what runs a scan.
- **What runs at login.** Hyprland runs no XDG autostart of its own, so
  `~/.config/singularity/autostart.sh run` — the last `exec` in
  `hyprland.lua` — is what launches the desktop entries in
  `~/.config/autostart`. Settings > Startup manages them: turn one off
  (`Hidden=true`), remove it, or add any installed application. Entries in
  `/etc/xdg/autostart` are listed too but are **off until you turn one on**,
  which copies it into `~/.config/autostart`; the spec says those should run
  by default, but none of them ever has on this machine and two of them
  duplicate a systemd user unit that already starts the same program.
  `TryExec` and `OnlyShowIn`/`NotShowIn` are honoured, so an entry meant for
  another desktop is shown as unavailable rather than run. Anything that
  should come back after a crash belongs in `dotfiles/systemd` as a user unit
  instead. `~/.cache/autostart.log` records what ran.
- **Power profile follows the charger.** A udev rule
  (`/etc/udev/rules.d/99-singularity-power-profile.rules`) runs
  `/usr/local/bin/singularity-power-profile` on every `power_supply` change,
  which switches `power-profiles-daemon` to `performance` while any supply
  reports `online`, `balanced` otherwise.

## Testing from zero

The point of the repo is that it works on a machine that has never seen it:

```bash
sudo pacman -S --needed git
git clone https://github.com/unihermes/singularity.git ~/singularity
cd ~/singularity && ./install.sh
```

Clone to a path you intend to keep. Stow's symlinks point at the repo's
location on disk, so moving it afterwards leaves every config in `~/.config`
dangling.
