// Singularity - Quickshell
// ~/.config/quickshell/services/SettingsIndex.js
//
// What the Settings window's search box (/) looks through: one entry per
// setting, naming the page it lives on and the heading it sits under.
//
// A written list rather than something read off the pages: only the open
// page exists at any moment -- the others are a Loader away and several run
// commands or read config the instant they load -- so there is nothing to
// walk. The cost is that this has to be kept in step by hand: a new
// SettingsField wants a line here, and `label` must match the field's own
// label exactly, since that string is what the page highlights and scrolls
// to when a result is picked.
//
// `keywords` is for the words someone would type that the label doesn't
// contain (the old name for a thing, the tool behind it, the unit).
// Entries without a matching field -- a whole section, a page's list --
// still work: the result opens the page and nothing is highlighted.

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
    { page: "network", section: "Saved nearby", label: "Saved nearby", keywords: "wifi scan rescan ssid connect join passphrase" },
    { page: "network", section: "Other networks", label: "Other network…", keywords: "hidden ssid connect join passphrase wifi" },
    { page: "network", section: "Saved", label: "Saved",       keywords: "known networks forget remove passphrase" },
    { page: "network", section: "Saved", label: "Auto-join",   keywords: "autoconnect automatic connect known network" },

    // --- Bluetooth ---------------------------------------------------------
    { page: "bluetooth", section: "Adapter",  label: "Adapter",      keywords: "bt radio bluez power on off rfkill name hci interface" },
    { page: "bluetooth", section: "Adapter",  label: "Discoverable", keywords: "visible advertise findable timeout" },
    { page: "bluetooth", section: "Adapter",  label: "Pairable",     keywords: "accept pairing requests" },
    { page: "bluetooth", section: "Paired",   label: "Paired",       keywords: "devices connect disconnect rename remove forget battery trusted reconnect" },
    { page: "bluetooth", section: "In range", label: "In range",     keywords: "scan discover pair headphones mouse keyboard nearby unnamed" },

    // --- Power & Idle ------------------------------------------------------
    { page: "power", section: "Power profile", label: "Profile",       keywords: "performance balanced power saver battery ppd" },
    { page: "power", section: "Battery", label: "Battery",             keywords: "battery level percent charging health time left stop at resume below limit band" },
    { page: "power", section: "Battery", label: "Charging",            keywords: "battery charge mode limit cap bios standard adaptive express custom threshold 80 percent" },
    { page: "power", section: "When idle", label: "Dim the screen",    keywords: "idle brightness timeout hypridle" },
    { page: "power", section: "When idle", label: "Lock",              keywords: "idle hyprlock timeout screen lock" },
    { page: "power", section: "When idle", label: "Turn screens off",  keywords: "idle dpms blank timeout" },
    { page: "power", section: "When idle", label: "Suspend",           keywords: "idle sleep timeout" },
    { page: "power", section: "When idle", label: "Suspend on battery", keywords: "idle sleep timeout charger unplugged" },
    { page: "power", section: "When idle", label: "Suspend plugged in", keywords: "idle sleep timeout charger ac" },
    { page: "power", section: "When idle", label: "Hibernate",         keywords: "idle timeout" },

    // --- Lock Screen -------------------------------------------------------
    { page: "lockscreen", section: "Background", label: "Background",   keywords: "hyprlock wallpaper screenshot plain image" },
    { page: "lockscreen", section: "Background", label: "Blur",         keywords: "hyprlock blur_passes background" },
    { page: "lockscreen", section: "Background", label: "Dim",          keywords: "hyprlock brightness darken background" },
    { page: "lockscreen", section: "Clock",    label: "Clock",        keywords: "hyprlock time 12 24 hour seconds date" },
    { page: "lockscreen", section: "Clock",    label: "Clock size",   keywords: "hyprlock clock big small huge font" },
    { page: "lockscreen", section: "Clock",    label: "Clock place",  keywords: "hyprlock clock position centre top corner" },
    { page: "lockscreen", section: "Clock",    label: "Under the clock", keywords: "hyprlock date media music notifications info line" },
    { page: "lockscreen", section: "Clock",    label: "Lock now",     keywords: "hyprlock preview test" },
    { page: "lockscreen", section: "Password", label: "Grace period", keywords: "hyprlock grace delay password unlock idle" },
    { page: "lockscreen", section: "Lid",      label: "When the lid closes", keywords: "lid laptop close suspend sleep screen off lid.sh delay after minutes" },
    { page: "lockscreen", section: "Lid",      label: "Lock right away", keywords: "lid close lock immediately" },
    { page: "lockscreen", section: "Lid",      label: "Hibernate", keywords: "lid hibernate hibernation suspend-then-hibernate disk power off battery" },

    // --- Appearance --------------------------------------------------------
    { page: "appearance", section: "Look",          label: "Look",                 keywords: "theme preset style" },
    { page: "appearance", section: "Look",          label: "Changes",              keywords: "changed modified customised customized differences undo revert" },
    { page: "appearance", section: "Look",          label: "Reset look",           keywords: "revert default" },
    { page: "appearance", section: "Look",          label: "Current",              keywords: "wallpaper background image" },
    { page: "appearance", section: "Look",          label: "One per look",         keywords: "wallpaper look theme remember pair background" },
    { page: "appearance", section: "Look",          label: "New wallpaper",        keywords: "wallpaper shuffle random login rotate slideshow interval timer" },
    { page: "appearance", section: "Colours",       label: "Palette",              keywords: "colour color grayscale wallpaper" },
    { page: "appearance", section: "Colours",       label: "Intensity",            keywords: "colour color saturation" },
    { page: "appearance", section: "Colours",       label: "Shade",                keywords: "light dark mode theme variant" },
    { page: "appearance", section: "Colours",       label: "Accent",               keywords: "colour color highlight hue" },
    { page: "appearance", section: "Colours",       label: "Custom accent",        keywords: "colour color hex rgb highlight" },
    { page: "appearance", section: "Colours",       label: "Level colour",         keywords: "meters levels volume brightness battery fill green second accent" },
    { page: "appearance", section: "Style",         label: "Style",                keywords: "theme frames channel lined flat retro minimal basic capsule glass tabbed terminal modules" },
    { page: "appearance", section: "Style",         label: "Roundness",            keywords: "rounding corners radius panels windows hyprland bar chips" },
    { page: "appearance", section: "Style",         label: "Bar shape",            keywords: "bar layout full width floating islands" },
    { page: "appearance", section: "Style",         label: "See-through",          keywords: "opacity transparency translucent glass bar panels" },
    { page: "appearance", section: "Style",         label: "Shaded grounds",       keywords: "gradient shading bar panels finish" },
    { page: "appearance", section: "Style",         label: "Heavy lines",          keywords: "stroke width border thickness outline finish" },
    { page: "appearance", section: "Style",         label: "Capital headings",     keywords: "titles caps uppercase case" },
    { page: "appearance", section: "Style",         label: "Heading rule",         keywords: "titles line divider" },
    { page: "appearance", section: "Style",         label: "Density",              keywords: "spacing padding compact" },
    { page: "appearance", section: "Style",         label: "Overlay dimming",      keywords: "scrim dark backdrop" },
    { page: "appearance", section: "Style", label: "Font",                keywords: "typeface family monospace shell bar" },
    { page: "appearance", section: "Style", label: "Font size",            keywords: "text scale px" },
    { page: "appearance", section: "System", label: "Animations",           keywords: "motion transitions speed" },
    { page: "appearance", section: "Bar",           label: "Position",             keywords: "bar top bottom edge" },
    { page: "appearance", section: "Bar",           label: "Workspaces",           keywords: "indicator dots" },
    { page: "appearance", section: "Bar",           label: "Clock",                keywords: "time date" },
    { page: "appearance", section: "Style",         label: "Shadows",              keywords: "drop shadow depth hard soft finish windows" },
    { page: "appearance", section: "Panels",        label: "Level popup",          keywords: "osd volume brightness popup toast edge number" },
    { page: "appearance", section: "Panels",        label: "Power menu",           keywords: "power menu shutdown reboot logout tiles list fullscreen" },
    { page: "appearance", section: "Panels",        label: "Overview backdrop",    keywords: "super w overview background dim solid clear" },
    { page: "appearance", section: "Panels",        label: "Workspace overview",   keywords: "super w overview grid row strip expose" },
    { page: "appearance", section: "Panels",        label: "Window switcher",      keywords: "alt tab switcher previews thumbnails icons titles" },
    { page: "appearance", section: "Panels",        label: "Switcher windows",     keywords: "alt tab switcher all workspaces every workspace current scope" },
    { page: "appearance", section: "Bar",           label: "Clock format",         keywords: "custom time date format pattern qt" },
    { page: "appearance", section: "Bar",           label: "Tray drawer",          keywords: "system tray hide collapse chevron pin icons" },
    { page: "appearance", section: "Bar",           label: "Workspace names",      keywords: "label rename workspaces web code chat" },
    { page: "appearance", section: "Style",         label: "Separators",           keywords: "divider between modules dots lines double stacked capped" },
    { page: "notifications", section: "Popups", label: "Group by app",          keywords: "stack collapse same app count" },
    { page: "appearance", section: "Panels",        label: "Notification popups",  keywords: "notifications cards compact banner style" },
    { page: "appearance", section: "Panels",        label: "Launcher details",     keywords: "launcher description comment hints keys" },
    { page: "appearance", section: "Panels",        label: "Launcher position",    keywords: "launcher centre top fullscreen dim" },
    { page: "appearance", section: "Panels",        label: "Launcher layout",      keywords: "launcher apps grid list dmenu spotlight" },
    { page: "appearance", section: "System",        label: "Flyouts open",         keywords: "animation drop fade scale menu popup" },
    { page: "appearance", section: "Bar",           label: "Control Centre icon",  keywords: "button logo glyph arch menu home star cog dashboard" },
    { page: "appearance", section: "Bar",           label: "Visualizer",           keywords: "audio spectrum music bars cava" },
    { page: "appearance", section: "Bar",           label: "Open windows",         keywords: "taskbar tasks apps icons titles tabs glide lift inset segmented spotlight index dots" },
    { page: "appearance", section: "Bar",           label: "Windows shown",        keywords: "taskbar workspace all scope" },
    { page: "appearance", section: "Bar",           label: "App icons",            keywords: "tint monochrome grey gray colour color accent tray" },
    { page: "appearance", section: "Bar",           label: "Clock island",         keywords: "notch toast" },
    { page: "appearance", section: "System",        label: "System font",          keywords: "typeface family gtk qt apps interface ui" },
    { page: "appearance", section: "System",        label: "Icons",                keywords: "icon theme kora apps gtk qt" },
    { page: "appearance", section: "System",        label: "Cursor",               keywords: "pointer mouse theme bibata" },
    { page: "appearance", section: "System",        label: "Cursor size",          keywords: "pointer mouse px big" },
    { page: "appearance", section: "Windows",       label: "Gaps between windows", keywords: "gaps_in hyprland tiling" },
    { page: "appearance", section: "Windows",       label: "Gaps at screen edges", keywords: "gaps_out hyprland bar floating islands margin inset" },
    { page: "appearance", section: "Windows",       label: "Focused opacity",      keywords: "active_opacity transparency" },
    { page: "appearance", section: "Windows",       label: "Unfocused opacity",    keywords: "inactive_opacity transparency" },
    { page: "appearance", section: "Windows",       label: "Terminal opacity",     keywords: "alacritty transparency background" },
    { page: "appearance", section: "Windows",       label: "Dim unfocused",        keywords: "dim_inactive" },
    { page: "appearance", section: "Windows",       label: "Blur",                 keywords: "hyprland decoration" },
    { page: "appearance", section: "Windows",       label: "Dim strength",         keywords: "dim_strength unfocused darken" },
    { page: "appearance", section: "Windows",       label: "Blur size",            keywords: "hyprland blur radius" },
    { page: "appearance", section: "Windows",       label: "Blur passes",          keywords: "hyprland blur quality" },
    { page: "appearance", section: "System",       label: "Window animation",     keywords: "hyprland open close popin slide fade" },
    { page: "appearance", section: "Look",       label: "Set as default",       keywords: "save baseline" },
    { page: "appearance", section: "Look",       label: "Reset to default",     keywords: "revert" },
    { page: "appearance", section: "Look",       label: "Factory reset",        keywords: "stock wipe" },

    // --- Window Rules ------------------------------------------------------
    { page: "windowrules", section: "Rules", label: "Rules",             keywords: "app class float add new order drag reorder priority" },
    { page: "windowrules", section: "Rules", label: "Add a rule…",       keywords: "app class pick running open now new" },
    { page: "windowrules", section: "Rules", label: "Name",              keywords: "alias rename label title" },
    { page: "windowrules", section: "Rules", label: "Opens as",          keywords: "float tiled fullscreen maximise maximize on top pin always above" },
    { page: "windowrules", section: "Rules", label: "Size",              keywords: "natural window dimensions custom percent pixels" },
    { page: "windowrules", section: "Rules", label: "Workspace",         keywords: "where it opens" },
    { page: "windowrules", section: "Workspace layouts", label: "Workspace layouts", keywords: "dwindle monocle tiling pinned" },

    // --- Display -----------------------------------------------------------
    { page: "display", section: "",  label: "Arrangement",  keywords: "monitor position extend duplicate mirror drag order left right above below layout" },
    { page: "display", section: "",  label: "Primary",      keywords: "monitor main workspace 1" },
    { page: "display", section: "",  label: "Workspaces",   keywords: "monitor reset external workspace 1 2 dock" },
    { page: "display", section: "",  label: "Displays",     keywords: "monitor resolution refresh rate hz scale hidpi fractional rotation rotate transform portrait mode" },

    // --- Notifications -----------------------------------------------------
    { page: "notifications", section: "", label: "Status",                      keywords: "dnd do not disturb silence mute" },
    { page: "notifications", section: "Status", label: "History",               keywords: "clear all dismiss open panel centre center list" },
    { page: "notifications", section: "", label: "Apps",                        keywords: "per-app silent silence mute app popups" },
    { page: "notifications", section: "Quiet hours", label: "Quiet hours",     keywords: "schedule dnd do not disturb night automatic time" },
    { page: "notifications", section: "Quiet hours", label: "Starts",          keywords: "quiet hours schedule dnd from begin time" },
    { page: "notifications", section: "Quiet hours", label: "Ends",            keywords: "quiet hours schedule dnd until finish time" },
    { page: "notifications", section: "Popups", label: "Position",              keywords: "corner where popups appear" },
    { page: "notifications", section: "How long popups stay", label: "Normal",  keywords: "timeout duration" },
    { page: "notifications", section: "How long popups stay", label: "Low priority", keywords: "timeout duration" },
    { page: "notifications", section: "How long popups stay", label: "Critical", keywords: "timeout duration urgent" },

    // --- Audio -------------------------------------------------------------
    { page: "audio", section: "Output", label: "Volume",    keywords: "level loudness mute speakers" },
    { page: "audio", section: "Output", label: "Mute",      keywords: "silence speakers microphone mic off" },
    { page: "audio", section: "Output", label: "Output",    keywords: "default sink speakers headphones hdmi displayport device" },
    { page: "audio", section: "Input",  label: "Input",     keywords: "default source microphone mic device" },
    // The mixer's rows are named after whatever happens to be running, so
    // there is no fixed field label to point at. These name their heading
    // instead: the result opens the page, and highlights nothing.
    { page: "audio", section: "", label: "Playing",   keywords: "mixer per app volume application stream" },
    { page: "audio", section: "", label: "Recording", keywords: "mixer capture app stream microphone" },

    // --- Startup -----------------------------------------------------------
    { page: "autostart", section: "When the PC starts", label: "Start", keywords: "boot default os operating system windows linux arch dual systemd-boot bootloader grub entry" },
    { page: "autostart", section: "When the PC starts", label: "Restart into", keywords: "reboot restart windows bios uefi firmware setup once boot" },
    { page: "autostart", section: "When the PC starts", label: "Sign in at boot", keywords: "autologin auto login password greeter ly boot skip sign in" },
    { page: "autostart", section: "At login", label: "At login",     keywords: "autostart startup login run launch desktop entry" },
    { page: "autostart", section: "At login", label: "Add an app…",  keywords: "autostart add app application start login" },
    { page: "autostart", section: "Packages", label: "From packages", keywords: "xdg autostart system installed entry keyring" },

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
    { page: "shell", section: "Alacritty", label: "Font size",  keywords: "terminal points" },
    { page: "shell", section: "Alacritty", label: "Opacity",    keywords: "terminal transparency background" },
    { page: "shell", section: "Alacritty", label: "Cursor",     keywords: "terminal block beam underline shape" },
    { page: "shell", section: "Alacritty", label: "Blinking", keywords: "terminal cursor blink" },
    { page: "shell", section: "Bash aliases", label: "Bash aliases", keywords: "bashrc bash_aliases shortcut command" },
    { page: "shell", section: "Bash aliases", label: "Add an alias…", keywords: "bashrc bash_aliases new shortcut command" },

    // --- Date & Time -------------------------------------------------------
    { page: "datetime", section: "Time zone", label: "Time zone",    keywords: "timezone tz city country region location clock current time utc offset timedatectl" },
    { page: "datetime", section: "Time zone", label: "Network time", keywords: "ntp set time automatically sync timesyncd" },
    { page: "datetime", section: "Clock and calendar", label: "Hour format", keywords: "12 24 hour am pm clock" },
    { page: "datetime", section: "Clock and calendar", label: "First day of the week", keywords: "calendar monday sunday saturday week start" },

    // --- Software Update ---------------------------------------------------
    { page: "updates", section: "Status",   label: "Status",            keywords: "update now check now last checked last upgrade pacman log syu upgraded" },
    { page: "updates", section: "Singularity", label: "Repository",     keywords: "singularity git pull commits behind dotfiles clone self update update.sh link.sh new packages" },
    { page: "updates", section: "Checking", label: "Check for updates", keywords: "update interval how often pacman checkupdates schedule next check" },
    { page: "updates", section: "Checking", label: "Include the AUR",   keywords: "aur yay packages" },
    { page: "updates", section: "Pending",  label: "Pending",           keywords: "updates available upgrade now yay versions" },
    { page: "updates", section: "Ignored",  label: "Ignored",           keywords: "ignorepkg hold skip held back ignore a package" },
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

// Every entry, with its page's name and number folded in, so a result row
// has everything it needs and search can match the page name too -- plus
// one entry per page, so a search can land on a whole section. `pages` is
// the Settings window's own list.
function build(pages) {
    var byId = {}
    var out = []
    for (var i = 0; i < pages.length; i++) {
        var pg = pages[i]
        byId[pg.id] = { page: pg, number: number(i) }
        out.push({
            page: pg.id,
            pageLabel: pg.label,
            icon: pg.icon,
            number: number(i),
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
            number: p.number,
            section: e.section,
            label: e.label,
            isPage: false,
            haystack: (e.label + " " + e.section + " " + p.page.label + " " + (e.keywords || "")).toLowerCase(),
        })
    }
    return out
}

// "01", "02": the sections' numbering, shared with their hits
function number(i) {
    return (i < 9 ? "0" : "") + (i + 1)
}

// Every word of the query has to appear somewhere in the entry; the rank is
// the best any of them scores against the label, so "font size" puts the
// setting called Font size above the ones that merely mention fonts.
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
