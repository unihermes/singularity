# To do

Delete this file once every item is done.

7. Full design review of the shell (against `qs/DESIGN.md`).
14. Windows: look for edge cases in how windows behave (floating, fullscreen, dialogs,
    popups, focus, placement, rules) and improve usability; look specifically at X11
    windows (menus, dialogs, scaling, focus, drag and drop under XWayland).

Design review ideas (from other shells and desktops, 2026-10-31; mock up before building).
My picks: 20, 15+16, 21.

15. Control Centre: volume and brightness as full-fill slider rows under the card
    (macOS, GNOME, Windows all lead with them).
16. Control Centre: Wi-Fi, Bluetooth and VPN as split toggles: the body toggles,
    the chevron expands the toggle into its network/device list in place (GNOME).
17. Clock: one dashboard flyout with the calendar, today's weather and the playing
    media (Caelestia).
18. Control Centre: an Edit chip to reorder, hide and add toggles in the panel itself,
    like Bar Widgets (macOS Tahoe).
19. Notifications: critical ones get an alert-coloured rail in popups and the sidebar
    (Dank Shell).
20. Keyboard navigation in flyouts: arrows/Tab move through rows, Enter activates;
    Left/Right step to the neighbouring module's flyout, like a menu bar.
21. Launcher: settings search from `SettingsIndex.js` (typing "roundness" jumps to it),
    and typed prefixes (`=` calc, `>` actions) besides the SUPER+key modes.
22. Bar: a right-click menu on every module (mute, toggle, Settings) without opening
    the flyout (Noctalia); a few modules already have one.
23. Flyouts: a short spring on a grown flyout's height so bar and flyout read as one
    shape growing (Caelestia, Dank Shell), following the Animations setting.
