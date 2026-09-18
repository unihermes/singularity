<!doctype html>
<html>
<head>
<style>
body { font-family: system-ui, sans-serif; line-height: 1.6; max-width: 900px; margin: 40px auto; padding: 0 20px; background: #0b0b0b; color: #c2c2c2; }
h1 { color: #ebebeb; border-bottom: 2px solid #303030; padding-bottom: 10px; }
h2 { color: #ebebeb; margin-top: 40px; }
h3 { color: #c2c2c2; margin-top: 20px; }
.section { border-left: 3px solid #4d4d4d; padding-left: 20px; margin: 30px 0; }
.critical { border-left-color: #a87676; }
.improvement { border-left-color: #7a7a7a; }
.feature { border-left-color: #7d9b7d; }
.personal { border-left-color: #6b7a8f; }
.quality { border-left-color: #8f7a6b; }
code { background: #1a1a1a; padding: 2px 6px; border-radius: 3px; font-family: monospace; color: #ebebeb; }
li { margin-bottom: 8px; }
ul ul { margin-top: 8px; }
.task { background: #1a1a1a; padding: 12px; margin: 10px 0; border-radius: 4px; }
.task-title { color: #ebebeb; font-weight: bold; margin-bottom: 8px; }
.task-desc { font-size: 0.95em; margin-bottom: 8px; }
.task-detail { font-size: 0.9em; color: #7a7a7a; margin-left: 16px; }
.note-header { background: #242424; padding: 12px; margin: 16px 0; border-left: 3px solid #7d9b7d; border-radius: 3px; }
.completed { text-decoration: line-through; opacity: 0.6; }
</style>
<title>Singularity — Future Work & Feature Ideas</title>
</head>
<body>

<h1>Singularity — Future Work & Feature Ideas</h1>
<p><em>Personal-use optimizations, new features, and architecture improvements for a custom desktop shell.</em></p>

<div class="note-header">
<strong>✏️ Note on Completion:</strong> When a task is completed, add a <code>&lt;s&gt;</code> tag around it (or mark with strikethrough) instead of deleting. This preserves the history of what was accomplished and prevents duplicating work.
</div>

<hr>

<h2>🔴 Critical Fixes (Blocking Issues)</h2>

<div class="section critical">

<div class="task completed">
<div class="task-title">1. <s>PpdProfile Singleton Not Resolving</s></div>
<div class="task-desc">
Verified fixed: PpdProfile.qml already has <code>pragma Singleton</code> and is consumed correctly everywhere (shell.qml, SettingsPagePower.qml). No <code>ReferenceError</code> reproduces against current code.
</div>
</div>

<div class="task completed">
<div class="task-title">2. <s>Missing Error State Handling</s></div>
<div class="task-desc">
Superseded by the current architecture rather than fixed as originally described: <code>Network.qml</code>/<code>Bluetooth.qml</code> as named here no longer exist. Network status shells out to <code>iwctl</code> with stderr suppressed and defensive parsing; Bluetooth and UPower state come from Quickshell's reactive DBus-backed services and are null-checked at every read site (e.g. <code>Bluetooth.defaultAdapter</code> guarded before use). <code>PpdProfile.profile === ""</code> already signals "PPD not answering" and the UI says so instead of showing dead buttons. No silent-crash path found; explicit retry timers were judged unnecessary since the services already reconnect reactively.
</div>
</div>

<div class="task completed">
<div class="task-title">3. <s>Power Profile Auto-Switch Too Aggressive</s></div>
<div class="task-desc">
Correction to the previous entry here: the auto-switch logic was never in the QML at all — it's a udev rule (<code>/etc/udev/rules.d/99-singularity-power-profile.rules</code>, installed by <code>install.sh</code>) that runs <code>/usr/local/bin/singularity-power-profile</code> on every <code>power_supply</code> uevent for Mains/USB devices. Confirmed via <code>busctl</code> alone with quickshell killed entirely: this machine's USB-C controller fires a "change" uevent roughly once a second even at idle, and the script unconditionally re-wrote <code>ActiveProfile</code> from current AC state on every single firing — wiping out a manual pick within about a second, exactly as reported.
</div>
<div class="task-detail">
<strong>Fix:</strong> the script now stamps its last-applied profile to <code>/run/singularity-power-profile.last</code> and exits without writing if the computed target already matches. A real plug/unplug still switches it (the computed target changes, so the stamp no longer matches); a manual pick in between now survives repeated same-state uevents since nothing re-writes when nothing changed. Fixed in <code>install.sh</code>; applying it to a live machine needs the file rewritten at <code>/usr/local/bin/singularity-power-profile</code> with root, which install.sh does via <code>sudo tee</code>.
</div>
</div>

</div>

<hr>

<h2>🏗️ Architecture Improvements</h2>

<div class="section improvement">

<div class="task">
<div class="task-title">0. Hyprland Config Complete Revamp</div>
<div class="task-desc">
Overhaul window management rules and keybinds for consistency, clarity, and maintainability. Current config has grown organically with ad-hoc rules that need consolidation.
</div>
<div class="task-detail">
<strong>Phase 1: Backup & Documentation</strong>
<ul>
<li>Create <code>hyprland.lua.backup</code> with current working version</li>
<li>Document purpose and scope of every existing window rule</li>
<li>Document all keybinds with their intent and category</li>
<li>Identify conflicts, overlaps, or inconsistent patterns</li>
</ul>

<strong>Phase 2: Window Rule Consolidation</strong>
<ul>
<li>Create a clear hierarchy: Primary apps (editor, browser) → Utility apps (file manager, settings) → Dialogs/Popups → System windows (PiP, notifications)</li>
<li>Standardize floating window sizing: implement 50% screen default for most floating windows</li>
<li>Unify centering behavior for dialogs</li>
<li>Add specific handling for browser popouts (sign-in, PiP, extensions)</li>
<li>Implement dynamic PiP positioning (bottom-right, ~10% screen area)</li>
<li>Lock PiP aspect ratio to 16:9 to prevent black bars on resize</li>
</ul>

<strong>Phase 3: Keybind Reorganization</strong>
<ul>
<li>Group binds by function in code (Launchers, Window Management, Focus, Workspaces, Media, etc.)</li>
<li>Add comments documenting each bind's purpose and which feature it controls</li>
<li>Create new category-based keybind structure in bar's Keybinds window</li>
<li>Add new utility keybinds: PiP snap-to-corner, window sizing, workspace jumping</li>
</ul>

<strong>Phase 4: Extraction & Helpers</strong>
<ul>
<li>Extract repeated patterns into Lua helper functions</li>
<li>Create window rule builder functions to reduce boilerplate</li>
<li>Add a "window rule validator" that checks for conflicts at startup</li>
</ul>

<strong>Success criteria:</strong> Config is well-organized, documented, and easy to extend. Adding a new rule takes &lt;5 lines. No duplicate or conflicting rules.
</div>
</div>

<div class="task completed">
<div class="task-title">1. <s>Split shell.qml into Focused Components</s></div>
<div class="task-desc">
Done: split into <code>ControlCentre.qml</code> (the whole control-centre flyout, all pages/submenus) and <code>BarModules.qml</code> (all 18 bar module declarations plus the widgetItems registry), both taking their bar/screenScope/window state as required properties rather than reaching for ids in shell.qml. <code>shell.qml</code> itself went from 2856 to ~1920 lines: the screen loop, per-screen scope, bar layout/reparenting plumbing, and the remaining 12 flyout panels.
</div>
<div class="task-detail">
<strong>Bugs found along the way (fixed):</strong> naming a required property the same as an id it's meant to be bound to (<code>root</code>, <code>settingsWindow</code>, <code>system</code>, <code>keybinds</code>) self-shadowed in the <code>Foo { root: root }</code> instantiation, leaving those properties <code>undefined</code> and silently breaking Settings/System/Keybinds from opening -- renamed to <code>shellRoot</code>/<code>settingsWin</code>/<code>systemWin</code>/<code>keybindsWin</code>. Separately (pre-existing, unrelated to the split, just never reachable until the above was fixed): <code>hyprland.lua</code>'s <code>maximizeFocused()</code> could catch a Quickshell window before its <code>float=true</code> rule landed, and <code>float-common-dialogs</code>' title heuristic matched the Settings window by title coincidence and force-sized it to 960x540 -- both now explicitly exclude <code>class = org.quickshell</code>.
</div>
</div>

<div class="task completed">
<div class="task-title">2. <s>Flyout Auto-Generation with Repeater</s></div>
<div class="task-desc">
Done, adapted: a literal single Repeater turned out not to fit this codebase -- the 13 flyouts (workspaces, calendar, brightness, volume, network, bluetooth, battery, tray menu, media, weather, privacy, failed, updates) are too heterogeneous in required state (some need <code>bar</code>, several are referenced by id from elsewhere -- e.g. <code>trayMenu</code> from <code>BarModules.qml</code>) to inject uniformly through one data array without either forcing unused properties onto the simple ones or losing by-id addressability for the ones that need it. Instead the 9 substantial ones became their own files (<code>CalendarFlyout.qml</code>, <code>NetworkFlyout.qml</code>, <code>BluetoothFlyout.qml</code>, <code>BatteryFlyout.qml</code>, <code>TrayMenuFlyout.qml</code>, <code>MediaFlyout.qml</code>, <code>WeatherFlyout.qml</code>, <code>FailedFlyout.qml</code>, <code>UpdatesFlyout.qml</code>, following the pattern <code>ControlCentre.qml</code>/<code>BarModules.qml</code> already established) and shell.qml references each with one line, e.g. <code>NetworkFlyout { scope: screenScope; bar: bar }</code>. The 4 smallest (workspaces, brightness, volume, privacy -- 20-40 lines each) were tried as separate files too, then folded back inline: splitting a single-use, already-short block into its own file cost more in navigation (another file to open) than it saved, with zero functional or performance difference either way since QML's object-tree cost doesn't depend on which file declares it.
</div>
<div class="task-detail">
<code>shell.qml</code> went from ~2856 to ~1011 lines. Adding a new substantial flyout is still effectively "1 line" -- write the file, add its instantiation -- just not through a Repeater; a small one-off flyout belongs inline in shell.qml instead. Two Process-backed actions the network flyout needed from the bar (<code>netScan</code>, <code>netConnect</code>) were exposed as <code>bar.scanNetworks()</code> / <code>bar.connectNetwork(cmd)</code> rather than handing the flyout raw Process ids.
</div>
</div>

<div class="task completed">
<div class="task-title">3. <s>SettingControl Component for Forms</s></div>
<div class="task-desc">
Already done under a different name: <code>SettingsField.qml</code> already is this component (label + optional hint on the left, a control slot on the right) and is already used consistently across every settings page that needs it (Input, Audio, Display, Power, Notifications, Shell, FileTypes -- <code>SettingsPageKeybinds.qml</code> is the one legitimate exception, a full-width list with no label/control split). No boilerplate found left to extract.
</div>
</div>

<div class="task completed">
<div class="task-title">4. <s>Constants & Theme Singleton</s></div>
<div class="task-desc">
Already done, and better than as specced: <code>Theme.qml</code> already covers colours, typography, motion, and bar/module geometry as one singleton (<code>Theme.barHeight</code>, <code>Theme.radius</code>, <code>Theme.moduleGap</code>, <code>Theme.fs()</code>, <code>Theme.dur()</code>, etc.). Splitting it into a separate <code>Constants.qml</code> as originally specced would mean checking two files for one concept instead of one -- a regression, not a cleanup. The handful of numbers still local to one file (e.g. <code>SettingsWindow.qml</code>'s <code>paneWidth: 740</code>) aren't reused anywhere else, so there's no consistency risk in leaving them where they are.
</div>
</div>

<div class="task completed">
<div class="task-title">5. <s>Service Layer Pattern for System Calls</s></div>
<div class="task-desc">
Already done, as one singleton per domain rather than one <code>Services.qml</code>: <code>PpdProfile.qml</code>, <code>Wallpaper.qml</code>, <code>FailedUnits.qml</code>, <code>Updates.qml</code>, <code>Notifications.qml</code>, <code>Media.qml</code>, <code>Weather.qml</code>, <code>Privacy.qml</code>, <code>Visualizer.qml</code>, and <code>HyprLuaWrite.qml</code> each already wrap their DBus/process/file calls behind a small API (<code>.get()</code>/<code>.set()</code>/<code>.refresh()</code>). Merging all of these into one <code>Services.qml</code> namespace would mean rewriting every call site across 15+ files to mix unrelated domains (power, bluetooth, wallpaper, notifications) into one large file, for no new capability -- worse locality and a bigger blast radius for the same behaviour. Not done, on the same "don't change functionality or efficiency for the worse" basis as the flyout consolidation above.
</div>
</div>

</div>

<hr>

<h2>✨ New Features (Prioritized by Impact)</h2>

<div class="section feature">

<h3>Priority Tier 1: High Impact, Medium Effort</h3>

<div class="task">
<div class="task-title">1.1 Custom Quick Actions</div>
<div class="task-desc">
Allow users to create custom buttons in the Quick Actions bar (currently hardcoded). Store in Settings.json for persistence.
</div>
<div class="task-detail">
<strong>What users can do:</strong>
<ul>
<li>Add a new QA button that runs a command (e.g., <code>notify-send "Hello"</code>)</li>
<li>Drag-to-reorder buttons</li>
<li>Set custom icon (pick from system icons or upload)</li>
<li>Edit or delete custom buttons</li>
</ul>

<strong>Implementation:</strong>
<ul>
<li>Add "Custom QA" page to Settings</li>
<li>Create button editor UI</li>
<li>Store in <code>Settings.json: { customQuickActions: [{ label, icon, command }] }</code></li>
<li>Load on shell startup and render dynamically</li>
</ul>

<strong>Success criteria:</strong> Users can add/edit/remove custom QA buttons. Changes persist across restarts.
</div>
</div>

<div class="task completed">
<div class="task-title">1.2 <s>Per-App Window Rules UI</s></div>
<div class="task-desc">
Done: a Window Rules page in Settings (<code>SettingsPageWindowRules.qml</code>) over <code>~/.config/singularity/window-rules.json</code>, shipped as its own stow package (<code>dotfiles/singularity</code>) and read by <code>hyprland.lua</code> on every load. Every per-app and popout exception that used to be hardcoded in <code>hyprland.lua</code> moved into it, so there is one place for window rules; only the shell's own machinery (monocle, Quickshell windows, XWayland drag fix, startup terminal) stays in Lua. Adapted from the spec: layout is Auto/Float rather than float/tile (non-floating already means monocle or tiled), "always on top" is Hyprland's pin, rules can also match on title and set a size, and new rules go on top with the higher rule winning a conflict.
</div>
<div class="task-detail">
<strong>What users configure:</strong>
<ul>
<li>App name / window class (with autocomplete from open windows)</li>
<li>Default layout: float or tile</li>
<li>Target workspace (1-5)</li>
<li>Open fullscreen: yes/no</li>
<li>Always on top: yes/no</li>
</ul>

<strong>How it works:</strong>
<ul>
<li>Settings UI stores rules in <code>~/.config/singularity/window-rules.json</code></li>
<li>On startup, hyprland.lua reads and applies rules dynamically</li>
<li>Users preview matched windows as they type app name</li>
</ul>

<strong>Success criteria:</strong> Users can define rules through UI. Rules persist and apply on window open. No manual config file editing needed.
</div>
</div>

<div class="task completed">
<div class="task-title">1.3 <s>Monocle Mode: Exclude App Popouts from Fullscreen</s></div>
<div class="task-desc">
Already done, via the window-rules system rather than a dedicated window-type check: every popout/dialog entry in <code>window-rules.json</code> (sign-in popups, file/settings dialogs, PiP, etc.) sets <code>float: true</code>, and <code>hyprland.lua</code>'s rule loader tags any rule with <code>float</code>, <code>pin</code>, or <code>fullscreen</code> set as <code>+monocle-exempt</code> (<code>exempt = r.float or r.pin or r.fullscreen</code>). <code>toggleLayout()</code>'s SUPER+M sweep and the monocle map-time sizing both skip windows carrying that tag, so a dialog spawned while the parent is in monocle floats and centers instead of inheriting fullscreen -- no per-app configuration needed, and covered by the same page 1.2 already built rather than a separate mechanism.
</div>
</div>

<div class="task">
<div class="task-title">1.4 Night Light with Sunrise/Sunset Auto</div>
<div class="task-desc">
Extend Night Light to automatically enable at sunset and disable at sunrise based on user's location.
</div>
<div class="task-detail">
<strong>What to add:</strong>
<ul>
<li>Location setting (city name or coordinates)</li>
<li>Sunrise/sunset API call (use free service like sunrise-sunset.org)</li>
<li>Automatic scheduling at sunrise and sunset</li>
<li>Fallback: manual time range if location unavailable (e.g., 6pm-7am)</li>
</ul>

<strong>Implementation:</strong>
<ul>
<li>Add location input to Display settings</li>
<li>Cache sunrise/sunset times daily</li>
<li>Use systemd timer or Hyprland event hooks for scheduling</li>
<li>Show next scheduled time in Display page</li>
</ul>

<strong>Success criteria:</strong> Night Light auto-enables at sunset without user intervention. Can still manually toggle anytime.
</div>
</div>

<div class="task">
<div class="task-title">1.5 Do Not Disturb Schedule</div>
<div class="task-desc">
Allow DND to automatically enable at night and disable in morning, with exceptions for important contacts.
</div>
<div class="task-detail">
<strong>Settings:</strong>
<ul>
<li>Enable/disable auto-DND</li>
<li>Start time (e.g., 10pm)</li>
<li>End time (e.g., 8am)</li>
<li>Exception list: allow notifications from these contacts/apps anyway</li>
</ul>

<strong>Integration:</strong>
<ul>
<li>Works with swaync notification daemon</li>
<li>Shows remaining DND time in status bar</li>
<li>Can manually override (touch any notification = disable DND for 1 hour)</li>
</ul>

<strong>Success criteria:</strong> DND auto-activates on schedule. Exceptions are respected. User can still manual override.
</div>
</div>

<div class="task completed">
<div class="task-title">1.6 <s>Night Mode in Brightness Flyout</s></div>
<div class="task-desc">
Done: <code>BrightnessFlyout.qml</code> now takes <code>shellRoot</code> as a required property (wired from <code>shell.qml</code> as <code>shellRoot: root</code>, same name Control Centre already uses) and reuses the exact <code>FlyoutAction</code> + <code>FlyoutStepper</code> pair from Quick Actions -- toggle plus a warmth stepper in Kelvin, shown only while Night Light is on. No new state: both read/write the same <code>root.nightLight</code> and <code>Settings.nightLightKelvin</code> Quick Actions already used, so the two stay in sync automatically.
</div>
</div>

<div class="task">
<div class="task-title">1.7 Quick Links Module</div>
<div class="task-desc">
Add customizable quick links bar to Control Centre or Bar. Store bookmarks/commands and launch with one click. Examples: frequently-visited websites, terminal commands, app shortcuts.
</div>
<div class="task-detail">
<strong>What users can do:</strong>
<ul>
<li>Add custom links (URL, command, or app shortcut)</li>
<li>Set icon and label for each link</li>
<li>Organize by category or drag-to-reorder</li>
<li>Edit or delete existing links</li>
</ul>

<strong>Implementation:</strong>
<ul>
<li>Add "Quick Links" page to Settings</li>
<li>Create link editor UI (name, URL/command, icon picker)</li>
<li>Store in Settings.json: <code>{ quickLinks: [{ label, icon, target (url/command), type }] }</code></li>
<li>Display as clickable chips in Control Centre or as bar module</li>
</ul>

<strong>Success criteria:</strong> Users can add/edit/remove quick links. Links persist and are easily accessible.
</div>
</div>

<div class="task">
<div class="task-title">1.8 Enhanced Appearance Settings Page</div>
<div class="task-desc">
Create a dedicated, full-featured Appearance settings page (separate from Control Centre flyout). More detailed than current flyout controls.
</div>
<div class="task-detail">
<strong>Current state:</strong> Appearance/theme controls live in Control Centre + Display settings, split across multiple places.
<br>
<strong>What to build:</strong>
<ul>
<li><strong>Theme selector:</strong> Dark, Light, Auto (follow system)</li>
<li><strong>Color customization:</strong> Edit the grayscale ramp (darker/lighter variants)</li>
<li><strong>Color scheme presets:</strong> Catppuccin, Dracula, Nord, custom</li>
<li><strong>Accent color picker:</strong> Choose highlight/alert colors</li>
<li><strong>Font selection:</strong> UI font, terminal font, font size scale</li>
<li><strong>Border & spacing:</strong> Adjust module padding, bar height, border radius</li>
<li><strong>Wallpaper manager:</strong> Current wallpaper, recent wallpapers, directory picker</li>
<li><strong>Preview panel:</strong> Live preview of theme changes on sample UI elements</li>
<li><strong>Import/export themes:</strong> Save current theme as JSON, load from file</li>
</ul>

<strong>Organization:</strong>
<ul>
<li>Tab 1: Theme & Colors (presets, color picker, preview)</li>
<li>Tab 2: Typography (font family, size, line height)</li>
<li>Tab 3: Layout (spacing, borders, bar height)</li>
<li>Tab 4: Wallpaper (current, gallery, directory)</li>
</ul>

<strong>Success criteria:</strong> Users can fully customize appearance without touching config files. Changes preview live.
</div>
</div>

<div class="task completed">
<div class="task-title">1.9 <s>Enhanced System Information Page</s></div>
<div class="task-desc">
Mostly already done before this pass (per-core bars, 60s CPU/network graphs, disk gauge, temp, uptime, live process list, full hardware specs, monitors, storage, quick links) -- the layout-reorganization and performance-metrics parts of the spec, which is why they're not repeated here. Added on top: an INPUT section (keyboards/mice/touchpad from <code>hyprctl devices -j</code>), a HEALTH section (battery health via UPower, failed systemd units reusing the existing <code>FailedUnits</code> singleton), network details (IP, connection type, wifi signal in dBm), and a QUICK ACTIONS row (Restart Audio via <code>systemctl --user restart wireplumber pipewire pipewire-pulse</code>, Check Updates via the existing <code>Updates</code> singleton).
</div>
<div class="task-detail">
<strong>Not done:</strong> CPU frequency/power-consumption metrics and a `du`-based storage breakdown -- both need either root or a slow recursive scan for a personal dashboard that's meant to open instantly, so left out rather than done poorly. A "clear cache" quick action was also left out: nothing in this codebase has a cache worth a one-click wipe without picking a specific, safe target first.
</div>
</div>

<div class="task">
<div class="task-title">1.10 Workspace Naming & Navigation</div>
<div class="task-desc">
Allow naming workspaces (Work, Gaming, Social, etc.) and jumping to them by name instead of number.
</div>
<div class="task-detail">
<strong>User workflow:</strong>
<ul>
<li>Settings → Workspaces page</li>
<li>Set name for each workspace (1-5)</li>
<li>In bar, show workspace name instead of number</li>
<li>Keybind: Super+Shift+J opens "Jump to Workspace" search</li>
<li>Type "Work" or "Gaming" to jump there</li>
</ul>

<strong>Implementation:</strong>
<ul>
<li>Store workspace names in Settings.json</li>
<li>Update workspace switcher UI to show names</li>
<li>Create jump-to-workspace keybind that prompts for name</li>
</ul>

<strong>Success criteria:</strong> Users can name workspaces. Names persist. Can jump by name with keybind.
</div>
</div>

<hr>

<h3>Priority Tier 2: Nice-to-Have Features</h3>

<div class="task completed">
<div class="task-title">2.1 <s>Volume/Brightness OSD Bar</s></div>
<div class="task-desc">
Done, as <code>LevelToast.qml</code>: a click-through toast flush under the bar (matching the SUPER+M layout toast's position rather than 10% from the top, for visual consistency with the rest of the shell) showing an icon and a thin fill bar 0-100%, fading in and out over <code>Theme.dur(150)</code> and auto-hiding after 2s.
</div>
<div class="task-detail">
Triggers via two reactive properties added to <code>bar</code> (<code>volumeLevel</code>, <code>volumeIsMuted</code>) plus the existing <code>brightness</code> property, all three already fed live by Pipewire and a watched sysfs file respectively -- so hardware keys, the flyout sliders, and scroll-on-chip all surface the OSD for free with no new IPC or per-trigger wiring. A 1.5s startup grace suppresses the toast, since both of these fire once on load regardless (brightness reading from sysfs async, volume settling once the sink reports ready) and that first fire isn't a user action.
</div>
</div>

<div class="task">
<div class="task-title">2.2 Screenshot & Recording Preview</div>
<div class="task-desc">
Show a thumbnail of the last screenshot in a corner widget. Click to open in image viewer. Quick keybind to re-copy to clipboard.
</div>
<div class="task-detail">
<strong>Widget placement:</strong>
<ul>
<li>Bottom-right corner by default (doesn't interfere with PiP)</li>
<li>Shows last 3 screenshots as small thumbnails</li>
<li>Click to open in feh/zathura</li>
<li>Right-click to delete</li>
</ul>

<strong>Keybinds:</strong>
<ul>
<li>Print (existing): take screenshot</li>
<li>Super+Ctrl+C: copy last screenshot to clipboard again</li>
</ul>

<strong>Success criteria:</strong> Screenshot preview widget works. Thumbnails update on new screenshots.
</div>
</div>

<div class="task">
<div class="task-title">2.3 Keyboard Layout Indicator</div>
<div class="task-desc">
Show current XKB layout in bar (US, DE, FR, etc.). Click to cycle to next layout.
</div>
<div class="task-detail">
<strong>What to implement:</strong>
<ul>
<li>Read current layout from Hyprland (via hyprctl)</li>
<li>Display as bar module showing 2-letter code (US, DE)</li>
<li>Click cycles to next configured layout</li>
<li>Populate layouts from Input settings page (already tracked)</li>
</ul>

<strong>Success criteria:</strong> Bar shows current layout. Clicking cycles layouts. Reflects actual Hyprland state.
</div>
</div>

<div class="task">
<div class="task-title">2.3a Display Mirror/Extend Mode Selector</div>
<div class="task-desc">
When an external display is plugged in, show a notification or settings option to select between mirror or extend mode without manual command-line setup.
</div>
<div class="task-detail">
<strong>Behavior:</strong>
<ul>
<li>Detect external display hotplug (monitor connected event)</li>
<li>Show quick dialog or notification with two options: Mirror or Extend</li>
<li>Mirror: both displays show same content</li>
<li>Extend: second monitor becomes additional workspace</li>
<li>Remember last choice (show quick toggle on next hotplug)</li>
</ul>

<strong>Implementation:</strong>
<ul>
<li>Listen to Hyprland monitor hotplug events</li>
<li>Show modal dialog in QuickShell with Mirror/Extend buttons</li>
<li>Call <code>hyprctl keyword monitor</code> to apply selected mode</li>
<li>Store preference in Settings.json for future hotplugs</li>
</ul>

<strong>Success criteria:</strong> Users can quickly switch display modes without terminal commands. Preference is remembered.
</div>
</div>

<div class="task">
<div class="task-title">2.4 VPN Status Module</div>
<div class="task-desc">
Monitor VPN connection status (WireGuard or OpenVPN). Show in bar and provide quick toggle.
</div>
<div class="task-detail">
<strong>What to monitor:</strong>
<ul>
<li><code>wg-quick</code> status (WireGuard)</li>
<li><code>openvpn</code> process status (OpenVPN)</li>
<li>Show connected/disconnected + connection name</li>
</ul>

<strong>Bar module:</strong>
<ul>
<li>Shows VPN status (icon + name)</li>
<li>Click to open VPN controls in Settings</li>
</ul>

<strong>Settings page:</strong>
<ul>
<li>List available VPN configs</li>
<li>Buttons to connect/disconnect</li>
<li>Show connection time and data transferred</li>
</ul>

<strong>Success criteria:</strong> VPN status shows accurately in bar. Quick toggle from Settings.
</div>
</div>

<div class="task">
<div class="task-title">2.5 CPU Temperature in Bar</div>
<div class="task-desc">
Show CPU temperature in the bar (only when hot, e.g., >70°C). We already read this in System window; just expose it in bar.
</div>
<div class="task-detail">
<strong>Behavior:</strong>
<ul>
<li>Monitor CPU temp via /sys/class/thermal or equivalent</li>
<li>Show in bar only if temp > 70°C (configurable threshold)</li>
<li>Display: icon + temp (e.g., 🌡️ 75°C)</li>
<li>Click to open System window</li>
</ul>

<strong>Success criteria:</strong> Temperature shows when high. Updates in real-time.
</div>
</div>

<div class="task">
<div class="task-title">2.6 Git Branch in Bar Title</div>
<div class="task-desc">
When a terminal is focused, show its git branch (if any) in the bar title instead of just "Terminal".
</div>
<div class="task-detail">
<strong>Implementation:</strong>
<ul>
<li>Read terminal's working directory (via /proc or terminal title)</li>
<li>Run <code>git -C &lt;dir&gt; branch --show-current</code> to get branch</li>
<li>Update bar title to show "Terminal • main" or similar</li>
<li>Refresh on focus or directory change</li>
</ul>

<strong>Success criteria:</strong> Terminal shows current git branch in bar when focused.
</div>
</div>

<div class="task">
<div class="task-title">2.7 Floating Window Grouping</div>
<div class="task-desc">
When 3+ floating windows are open, auto-organize them in a grid. Keybind to toggle between grid and cascade view.
</div>
<div class="task-detail">
<strong>Behavior:</strong>
<ul>
<li>Detect when N floating windows are open</li>
<li>Auto-tile them in a 2x2 or 2x3 grid</li>
<li>Super+Shift+G toggles between grid and cascade (free-floating)</li>
<li>Option: auto-grid only windows from same app</li>
</ul>

<strong>Success criteria:</strong> Multiple floating windows can be quickly organized. Grid view improves usability.
</div>
</div>

<div class="task">
<div class="task-title">2.8 Media Controls on Lock Screen</div>
<div class="task-desc">
Extend media player integration. Add next/prev/pause/play buttons to lock screen when media is playing.
</div>
<div class="task-detail">
<strong>What to add:</strong>
<ul>
<li>Read media player status from D-Bus (already done in Media module)</li>
<li>Show on lock screen: album art + title + artist + controls</li>
<li>Buttons: previous, play/pause, next</li>
<li>Optional: show album art as lock screen background</li>
</ul>

<strong>Success criteria:</strong> Media controls visible and functional on lock screen.
</div>
</div>

<div class="task">
<div class="task-title">2.9 System Tray with Context Menus</div>
<div class="task-desc">
Improve system tray. Right-click on icons to open context menus from their D-Bus service. Allow un-pinning apps.
</div>
<div class="task-detail">
<strong>Enhancements:</strong>
<ul>
<li>Fetch context menus from D-Bus StatusNotifierItem interface</li>
<li>Right-click shows menu (Quit, Settings, Open, etc.)</li>
<li>Left-click: primary action or open window</li>
<li>Allow dragging to reorder</li>
<li>Settings to pin/unpin apps from tray</li>
</ul>

<strong>Success criteria:</strong> Tray icons are more functional. Context menus work properly.
</div>
</div>

<div class="task">
<div class="task-title">2.10 Notification History Panel</div>
<div class="task-desc">
Sidebar showing last N notifications. Click to re-open or re-action them. Search by app or text.
</div>
<div class="task-detail">
<strong>Features:</strong>
<ul>
<li>Fetch notification history from swaync</li>
<li>Show last 20-50 notifications in a scrollable list</li>
<li>Display: app icon, title, timestamp, body preview</li>
<li>Click to re-trigger original action (if available)</li>
<li>Search bar to filter by app or text</li>
<li>Keybind (Super+N) to toggle history panel</li>
</ul>

<strong>Success criteria:</strong> Users can browse and re-act on past notifications.
</div>
</div>

<hr>

<h3>Priority Tier 3: Polish & Fun Features (Lower Priority)</h3>

<div class="task">
<div class="task-title">3.1 Weather Forecast in Lock Screen</div>
<div class="task-desc">
Show 3-day weather forecast on lock screen with color-coded icons (rainy=blue, sunny=yellow, etc.).
</div>
<div class="task-detail">
<strong>Implementation:</strong>
<ul>
<li>Fetch weather from free API (Open-Meteo, etc.)</li>
<li>Cache daily forecast</li>
<li>Display: temp, condition, icon on lock screen</li>
<li>Update once per day or on demand</li>
</ul>

<strong>Success criteria:</strong> Weather forecast appears on lock screen. Updates daily.
</div>
</div>

<div class="task">
<div class="task-title">3.2 System Uptime on Lock Screen</div>
<div class="task-desc">
Show uptime before login (useful for debugging crashes and understanding system stability).
</div>
<div class="task-detail">
<strong>What to display:</strong>
<ul>
<li>Read from <code>/proc/uptime</code></li>
<li>Format: "Uptime: 5d 12h 34m"</li>
<li>Show on lock screen above/below clock</li>
</ul>

<strong>Success criteria:</strong> Uptime visible on lock screen. Helpful for debugging.
</div>
</div>

<div class="task">
<div class="task-title">3.3 Quote or Daily Affirmation</div>
<div class="task-desc">
Fetch a quote or affirmation on startup. Display on lock screen or splash. Cache for offline use.
</div>
<div class="task-detail">
<strong>Implementation:</strong>
<ul>
<li>Fetch from free API (quotable.io, zenquotes.io)</li>
<li>Cache locally (expires daily)</li>
<li>Show on lock screen with author</li>
<li>Graceful fallback if offline</li>
</ul>

<strong>Success criteria:</strong> Quote displays on lock screen. Caching works.
</div>
</div>

<div class="task">
<div class="task-title">3.4 Focus Mode / Distraction-Free</div>
<div class="task-desc">
Hide all bar modules except clock and battery. Mute notifications. Hotkey to toggle. Auto-revert after N minutes or on window blur.
</div>
<div class="task-detail">
<strong>What happens in Focus Mode:</strong>
<ul>
<li>Hide all bar modules (volume, network, bluetooth, etc.)</li>
<li>Show only clock + battery</li>
<li>Mute all notifications except alarms</li>
<li>Dim screen slightly (optional)</li>
</ul>

<strong>Triggers & exit:</strong>
<ul>
<li>Keybind (Super+F) to toggle Focus Mode</li>
<li>Auto-exit after N minutes (configurable)</li>
<li>Auto-exit if window loses focus (optional)</li>
<li>Manually press Super+F again to exit immediately</li>
</ul>

<strong>Success criteria:</strong> Focus Mode works. Notifications are muted. Auto-exit works as configured.
</div>
</div>

<div class="task">
<div class="task-title">3.5 App Launcher Smart Search Ranking</div>
<div class="task-desc">
Rank app launcher results by recency, frequency, and user stars. Learn from usage patterns.
</div>
<div class="task-detail">
<strong>Ranking factors:</strong>
<ul>
<li>Frequency: how often launched (track in JSON)</li>
<li>Recency: recently launched apps come first</li>
<li>Starred: user can star favorite apps</li>
<li>Pattern matching: exact matches > prefix > substring</li>
</ul>

<strong>Implementation:</strong>
<ul>
<li>Track launches in <code>~/.local/state/singularity/app-stats.json</code></li>
<li>Update on each app launch (from launcher or direct command)</li>
<li>Rerank results on every keystroke</li>
</ul>

<strong>Success criteria:</strong> Frequently-used apps appear first in search results. Learning works.
</div>
</div>

<div class="task">
<div class="task-title">3.6 Workspace per Monitor (Dual Display Support)</div>
<div class="task-desc">
Currently all monitors share workspaces 1-5. Add option to isolate workspaces per display for multi-monitor setups.
</div>
<div class="task-detail">
<strong>Option in Display settings:</strong>
<ul>
<li>Shared workspaces (current default)</li>
<li>Per-monitor workspaces (each monitor gets 1-5)</li>
</ul>

<strong>Behavior when enabled:</strong>
<ul>
<li>Left monitor: workspaces 1-5</li>
<li>Right monitor: workspaces 6-10</li>
<li>Super+1 jumps to workspace 1 on active monitor</li>
<li>Super+6 jumps to workspace 6 on other monitor</li>
</ul>

<strong>Success criteria:</strong> Users can toggle per-monitor workspaces. Keybinds work correctly on each display.
</div>
</div>

<div class="task">
<div class="task-title">3.7 Custom Color Scheme Editor</div>
<div class="task-desc">
Graphical color picker for the grayscale ramp. Live preview on bar and flyouts. Export to theme file.
</div>
<div class="task-detail">
<strong>UI in Settings → Appearance:</strong>
<ul>
<li>Sliders or color pickers for each ramp color (base, surface, border, etc.)</li>
<li>Real-time preview on bar and a sample flyout</li>
<li>Preset themes (Dark, Light, High Contrast)</li>
<li>Export current theme to a JSON file</li>
<li>Import theme from file</li>
</ul>

<strong>Success criteria:</strong> Users can create and export custom themes. Preview updates live.
</div>
</div>

<div class="task">
<div class="task-title">3.8 Sound Visualizer Enhancements</div>
<div class="task-desc">
Improve the existing sound visualizer. Make it optional in Quick Actions. Add frequency bands. Optional beat-sync.
</div>
<div class="task-detail">
<strong>Enhancements:</strong>
<ul>
<li>Toggle visualizer visibility via Settings</li>
<li>Switch between spectrum (current) and frequency bands view</li>
<li>Optional beat-sync (if MPD or playerctl is available)</li>
<li>Adjustable sensitivity and color scheme</li>
</ul>

<strong>Success criteria:</strong> Visualizer is more customizable. Frequency bands work. Beat-sync is smooth.
</div>
</div>

<div class="task">
<div class="task-title">3.9 Keyboard Shortcuts Cheat Sheet</div>
<div class="task-desc">
Help menu (Super+?) listing all keybinds by category. Search by command name. Auto-update from hyprland.lua.
</div>
<div class="task-detail">
<strong>UI:</strong>
<ul>
<li>Popup window showing all binds organized by category</li>
<li>Search bar to filter by keybind or command name</li>
<li>Show action description alongside keybind</li>
<li>Copy keybind to clipboard on click</li>
</ul>

<strong>Data source:</strong>
<ul>
<li>Parse hyprland.lua to extract all binds and comments</li>
<li>Auto-update when hyprland.lua changes</li>
<li>No manual maintenance needed</li>
</ul>

<strong>Success criteria:</strong> Cheat sheet displays all binds. Search works. Updates when config changes.
</div>
</div>

<div class="task">
<div class="task-title">3.10 Bluetooth Connection Indicator</div>
<div class="task-desc">
When user clicks on a Bluetooth device, show visual feedback (highlight, loading spinner) indicating pairing/connection in progress.
</div>
<div class="task-detail">
<strong>Current state:</strong> Clicking a device seems to do nothing while connecting.
<br>
<strong>Improvement:</strong>
<ul>
<li>Show a loading spinner on the device while connecting</li>
<li>Highlight it with accent color</li>
<li>Show "Connecting..." status text</li>
<li>Update to "Connected" or "Failed" when done</li>
<li>Auto-dismiss status after 3 seconds on success</li>
</ul>

<strong>Success criteria:</strong> Users see feedback during Bluetooth connection process.
</div>
</div>

</div>

<hr>

<h2>🎯 Personal-Use Optimizations</h2>

<div class="section personal">

<div class="task">
<div class="task-title">1. Auto-Login & Auto-Start</div>
<div class="task-desc">
Skip password on boot and automatically launch preferred applications. Restore previous workspace layout on startup.
</div>
<div class="task-detail">
<strong>What to implement:</strong>
<ul>
<li>Configure auto-login in login manager (SDDM or similar)</li>
<li>Auto-launch Zen browser, terminal, editor on startup</li>
<li>Save current window layout before logout</li>
<li>Restore on next login (which windows, where)</li>
</ul>

<strong>Benefits:</strong> Boot to fully productive state without manual app launching.
<br><strong>Success criteria:</strong> System auto-logs in. Apps auto-launch. Workspace layout restores.
</div>
</div>

<div class="task">
<div class="task-title">2. Aggressive Performance Caching</div>
<div class="task-desc">
Cache expensive computations to disk to make shell startup faster and smoother.
</div>
<div class="task-detail">
<strong>What to cache:</strong>
<ul>
<li>Wallpaper color palette (recompute only if wallpaper changes)</li>
<li>Weather data (cache for 12 hours)</li>
<li>Monitor info and layout (cache, re-fetch on hotplug)</li>
<li>Icon theme and system fonts</li>
</ul>

<strong>Lazy-loading:</strong>
<ul>
<li>Load Settings pages on-demand, not all at startup</li>
<li>Preload only frequently-used singletons (Clock, Battery, Theme)</li>
</ul>

<strong>Success criteria:</strong> Shell startup is visibly faster. No noticeable lag when lazy-loading pages.
</div>
</div>

<div class="task">
<div class="task-title">3. Dev-Friendly Shortcuts</div>
<div class="task-desc">
Add personalized keybinds for common developer tasks. Requires integration with Hyprland config.
</div>
<div class="task-detail">
<strong>Suggested binds:</strong>
<ul>
<li><code>Super+Shift+E</code> → Open nvim with git root directory</li>
<li><code>Super+Shift+T</code> → New terminal in current directory</li>
<li><code>Super+Shift+F</code> → fzf file picker in current workspace (opens file in editor)</li>
<li><code>Super+Shift+G</code> → Jump to git repo (if focused window is in a git repo)</li>
</ul>

<strong>Implementation:</strong>
<ul>
<li>Add these binds to hyprland.lua keybinds section</li>
<li>Create wrapper scripts if needed</li>
<li>Use current window context to determine directory</li>
</ul>

<strong>Success criteria:</strong> All binds work. Focus on window in git repo and press binds to see effect.
</div>
</div>

<div class="task">
<div class="task-title">4. Auto-Save & Backup Everything</div>
<div class="task-desc">
Ensure no work is ever lost. Auto-save Settings on every change. Daily backups. Git sync of config.
</div>
<div class="task-detail">
<strong>What to implement:</strong>
<ul>
<li>Settings.json auto-saves on every UI change (already mostly done)</li>
<li>Daily backup: <code>cp Settings.json Settings.json.$(date +%Y%m%d).bak</code></li>
<li>Keep last 7 days of backups</li>
<li>Git hook: on hyprland.lua change, auto-commit with message "Update window config"</li>
<li>Optional: sync to remote git repo automatically</li>
</ul>

<strong>Success criteria:</strong> No lost settings. Can revert to previous version. Config changes are in git history.
</div>
</div>

<div class="task">
<div class="task-title">5. Personal Dashboard (Replace System Window)</div>
<div class="task-desc">
Replace the generic System window with a personal status board showing what matters to you.
</div>
<div class="task-detail">
<strong>Possible widgets:</strong>
<ul>
<li><strong>Calendar:</strong> upcoming events (if using a calendar tool)</li>
<li><strong>Todo list:</strong> tasks for today (if using todo app)</li>
<li><strong>RSS/News:</strong> top stories from Hacker News or subscribed feeds</li>
<li><strong>Git status:</strong> list dirty repos, open PRs, recent commits</li>
<li><strong>System stats:</strong> uptime, temp, disk usage, memory</li>
<li><strong>Quick stats:</strong> apps launched today, focus time, screen time</li>
</ul>

<strong>Customization:</strong>
<ul>
<li>User picks which widgets to show</li>
<li>Reorder by drag-and-drop</li>
<li>Configure refresh rates</li>
</ul>

<strong>Success criteria:</strong> Dashboard is useful and personalized to your workflow.
</div>
</div>

<div class="task">
<div class="task-title">6. Aggressive Personalization</div>
<div class="task-desc">
Adapt the shell appearance and behavior to time of day and usage patterns.
</div>
<div class="task-detail">
<strong>Time-based:</strong>
<ul>
<li>Different color scheme during work hours vs. evening (e.g., warmer tones at night)</li>
<li>Font size scales with time (smaller in morning, larger in evening)</li>
<li>Auto-enable Night Light at sunset (already planned above)</li>
<li>Auto-enable Focus Mode at night (already planned)</li>
</ul>

<strong>Usage-based:</strong>
<ul>
<li>Track idle time via Hyprland events</li>
<li>Auto-switch to "reading mode" after 5 min idle (larger fonts, lower contrast)</li>
<li>Return to normal mode on any activity</li>
</ul>

<strong>Success criteria:</strong> Shell feel adaptive and personalized to your daily rhythm.
</div>
</div>

</div>

<hr>

<h2>📊 Code Quality & Testing</h2>

<div class="section quality">

<div class="task">
<div class="task-title">1. QML Unit Tests</div>
<div class="task-desc">
Add comprehensive test suites for critical Lua and QML modules. Run in CI.
</div>
<div class="task-detail">
<strong>What to test:</strong>
<ul>
<li><code>HyprBinds.js</code> → 30+ test cases for bind parsing and conflict detection</li>
<li><code>HyprTables.js</code> → 20+ test cases for table manipulation</li>
<li><code>Services.qml</code> → tests for each service (mock DBus)</li>
<li><code>Constants.qml</code> → ensure all values are defined and reasonable</li>
</ul>

<strong>How to run:</strong>
<ul>
<li>Use Qt's qmltestrunner</li>
<li>Add test job to CI pipeline</li>
<li>Fail build if tests fail</li>
</ul>

<strong>Success criteria:</strong> 70%+ code coverage. All critical paths tested. CI enforces test suite.
</div>
</div>

<div class="task">
<div class="task-title">2. Error Logging & Debug Console</div>
<div class="task-desc">
Create a centralized debug logging system. Export logs for troubleshooting.
</div>
<div class="task-detail">
<strong>Create Debug.qml singleton with methods:</strong>
<ul>
<li><code>Debug.log(category, message, level)</code></li>
<li><code>Debug.warn(message)</code></li>
<li><code>Debug.error(message)</code></li>
</ul>

<strong>What to log:</strong>
<ul>
<li>All DBus operations (calls, responses, errors)</li>
<li>Settings changes and validation</li>
<li>Window events (map, close, focus)</li>
<li>Errors and exceptions</li>
</ul>

<strong>Output:</strong>
<ul>
<li>Write to <code>~/.local/state/singularity/debug.log</code></li>
<li>Rotate logs (keep last 7 days)</li>
<li>Add "Export Debug Logs" button in System window</li>
</ul>

<strong>Success criteria:</strong> Debug logs are comprehensive and helpful for troubleshooting. Export works.
</div>
</div>

<div class="task">
<div class="task-title">3. Settings Migrations</div>
<div class="task-desc">
Version Settings.json and auto-upgrade on load without losing data. Backup old settings before migrating.
</div>
<div class="task-detail">
<strong>Implementation:</strong>
<ul>
<li>Add version field: <code>"version": "1.0.0"</code> in Settings.json</li>
<li>On load, check version against current app version</li>
<li>If older, run migration script</li>
<li>Backup old file: <code>Settings.json.v1.0.0.backup</code></li>
<li>Migrate data and update version field</li>
</ul>

<strong>Example migration:</strong>
<ul>
<li>If old settings don't have "customQuickActions", initialize to empty array</li>
<li>If old settings have deprecated field X, move to field Y</li>
</ul>

<strong>Success criteria:</strong> Old settings upgrade without loss. Can rollback if needed.
</div>
</div>

<div class="task">
<div class="task-title">4. Keybind Validation at Boot</div>
<div class="task-desc">
Check for duplicate or conflicting keybinds. Warn in logs if found. Prevent accidental keybind collisions.
</div>
<div class="task-detail">
<strong>Validation checks:</strong>
<ul>
<li>No two binds use the same keybind (e.g., Super+1)</li>
<li>No conflicts with Hyprland reserved binds</li>
<li>All referenced commands exist (check for typos)</li>
<li>Keybinds are properly formatted</li>
</ul>

<strong>On conflict:</strong>
<ul>
<li>Log a warning with details</li>
<li>Disable the conflicting bind (or the newer one)</li>
<li>Show a warning in the bar's Keybinds window</li>
</ul>

<strong>Success criteria:</strong> Conflicts are detected and logged. User is informed. System doesn't crash.
</div>
</div>

</div>

<hr>

<h2>🔮 Wild Ideas (Very Low Priority)</h2>

<ul>
<li><strong>Gesture support</strong> — Swipe up = trigger Super, swipe left = workspace -1, etc. (requires touchpad firmware)</li>
<li><strong>Voice control</strong> — Super+V to launch voice-to-command (requires speech recognition setup)</li>
<li><strong>Ambient lighting</strong> — Sync keyboard RGB LEDs to wallpaper color (requires device support)</li>
<li><strong>Smart standby</strong> — Suspend when you leave (via motion sensor), wake on approach (requires hardware)</li>
<li><strong>Habit tracking</strong> — Track app usage patterns, suggest breaks, measure focus time</li>
<li><strong>Pomodoro timer</strong> — Integrated timer in bar, auto-mute notifications during focus sessions</li>
<li><strong>AI assistant</strong> — Voice or text search to launcher (integrate Claude API or local LLM)</li>
<li><strong>Game launcher</strong> — Quick-launch games, show achievements, track playtime</li>
</ul>

<hr>

<p><em>Last updated: 2026-09-17 — Document tracks planned work. Completed items are struck through, not deleted.</em></p>

</body>
</html>
