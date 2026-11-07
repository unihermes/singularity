# Gaming fixes and tweaks (desktop, RTX 4070, Ryzen 7 7700X)

Anything marked **repo** comes back
by itself on a fresh `./install.sh`; **manual** means you redo it by hand.

## Packages (manual: not in the repo lists)
- Enable `[multilib]` in /etc/pacman.conf, then:
  `steam gamemode lib32-gamemode gamescope mangohud lib32-mangohud lib32-nvidia-utils`
- Games on this machine: Overwatch, No Man's Sky, Minecraft (modrinth-app), Proton Experimental.

## Shader cache (the big one for Overwatch stutter)
- **Steam > Settings > Downloads > Shader Pre-Caching: OFF** (manual). Its merged cache grew past
  4 GiB, the offsets wrapped ("Mismatching key!" in shader_log.txt) and DXVK recompiled ~10 min on
  every launch (154 fps, 18 GB RAM). With it off the driver cache in ~/.cache/nvidia is used
  (~2.4 GB for OW) and a warm launch compiles in ~3 s.
- **repo:** `__GL_SHADER_DISK_CACHE_SIZE=10737418240` (10 GiB; the default 1 GiB cap evicted OW's
  cache) and `__GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1` in hypr/env.lua and in
  dotfiles/systemd/.config/environment.d/nvidia-shader-cache.conf (so apps started by systemd or
  D-Bus get them too). Needs a re-login after first install.
- If OW stutters: check the size of `~/.cache/nvidia/GLCache/ee579c6f.../92f74448a56b9fe8.bin`
  (about 2.4 GB when warm). Smaller means it was pruned and is recompiling; also check whether
  pre-caching got turned back on.
- Steam's "Processing Vulkan shaders" before launch restarts at 0% and runs 25+ min: Skip is fine.

## Launch options (manual, per game in Steam)
- Overwatch: `PROTON_ENABLE_NVAPI=1 %command%`
- `gamemoderun` was dropped: the user isn't in the `gamemode` group, so it did nothing.
  (Untested: adding yourself to `gamemode`, and `split_lock_mitigate`; both need root.)
- Tested and no effect, reverted: tearing (allow_tearing + immediate), PROTON_ENABLE_WAYLAND=1,
  Overwatch's Reduce Buffering off. Steady state already held the 300 fps cap.
- Never edit in-game graphics files (e.g. Overwatch Settings_v0.ini).

## Hyprland (repo)
- game-keys.lua: while a game has focus every SUPER bind, CTRL+SPACE and the bare right-hand
  modifiers are off; ALT+Tab and the recorder binds stay. Games open on the primary display's
  current workspace, stay fullscreen, and hold the **Power Saver** profile on the desktop while open.
- Minecraft counts as a game; Steam popouts/menus get no border, rounding or shadow.
- Vibrance stays on in games (it was not behind the flicker).
- Recorder (gpu-screen-recorder): instant replay records the game's screen with only the Game
  and Chat audio channels.
- Audio channels Game / Chat / Media with EQ per channel; drag an app onto a channel.

## Display (manual, in ~/.local/state/singularity/)
- VRR (`misc.vrr 2`) is on, in hyprland.json. VRR was NOT the DP-3 flicker; leave it on.
- DP-3 flicker in games came from a reduced-blanking modeline (138.50 MHz) in display-fixes.lua:
  NVIDIA memory-clock switches need a longer vblank. Fix: pcTimings for the P2418HZm is empty
  (plain 1920x1080@60.00). Modelines with full blanking (148.50, 173.00) are rejected by the
  driver and Hyprland silently keeps the old mode. If flicker returns, the other fix is locking the
  memory clock during games (`nvidia-smi -lmc`, root).
- DP-3 at scale 0.75 at 2560x32 (monitors.lua), `xwayland.force_zero_scaling = true` (custom.lua).
  Its EDID caps at 170 MHz, so no 1440p signal, and NVIDIA has no DSR on Linux.

## CPU and power (manual)
- Keep power-profiles-daemon on **power-saver**. Idle floor is ~37 W either way, but balanced
  boosts light multi-thread work (Steam downloads, fossilize) to 85 °C; power-saver stays ~50 °C
  with the same 300 fps in OW (Tctl 52 vs 61-62).
- Fans: see the desktop-fans notes (fan5 = pump, fixed 100%), CoolerControl daemon enabled.

## Testing recipe (unattended)
- /dev/uinput is writable (input group) and `hyprctl dispatch 'hl.dsp.cursor.move({x=..,y=..})'`
  gives clicks. MangoHud logging toggle: Shift_R+F2 (LShift is Winston's jump). Closing with
  hl.dsp.window.close quits OW cleanly. Practice Range can't show map/hero compiles or real
  match CPU load.
