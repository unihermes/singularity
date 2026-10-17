// Singularity - Quickshell
// ~/.config/quickshell/windows/SettingsWindow.qml
//
// Settings: a one-line title bar holding the search, and under it one
// framed panel showing Home (every page as a tile, WindowHome.qml), the
// open page, or what the search matched. Inside a page the title bar reads
// Settings › Page, with a back button to Home. Changes apply as they're
// made -- there is no Save -- and each page
// writes straight to the thing it controls (mimeapps.list, binds.lua,
// hypridle.conf, pipewire) rather than to a store of its own -- except
// Appearance and Notifications, whose settings are Settings.qml's, shared
// with the Control Centre and the notification flyout.
//
// The ground and Escape come from WindowChrome.qml.
//
// Search: `/` (or a click) puts the cursor in the bar. Empty, on Home, the
// arrow keys walk the tiles and Enter opens one; typed into, the panel
// lists what matches from SettingsIndex.js -- whole pages and single
// settings -- and picking a setting opens its page and asks the page to
// scroll to it and ring it. Escape clears the query, then leaves the bar,
// then closes the window.
//
// No memory: every open starts on Home (or the page open() is asked for),
// and the page is a Loader that only exists while the window is visible,
// so nothing a page read or ran survives a close -- and nothing runs at all
// while Settings is shut.
//
// Floating and centring come from the "quickshell-windows" rule in
// windows.lua, as for System.

import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import QtQuick
import "../services"
import "../settings"
import "../flyouts"
import "../services/SettingsIndex.js" as SettingsIndex
import "../services/Looks.js" as Looks
import "../services/Styles.js" as Styles

