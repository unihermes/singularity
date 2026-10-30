# To do

Delete this file once every item is done.

4. Roundness: make sure it is set in one place (one Theme token everything reads,
   no hard-coded radii elsewhere).
7. Full design review of the shell (against `qs/DESIGN.md`).
8. Settings redesign, picked 2026-10-30 (mockups: round one https://claude.ai/artifact/3oVR1yGwxkbiUDo7899xL4,
   round two https://claude.ai/artifact/5jhzv7WxLWhkR9FsU9ak5W). Structure A everywhere: one flat sidebar
   of short pages under headings, search box at its top whose results replace the sidebar, no home (opens
   on the last page). Groups: Connections (Network, Bluetooth, VPN), Device (Display, Sound, Keyboard &
   Mouse, Devices, Battery & Idle, Recording), Look (Theme, Wallpaper & Desktop, Bar, Panels & Popups,
   Windows, Fonts & Icons, Lock Screen, Notifications), Apps (Login & Startup, Default Apps, Terminal,
   Shortcuts), System (Date & Time, Software Update). Appearance splits into those six Look pages; Window
   Rules folds into Windows; the lid and lock timing move to Battery & Idle; Lock Screen keeps its look
   and unlocking. Page anatomy per page: A grouped lists (Network, Display, Sound, Default Apps);
   B two columns, section name and line on the left, rows right, preview column on visual pages
   (Bluetooth, VPN, Keyboard & Mouse, Devices, Battery & Idle, Recording, Notifications, Login &
   Startup, Terminal, Shortcuts, Date & Time, Software Update); C a status card then a card per
   section showing three rows with the rest under More (Theme, Wallpaper & Desktop, Bar, Panels &
   Popups, Windows, Fonts & Icons, Lock Screen). Stages: structure, then the three anatomies as shared
   components, then each page.
14. Windows: look for edge cases in how windows behave (floating, fullscreen, dialogs,
    popups, focus, placement, rules) and improve usability; look specifically at X11
    windows (menus, dialogs, scaling, focus, drag and drop under XWayland).
