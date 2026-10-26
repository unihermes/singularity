// Singularity - Quickshell
// ~/.config/quickshell/services/SettingsIndex.js
//
// What Settings' search looks through: one entry per setting with its page
// and heading. Kept by hand (pages load lazily, so there's nothing to walk):
// a new SettingsField wants a line, `label` matching the field's exactly.
// `keywords` holds words the label lacks. An entry with no matching field
// just opens the page.

.pragma library

var entries = [
    // --- Network -----------------------------------------------------------
    { page: "network", section: "Status", label: "Status",     keywords: "wifi wi-fi wireless radio iwd on off ssid connected joined ethernet wired cable lan networkd" },
    { page: "network", section: "Status", label: "Interface",  keywords: "device wlan adapter" },
    { page: "network", section: "Status", label: "IP address", keywords: "ipv4 dhcp address copy" },
    { page: "network", section: "Status", label: "Gateway",    keywords: "router default route copy" },
    { page: "network", section: "Status", label: "MAC",        keywords: "hardware address ethernet copy" },
    { page: "network", section: "Status", label: "Speed",      keywords: "bitrate link rate mbit" },
    { page: "network", section: "Status", label: "Signal",     keywords: "strength dbm rssi band ghz" },
    { page: "network", section: "In range", label: "In range", keywords: "wifi scan rescan ssid connect join passphrase saved nearby other networks strength" },
    { page: "network", section: "In range", label: "Other network…", keywords: "hidden ssid connect join passphrase wifi" },
    { page: "network", section: "Saved", label: "Saved",       keywords: "known networks forget remove passphrase" },
    { page: "network", section: "Saved", label: "Auto-join",   keywords: "autoconnect automatic connect known network" },

    // --- Bluetooth ---------------------------------------------------------
    { page: "bluetooth", section: "Adapter",  label: "Adapter",      keywords: "bt radio bluez power on off rfkill name hci interface" },
    { page: "bluetooth", section: "Adapter",  label: "Discoverable", keywords: "visible advertise findable timeout" },
    { page: "bluetooth", section: "Adapter",  label: "Pairable",     keywords: "accept pairing requests" },
    { page: "bluetooth", section: "Paired",   label: "Paired",       keywords: "devices connect disconnect rename remove forget trusted address" },
    { page: "bluetooth", section: "Paired",   label: "Battery",      keywords: "level charge earbuds case left right percent" },
    { page: "bluetooth", section: "Paired",   label: "Reconnect by itself", keywords: "trusted auto connect automatic" },
    { page: "bluetooth", section: "In range", label: "In range",     keywords: "scan discover pair headphones mouse keyboard nearby unnamed" },

    // --- Power & Idle ------------------------------------------------------
    { page: "power", section: "Power", label: "Profile",       keywords: "performance balanced power saver battery ppd" },
    { page: "power", section: "Power", label: "Power",               keywords: "battery level percent charging health time left stop at resume below limit band" },
    { page: "power", section: "Power", label: "Charging",            keywords: "battery charge mode limit cap bios standard adaptive express custom threshold 80 percent" },
    { page: "power", section: "When idle", label: "Dim the screen",    keywords: "idle brightness timeout hypridle" },
    { page: "power", section: "When idle", label: "Lock",              keywords: "idle hyprlock timeout screen lock" },
    { page: "power", section: "When idle", label: "Turn screens off",  keywords: "idle dpms blank timeout" },
    { page: "power", section: "When idle", label: "Suspend",           keywords: "idle sleep timeout on battery plugged in charger unplugged ac" },
    { page: "power", section: "When idle", label: "Suspend on battery", keywords: "idle sleep timeout charger unplugged" },
    { page: "power", section: "When idle", label: "Hibernate",         keywords: "idle timeout" },

    // --- VPN ---------------------------------------------------------------
    { page: "vpn", section: "Connection", label: "VPN", keywords: "proton wireguard tunnel privacy connect" },
    { page: "vpn", section: "Connection", label: "Route everything", keywords: "full tunnel split all traffic dns" },
    { page: "vpn", section: "Connection", label: "Kill switch", keywords: "block leak drop firewall nftables" },
    { page: "vpn", section: "Connection", label: "Connect at login", keywords: "auto reconnect startup" },
    { page: "vpn", section: "Servers", label: "Import from Downloads", keywords: "proton wireguard conf file server add country p2p" },
    { page: "vpn", section: "qBittorrent", label: "Only over the VPN", keywords: "qbittorrent torrent bind interface leak" },
    { page: "vpn", section: "qBittorrent", label: "Forwarded port", keywords: "port forwarding nat-pmp natpmp seed listening" },

    // --- Devices -----------------------------------------------------------
    { page: "devices", section: "Phone", label: "Phone", keywords: "android adb scrcpy mirror screen screenshot usb debugging battery ring send file" },
    { page: "devices", section: "Phone", label: "Pair over Wi-Fi", keywords: "wireless debugging qr code adb pair wifi mirror" },
    { page: "devices", section: "Phone link", label: "Phone link", keywords: "kde connect notifications reply ring find my phone clipboard share send files battery pair unpair" },
    { page: "devices", section: "Phone link", label: "Look again", keywords: "kde connect discover refresh find phone network" },
    { page: "devices", section: "Headset", label: "Headset", keywords: "headsetcontrol arctis steelseries battery wireless" },
    { page: "devices", section: "Headset", label: "Sidetone", keywords: "headset mic monitoring hear own voice feedback" },
    { page: "devices", section: "Headset", label: "Microphone level", keywords: "headset mic gain volume input" },
    { page: "devices", section: "Headset", label: "Turn off when idle", keywords: "headset auto off inactive time sleep timeout" },
    { page: "devices", section: "Headset", label: "Mute light", keywords: "headset mic mute led brightness" },
    { page: "devices", section: "Headset", label: "Volume limiter", keywords: "headset loudness cap hearing" },
    { page: "devices", section: "Headset", label: "Bluetooth at power-on", keywords: "headset bt bluetooth on start" },
    { page: "devices", section: "Headset", label: "Lights", keywords: "headset leds rgb lighting" },
    { page: "devices", section: "Headset", label: "Voice prompts", keywords: "headset spoken announcements beeps" },
    { page: "devices", section: "Wireless", label: "Wireless", keywords: "peripherals mouse keyboard controller battery level low upower receiver" },
    { page: "devices", section: "Drives", label: "Drives", keywords: "usb stick disk sd card mount unmount eject open removable udisks" },
    { page: "devices", section: "USB", label: "USB", keywords: "devices plugged in peripherals webcam camera receiver hub speed vendor product id lsusb" },

    // --- Recording ---------------------------------------------------------
    { page: "recording", section: "Instant replay", label: "Instant replay", keywords: "clip shadowplay game save last minute buffer gpu-screen-recorder" },
    { page: "recording", section: "Instant replay", label: "Replay length",  keywords: "seconds minutes buffer memory ram clip" },
    { page: "recording", section: "Files", label: "Format",     keywords: "codec av1 h264 h.264 avc size quality compatibility nvenc" },
    { page: "recording", section: "Files", label: "Recordings", keywords: "screen record video folder videos mp4" },
    { page: "recording", section: "Files", label: "Replays",    keywords: "clips folder videos game mp4" },

    // --- Lock Screen -------------------------------------------------------
    { page: "lockscreen", section: "Background", label: "Background",   keywords: "hyprlock wallpaper screenshot plain image" },
    { page: "lockscreen", section: "Background", label: "Blur",         keywords: "hyprlock blur_passes background" },
    { page: "lockscreen", section: "Background", label: "Dim",          keywords: "hyprlock brightness darken background" },
    { page: "lockscreen", section: "Clock",    label: "Clock",        keywords: "hyprlock time 12 24 hour seconds date" },
    { page: "lockscreen", section: "Clock",    label: "Clock size",   keywords: "hyprlock clock big small huge font" },
    { page: "lockscreen", section: "Clock",    label: "Clock place",  keywords: "hyprlock clock position centre top corner" },
    { page: "lockscreen", section: "Clock",    label: "Under the clock", keywords: "hyprlock date media music notifications info line" },
    { page: "lockscreen", section: "Background", label: "Lock now",     keywords: "hyprlock preview test" },
    { page: "lockscreen", section: "Locking", label: "Grace period", keywords: "hyprlock grace delay password unlock idle" },
    { page: "lockscreen", section: "Fingerprint", label: "Unlock with a fingerprint", keywords: "hyprlock fprintd finger reader sensor biometric" },
    { page: "lockscreen", section: "Fingerprint", label: "Fingers", keywords: "fprintd enroll add remove delete finger thumb index hand" },
    { page: "lockscreen", section: "Locking",  label: "When the lid closes", keywords: "lid laptop close suspend sleep screen off lid.sh delay after minutes" },
    { page: "lockscreen", section: "Locking",  label: "Lock right away", keywords: "lid close lock immediately" },
    { page: "lockscreen", section: "Locking",  label: "Hibernate", keywords: "lid hibernate hibernation suspend-then-hibernate disk power off battery" },

    // --- Appearance --------------------------------------------------------
    { page: "notifications", section: "Popups", label: "Group by app",          keywords: "stack collapse same app count" },
    { page: "appearance", section: "Changes", label: "Save as default", keywords: "save baseline set default" },
    { page: "appearance", section: "Changes", label: "Reset", keywords: "revert reset to default" },
    { page: "appearance", section: "Changes", label: "Undo all", keywords: "changed modified customised customized differences undo revert" },
    { page: "appearance", section: "Changes", label: "Factory reset", keywords: "stock wipe" },
    { page: "appearance", section: "Theme", label: "Look", keywords: "theme colours colors palette preset arch nord dracula tokyo night catppuccin mocha one dark kanagawa singularity" },
    { page: "appearance", section: "Theme", label: "Style", keywords: "theme frames channel double solid glass flat lined modules windows 10 square taskbar" },
    { page: "appearance", section: "Theme", label: "Roundness", keywords: "rounding corners radius panels windows hyprland bar chips" },
    { page: "appearance", section: "Theme", label: "See-through", keywords: "opacity transparency translucent glass bar panels" },
    { page: "appearance", section: "Theme", label: "Shadows", keywords: "drop shadow depth hard soft finish windows" },
    { page: "appearance", section: "Theme", label: "Shaded grounds", keywords: "gradient shading bar panels finish" },
    { page: "appearance", section: "Theme", label: "Heavy lines", keywords: "stroke width border thickness outline finish" },
    { page: "appearance", section: "Theme", label: "Case", keywords: "headings titles caps capital uppercase title case" },
    { page: "appearance", section: "Theme", label: "Heading rule", keywords: "titles line divider" },
    { page: "appearance", section: "Theme", label: "Mark", keywords: "heading prefix slash // colons guillemet prompt terminal branch arrow bullet symbol accent bar brackets rule tab filled tag pill colour color accent grey" },
    { page: "appearance", section: "Theme", label: "Your mark", keywords: "heading prefix custom symbol characters" },
    { page: "appearance", section: "Theme", label: "Heading size", keywords: "headings titles larger smaller font" },
    { page: "appearance", section: "Theme", label: "Palette", keywords: "colour color grayscale wallpaper ramp roles base surface border text custom hex" },
    { page: "appearance", section: "Theme", label: "Intensity", keywords: "colour color saturation" },
    { page: "appearance", section: "Theme", label: "Shade", keywords: "light dark mode theme variant" },
    { page: "appearance", section: "Theme", label: "Accent", keywords: "colour color highlight hue" },
    { page: "appearance", section: "Theme", label: "Custom accent", keywords: "colour color hex rgb highlight" },
    { page: "appearance", section: "Theme", label: "Hue", keywords: "accent colour color picker wheel" },
    { page: "appearance", section: "Theme", label: "Lightness", keywords: "accent colour color picker light dark" },
    { page: "appearance", section: "Theme", label: "Text on the accent", keywords: "white dark contrast tab label foreground" },
    { page: "appearance", section: "Theme", label: "Level colour", keywords: "meters levels volume brightness battery fill green second accent" },
    { page: "appearance", section: "Theme", label: "Status", keywords: "good alert status colours colors" },
    { page: "appearance", section: "Theme", label: "Good", keywords: "status green charging success colour color" },
    { page: "appearance", section: "Theme", label: "Alert", keywords: "status red critical error warning colour color" },
    { page: "appearance", section: "Theme", label: "Density", keywords: "spacing padding compact roomy normal custom preset" },
    { page: "appearance", section: "Theme", label: "Spacing", keywords: "density gaps padding compact roomy percent" },
    { page: "appearance", section: "Theme", label: "Row height", keywords: "density rows lists fields compact roomy" },
    { page: "appearance", section: "Theme", label: "Font", keywords: "typeface family monospace shell bar" },
    { page: "appearance", section: "Theme", label: "Font size", keywords: "text scale px" },
    { page: "appearance", section: "Bar", label: "Position", keywords: "bar top bottom edge" },
    { page: "appearance", section: "Bar", label: "Centre anchor", keywords: "pin middle centre clock bar widgets" },
    { page: "appearance", section: "Bar", label: "Bar widgets", keywords: "arrange layout modules reset order hide show drag left centre right" },
    { page: "appearance", section: "Bar", label: "Bar shape", keywords: "bar layout full width floating islands" },
    { page: "appearance", section: "Bar", label: "Height", keywords: "bar height size tall thin px" },
    { page: "appearance", section: "Bar", label: "Icon size", keywords: "bar glyphs icons size px" },
    { page: "appearance", section: "Bar", label: "Module padding", keywords: "bar chips modules padding room px" },
    { page: "appearance", section: "Bar", label: "Chips", keywords: "modules frame outline outlined bare strip grouped border chip" },
    { page: "appearance", section: "Bar", label: "Separators", keywords: "divider between modules dots lines double stacked capped" },
    { page: "appearance", section: "Bar", label: "Control Centre icon", keywords: "button logo glyph arch menu home star cog dashboard" },
    { page: "appearance", section: "Bar", label: "Visualizer", keywords: "audio spectrum music bars cava" },
    { page: "appearance", section: "Bar", label: "Music visualizer", keywords: "spectrum bars cava music media module off" },
    { page: "appearance", section: "Bar", label: "Music title", keywords: "track song artist media module text" },
    { page: "appearance", section: "Bar", label: "Visualizer bars", keywords: "audio spectrum bands count cava" },
    { page: "appearance", section: "Bar", label: "Hide when silent", keywords: "visualizer music chip paused player" },
    { page: "appearance", section: "Bar", label: "Tray drawer", keywords: "system tray hide collapse chevron pin icons" },
    { page: "appearance", section: "Bar", label: "Hidden tray icons", keywords: "system tray hide remove unhide show app icons" },
    { page: "appearance", section: "Bar", label: "Workspaces", keywords: "indicator dots" },
    { page: "appearance", section: "Bar", label: "Workspace names", keywords: "label rename workspaces web code chat" },
    { page: "appearance", section: "Bar", label: "Open windows", keywords: "taskbar tasks apps icons titles tabs glide lift inset segmented spotlight index dots" },
    { page: "appearance", section: "Bar", label: "Windows shown", keywords: "taskbar workspace all scope" },
    { page: "appearance", section: "Bar", label: "App icons", keywords: "tint monochrome grey gray colour color accent tray" },
    { page: "appearance", section: "Bar", label: "Clock", keywords: "time date" },
    { page: "appearance", section: "Bar", label: "Clock format", keywords: "custom time date format pattern qt" },
    { page: "appearance", section: "Bar", label: "Clock island", keywords: "notch toast" },
    { page: "appearance", section: "Panels", label: "Flyouts open", keywords: "animation drop fade scale menu popup" },
    { page: "appearance", section: "Panels", label: "Flyout width", keywords: "flyouts menus wider narrower width percent" },
    { page: "appearance", section: "Panels", label: "Overlay dimming", keywords: "scrim dark backdrop" },
    { page: "appearance", section: "Panels", label: "Launcher layout", keywords: "launcher apps grid list dmenu spotlight" },
    { page: "appearance", section: "Panels", label: "Launcher position", keywords: "launcher centre top fullscreen dim" },
    { page: "appearance", section: "Panels", label: "Launcher details", keywords: "launcher description comment hints keys" },
    { page: "appearance", section: "Panels", label: "Rows shown", keywords: "launcher results rows count height" },
    { page: "appearance", section: "Panels", label: "Notification popups", keywords: "notifications cards compact banner style" },
    { page: "appearance", section: "Panels", label: "Popup width", keywords: "notifications popups wider narrower width px" },
    { page: "appearance", section: "Panels", label: "Window switcher", keywords: "alt tab switcher previews thumbnails icons titles" },
    { page: "appearance", section: "Panels", label: "Switcher windows", keywords: "alt tab switcher all workspaces every workspace current scope" },
    { page: "appearance", section: "Panels", label: "Workspace overview", keywords: "super w overview grid row strip expose" },
    { page: "appearance", section: "Panels", label: "Overview backdrop", keywords: "super w overview background dim solid clear" },
    { page: "appearance", section: "Panels", label: "Power menu", keywords: "power menu shutdown reboot logout tiles list fullscreen" },
    { page: "appearance", section: "Panels", label: "Level popup", keywords: "osd volume brightness popup toast edge number" },
    { page: "appearance", section: "Desktop", label: "Current", keywords: "wallpaper background image" },
    { page: "appearance", section: "Desktop", label: "New wallpaper", keywords: "wallpaper shuffle random login rotate slideshow interval timer" },
    { page: "appearance", section: "Desktop", label: "Fit", keywords: "wallpaper fill fit centre center tile scale swaybg" },
    { page: "appearance", section: "Desktop", label: "Folder", keywords: "wallpaper folder directory images open add" },
    { page: "appearance", section: "Desktop", label: "Colours from it", keywords: "wallpaper palette matugen colours colors use" },
    { page: "appearance", section: "Desktop", label: "Clock", keywords: "desktop widgets clock time date week wallpaper" },
    { page: "appearance", section: "Desktop", label: "Weather", keywords: "desktop widgets weather forecast temperature wallpaper" },
    { page: "appearance", section: "Desktop", label: "Now playing", keywords: "desktop widgets music media player spotify wallpaper" },
    { page: "appearance", section: "Desktop", label: "System", keywords: "desktop widgets stats cpu gpu ram memory temperature disk storage monitor wallpaper" },
    { page: "appearance", section: "Desktop", label: "System info", keywords: "desktop widgets fastfetch neofetch distro kernel uptime host ip packages cpu gpu hardware" },
    { page: "appearance", section: "Desktop", label: "Placement", keywords: "desktop widgets edit move drag place position size small medium large right-click menu sticky notes" },
    { page: "appearance", section: "Desktop", label: "Window gaps", keywords: "gaps_in between windows hyprland tiling" },
    { page: "appearance", section: "Desktop", label: "Edge gaps", keywords: "screen edges gaps_out hyprland bar floating islands margin inset" },
    { page: "appearance", section: "Desktop", label: "Border width", keywords: "window border thickness hyprland px" },
    { page: "appearance", section: "Desktop", label: "Focused border", keywords: "window active border colour color accent" },
    { page: "appearance", section: "Desktop", label: "Focused colour", keywords: "window active border custom hex" },
    { page: "appearance", section: "Desktop", label: "Unfocused border", keywords: "window inactive border colour color none" },
    { page: "appearance", section: "Desktop", label: "Unfocused colour", keywords: "window inactive border custom hex" },
    { page: "appearance", section: "Desktop", label: "Window corners", keywords: "rounding radius windows hyprland match" },
    { page: "appearance", section: "Desktop", label: "Window rounding", keywords: "radius corners px own" },
    { page: "appearance", section: "Desktop", label: "Focused opacity", keywords: "active_opacity transparency" },
    { page: "appearance", section: "Desktop", label: "Unfocused opacity", keywords: "inactive_opacity transparency" },
    { page: "appearance", section: "Desktop", label: "Dim unfocused", keywords: "dim_inactive" },
    { page: "appearance", section: "Desktop", label: "Dim strength", keywords: "dim_strength unfocused darken" },
    { page: "appearance", section: "Desktop", label: "Blur", keywords: "hyprland decoration" },
    { page: "appearance", section: "Desktop", label: "Blur size", keywords: "hyprland blur radius" },
    { page: "appearance", section: "Desktop", label: "Blur passes", keywords: "hyprland blur quality" },
    { page: "appearance", section: "Desktop", label: "Window shadow", keywords: "drop shadow windows hyprland size small large" },
    { page: "appearance", section: "Desktop", label: "Tab bar", keywords: "grouped windows tabs groupbar accent" },
    { page: "appearance", section: "Desktop", label: "Animations", keywords: "motion transitions speed" },
    { page: "appearance", section: "Desktop", label: "Per-part speeds…", keywords: "animation speed windows workspaces shell" },
    { page: "appearance", section: "Desktop", label: "Window speed", keywords: "animation speed windows open close hyprland" },
    { page: "appearance", section: "Desktop", label: "Workspace speed", keywords: "animation speed workspaces switch scratchpad" },
    { page: "appearance", section: "Desktop", label: "Shell speed", keywords: "animation speed flyouts shell hover" },
    { page: "appearance", section: "Desktop", label: "Window animation", keywords: "hyprland open close popin slide fade" },
    { page: "appearance", section: "Apps", label: "System font", keywords: "typeface family gtk qt apps interface ui" },
    { page: "appearance", section: "Apps", label: "Icons", keywords: "icon theme kora apps gtk qt" },
    { page: "appearance", section: "Apps", label: "Cursor", keywords: "pointer mouse theme bibata size px big" },

    // --- Window Rules ------------------------------------------------------
    { page: "windowrules", section: "Apps", label: "Apps",              keywords: "app class rules remembered sizes list" },
    { page: "windowrules", section: "Apps", label: "Add a rule…",       keywords: "app class pick running open now new" },
    { page: "windowrules", section: "Apps", label: "Name",              keywords: "alias rename label title" },
    { page: "windowrules", section: "Apps", label: "Opens",             keywords: "as left float tiled fullscreen fills maximise maximize on top pin always above" },
    { page: "windowrules", section: "Apps", label: "First time",        keywords: "own size filled fills default new" },
    { page: "windowrules", section: "Apps", label: "Last left",         keywords: "remembered size forget memory restore" },
    { page: "windowrules", section: "Apps", label: "Size",              keywords: "natural window dimensions custom percent pixels" },
    { page: "windowrules", section: "Apps", label: "Workspace",         keywords: "where it opens" },
    { page: "windowrules", section: "Popups and dialogs", label: "Block their window", keywords: "came from popup dialog modal block lock parent" },
    { page: "windowrules", section: "Popups and dialogs", label: "Open over it", keywords: "their window popup dialog centre center parent owner" },
    { page: "windowrules", section: "Popups and dialogs", label: "Remember sizes", keywords: "their popup dialog size memory" },
    { page: "windowrules", section: "Workspace layouts", label: "Workspace layouts", keywords: "dwindle monocle tiling pinned" },

    // --- Display -----------------------------------------------------------
    { page: "display", section: "",  label: "Arrangement",  keywords: "monitor position extend duplicate mirror drag order left right above below layout" },
    { page: "display", section: "",  label: "Primary",      keywords: "monitor main workspace 1" },
    { page: "display", section: "",  label: "Workspaces",   keywords: "monitor reset external workspace 1 2 dock" },
    { page: "display", section: "",  label: "Vibrance",     keywords: "digital vibrance saturation colour color vivid nvidia greyscale grayscale shader" },
    { page: "display", section: "",  label: "Variable refresh", keywords: "vrr gsync g-sync freesync adaptive sync tearing stutter games fullscreen" },
    { page: "display", section: "",  label: "Resolution",   keywords: "monitor native mode pixels" },
    { page: "display", section: "",  label: "Refresh rate", keywords: "monitor hz mode" },
    { page: "display", section: "",  label: "Scale",        keywords: "monitor hidpi fractional zoom size" },
    { page: "display", section: "",  label: "Rotation",     keywords: "monitor rotate transform portrait" },

    // --- Notifications -----------------------------------------------------
    { page: "notifications", section: "", label: "Status",                      keywords: "dnd do not disturb silence mute" },
    { page: "notifications", section: "Status", label: "History",               keywords: "clear all dismiss open panel centre center list" },
    { page: "notifications", section: "", label: "Apps",                        keywords: "per-app silent silence mute app popups" },
    { page: "notifications", section: "Status", label: "Quiet hours",     keywords: "schedule dnd do not disturb night automatic time" },
    { page: "notifications", section: "Status", label: "Starts",          keywords: "quiet hours schedule dnd from begin time" },
    { page: "notifications", section: "Status", label: "Ends",            keywords: "quiet hours schedule dnd until finish time" },
    { page: "notifications", section: "Popups", label: "Position",              keywords: "corner where popups appear" },
    { page: "notifications", section: "Popups", label: "Normal",  keywords: "how long timeout duration" },
    { page: "notifications", section: "Popups", label: "Low", keywords: "low priority how long timeout duration" },
    { page: "notifications", section: "Popups", label: "Critical", keywords: "how long timeout duration urgent" },

    // --- Audio -------------------------------------------------------------
    { page: "audio", section: "Output", label: "Volume",    keywords: "level loudness mute silence speakers microphone mic off" },
    { page: "audio", section: "Output", label: "Output",    keywords: "default sink speakers headphones hdmi displayport device" },
    { page: "audio", section: "Input",  label: "Input",     keywords: "default source microphone mic device" },
    { page: "audio", section: "Channels", label: "Channels", keywords: "game chat media virtual sinks sonar outputs mix" },
    { page: "audio", section: "Channels", label: "ChatMix",  keywords: "dial balance game chat headset steelseries arctis sonar" },
    // the bands' labels come from Channels.eq; this names their heading
    { page: "audio", section: "", label: "Equalizer", keywords: "eq bass treble mids footsteps voice clarity game chat media tone sound" },
    // the mixer's rows have no fixed label; these name their heading
    { page: "audio", section: "", label: "Playing",   keywords: "mixer per app volume application stream" },
    { page: "audio", section: "", label: "Recording", keywords: "mixer capture app stream microphone" },

    // --- Startup -----------------------------------------------------------
    { page: "autostart", section: "When the PC starts", label: "Start", keywords: "boot default os operating system windows linux arch dual systemd-boot bootloader grub entry" },
    { page: "autostart", section: "When the PC starts", label: "Restart into", keywords: "reboot restart windows bios uefi firmware setup once boot" },
    { page: "autostart", section: "When the PC starts", label: "Sign in at boot", keywords: "autologin auto login password greeter ly boot skip sign in" },
    { page: "autostart", section: "At login", label: "At login",     keywords: "autostart startup login run launch desktop entry" },
    { page: "autostart", section: "At login", label: "Add an app…",  keywords: "autostart add app application start login" },
    { page: "autostart", section: "At login", label: "From packages", keywords: "xdg autostart system installed entry keyring" },

    // --- File Types --------------------------------------------------------
    { page: "filetypes", section: "Common", label: "Web browser",  keywords: "default http https url link mimeapps" },
    { page: "filetypes", section: "Common", label: "File manager", keywords: "default folder directory mimeapps" },
    { page: "filetypes", section: "Common", label: "Text",         keywords: "default editor plain markdown mimeapps" },
    { page: "filetypes", section: "Common", label: "PDF",          keywords: "default viewer mimeapps" },
    { page: "filetypes", section: "Common", label: "Images",       keywords: "default viewer png jpeg mimeapps" },
    { page: "filetypes", section: "Common", label: "Video",        keywords: "default player mp4 mkv mimeapps" },
    { page: "filetypes", section: "Common", label: "Audio",        keywords: "default player mp3 flac mimeapps" },
    { page: "filetypes", section: "Common", label: "Archives",     keywords: "default zip tar mimeapps" },
    { page: "filetypes", section: "Common", label: "Email links",  keywords: "default mailto mimeapps" },

    // --- Terminal ----------------------------------------------------------
    { page: "shell", section: "Terminal", label: "Terminal", keywords: "alacritty ghostty default emulator app" },
    { page: "shell", section: "Terminal", label: "Font size",  keywords: "terminal alacritty ghostty points" },
    { page: "shell", section: "Terminal", label: "Opacity",    keywords: "terminal alacritty ghostty transparency background" },
    { page: "shell", section: "Terminal", label: "Cursor",     keywords: "terminal alacritty ghostty block beam underline shape blink blinking" },
    { page: "shell", section: "Bash aliases", label: "Bash aliases", keywords: "bashrc bash_aliases shortcut command" },
    { page: "shell", section: "Bash aliases", label: "Add an alias…", keywords: "bashrc bash_aliases new shortcut command" },

    // --- Date & Time -------------------------------------------------------
    { page: "datetime", section: "Time zone", label: "Time zone",    keywords: "timezone tz city country region location clock current time utc offset timedatectl network time ntp set automatically sync timesyncd" },
    { page: "datetime", section: "Clock and calendar", label: "Hour format", keywords: "12 24 hour am pm clock" },
    { page: "datetime", section: "Clock and calendar", label: "First day of the week", keywords: "calendar monday sunday saturday week start" },

    // --- Software Update ---------------------------------------------------
    { page: "updates", section: "Status",   label: "Status",            keywords: "update now check now last checked last upgrade pacman log syu upgraded" },
    { page: "updates", section: "Status", label: "Repository",     keywords: "singularity git pull commits behind dotfiles clone self update update.sh link.sh new packages" },
    { page: "updates", section: "Status", label: "Check for updates", keywords: "update interval how often pacman checkupdates schedule next check" },
    { page: "updates", section: "Status", label: "Include the AUR",   keywords: "aur yay packages" },
    { page: "updates", section: "Packages", label: "Packages",          keywords: "pending updates available upgrade now yay versions" },
    { page: "updates", section: "Packages", label: "Ignored",           keywords: "ignorepkg hold skip held back ignore a package" },
    { page: "updates", section: "Packages", label: "Remove",            keywords: "uninstall remove a package delete pacman aur yay installed programs apps" },
    { page: "updates", section: "Upkeep",   label: "Orphaned packages", keywords: "orphans unused dependencies pacman maintenance" },
    { page: "updates", section: "Upkeep",   label: "Reclaimable space", keywords: "cache clean up disk space paccache maintenance" },

    // --- Input -------------------------------------------------------------
    { page: "input", section: "Keyboard", label: "Keyboard",          keywords: "layout xkb language us de variant colemak dvorak add a layout" },
    { page: "input", section: "Keyboard", label: "Switch layouts with", keywords: "xkb grp toggle alt shift super space" },
    { page: "input", section: "Keyboard", label: "Caps Lock key",     keywords: "xkb options caps escape ctrl remap" },
    { page: "input", section: "Keyboard", label: "Compose key",       keywords: "xkb accents dead keys alt" },
    { page: "input", section: "Keyboard", label: "Other XKB options", keywords: "xkb options kb_options" },
    { page: "input", section: "Keyboard", label: "Repeat delay",      keywords: "key held repeat" },
    { page: "input", section: "Keyboard", label: "Repeat rate",       keywords: "key held repeat" },
    { page: "input", section: "Keyboard", label: "Try it",            keywords: "key repeat test" },
    { page: "input", section: "Keyboard", label: "Num Lock on at login", keywords: "numlock numpad" },
    { page: "input", section: "Keyboard", label: "Advanced…",         keywords: "xkb options more" },
    { page: "input", section: "Mouse", label: "Pointer speed",        keywords: "sensitivity mouse speed" },
    { page: "input", section: "Mouse", label: "Acceleration",         keywords: "accel flat adaptive pointer" },
    { page: "input", section: "Mouse", label: "Focus follows mouse",  keywords: "sloppy focus hover click" },
    { page: "input", section: "Mouse", label: "Left-handed",          keywords: "buttons swap" },
    { page: "input", section: "Touchpad", label: "Tap to click",      keywords: "trackpad" },
    { page: "input", section: "Touchpad", label: "Click by finger count", keywords: "trackpad right middle" },
    { page: "input", section: "Touchpad", label: "Drag lock",         keywords: "trackpad" },
    { page: "input", section: "Touchpad", label: "Middle-click emulation", keywords: "trackpad paste" },
    { page: "input", section: "Touchpad", label: "Scroll speed",      keywords: "trackpad two finger scroll factor" },
    { page: "input", section: "Touchpad", label: "Natural scrolling", keywords: "trackpad reverse invert" },
    { page: "input", section: "Touchpad", label: "Disable while typing", keywords: "trackpad dwt palm" },

    // --- Keybinds ----------------------------------------------------------
    { page: "keybinds", section: "", label: "Keybinds", keywords: "shortcuts keys bindings super hotkey presets" },
]