FloatingWindow {
    id: root

    // the open page, or "" for Home
    property string currentPage: ""
    // the setting a search result picked, for the page to scroll to and ring
    property string highlight: ""

    visible: false
    title: "Settings"
    color: "transparent"

    implicitWidth: Theme.windowSize.width
    implicitHeight: Theme.windowSize.height

    // an unknown or empty page opens Home
    function open(page) {
        currentPage = pages.some(p => p.id === page) ? page : ""
        highlight = ""
        home.toTop()
        searchBar.text = ""
        visible = true
    }
    function close() { visible = false }

    // the compositor closing it has to clear visible, or the next open()
    // would be a no-op
    onClosed: visible = false
    onVisibleChanged: if (visible) chrome.keySink.forceActiveFocus()

    // in Home's groups, in Home's order: connections, the machine itself,
    // how the desktop looks and behaves, apps, then the clock and updates
    readonly property var groups: [
        { heading: "Connections", ids: ["network", "bluetooth"] },
        { heading: "Device",      ids: ["display", "audio", "input", "power"] },
        { heading: "Look & Feel", ids: ["appearance", "lockscreen", "notifications", "windowrules"] },
        { heading: "Apps",        ids: ["autostart", "filetypes", "shell", "keybinds"] },
        { heading: "System",      ids: ["datetime", "updates"] },
    ]
    readonly property var pages: [
        { id: "network",       label: "Network",       icon: "󰤨", blurb: "Wi-Fi and the link",               source: "../settings/SettingsPageNetwork.qml" },
        { id: "bluetooth",     label: "Bluetooth",     icon: "󰂯", blurb: "Adapter and devices",              source: "../settings/SettingsPageBluetooth.qml" },
        { id: "display",       label: "Display",       icon: "󰍹", blurb: "Resolution and scale",              source: "../settings/SettingsPageDisplay.qml" },
        { id: "audio",         label: "Audio",         icon: "󰕾", blurb: "Outputs and inputs",                source: "../settings/SettingsPageAudio.qml" },
        { id: "input",         label: "Input",         icon: "󰌌", blurb: "Keyboard and pointer",              source: "../settings/SettingsPageInput.qml" },
        { id: "power",         label: "Power & Idle",  icon: "󰂄", blurb: "Profile, idle and sleep",           source: "../settings/SettingsPagePower.qml" },
        { id: "appearance",    label: "Appearance",    icon: "󰏘", blurb: "Look, colours and bar",             source: "../settings/SettingsPageAppearance.qml" },
        { id: "lockscreen",    label: "Lock Screen",   icon: "󰌾", blurb: "Look, grace and lid",                source: "../settings/SettingsPageLockScreen.qml" },
        { id: "notifications", label: "Notifications", icon: "󰂚", blurb: "Do Not Disturb, popups",            source: "../settings/SettingsPageNotifications.qml" },
        { id: "windowrules",   label: "Window Rules",  icon: "󰖲", blurb: "App rules and layouts",             source: "../settings/SettingsPageWindowRules.qml" },
        { id: "autostart",     label: "Startup",       icon: "󰐊", blurb: "What runs at login",                source: "../settings/SettingsPageAutostart.qml" },
        { id: "filetypes",     label: "File Types",    icon: "󰈔", blurb: "Default apps",                      source: "../settings/SettingsPageFileTypes.qml" },
        { id: "shell",         label: "Terminal",      icon: "󰆍", blurb: "Terminal app and aliases",          source: "../settings/SettingsPageShell.qml" },
        { id: "keybinds",      label: "Keybinds",      icon: "󰘳", blurb: "Shortcuts and presets",             source: "../settings/SettingsPageKeybinds.qml" },
        { id: "datetime",      label: "Date & Time",   icon: "󰥔", blurb: "Time zone and clock",               source: "../settings/SettingsPageDateTime.qml" },
        { id: "updates",       label: "Software Update", icon: "󰚰", blurb: "Checks, AUR and ignored",         source: "../settings/SettingsPageUpdates.qml" },
    ]
    readonly property var openPage: pages.find(p => p.id === currentPage) || null

    // --- Home's tiles: what each page is set to now --------------------------

    // only where it's cheap to know; a tile without one shows just its name
    // and what's inside
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: !!btAdapter && btAdapter.state === BluetoothAdapterState.Enabled
    readonly property var btConnected: btOn ? btAdapter.devices.values.filter(d => d.connected) : []

    function status(id) {
        switch (id) {
        case "network":
            if (Network.wired) return { text: "Wired · " + Network.wiredDevice }
            if (Network.ssid !== "") return { text: "Wi-Fi · " + Network.ssid, color: Theme.good }
            return { text: Network.powered ? "Not connected" : "Wi-Fi off" }
        case "bluetooth":
            if (!btAdapter) return { text: "No adapter" }
            if (!btOn) return { text: "Off" }
            return btConnected.length > 0
                ? { text: "On · " + btConnected.map(d => d.name).join(", "), color: Theme.good }
                : { text: "On" }
        case "audio":
            return Audio.ready
                ? { text: Audio.plainName(Audio.sink) + " · " + (Audio.muted ? "muted" : Audio.percent + "%") }
                : { text: "" }
        case "power": {
            var c = PpdProfile.choices.find(c => c.value === PpdProfile.profile)
            return { text: [c ? c.text : "", Battery.present ? Battery.percent + "%" : ""].filter(t => t).join(" · ") }
        }
        case "appearance": {
            var look = LookStore.looks[Settings.look], style = Styles.get(Settings.style)
            return { text: [look ? look.name : Settings.look, style ? style.name : ""].filter(t => t).join(" · ") }
        }
        case "notifications":
            return { text: Settings.notifDnd ? "Do Not Disturb on" : "" }
        case "shell":
            return { text: Settings.terminalApp.charAt(0).toUpperCase() + Settings.terminalApp.slice(1) }
        case "datetime":
            return { text: Settings.clock24 ? "24-hour" : "12-hour" }
        case "updates":
            return Updates.count > 0
                ? { text: Updates.count + (Updates.count === 1 ? " update ready" : " updates ready"), color: Theme.accent }
                : { text: Updates.lastChecked ? "Up to date" : "" }
        }
        return { text: "" }
    }
    // the devices' properties, which plainName() reads to shorten the
    // output's name, only arrive while something tracks them
    PwObjectTracker { objects: root.visible && root.currentPage === "" ? Audio.devices : [] }

    readonly property var homeGroups: groups.map(g => ({
        heading: g.heading,
        items: g.ids.map(id => {
            var p = pages.find(p => p.id === id), st = status(id)
            return { id: id, icon: p.icon, label: p.label, blurb: p.blurb, status: st.text, statusColor: st.color }
        })
    }))

    function select(pageId) {
        highlight = ""
        currentPage = pageId
        // a page's field may have had focus; give Escape back to the window
        chrome.keySink.forceActiveFocus()
    }

    // --- search ------------------------------------------------------------

    readonly property string query: searchBar.text.trim()
    readonly property var index: SettingsIndex.build(pages)
    // what the arrow keys walk: Home's tiles, or what matched
    readonly property var rows: query === ""
        ? pages.map(p => ({ page: p.id, label: p.label, blurb: p.blurb, icon: p.icon, isPage: true }))
        : SettingsIndex.search(index, query, 30).map(e => ({
            page: e.page, label: e.label, icon: e.icon, isPage: e.isPage,
            blurb: e.isPage ? "Section"
                : e.section === "" ? e.pageLabel : e.pageLabel + " · " + e.section,
            entry: e }))
    // the row the arrow keys are on; only drawn while the bar has focus
    property int cursor: 0
    readonly property bool searchFocused: searchBar.focused
    // walking Home's tiles: an empty query, with Home showing
    readonly property bool walkingHome: query === "" && currentPage === ""

    function focusSearch() { searchBar.forceFocus() }

    function moveCursor(delta) {
        if (rows.length === 0 || (query === "" && !walkingHome)) return
        cursor = (cursor + delta + rows.length) % rows.length
        if (walkingHome) home.reveal(rows[cursor].page)
        else list.reveal(cursor)
    }

    function activate(row) {
        if (row.isPage) select(row.page)
        else reveal(row.entry)
        searchBar.text = ""
        chrome.keySink.forceActiveFocus()
    }

    // Open the result's page and let it know which setting was asked for.
    // Setting highlight first means the Loader's onLoaded has it ready; when
    // the page is already open there is no reload, so it is handed over here.
    function reveal(entry) {
        highlight = entry.label
        if (currentPage === entry.page) {
            if (pane.item) pane.item.highlight = ""
            if (pane.item) pane.item.highlight = entry.label
        } else {
            currentPage = entry.page
        }
    }

    // this machine's name, for the subtitle, as System shows it
    FileView {
        id: hostFile
        path: "/proc/sys/kernel/hostname"
        printErrors: false
        blockLoading: true
    }

    WindowChrome {
        id: chrome
        window: root

        // `/` anywhere in the window, as long as no page field is typing:
        // the sink only sees keys nothing more local wanted, same as Escape
        Keys.onPressed: event => {
            if (event.text === "/") {
                root.focusSearch()
                event.accepted = true
            }
        }
    }

    // --- title bar, with the search in it ----------------------------------

    WindowHeader {
        id: header
        window: root
        title: "Settings"
        subtitle: hostFile.text().trim()
        page: root.openPage ? root.openPage.label : ""
        onBack: root.select("")
    }

    FlyoutInput {
        id: searchBar
        parent: header.slot
        anchors.fill: parent
        echoPassword: false
        glyph: "󰍉"
        placeholder: "Search settings"
        hints: focused ? ["Up/Down navigate", "Enter select"] : ["/ to focus"]

        onTextChanged: root.cursor = 0
        // however it got focus (`/` or a click), the arrows start from the
        // open section
        onFocusedChanged: if (focused)
            root.cursor = root.query === "" ? Math.max(0, root.pages.findIndex(p => p.id === root.currentPage)) : 0
        onDownPressed: root.moveCursor(1)
        onUpPressed: root.moveCursor(-1)
        onTabPressed: root.moveCursor(1)
        onBackTabPressed: root.moveCursor(-1)
        onAccepted: if (root.rows.length > 0 && (root.query !== "" || root.walkingHome))
            root.activate(root.rows[root.cursor])
        // first clear the query, then leave the bar; the window's own
        // Escape closes it after that
        onEscapePressed: {
            if (text !== "") text = ""
            else chrome.keySink.forceActiveFocus()
        }
    }

    // --- the panel: Home, the open page, or what the search matched ---------

    WindowPanel {
        id: panel
        anchors.top: header.bottom
        anchors.topMargin: Theme.spaceXl
        x: Theme.windowPad
        width: root.width - Theme.windowPad * 2
        // the window's real size, not the one asked for: the two differ
        // after a density or Font Size change while the window is open, which
        // leaves the window as it was and re-lays out what's inside
        height: root.height - y - Theme.windowPad

        WindowHome {
            id: home
            x: Theme.panelPad
            y: Theme.panelPad
            width: parent.width - Theme.panelPad * 2
            height: parent.height - Theme.panelPad * 2
            visible: root.walkingHome
            groups: root.homeGroups
            cursorId: root.searchFocused && root.rows.length > 0 ? root.rows[root.cursor].page : ""
            onActivated: id => root.select(id)
            onHovered: id => {
                if (root.searchFocused) root.cursor = root.rows.findIndex(r => r.page === id)
            }
        }

        // what the search matched, under a count, in Home's column
        Item {
            id: results
            visible: root.query !== ""
            readonly property int columnWidth: Math.min(Theme.fit(760), parent.width - Theme.panelPad * 2)
            x: Math.round((parent.width - columnWidth) / 2)
            y: Theme.panelPad
            width: columnWidth
            height: parent.height - Theme.panelPad * 2

            FlyoutHeading {
                id: listHeading
                width: parent.width
                text: root.rows.length === 1 ? "1 RESULT" : root.rows.length + " RESULTS"
            }

            Text {
                anchors.top: listHeading.bottom
                anchors.topMargin: Theme.spaceL
                x: Theme.spaceL
                visible: root.rows.length === 0
                text: "Nothing matches"
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }

            Flickable {
                id: list
                anchors.top: listHeading.bottom
                anchors.topMargin: Theme.spaceL
                anchors.bottom: parent.bottom
                width: parent.width
                contentHeight: listCol.implicitHeight
                interactive: contentHeight > height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                // keep the arrow keys' row on screen
                function reveal(i) {
                    var row = rowRepeater.itemAt(i)
                    if (!row) return
                    if (row.y < contentY) contentY = row.y
                    else if (row.y + row.height > contentY + height) contentY = row.y + row.height - height
                }

                Column {
                    id: listCol
                    width: list.width
                    spacing: 0

                    Repeater {
                        id: rowRepeater
                        model: root.query !== "" ? root.rows : []

                        SettingsSectionRow {
                            required property var modelData
                            required property int index
                            icon: modelData.icon
                            label: modelData.label
                            blurb: modelData.blurb || ""
                            current: root.searchFocused && root.cursor === index
                            onHovered: if (root.searchFocused) root.cursor = index
                            onClicked: root.activate(modelData)
                        }
                    }
                }
            }

            ScrollBar {
                anchors.right: list.right
                anchors.rightMargin: -Theme.spaceS
                flickable: list
            }
        }

        // the open page; kept while a search covers it, so its state lives on
        Loader {
            id: pane
            // sections folded on this window's pages (FlyoutHeading),
            // kept across page switches and dropped with the window
            property var foldedSections: []
            // the tab each tabbed page was left on (SettingsPage.tabs)
            property var pageTabs: ({})
            x: Theme.panelPad
            y: Theme.panelPad
            width: parent.width - Theme.panelPad * 2
            height: parent.height - Theme.panelPad * 2
            visible: root.query === ""
            active: root.visible && root.openPage !== null
            // built off the render loop, so the window maps at once and
            // the page lands a moment later instead of holding up both
            asynchronous: true
            onLoaded: {
                if (!item) return
                item.titled = false
                if (root.highlight !== "") item.highlight = root.highlight
            }
            source: root.openPage ? root.openPage.source : ""
        }
    }
}
