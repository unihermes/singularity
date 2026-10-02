<div align="center">

# Singularity

**A complete Arch Linux desktop in one command: Hyprland, a hand-built Quickshell shell, and every app themed to match.**

[![checks](https://github.com/unihermes/singularity/actions/workflows/checks.yml/badge.svg)](https://github.com/unihermes/singularity/actions/workflows/checks.yml)
![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?logo=arch-linux&logoColor=white)
![Hyprland](https://img.shields.io/badge/Hyprland-Lua_config-58E1FF?logo=wayland&logoColor=black)
![Quickshell](https://img.shields.io/badge/Quickshell-QML-41CD52?logo=qt&logoColor=white)
![Idempotent](https://img.shields.io/badge/install-idempotent-brightgreen)

</div>

Singularity turns a fresh Arch **Minimal** install into a finished desktop:
packages, services, boot tweaks, dotfiles and a shell written from scratch in
QML. Everything you see is one design system, so the bar, the lock screen,
the terminal, the editor, GTK and Qt apps, the greeter and even Claude Code
change together when you pick a new look.

```bash
git clone https://github.com/unihermes/singularity.git && cd singularity && ./install.sh
```

## Contents

- [Highlights](#highlights)
- [Requirements](#requirements)
- [Installing](#installing)
- [First steps](#first-steps)
- [Looks and Styles](#looks-and-styles)
- [The shell](#the-shell)
- [Everything else that follows the look](#everything-else-that-follows-the-look)
- [Repository layout](#repository-layout)
- [Development](#development)
- [Machine notes](#machine-notes)
- [Troubleshooting](#troubleshooting)

## Highlights

- **A shell of its own.** Bar, flyouts, Control Centre, launcher, notification
  daemon, lock screen setup, Settings and System windows, all in
  [Quickshell](https://quickshell.outfoxxed.me) and editable live.
- **Looks and Styles.** 20+ looks (GNOME 2, CDE, NeXTSTEP, Gruvbox,
  Catppuccin, Nord, …) on top of ten Styles that draw all of the chrome at
  once, so no combination of settings can clash.
- **Settings for everything.** Displays, input, power and idle, the lock
  screen, window rules, keybinds, notifications, audio, Bluetooth, Wi-Fi,
  startup apps, file types, updates. Every page writes the real config file
  (hyprland.lua, hypridle.conf, lid.sh, mimeapps.list, …) in place.
- **One-command install, safe to rerun.** Every step is idempotent, and
  configs you already had are backed up rather than overwritten.
- **Fast, quiet boot** on the XPS 13 it was built on, with the reasons for
  each change written down (see [Machine notes](#machine-notes)).
- **Checked on every commit:** a pre-commit hook and GitHub Actions run the
  same tests and lints (see [Development](#development)).

## Requirements

- Arch Linux, installed with the archinstall **Minimal** profile (or any Arch
  system with `sudo`)
- An internet connection during the install
- Your own user account; `install.sh` refuses to run as root

The repo is built and tested on a Dell XPS 13 with Intel graphics. Nothing
in the shell is specific to it, but the boot tweaks in `install.sh` are
written for that hardware and skip themselves where they don't apply.

## Installing

```bash
sudo pacman -S --needed git
git clone https://github.com/unihermes/singularity.git ~/singularity
cd ~/singularity && ./install.sh
```

Clone it somewhere you'll keep it: the configs are symlinked from this folder,
so moving it later leaves `~/.config` pointing nowhere. Reboot when it
finishes and pick **Hyprland** in the greeter.

<details>
<summary>What <code>install.sh</code> does</summary>

1. Syncs the system and installs `base-devel git stow`
2. Bootstraps `yay` from `yay-bin` if it isn't there
3. Installs everything in `packages/pacman.txt` and `packages/aur.txt`
4. Links `dotfiles/` into `$HOME` with GNU stow (`link.sh`) and builds the
   `alttab-relay` helper
5. Rebuilds font and icon caches, makes Thunar the folder handler, and quiets
   the kernel command line
6. Applies the boot fixes: vfat in the initramfs, iwd no longer blocking the
   greeter, the webcam stack switched off, unused TPM setup masked
7. Enables iwd, systemd-networkd and -resolved, PipeWire, Bluetooth (with its
   pairing agent and power restore), power-profiles-daemon, the AC-power
   profile switch, and the `ly` greeter

`--needed`, `stow -R` and `enable --now` make every step a no-op the second
time, so rerunning it is always safe.

</details>

### Dotfiles only

```bash
./link.sh
```

Links the configs and nothing else: no packages, services or sudo. Use it on
a machine where you only want the configs, or after adding a folder under
`dotfiles/`. Apps write a default config when none exists (Hyprland does on
every start), and that file would block the link; `link.sh` moves any such
file to a timestamped `~/.config-backup-*` first. Nothing is deleted.

## First steps

| Keys | Opens |
|---|---|
| `SUPER + ,` | Settings |
| `CTRL + SPACE` | Launcher: apps, then `Tab` for files, clipboard and the calculator |
| `SUPER + Return` | Terminal (Alacritty) |
| `SUPER + K` | Every keybind, editable |
| `SUPER + W` | All workspaces |
| `SUPER + L` | Lock the screen |
| `SUPER + SHIFT + E` | Power menu |
| `ALT + Tab` | Window switcher |
| `Print` | Screenshot an area (`SHIFT` window, `CTRL` screen, `ALT` copy text) |

The bar is clickable throughout: the Arch logo opens the Control Centre, and
each module opens a flyout with its controls and a "More in Settings" link.

## Looks and Styles

A **look** is a palette and accent plus a starting point for every
appearance setting. The default, **Singularity**, is one grayscale ramp with
pale blue text and a single indigo accent (`#5555c8`):

| | | | |
|---|---|---|---|
| `#0b0b0b` base | `#121212` bar | `#141414` panel | `#1a1a1a` surface |
| `#242424` overlay | `#303030` border | `#4d4d4d` muted | `#7a7a7a` subtext |
| `#d0e2fa` text | `#ebebeb` bright | | |

It ships with the classic desktops GNOME 2, Breeze Dark, Greybird, CDE,
NeXTSTEP, Elementary and Ambiance, and the palettes Gruvbox (dark and light),
Catppuccin Mocha and Latte, Tokyo Night, Nord, Rosé Pine Moon and Dawn,
Everforest, Kanagawa and One Dark.

A **Style** decides how the chrome is drawn: frames, bar chips, hover, level
meters, section frames, the heading mark and where flyouts sit. There are
ten: Channel, Lined, Flat, Retro, Minimal, Basic, Capsule, Glass, Tabbed and
Terminal. Beside it are only dials that move everything together
(Roundness, Bar shape, Density, See-through) and a few finishing switches.

Pick a look from **Settings → Appearance → Look**, the Control Centre, or a
keybind (`qs ipc call look cycle`, `qs ipc call look set <name>`). The other
tabs adjust it; a dot marks every setting that differs from the look, and the
Look tab lists those changes with a way back for each. **Set as default**
saves your setup as the point Reset returns to.

Looks live in `quickshell/services/looks.json` (copy an entry to make your
own); Styles are in `services/Styles.js`; `DESIGN.md` in the shell's folder
is the design reference for every element.

## The shell

**Launcher.** One box, four modes, cycled with `Tab`:

| Mode | Key | |
|---|---|---|
| Applications | `CTRL + SPACE` | Desktop entries; Enter launches |
| Files | `SUPER + S` | Recent files, or names under `~` via `fd`; `Shift+Enter` opens the folder |
| Clipboard | `SUPER + H` | cliphist history; `Shift+Del` removes |
| Calculator | `SUPER + /` | Enter copies the result |

The calculator is its own parser (`services/Calc.js`), never `eval()`, so a
box one hotkey away can't run code. File search includes dotfiles but skips
app data dumps, and ranks its own results rather than taking `fd`'s first.

**Notifications.** The shell is the notification daemon. Popups stack from
the corner you pick, each with an urgency stripe that counts its time down;
pointing at one holds it. Everything lands in the history behind the bell
(right-click for Do Not Disturb), which survives restarts.
`qs ipc call notifications toggle|dnd|clear` works from keybinds.

**Settings and System.** Settings covers the desktop; System shows the
machine: CPU, memory, processes, storage, network, power, hardware, the
config files, and a **Health** page that finds problems (failed units,
broken links, `.pacnew` files, full disks, firmware updates) and puts the fix
next to each one. Settings search finds any field.

**Power and the lid.** Closing the lid turns the screen off and suspends after
5 minutes, then hibernates an hour later once hibernation is set up
(`install.sh` makes a swapfile for it). With an external monitor connected,
only the laptop panel turns off. All of it is `hypr/lid.sh`, logged to
`journalctl -t singularity-lid`. The power profile follows the charger.

**Moving machines.** `settings-bundle export` packs your appearance, app
usage, notes and wallpaper into a tarball; `settings-bundle import FILE`
restores it.

## Everything else that follows the look

`services/AppearanceSync.qml` renders the current look for everything outside
the shell, into `~/.local/state/singularity/`:

- **GTK 3/4 and Qt** apps take the ramp and accent (adw-gtk3, qt6ct), and the
  theme, icons, cursor and fonts are set through gsettings. Change them on
  the Appearance page; hand edits are overwritten.
- **Alacritty, starship, fastfetch and zathura** recolour live. The terminal's
  16 ANSI colours are a lightness ramp in the look's tones, so output stays
  legible but monochrome (`renderAlacritty()` is the one place to change
  that).
- **Neovim** ([LazyVim](https://lazyvim.org) with familiar shortcuts:
  `Ctrl+P`, `Ctrl+Shift+F`, `Ctrl+B`, `F2`, `F12`) builds every highlight,
  plugins included, from the look, and open editors recolour live.
- **Claude Code** gets a `custom:singularity` theme.
- **ly**, the greeter, runs on a VT without true colour, so `install.sh`
  loads the Singularity ramp into the VT palette and adds a status stack
  (battery, power, Wi-Fi, kernel, last login).
- **Floorp** gets a `userChrome.css` and `user.js` built into its profile.

Anything the shell saves (settings, display rules, the wallpaper, the
generated colour files) lives in `~/.local/state/singularity/`, never in the
repo. Deleting it resets the shell to its defaults.

## Repository layout

```
singularity/
├── install.sh              # provision a whole machine
├── link.sh                 # link the dotfiles only
├── packages/               # pacman.txt and aur.txt, one package per line
├── wallpapers/
├── tools/                  # checks run by the pre-commit hook and CI
│   ├── git-hooks/pre-commit
│   ├── check-settings-index.py
│   ├── check-unused.py
│   ├── test-js.mjs
│   └── glyph-svg.py        # Nerd Font glyphs as SVG, for HTML mockups
├── .github/workflows/      # the same checks on every push
└── dotfiles/               # each folder mirrors its path under $HOME
    ├── quickshell/.config/quickshell/
    │   ├── shell.qml       # entry point: IPC, one scope per screen, flyouts
    │   ├── DESIGN.md       # the design reference
    │   ├── bar/            # the bar window and its modules
    │   ├── flyouts/        # flyouts, popups, overlays and shared controls
    │   ├── settings/       # Settings pages (appearance/ holds its tabs)
    │   ├── windows/        # Settings, System, Keybinds and Notes windows
    │   ├── services/       # singletons: Theme, Settings, Network, Audio, …
    │   └── scripts/        # helpers the shell runs
    ├── hypr/               # hyprland.lua, hypridle, hyprlock, lid.sh, helpers
    ├── singularity/        # window rules, autostart, clean, diagnose, settings-bundle
    ├── systemd/            # Bluetooth agent and power restore, WirePlumber drop-in
    ├── nvim/  alacritty/  starship/  fastfetch/  zathura/  floorp/
    ├── gtk/  fontconfig/  bash/
    └── wofi/               # fallback launcher when the shell is down
```

## Development

The configs are symlinks into the repo, so editing a file under
`~/.config` edits the repo, and Quickshell reloads the shell the moment a QML
file is saved. `quickshell` run from a terminal prints QML errors with file
and line; `qs log` shows the running instance's.

**Checks.** `link.sh` points git at `tools/git-hooks`, whose pre-commit hook
runs, for whatever is staged:

| Check | What it catches |
|---|---|
| `tools/check-settings-index.py` | A Settings field that search can't find, or a search entry for a field that's gone |
| `tools/check-unused.py` | Files, functions, properties and signals nothing reads |
| `node --test tools/test-js.mjs` | Regressions in the plain-JS modules: the calculator, time windows, formats, Style resolution, the channel outline, and the readers/writers of `hyprland.lua` |

GitHub Actions runs all three on every push, plus `bash -n` on every script
and `luac -p` on every Lua file.

**Conventions.** UI work starts from `DESIGN.md`: take colours and sizes from
`Theme`, reach for the shared components (`FlyoutRow`, `SettingsField`,
`FlyoutSegmented`, …), and record new decisions there. Comments explain the
code as it is; history and reasons for a change go in the commit message.

**Driving the shell.** Everything the keybinds do is an IPC call;
`qs ipc show` lists them, e.g. `qs ipc call settings open display`.

**Package lists.** Once a system is worth keeping:

```bash
pacman -Qqen > packages/pacman.txt   # explicit native
pacman -Qqem > packages/aur.txt      # foreign (AUR)
```

This drops the comments in the current lists; keep a copy if you want them.

## Machine notes

<details>
<summary>Boot speed on the XPS 13</summary>

With the webcam enabled, the IPU6 camera stack stalls module loading for about
10 s at boot, waiting on the `ov01a10` sensor. `install.sh` routes the
greeter's dependencies around it:

- **`/boot`**: vfat is a module, so the ESP mount sat in the stall. `vfat`
  goes in `MODULES=()` in `/etc/mkinitcpio.conf` (backed up first).
- **iwd** is `Type=dbus` and needs crypto modules before claiming its bus
  name, while ly waits on `network.target`; a drop-in sets `Type=exec`.
- **TPM setup** (`systemd-tpm2-setup*`, `systemd-pcrproduct`) is masked unless
  `/etc/crypttab` asks for a TPM unlock. The TPM's contents are untouched, so
  Windows and BitLocker are unaffected.
- **The webcam** is switched off: `/etc/modprobe.d/singularity-vsc.conf`
  blacklists its stack, removing the stall, and avoids a kernel oops at
  shutdown after resuming from hibernation. Delete the file and run
  `mkinitcpio -P` to bring it back.

`systemd-analyze blame` and `systemd-analyze critical-chain ly@tty2.service`
show where boot time goes.

</details>

<details>
<summary>Networking, hibernation and other notes</summary>

- **Networking is iwd + systemd-networkd + resolved**, not NetworkManager.
  Connect from the bar or `iwctl station wlan0 connect <SSID>`.
- **Hibernation** needs a disk swapfile (zram can't hold the image), so
  `install.sh` creates a RAM-sized `/swapfile`, adds the `resume` hook and
  sets `resume=`/`resume_offset=`. The image is capped at 4 GB so resuming
  doesn't decompress gigabytes of page cache single-threaded. Recreating the
  swapfile moves it; rerun `install.sh` afterwards.
- **State that survives a reboot**: rfkill, volume and brightness persist on
  their own; `bt-power-restore.service` covers BlueZ adapter power, which
  otherwise always comes back off.
- **Startup apps**: Hyprland has no XDG autostart, so
  `~/.config/singularity/autostart.sh` runs `~/.config/autostart` (managed in
  Settings → Startup). System-wide entries are listed but off until you turn
  one on.
- **AUR safety**: read the PKGBUILD diffs yay shows. `install.sh` doesn't pass
  `--noconfirm` to the AUR step for this reason.
- **Kora 2.0.0** dropped upstream symlinks; if icons half-resolve, check the
  AUR comments.

</details>

## Troubleshooting

**No greeter at boot.** Check that `ly` is installed, its unit is
`ly@tty2.service`, no other display manager owns `display-manager.service`,
and the default target is `graphical.target`. `install.sh` enables ly but
doesn't start it, since it would take over the VT mid-install.

**Back at the greeter after logging in.** Hyprland exited. From a TTY
(`CTRL + ALT + F3`) run `Hyprland` by hand, then `hyprctl configerrors`.

**No bar.** Run `quickshell` from a terminal in the session to see the QML
error; after a Quickshell update it's usually a renamed import.

**Watching boot.** `BOOT_VERBOSE=1 ./install.sh` turns systemd's `[ OK ]`
lines back on; rerun without it to go quiet again.

**Wrong font or icon names.** Nerd Font and icon theme names vary; check the
real strings with `fc-list : family | grep -i ubuntu`, `fc-match monospace`
and `ls /usr/share/icons`.

**Something's broken and you don't know what.** `diagnose` prints a report,
and System → Health finds most problems and offers the fix.