// every entry with its page's name folded in, plus one per page; `pages` is
// the Settings window's own list
function build(pages) {
    var byId = {}
    var out = []
    for (var i = 0; i < pages.length; i++) {
        var pg = pages[i]
        byId[pg.id] = { page: pg }
        out.push({
            page: pg.id,
            pageLabel: pg.label,
            icon: pg.icon,
            section: "",
            label: pg.label,
            isPage: true,
            haystack: (pg.label + " " + (pg.blurb || "")).toLowerCase(),
        })
    }
    for (var j = 0; j < entries.length; j++) {
        var e = entries[j], p = byId[e.page]
        if (!p) continue
        out.push({
            page: e.page,
            pageLabel: p.page.label,
            icon: p.page.icon,
            section: e.section,
            label: e.label,
            isPage: false,
            haystack: (e.label + " " + e.section + " " + p.page.label + " " + (e.keywords || "")).toLowerCase(),
        })
    }
    return out
}

// every query word must appear; ranked by the best score against the label
function score(entry, words) {
    var label = entry.label.toLowerCase()
    var best = 0
    for (var i = 0; i < words.length; i++) {
        var w = words[i]
        if (entry.haystack.indexOf(w) < 0) return 0
        var at = label.indexOf(w)
        var here = at === 0 ? 4
            : at > 0 && label.charAt(at - 1) === " " ? 3
            : at > 0 ? 2
            : 1
        if (here > best) best = here
    }
    return best
}

function search(index, query, limit) {
    var words = query.toLowerCase().split(/\s+/).filter(w => w !== "")
    if (words.length === 0) return []
    var hits = []
    for (var i = 0; i < index.length; i++) {
        var s = score(index[i], words)
        // the original order breaks ties, so a page's settings stay in the
        // order they appear on it
        if (s > 0) hits.push({ entry: index[i], score: s, at: i })
    }
    hits.sort((a, b) => b.score - a.score || a.at - b.at)
    return hits.slice(0, limit || 12).map(h => h.entry)
}
