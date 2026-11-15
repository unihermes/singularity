// The menu bar's menus for apps that don't export their own (services/AppMenus.qml):
// each entry sends the app its own shortcut. Apps are matched by window class;
// any other app gets the common Edit menu.
//
// A menu is [title, entries]. An entry is a separator "-", a [label, keys]
// pair, or a [label, [entries]] submenu. Keys are Hyprland's names, as in
// binds.lua ("CTRL+SHIFT+T"); a space separates the steps of a chord
// ("CTRL+K CTRL+O").

.pragma library

var EDIT = ["Edit", [
    ["Undo", "CTRL+Z"], ["Redo", "CTRL+SHIFT+Z"], "-",
    ["Cut", "CTRL+X"], ["Copy", "CTRL+C"], ["Paste", "CTRL+V"], "-",
    ["Select all", "CTRL+A"], ["Find", "CTRL+F"],
]]

var ZOOM = [["Zoom in", "CTRL+equal"], ["Zoom out", "CTRL+minus"], ["Actual size", "CTRL+0"]]

var BROWSER = [
    ["File", [
        ["New tab", "CTRL+T"], ["New window", "CTRL+N"], ["New private window", "CTRL+SHIFT+P"], "-",
        ["Open file…", "CTRL+O"], ["Save page as…", "CTRL+S"], "-",
        ["Print…", "CTRL+P"], "-",
        ["Close tab", "CTRL+W"], ["Reopen closed tab", "CTRL+SHIFT+T"],
    ]],
    ["Edit", EDIT[1].slice(0, -1).concat([["Find in page", "CTRL+F"]])],
    ["View", [
        ["Reload", "CTRL+R"], ["Reload without cache", "CTRL+SHIFT+R"], "-",
    ].concat(ZOOM).concat(["-", ["Full screen", "F11"], ["Page source", "CTRL+U"]])],
    ["History", [
        ["Back", "ALT+Left"], ["Forward", "ALT+Right"], "-",
        ["Show history", "CTRL+H"], ["Downloads", "CTRL+SHIFT+Y"],
    ]],
    ["Bookmarks", [
        ["Bookmark this page", "CTRL+D"], ["Bookmarks sidebar", "CTRL+B"], ["Manage bookmarks", "CTRL+SHIFT+O"],
    ]],
    ["Tools", [
        ["Developer tools", "CTRL+SHIFT+I"], ["Web console", "CTRL+SHIFT+K"], ["Add-ons", "CTRL+SHIFT+A"],
    ]],
]

var CODE = [
    ["File", [
        ["New file", "CTRL+N"], ["New window", "CTRL+SHIFT+N"], "-",
        ["Open file…", "CTRL+O"], ["Open folder…", "CTRL+K CTRL+O"], "-",
        ["Save", "CTRL+S"], ["Save as…", "CTRL+SHIFT+S"], "-",
        ["Close editor", "CTRL+W"], ["Close window", "CTRL+SHIFT+W"],
    ]],
    ["Edit", [
        ["Undo", "CTRL+Z"], ["Redo", "CTRL+SHIFT+Z"], "-",
        ["Cut", "CTRL+X"], ["Copy", "CTRL+C"], ["Paste", "CTRL+V"], "-",
        ["Find", "CTRL+F"], ["Replace", "CTRL+H"], ["Find in files", "CTRL+SHIFT+F"], "-",
        ["Toggle comment", "CTRL+slash"],
    ]],
    ["View", [
        ["Command palette…", "CTRL+SHIFT+P"], "-",
        ["Explorer", "CTRL+SHIFT+E"], ["Search", "CTRL+SHIFT+F"], ["Source control", "CTRL+SHIFT+G"],
        ["Extensions", "CTRL+SHIFT+X"], "-",
        ["Sidebar", "CTRL+B"], ["Terminal", "CTRL+grave"], ["Word wrap", "ALT+Z"], "-",
        ["Zoom in", "CTRL+equal"], ["Zoom out", "CTRL+minus"],
    ]],
    ["Go", [
        ["Go to file…", "CTRL+P"], ["Go to line…", "CTRL+G"], ["Go to symbol…", "CTRL+SHIFT+O"], "-",
        ["Go to definition", "F12"], ["Back", "CTRL+ALT+minus"], ["Forward", "CTRL+SHIFT+minus"],
    ]],
    ["Run", [
        ["Start debugging", "F5"], ["Run without debugging", "CTRL+F5"], ["Stop", "SHIFT+F5"],
    ]],
    ["Terminal", [
        ["New terminal", "CTRL+SHIFT+grave"],
    ]],
]

var TERMINAL = [
    ["Shell", [
        ["New window", "CTRL+SHIFT+N"],
    ]],
    ["Edit", [
        ["Copy", "CTRL+SHIFT+C"], ["Paste", "CTRL+SHIFT+V"],
    ]],
    ["View", ZOOM],
]

