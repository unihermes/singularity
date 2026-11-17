# TODO

1. Add an optional X11 fallback session alongside Hyprland using Xfce and xfwm4, selectable at login. Make session startup and environment settings aware of the selected desktop, and reuse existing applications and services where practical. The full xfce4 group plus xorg-server and xorg-xinit would add 27 packages on the current machine, including dependencies; the count will vary by installation. Initially use Xfce's panel and settings, and evaluate porting Singularity's Quickshell features to X11 separately.
