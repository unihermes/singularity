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
    // --- Appearance --------------------------------------------------------
    { page: "appearance", section: "Look",          label: "Look",                 keywords: "theme preset style" },
    { page: "appearance", section: "Look",          label: "Reset look",           keywords: "revert default" },
    { page: "appearance", section: "Wallpaper",     label: "Current",              keywords: "wallpaper background image" },
    { page: "appearance", section: "Wallpaper",     label: "New wallpaper",        keywords: "wallpaper shuffle random login rotate slideshow interval timer" },
    { page: "appearance", section: "Colours",       label: "Palette",              keywords: "colour color grayscale wallpaper" },
    { page: "appearance", section: "Colours",       label: "Intensity",            keywords: "colour color saturation" },
    { page: "appearance", section: "Colours",       label: "Shade",                keywords: "light dark mode theme variant" },
    { page: "appearance", section: "Colours",       label: "Accent",               keywords: "colour color highlight hue" },
    { page: "appearance", section: "Colours",       label: "Custom accent",        keywords: "colour color hex rgb highlight" },
    { page: "appearance", section: "Style",         label: "Frames",               keywords: "stroke bevel double" },
    { page: "appearance", section: "Style",         label: "Stroke width",         keywords: "border outline line thickness px" },
    { page: "appearance", section: "Style",         label: "Corner radius",        keywords: "rounding corners flyouts modules" },
    { page: "appearance", section: "Style",         label: "Density",              keywords: "spacing padding compact" },
    { page: "appearance", section: "Style",         label: "Headings",             keywords: "titles caps uppercase bold rule" },
    { page: "appearance", section: "Style",         label: "Panel opacity",        keywords: "transparency translucent glass flyouts" },
    { page: "appearance", section: "Style",         label: "Overlay dimming",      keywords: "scrim dark backdrop" },
    { page: "appearance", section: "Text & motion", label: "Font",                 keywords: "typeface family monospace shell bar" },
    { page: "appearance", section: "Text & motion", label: "Font size",            keywords: "text scale px" },
    { page: "appearance", section: "Text & motion", label: "Animations",           keywords: "motion transitions speed" },
    { page: "appearance", section: "Bar",           label: "Position",             keywords: "bar top bottom edge" },
    { page: "appearance", section: "Bar",           label: "Shape",                keywords: "bar layout full width floating islands notch bare" },
    { page: "appearance", section: "Bar",           label: "Modules",              keywords: "bar chips" },
    { page: "appearance", section: "Bar",           label: "Workspaces",           keywords: "indicator dots" },
    { page: "appearance", section: "Bar",           label: "Clock",                keywords: "time date" },
    { page: "appearance", section: "Bar",           label: "Clock island",         keywords: "notch toast" },
    { page: "appearance", section: "Bar",           label: "Height",               keywords: "bar size px" },
    { page: "appearance", section: "Bar",           label: "Module gap",           keywords: "bar spacing" },
    { page: "appearance", section: "Bar",           label: "Opacity",              keywords: "bar transparency alpha" },
    { page: "appearance", section: "Bar",           label: "Bar text size",        keywords: "bar font icons scale px" },
    { page: "appearance", section: "System",        label: "System font",          keywords: "typeface family gtk qt apps interface ui" },
    { page: "appearance", section: "System",        label: "Icons",                keywords: "icon theme kora apps gtk qt" },
    { page: "appearance", section: "System",        label: "Cursor",               keywords: "pointer mouse theme bibata" },
    { page: "appearance", section: "System",        label: "Cursor size",          keywords: "pointer mouse px big" },
    { page: "appearance", section: "Windows",       label: "Gaps between windows", keywords: "gaps_in hyprland tiling" },
    { page: "appearance", section: "Windows",       label: "Gaps at screen edges", keywords: "gaps_out hyprland" },
    { page: "appearance", section: "Windows",       label: "Border width",         keywords: "border_size hyprland" },
    { page: "appearance", section: "Windows",       label: "Corner radius",        keywords: "rounding hyprland windows" },
    { page: "appearance", section: "Windows",       label: "Focused opacity",      keywords: "active_opacity transparency" },
    { page: "appearance", section: "Windows",       label: "Unfocused opacity",    keywords: "inactive_opacity transparency" },
    { page: "appearance", section: "Windows",       label: "Dim unfocused",        keywords: "dim_inactive" },
    { page: "appearance", section: "Windows",       label: "Blur",                 keywords: "hyprland decoration" },
    { page: "appearance", section: "Windows",       label: "Shadows",              keywords: "hyprland decoration drop" },
    { page: "appearance", section: "Windows",       label: "Dim strength",         keywords: "dim_strength unfocused darken" },
    { page: "appearance", section: "Windows",       label: "Blur size",            keywords: "hyprland blur radius" },
    { page: "appearance", section: "Windows",       label: "Blur passes",          keywords: "hyprland blur quality" },
    { page: "appearance", section: "Windows",       label: "Shadow size",          keywords: "hyprland shadow range spread" },
    { page: "appearance", section: "Windows",       label: "Shadow darkness",      keywords: "hyprland shadow colour color opacity" },
    { page: "appearance", section: "Windows",       label: "Border colours",       keywords: "hyprland border accent active inactive colour color" },
    { page: "appearance", section: "Windows",       label: "Window animation",     keywords: "hyprland open close popin slide fade" },
    { page: "appearance", section: "Default",       label: "Set as default",       keywords: "save baseline" },
    { page: "appearance", section: "Default",       label: "Reset to default",     keywords: "revert" },
    { page: "appearance", section: "Default",       label: "Factory reset",        keywords: "stock wipe" },

    // --- Display -----------------------------------------------------------
    { page: "display", section: "",  label: "Arrangement",  keywords: "monitor position extend duplicate mirror" },
    { page: "display", section: "",  label: "Primary",      keywords: "monitor main workspace 1" },
    { page: "display", section: "",  label: "Now",          keywords: "monitor current rule" },
    { page: "display", section: "",  label: "Scale",        keywords: "monitor hidpi fractional" },
    { page: "display", section: "",  label: "Mode",         keywords: "monitor resolution refresh rate hz" },

    // --- Audio -------------------------------------------------------------
    { page: "audio", section: "Output", label: "Volume",    keywords: "level loudness mute speakers" },
    { page: "audio", section: "Output", label: "Device",    keywords: "default sink source speakers headphones hdmi microphone" },
    { page: "audio", section: "Output", label: "Output",    keywords: "sink speakers headphones device" },
    { page: "audio", section: "Input",  label: "Input",     keywords: "source microphone mic device" },
    // The mixer's rows are named after whatever happens to be running, so
    // there is no fixed field label to point at. These name their heading
    // instead: the result opens the page, and highlights nothing.
    { page: "audio", section: "", label: "Playing",   keywords: "mixer per app volume application stream" },
    { page: "audio", section: "", label: "Recording", keywords: "mixer capture app stream microphone" },

    // --- Network -----------------------------------------------------------
    { page: "network", section: "Status", label: "Wi-Fi",      keywords: "wifi wireless radio iwd on off" },
    { page: "network", section: "Status", label: "Interface",  keywords: "device wlan adapter" },
    { page: "network", section: "Status", label: "IP address", keywords: "ipv4 dhcp address" },
    { page: "network", section: "Status", label: "Gateway",    keywords: "router default route" },
    { page: "network", section: "Status", label: "MAC",        keywords: "hardware address ethernet" },
    { page: "network", section: "Status", label: "Link",       keywords: "bitrate signal strength speed" },
    { page: "network", section: "Networks", label: "Networks", keywords: "wifi scan ssid connect join forget passphrase" },

    // --- Bluetooth ---------------------------------------------------------
    { page: "bluetooth", section: "Adapter", label: "Bluetooth",    keywords: "bt radio bluez power on off rfkill" },
    { page: "bluetooth", section: "Adapter", label: "Name",         keywords: "adapter hostname identity" },
    { page: "bluetooth", section: "Adapter", label: "Interface",    keywords: "hci adapter id mac address" },
    { page: "bluetooth", section: "Adapter", label: "Discoverable", keywords: "visible advertise findable" },
    { page: "bluetooth", section: "Adapter", label: "Pairable",     keywords: "accept pairing requests" },
    { page: "bluetooth", section: "Nearby",  label: "Nearby",       keywords: "scan discover pair headphones mouse keyboard unnamed" },

    // --- Input -------------------------------------------------------------
    { page: "input", section: "Keyboard", label: "Layout",            keywords: "xkb us de language" },
    { page: "input", section: "Keyboard", label: "Variant",           keywords: "xkb colemak dvorak" },
    { page: "input", section: "Keyboard", label: "Options",           keywords: "xkb caps escape" },
    { page: "input", section: "Keyboard", label: "Repeat rate",       keywords: "key held" },
    { page: "input", section: "Keyboard", label: "Repeat delay",      keywords: "key held" },
    { page: "input", section: "Keyboard", label: "Num Lock on at login", keywords: "numlock numpad" },
    { page: "input", section: "Mouse", label: "Sensitivity",          keywords: "pointer speed" },
    { page: "input", section: "Mouse", label: "Acceleration",         keywords: "accel flat pointer" },
    { page: "input", section: "Mouse", label: "Focus follows mouse",  keywords: "sloppy focus hover" },
    { page: "input", section: "Mouse", label: "Left-handed",          keywords: "buttons swap" },
    { page: "input", section: "Touchpad", label: "Tap to click",      keywords: "trackpad" },
    { page: "input", section: "Touchpad", label: "Natural scrolling", keywords: "trackpad reverse invert" },
    { page: "input", section: "Touchpad", label: "Disable while typing", keywords: "trackpad dwt palm" },
    { page: "input", section: "Touchpad", label: "Scroll speed",      keywords: "trackpad two finger" },
    { page: "input", section: "Touchpad", label: "Click by finger count", keywords: "trackpad right middle" },
    { page: "input", section: "Touchpad", label: "Drag lock",         keywords: "trackpad" },
    { page: "input", section: "Touchpad", label: "Middle-click emulation", keywords: "trackpad paste" },

    // --- Power & Idle ------------------------------------------------------
    { page: "power", section: "Power profile", label: "Profile",       keywords: "performance balanced power saver battery ppd" },
    { page: "power", section: "When idle", label: "Dim the screen",    keywords: "idle brightness timeout hypridle" },
    { page: "power", section: "When idle", label: "Lock",              keywords: "idle hyprlock timeout screen lock" },
    { page: "power", section: "When idle", label: "Turn screens off",  keywords: "idle dpms blank timeout" },
    { page: "power", section: "When idle", label: "Suspend",           keywords: "idle sleep timeout" },
    { page: "power", section: "When idle", label: "Suspend on battery", keywords: "idle sleep timeout charger" },
    { page: "power", section: "When idle", label: "Hibernate",         keywords: "idle timeout" },

    // --- Notifications -----------------------------------------------------
    { page: "notifications", section: "Quick actions", label: "Do Not Disturb", keywords: "dnd silence mute" },
    { page: "notifications", section: "Quick actions", label: "Clear all",      keywords: "dismiss history" },
    { page: "notifications", section: "Quick actions", label: "Open the panel", keywords: "swaync centre center" },
    { page: "notifications", section: "Popups", label: "Position",              keywords: "corner where popups appear" },
    { page: "notifications", section: "How long popups stay", label: "Normal",  keywords: "timeout duration" },
    { page: "notifications", section: "How long popups stay", label: "Low priority", keywords: "timeout duration" },
    { page: "notifications", section: "How long popups stay", label: "Critical", keywords: "timeout duration urgent" },

    // --- Window Rules ------------------------------------------------------
    { page: "windowrules", section: "Add a rule", label: "Open now",     keywords: "app class pick running" },
    { page: "windowrules", section: "Rules", label: "Name",              keywords: "alias rename label title" },
    { page: "windowrules", section: "Rules", label: "Layout",            keywords: "float tiled auto" },
    { page: "windowrules", section: "Rules", label: "Size",              keywords: "natural window dimensions" },
    { page: "windowrules", section: "Rules", label: "Workspace",         keywords: "where it opens" },
    { page: "windowrules", section: "Rules", label: "Open fullscreen",   keywords: "maximise maximize" },
    { page: "windowrules", section: "Rules", label: "Always on top",     keywords: "pin float above" },
    { page: "windowrules", section: "Workspace layouts", label: "Workspace layouts", keywords: "dwindle monocle tiling pinned" },

    // --- Keybinds ----------------------------------------------------------
    { page: "keybinds", section: "", label: "Keybinds", keywords: "shortcuts keys bindings super hotkey presets" },

    // --- Terminal ----------------------------------------------------------
    { page: "shell", section: "Alacritty", label: "Font size",  keywords: "terminal points" },
    { page: "shell", section: "Alacritty", label: "Opacity",    keywords: "terminal transparency background" },
    { page: "shell", section: "Alacritty", label: "Cursor",     keywords: "terminal block beam blink" },
    { page: "shell", section: "Bash aliases", label: "Bash aliases", keywords: "bashrc shortcut command" },

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
    // --- Startup -----------------------------------------------------------
    { page: "autostart", section: "At login", label: "At login",     keywords: "autostart startup login run launch desktop entry" },
    { page: "autostart", section: "Add",      label: "Application",  keywords: "autostart add app start login" },
    { page: "autostart", section: "Packages", label: "From installed packages", keywords: "xdg autostart system entry keyring" },
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