var GHOSTTY = [
    ["Shell", [
        ["New window", "CTRL+SHIFT+N"], ["New tab", "CTRL+SHIFT+T"], "-",
        ["Split right", "CTRL+SHIFT+O"], ["Split down", "CTRL+SHIFT+E"], "-",
        ["Close", "CTRL+SHIFT+W"],
    ]],
    ["Edit", [
        ["Copy", "CTRL+SHIFT+C"], ["Paste", "CTRL+SHIFT+V"], ["Select all", "CTRL+SHIFT+A"],
    ]],
    ["View", ZOOM],
]

var FILES = [
    ["File", [
        ["New window", "CTRL+N"], ["New tab", "CTRL+T"], ["New folder", "CTRL+SHIFT+N"], "-",
        ["Properties", "ALT+Return"], "-",
        ["Close tab", "CTRL+W"],
    ]],
    ["Edit", [
        ["Cut", "CTRL+X"], ["Copy", "CTRL+C"], ["Paste", "CTRL+V"], "-",
        ["Select all", "CTRL+A"], ["Rename…", "F2"], ["Move to trash", "Delete"], "-",
        ["Find", "CTRL+F"],
    ]],
    ["View", [
        ["Reload", "CTRL+R"], ["Hidden files", "CTRL+H"], ["Side pane", "F9"], ["Location bar", "CTRL+L"], "-",
        ["Icons", "CTRL+1"], ["Detailed list", "CTRL+2"], ["Compact list", "CTRL+3"], "-",
    ].concat(ZOOM.slice(0, 2))],
    ["Go", [
        ["Back", "ALT+Left"], ["Forward", "ALT+Right"], ["Parent folder", "ALT+Up"], ["Home", "ALT+Home"],
    ]],
]

var NOTES = [
    ["File", [
        ["New note", "CTRL+N"], ["Open quick switcher…", "CTRL+O"], "-",
        ["Close tab", "CTRL+W"],
    ]],
    EDIT,
    ["View", [
        ["Command palette…", "CTRL+P"], ["Reading view", "CTRL+E"], ["Search all notes", "CTRL+SHIFT+F"], "-",
    ].concat(ZOOM).concat(["-", ["Settings", "CTRL+comma"]])],
]

var MUSIC = [
    EDIT,
    ["Playback", [
        ["Play or pause", "space"], ["Next track", "CTRL+Right"], ["Previous track", "CTRL+Left"], "-",
        ["Volume up", "CTRL+Up"], ["Volume down", "CTRL+Down"], "-",
        ["Shuffle", "CTRL+S"], ["Repeat", "CTRL+R"],
    ]],
]

// window class pattern, menus; the first match wins
var APPS = [
    [/^(floorp|zen.*|firefox.*|librewolf|waterfox)$/i, BROWSER],
    [/^(vscodium|codium|code|code-oss|cursor)$/i, CODE],
    [/^com\.mitchellh\.ghostty$/, GHOSTTY],
    [/^(alacritty|kitty|foot|org\.wezfurlong\.wezterm)$/i, TERMINAL],
    [/^(thunar|org\.gnome\.nautilus|nemo|pcmanfm.*)$/i, FILES],
    [/^obsidian$/i, NOTES],
    [/^spotify$/i, MUSIC],
]

var KEY_NAMES = {
    CTRL: "Ctrl", SHIFT: "Shift", ALT: "Alt", SUPER: "Super",
    equal: "=", minus: "-", grave: "`", slash: "/", comma: ",", period: ".",
    Left: "←", Right: "→", Up: "↑", Down: "↓", Return: "Enter", Delete: "Del", space: "Space",
}

// "CTRL+SHIFT+T" as the menu shows it: "Ctrl+Shift+T"
function keysText(keys) {
    return keys.split(" ").map(step => step.split("+").map(k => KEY_NAMES[k] || k).join("+")).join(" ")
}

// "CTRL+K CTRL+O" as send_shortcut's steps: [{ mods: "CTRL", key: "K" }, …]
function keySteps(keys) {
    return keys.split(" ").map(step => {
        var parts = step.split("+")
        return { mods: parts.slice(0, -1).join(" "), key: parts[parts.length - 1] }
    })
}

var nextId = 1
function entry(e) {
    if (e === "-") return { id: nextId++, separator: true, label: "", enabled: true, children: null }
    if (Array.isArray(e[1]))
        return { id: nextId++, label: e[0], enabled: true, separator: false, children: e[1].map(entry) }
    return { id: nextId++, label: e[0], enabled: true, separator: false, children: null,
             shortcut: keysText(e[1]), keys: e[1] }
}

// The menus for a window class, in the shape the helper gives exported
// menus: [{ label, children: [item] }]
function forClass(cls) {
    var found = APPS.find(a => a[0].test(cls || ""))
    var menus = found ? found[1] : [EDIT]
    return menus.map(m => ({ id: nextId++, label: m[0], enabled: true, separator: false, children: m[1].map(entry) }))
}
