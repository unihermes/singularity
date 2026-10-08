// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageFileTypes.qml
//
// Which app opens what. The common kinds of file are grouped (a browser is
// http, https and html at once; images are a handful of types), and every
// other type the system knows is searchable below them.
//
// The full type list is the shared-mime-info database, not just what apps
// declare, and it stays behind a button: a thousand rows is a scroll, not a
// list, so the search is what the section leads with.
//
// Candidates come from the MimeType= lines of the installed .desktop files --
// Quickshell's DesktopEntries doesn't expose them, so they're read directly.
// An app also counts for a type it doesn't name but inherits: shared-mime-info
// records that application/json is ultimately a kind of text/plain, so an
// editor declaring text/plain can be picked for it. Without that nearly every
// application/* text format has no candidate but a browser, which is how
// JSON ends up opening in Zen.
// The current default is the first entry mimeapps.list gives, falling back
// to mimeinfo.cache's pick, the same order xdg-open resolves in.
//
// Writes go through `xdg-mime default`, which edits ~/.config/mimeapps.list.
// A group is only pointed at the types its chosen app actually declares, so
// picking an image viewer without SVG support leaves SVGs where they were.

import Quickshell
import Quickshell.Io
import QtQuick
import "../services"
import "../flyouts"

SettingsPage {
    id: page

    sectioned: true

    title: "File Types"
    description: "The app each kind of file opens with."

    // A kind's first type is its main one: the apps offered first are the
    // ones that declare it outright (a browser declares https links; Neovim
    // only gets to HTML because HTML is a kind of text).
    readonly property var groups: [
        { label: "Web browser",  covers: "Links and web pages",
          types: ["x-scheme-handler/https", "x-scheme-handler/http", "text/html", "application/xhtml+xml"] },
        { label: "File manager", covers: "Folders", types: ["inode/directory"] },
        { label: "Text",         covers: "Plain text, Markdown, JSON, scripts",
          types: ["text/plain", "text/markdown", "application/json", "text/x-shellscript"] },
        { label: "PDF",          covers: "PDF documents", types: ["application/pdf"] },
        { label: "Images",       covers: "PNG, JPEG, GIF, WebP, SVG, BMP",
          types: ["image/png", "image/jpeg", "image/gif", "image/webp", "image/svg+xml", "image/bmp"] },
        { label: "Video",        covers: "MP4, MKV, WebM, MOV",
          types: ["video/mp4", "video/x-matroska", "video/webm", "video/quicktime"] },
        { label: "Audio",        covers: "MP3, FLAC, Ogg, WAV",
          types: ["audio/mpeg", "audio/flac", "audio/ogg", "audio/x-wav"] },
        { label: "Archives",     covers: "Zip, tar, gzip, 7z",
          types: ["application/zip", "application/x-tar", "application/gzip", "application/x-7z-compressed"] },
        { label: "Email links",  covers: "mailto: links", types: ["x-scheme-handler/mailto"] },
        { label: "Documents",    covers: "Word and OpenDocument text",
          types: ["application/vnd.openxmlformats-officedocument.wordprocessingml.document", "application/msword",
                  "application/vnd.oasis.opendocument.text"] },
        { label: "Spreadsheets", covers: "Excel, OpenDocument, CSV",
          types: ["application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "application/vnd.ms-excel",
                  "application/vnd.oasis.opendocument.spreadsheet", "text/csv"] },
        { label: "Presentations", covers: "PowerPoint and OpenDocument",
          types: ["application/vnd.openxmlformats-officedocument.presentationml.presentation", "application/vnd.ms-powerpoint",
                  "application/vnd.oasis.opendocument.presentation"] },
        { label: "Calendar invites", covers: ".ics invitations", types: ["text/calendar"] },
    ]

    // desktop id -> { id, name, types: [mime] }, apps declaring any type
    property var apps: ({})
    // desktop id -> Name, every entry -- a default can point at one that
    // declares no types (a browser's "userapp-" entry)
    property var names: ({})
    // desktop id -> Icon=, as written (a theme name or a path)
    property var icons: ({})
    // mime -> its description in the mime database ("Markdown document")
    property var comments: ({})
    // mime -> desktop id, mimeapps.list's explicit choice
    property var defaults: ({})
    // mime -> desktop id, mimeinfo.cache's fallback
    property var cached: ({})
    // mime -> [direct parent mime], from shared-mime-info
    property var parents: ({})
    // every type the mime database knows, whether or not an app wants it
    property var known: []
    property bool loaded: false
    property string query: ""
    // the unfiltered list is opt-in, and grows a page at a time
    property bool showAll: false
    property int limit: pageSize
    readonly property int pageSize: 60

    onQueryChanged: { limit = pageSize; openType = "" }
    onShowAllChanged: limit = pageSize

    function appName(id) {
        return names[id] || id.replace(/\.desktop$/, "")
    }

    function appIcon(id) {
        var i = icons[id] || ""
        return i === "" ? "" : i.startsWith("/") ? "file://" + i : Quickshell.iconPath(i, true)
    }

    // "Markdown document", or the type itself when the database has no words
    function typeName(mime) {
        return comments[mime] || mime
    }

    function current(mime) {
        var d = defaults[mime]
        return d !== undefined ? d : (cached[mime] || "")
    }

    // A type and everything it inherits from. The two implicit rules the
    // subclasses file leaves out are in the spec: every text/* is a text/plain,
    // and every */*+xml is an application/xml.
    property var ancestorCache: ({})
    onParentsChanged: ancestorCache = ({})

    function ancestors(mime) {
        var hit = ancestorCache[mime]
        if (hit !== undefined) return hit
        var seen = {}, queue = [mime], out = []
        while (queue.length) {
            var t = queue.shift()
            if (seen[t]) continue
            seen[t] = true
            out.push(t)
            ;(parents[t] || []).forEach(p => queue.push(p))
            if (t.indexOf("text/") === 0 && t !== "text/plain") queue.push("text/plain")
            if (/\+xml$/.test(t)) queue.push("application/xml")
        }
        ancestorCache[mime] = out
        return out
    }

    // Does this app declare the type, or anything the type is a kind of?
    function handles(app, mime) {
        return ancestors(mime).some(t => app.types.indexOf(t) >= 0)
    }

    // apps declaring the type itself, not through a supertype, by name
    function declaring(mime) {
        var out = []
        for (var id in apps) if (apps[id].types.indexOf(mime) >= 0) out.push(apps[id])
        return out.sort((x, y) => x.name.localeCompare(y.name))
    }

    // apps declaring any of these types (or a supertype), by name
    function candidates(types) {
        var out = []
        for (var id in apps) {
            var a = apps[id]
            if (types.some(t => handles(a, t))) out.push(a)
        }
        return out.sort((x, y) => x.name.localeCompare(y.name))
    }

    // The group's types an app could take that have no default yet.
    function unset(types) {
        return types.filter(t => current(t) === "" && candidates([t]).length > 0)
    }

    // The group's default, if its types agree; "mixed" if they don't.
    function groupCurrent(types) {
        var seen = ""
        for (var i = 0; i < types.length; i++) {
            var c = current(types[i])
            if (c === "") continue
            if (seen === "") seen = c
            else if (seen !== c) return "mixed"
        }
        return seen
    }

    function setDefault(appId, types) {
        var declared = apps[appId] ? types.filter(t => handles(apps[appId], t)) : types
        if (declared.length === 0) return
        setProc.queue.push({ command: ["xdg-mime", "default", appId].concat(declared),
            message: appName(appId) + " now opens " + (declared.length === 1 ? declared[0] : declared.length + " types") })
        nextSet()
    }

    // One xdg-mime at a time, in order: a Process still running ignores a
    // new command, so a click made meanwhile was lost.
    function nextSet() {
        if (setProc.running || setProc.queue.length === 0) return
        var job = setProc.queue.shift()
        setProc.pending = job.message
        setProc.command = job.command
        setProc.running = true
    }

    // Every type the database lists, plus any an installed app invents that
    // it doesn't. Sorted once, here, so the search only filters.
    readonly property var everyType: {
        if (!loaded) return []
        var set = {}
        known.forEach(t => set[t] = true)
        for (var id in apps) apps[id].types.forEach(t => set[t] = true)
        for (var m in parents) set[m] = true
        return Object.keys(set).sort()
    }

    // What the search matches, before the page limit. A bare type search is
    // a substring; anything else also matches the apps that handle the type,
    // which is the slow half and so is only tried when the name can't match.
    readonly property var matches: {
        var q = query.trim().toLowerCase()
        if (q === "") return showAll ? everyType : []
        return everyType.filter(t => t.indexOf(q) >= 0
            || (comments[t] || "").toLowerCase().indexOf(q) >= 0
            || candidates([t]).some(a => a.name.toLowerCase().indexOf(q) >= 0))
    }

    readonly property var allTypes: matches.slice(0, limit)

    Component.onCompleted: {
        scanProc.running = true
        defaultsProc.running = true
        mimeProc.running = true
    }

    // One record per .desktop file, user copies shadowing system ones:
    // id <TAB> Name <TAB> MimeType. Only the [Desktop Entry] group counts --
    // Actions carry Name= lines too. Hidden=true entries are deletions.
    Process {
        id: scanProc
        command: ["sh", "-c", `
            IFS=:
            for d in "\${XDG_DATA_HOME:-$HOME/.local/share}" \${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do
                [ -d "$d/applications" ] || continue
                find "$d/applications" -name '*.desktop' 2>/dev/null | while read -r f; do
                    id=\${f#"$d/applications/"}
                    awk -v id="$(printf %s "$id" | tr / -)" -F= '
                        /^\\[/ { inmain = ($0 == "[Desktop Entry]") }
                        inmain && $1 == "Name" && name == "" { name = substr($0, 6) }
                        inmain && $1 == "MimeType" { mime = substr($0, 10) }
                        inmain && $1 == "Icon" && icon == "" { icon = substr($0, 6) }
                        inmain && $1 == "Hidden" && $2 == "true" { hidden = 1 }
                        END { printf "%s\\t%s\\t%s\\t%s\\t%s\\n", id, name, mime, hidden, icon }' "$f"
                done
            done`]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = {}
                text.split("\n").forEach(line => {
                    var f = line.split("\t")
                    if (f.length < 4 || out[f[0]] !== undefined) return
                    // first one seen wins, hidden or not, so a user's
                    // Hidden=true copy removes the system entry
                    out[f[0]] = f[3] === "1" ? null
                        : { id: f[0], name: f[1] || f[0], types: f[2].split(";").filter(t => t !== ""), icon: f[4] || "" }
                })
                var apps = {}, names = {}, icons = {}
                for (var id in out) {
                    if (!out[id]) continue
                    names[id] = out[id].name
                    icons[id] = out[id].icon
                    if (out[id].types.length) apps[id] = out[id]
                }
                page.apps = apps
                page.names = names
                page.icons = icons
                page.loaded = true
            }
        }
    }

    // mimeapps.list's [Default Applications] in precedence order, then
    // mimeinfo.cache. D <TAB> mime <TAB> first-app, C likewise.
    Process {
        id: defaultsProc
        command: ["sh", "-c", `
            IFS=:
            cfg=\${XDG_CONFIG_HOME:-$HOME/.config}
            data=\${XDG_DATA_HOME:-$HOME/.local/share}
            for f in "$cfg/mimeapps.list" $(printf %s "\${XDG_CONFIG_DIRS:-/etc/xdg}" | sed 's|:|/mimeapps.list:|g; s|$|/mimeapps.list|') \
                     "$data/applications/mimeapps.list" $(printf %s "\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" | sed 's|:|/applications/mimeapps.list:|g; s|$|/applications/mimeapps.list|'); do
                [ -f "$f" ] && awk -F= '/^\\[/ { on = ($0 == "[Default Applications]") } on && NF > 1 { split($2, a, ";"); if (a[1] != "") printf "D\\t%s\\t%s\\n", $1, a[1] }' "$f"
            done
            for d in "$data" \${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do
                f="$d/applications/mimeinfo.cache"
                [ -f "$f" ] && awk -F= '/^\\[/ { on = ($0 == "[MIME Cache]") } on && NF > 1 { split($2, a, ";"); if (a[1] != "") printf "C\\t%s\\t%s\\n", $1, a[1] }' "$f"
            done`]
        stdout: StdioCollector {
            onStreamFinished: {
                var d = {}, c = {}
                text.split("\n").forEach(line => {
                    var f = line.split("\t")
                    if (f.length < 3) return
                    var map = f[0] === "D" ? d : c
                    if (map[f[1]] === undefined) map[f[1]] = f[2]
                })
                page.defaults = d
                page.cached = c
            }
        }
    }

    // The mime database, from every data dir in turn: S <TAB> child <TAB>
    // parent for the subclass graph, T <TAB> type for the roster of types.
    Process {
        id: mimeProc
        command: ["sh", "-c", `
            IFS=:
            for d in "\${XDG_DATA_HOME:-$HOME/.local/share}" \${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do
                [ -f "$d/mime/subclasses" ] && sed 's/^/S\t/; s/ /\t/' "$d/mime/subclasses"
                [ -f "$d/mime/types" ] && sed 's/^/T\t/' "$d/mime/types"
                # each type's description in English: the first <comment>
                # with no xml:lang under its <mime-type>
                for x in "$d"/mime/packages/*.xml; do
                    [ -f "$x" ] && awk '
                        match($0, /<mime-type type="[^"]+"/) { t = substr($0, RSTART + 17, RLENGTH - 18); done = 0 }
                        t != "" && !done && /<comment>/ { c = $0; sub(/.*<comment>/, "", c); sub(/<\\/comment>.*/, "", c); printf "D\\t%s\\t%s\\n", t, c; done = 1 }' "$x"
                done
            done
            exit 0`]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = {}, seen = {}, types = [], words = {}
                text.split("\n").forEach(line => {
                    var f = line.split("\t")
                    if (f[0] === "S") {
                        if (f.length < 3 || f[1] === "" || f[2] === "") return
                        ;(p[f[1]] = p[f[1]] || []).push(f[2])
                    } else if (f[0] === "D" && f[1] && f[2] && !words[f[1]]) {
                        words[f[1]] = f[2].replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
                    } else if (f[0] === "T" && f[1] && !seen[f[1]]) {
                        seen[f[1]] = true
                        types.push(f[1])
                    }
                })
                page.parents = p
                page.known = types
                page.comments = words
            }
        }
    }

    Process {
        id: setProc
        property string pending: ""
        property var queue: []
        stderr: StdioCollector { id: setErr }
        onExited: code => {
            if (code === 0) page.say(pending, false)
            else page.say("xdg-mime failed: " + (setErr.text.trim().split("\n")[0] || "exit " + code), true)
            if (queue.length > 0) page.nextSet()
            else defaultsProc.running = true
        }
    }

    // --- layout --------------------------------------------------------------

    // A common kind: what it covers (or what in it has no default yet) and a
    // dropdown of apps with their icons. The apps made for its main type come
    // first; the rest that could open it are behind the list's last entry.
    component HandlerRow: SettingsField {
        id: hr
        property var types: []
        property string covers: ""
        // the list grown to every app that can open one of its types
        property bool wide: false
        readonly property var made: page.declaring(types[0])
        readonly property var others: page.candidates(types).filter(a => made.indexOf(a) < 0)
        readonly property var offered: wide || made.length === 0 ? made.concat(others) : made
        readonly property string chosen: page.groupCurrent(types)
        // the default as one of the offered apps: a default naming another
        // entry of the same app (zathura.desktop against zathura-pdf-mupdf,
        // which is the one declaring PDFs) counts as that app
        readonly property string shown: {
            if (offered.some(a => a.id === chosen)) return chosen
            var same = offered.find(a => page.names[chosen] !== undefined && a.name === page.names[chosen])
            return same ? same.id : chosen
        }
        readonly property var missing: page.unset(types).map(t => page.typeName(t).replace(/ document$/, ""))
        readonly property string more: "__more__"

        hint: chosen === "mixed" ? "Mixed — pick one to set them all"
            : missing.length > 0 && missing.length < types.length ? "No default: " + missing.join(", ")
            : chosen === "" ? "Nothing set"
            : !page.names[chosen] ? chosen + " (not installed)"
            : covers

        SettingsDropdown {
            anchors.right: parent.right
            width: Theme.fit(260)
            visible: hr.offered.length > 0
            enabled: !setProc.running
            maxRows: 10
            // the current one too, if it's an installed app none of the
            // offered ones are
            model: {
                var ids = hr.offered.map(a => a.id)
                if (hr.shown !== "" && hr.shown !== "mixed" && ids.indexOf(hr.shown) < 0 && page.names[hr.shown]) ids.unshift(hr.shown)
                if (!hr.wide && hr.others.length > 0 && hr.made.length > 0) ids.push(hr.more)
                return ids
            }
            current: hr.shown
            labelFor: id => id === hr.more ? "More apps (" + hr.others.length + ")…" : page.appName(id)
            iconFor: id => id === hr.more ? "" : page.appIcon(id)
            placeholder: hr.chosen === "mixed" ? "Mixed" : "Choose an app"
            onPicked: id => {
                if (id === hr.more) {
                    hr.wide = true
                    Qt.callLater(() => open = true)
                } else page.setDefault(id, hr.types)
            }
        }

        Text {
            anchors.right: parent.right
            visible: hr.offered.length === 0
            height: Theme.chipHeight
            verticalAlignment: Text.AlignVCenter
            text: page.loaded ? "No installed app handles this" : "Reading apps…"
            color: Theme.muted
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
    }

    FlyoutHeading { text: "COMMON" }

    Repeater {
        model: page.groups
        HandlerRow {
            required property var modelData
            label: modelData.label
            covers: modelData.covers
            types: modelData.types
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "EVERY TYPE" }

    FlyoutInput {
        id: search
        placeholder: "Search: markdown, avif, image/heif, zathura"
        glyph: "󰍉"
        echoPassword: false
        onTextChanged: page.query = text
        onEscapePressed: if (text !== "") text = ""
    }

    FlyoutRow {
        visible: !page.loaded
        enabled: false
        label: "Reading the mime database…"
    }

    // Browsing the lot is a deliberate act -- searching is the fast path, and
    // a thousand rows takes a moment to build -- so it's a row of its own,
    // and it steps aside once there's a search to answer.
    FlyoutRow {
        visible: page.loaded && page.query.trim() === ""
        label: page.showAll ? "Hide the full list" : "Show all " + page.everyType.length + " types"
        trailing: page.showAll ? "󰅀" : "󰅂"
        onActivated: page.showAll = !page.showAll
    }

    // the type open under its row
    property string openType: ""

    // A type, named in words, with its app; it opens to the apps that can
    // take it, the current one ticked.
    component TypeBlock: Column {
        id: tb
        required property string modelData
        readonly property string cur: page.current(modelData)
        readonly property bool isOpen: page.openType === modelData

        width: parent ? parent.width : 0

        FlyoutRow {
            label: page.typeName(tb.modelData)
            note: page.comments[tb.modelData] ? tb.modelData : ""
            highlighted: tb.isOpen
            trailing: (tb.cur === "" ? "Nothing set" : page.appName(tb.cur)) + "  " + (tb.isOpen ? "󰅀" : "󰅂")
            onActivated: page.openType = tb.isOpen ? "" : tb.modelData
        }

        SettingsIndent {
            visible: tb.isOpen

            Repeater {
                model: tb.isOpen ? page.candidates([tb.modelData]) : []
                FlyoutRow {
                    required property var modelData
                    leadingImage: page.appIcon(modelData.id)
                    leadingIcon: page.icons[modelData.id] ? "" : "󰣆"
                    label: modelData.name
                    highlighted: modelData.id === tb.cur
                    trailing: modelData.id === tb.cur ? "󰄬" : ""
                    onActivated: if (modelData.id !== tb.cur) page.setDefault(modelData.id, [tb.modelData])
                }
            }
            FlyoutRow {
                visible: tb.isOpen && page.candidates([tb.modelData]).length === 0
                enabled: false
                label: "No installed app opens it"
            }
        }
    }

    Repeater {
        model: page.allTypes
        TypeBlock {}
    }

    // Rows are cheap individually and dear in bulk, so the list arrives in
    // pages rather than all at once.
    FlyoutRow {
        readonly property int rest: page.matches.length - page.allTypes.length
        visible: rest > 0
        label: "Show " + Math.min(rest, page.pageSize) + " more (" + rest + " left)"
        onActivated: page.limit += page.pageSize
    }

    FlyoutRow {
        visible: page.query.trim() !== "" && page.matches.length === 0
        enabled: false
        label: "No type matches \"" + page.query.trim() + "\""
    }
}
