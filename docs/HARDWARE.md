# Laptop, desktop and hardware

- `dotfiles/singularity/.config/singularity/platform.sh` is the single detector
  (`has CAP`) and policy resolver (`feature NAME`). Its `profiles/laptop.conf`
  and `profiles/desktop.conf` select usage policies; hardware gates still apply.
- `scripts/hardware.sh` sources that resolver and adds provisioning helpers. First
  interactive install offers the detected choice; explicit laptop/desktop,
  saved choice, then detection supply it elsewhere. `--plan` is read-only.
  Install, link and update must use `select_machine`, never duplicate detection.
- Hardware packages go in `packages/hardware/CAP.txt`; policy packages in
  `packages/laptop.txt` or `packages/desktop.txt`. Hardware fixes use `has`;
  hibernation setup, cooling and other usage policies use `feature`.
- QML uses `Platform.has()` and `Platform.allows()` (fail closed until loaded).
  Hyprland uses `shared.has/allows`; `platform.lua` gates device configuration,
  including saved overrides. Keep settings visibility and search gates aligned.
- Shared files can be linked everywhere; unsupported code must not activate.
  A desktop may have an external touchpad; a laptop may lack a lid or backlight.
- `python3 tools/test-platform.py` checks profile selection, package selection,
  hardware/policy combinations, preview side effects and compositor gates.

