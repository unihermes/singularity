// Singularity - Quickshell
// ~/.config/quickshell/windows/SettingsWindow.qml
//
// Settings: a title bar with the search, over one panel split by a
// hairline: the pages on the left (each with what it's set to now) and the
// open page on the right under its name. Typed into, the search lists its
// hits (SettingsIndex.js) in place of the pages; a hit opens its page and
// rings the setting. Changes apply at once, written straight to what they
// control. `/` focuses the search, where the arrow keys walk the pages;
// Escape clears, leaves the bar, then closes. It opens on the page it was
// left on (`lastPage`, kept by shell.qml); the page Loader exists only
// while visible.

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

    // the open page, and the one the window was last left on
    property string currentPage: pages[0].id
    property string lastPage: ""
    onCurrentPageChanged: lastPage = currentPage
    // the setting a search result picked, for the page to scroll to and ring
    property string highlight: ""

    visible: false
    title: "Settings"
    color: "transparent"

    implicitWidth: Theme.windowSize.width
    implicitHeight: Theme.windowSize.height

    // an unknown or empty page opens the last one
    function open(page) {
        var known = id => pages.some(p => p.id === id)
        currentPage = known(page) ? page : known(lastPage) ? lastPage : pages[0].id
        highlight = ""
        searchBar.text = ""
        visible = true
        Qt.callLater(() => nav.reveal(currentPage))
    }
    function close() { visible = false }

    // the compositor closing it has to clear visible, or the next open()
    // would be a no-op
    onClosed: visible = false
    onVisibleChanged: if (visible) chrome.keySink.forceActiveFocus()

    // the sidebar's groups, in order: connections, the machine itself, how
    // the desktop looks and behaves, apps, then the clock and updates
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
        { id: "appearance",    label: "Appearance",    icon: "󰏘", blurb: "Theme, bar and desktop",            source: "../settings/SettingsPageAppearance.qml" },
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

    // --- the sidebar: what each page is set to now ---------------------------

    // only where it's cheap to know; a page without one shows what's inside
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
            var look = Looks.looks[Settings.look], style = Styles.get(Settings.style)
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
    PwObjectTracker { objects: root.visible ? Audio.devices : [] }

    readonly property var navGroups: groups.map(g => ({
        heading: g.heading,
        items: g.ids.map(id => {
            var p = pages.find(p => p.id === id), st = status(id)
            return { id: id, icon: p.icon, label: p.label,
                     line: st.text || p.blurb, lineColor: st.text && st.color ? st.color : Theme.subtext }
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
    // what the arrow keys walk: the pages, or what matched
    readonly property var rows: query === ""
        ? pages.map(p => ({ page: p.id, label: p.label, blurb: p.blurb, icon: p.icon, isPage: true }))
        : SettingsIndex.search(index, query, 30).map(e => ({
            page: e.page, label: e.label, icon: e.icon, isPage: e.isPage,
            blurb: e.isPage ? "Section"
                : e.section === "" ? e.pageLabel : e.pageLabel + " · " + e.section,
            entry: e }))
    // the hit the arrow keys are on; only drawn while the bar has focus
    property int cursor: 0
    readonly property bool searchFocused: searchBar.focused

    function focusSearch() { searchBar.forceFocus() }

    // with no query the arrows open the next page at once
    function moveCursor(delta) {
        if (rows.length === 0) return
        if (query === "") {
            var i = pages.findIndex(p => p.id === currentPage)
            highlight = ""
            currentPage = pages[(i + delta + pages.length) % pages.length].id
            nav.reveal(currentPage)
            return
        }
        cursor = (cursor + delta + rows.length) % rows.length
        list.reveal(cursor)
    }

    function activate(row) {
        if (row.isPage) select(row.page)
        else reveal(row.entry)
        searchBar.text = ""
        chrome.keySink.forceActiveFocus()
    }

    // opens the result's page and hands it the setting (highlight first, so
    // a fresh page has it on load)
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
        onDownPressed: root.moveCursor(1)
        onUpPressed: root.moveCursor(-1)
        onTabPressed: root.moveCursor(1)
        onBackTabPressed: root.moveCursor(-1)
        onAccepted: if (root.rows.length > 0 && root.query !== "")
            root.activate(root.rows[root.cursor])
        // first clear the query, then leave the bar; the window's own
        // Escape closes it after that
        onEscapePressed: {
            if (text !== "") text = ""
            else chrome.keySink.forceActiveFocus()
        }
    }

    // --- the panel: the pages (or what the search matched), then the page --

    WindowPanel {
        id: panel
        anchors.top: header.bottom
        anchors.topMargin: Theme.spaceXl
        x: Theme.windowPad
        width: root.width - Theme.windowPad * 2
        // the window's real size (a Font Size change leaves the window as is)
        height: root.height - y - Theme.windowPad

        Item {
            id: side
            x: Theme.panelPad
            y: Theme.panelPad
            width: Theme.fit(260)
            height: parent.height - Theme.panelPad * 2

            Flickable {
                id: nav
                visible: root.query === ""
                anchors.fill: parent
                anchors.rightMargin: Theme.scrollGutter
                contentHeight: navCol.implicitHeight
                interactive: contentHeight > height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                // keep the open page's row on screen, for the arrow keys
                function reveal(id) {
                    for (var g = 0; g < navGroupRep.count; g++) {
                        var rows = navGroupRep.itemAt(g).rowRepeater
                        for (var r = 0; r < rows.count; r++) {
                            var row = rows.itemAt(r)
                            if (row.pageId !== id) continue
                            var y = row.mapToItem(navCol, 0, 0).y
                            if (y < contentY) contentY = y
                            else if (y + row.height > contentY + height) contentY = y + row.height - height
                            return
                        }
                    }
                }

                // packed so all the pages fit without scrolling
                Column {
                    id: navCol
                    width: nav.width
                    spacing: Theme.spaceS

                    Repeater {
                        id: navGroupRep
                        model: root.navGroups

                        Column {
                            id: navGroup
                            required property var modelData
                            property Item rowRepeater: navRows
                            width: navCol.width
                            spacing: 0

                            FlyoutHeading { width: parent.width; text: navGroup.modelData.heading.toUpperCase() }

                            Repeater {
                                id: navRows
                                model: navGroup.modelData.items

                                SettingsSectionRow {
                                    required property var modelData
                                    readonly property string pageId: modelData.id
                                    icon: modelData.icon
                                    label: modelData.label
                                    blurb: modelData.line
                                    blurbColor: modelData.lineColor
                                    current: root.currentPage === modelData.id
                                    onClicked: root.select(modelData.id)
                                }
                            }
                        }
                    }
                }
            }

            ScrollBar {
                anchors.right: parent.right
                anchors.top: nav.top
                height: nav.height
                visible: nav.visible && nav.interactive
                flickable: nav
            }

            // what the search matched, under a count
            Item {
                id: results
                visible: root.query !== ""
                anchors.fill: parent

                FlyoutHeading {
                    id: listHeading
                    width: parent.width - Theme.scrollGutter
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
                    anchors.topMargin: Theme.spaceS
                    anchors.bottom: parent.bottom
                    width: parent.width - Theme.scrollGutter
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
                    anchors.right: parent.right
                    anchors.top: list.top
                    height: list.height
                    flickable: list
                }
            }
        }

        // the hairline between the pages and the page
        Rectangle {
            id: split
            x: side.x + side.width + Theme.panelPad
            y: Theme.panelPad
            width: Theme.borderWidth
            height: parent.height - Theme.panelPad * 2
            color: Theme.stroke
        }

        Item {
            id: pageArea
            x: split.x + split.width + Theme.panelPad + Theme.spaceS
            y: Theme.panelPad
            width: parent.width - x - Theme.panelPad
            height: parent.height - Theme.panelPad * 2

            // the page's icon and name, large, over its own description
            Row {
                id: pageTitle
                x: Theme.spaceS
                spacing: Theme.spaceL
                height: Math.max(pageIcon.implicitHeight, pageName.implicitHeight) + Theme.spaceS

                Text {
                    id: pageIcon
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.openPage ? root.openPage.icon : ""
                    color: Theme.hasAccent ? Qt.lighter(Theme.accent, 1.4) : Theme.textStrong
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.fontTitle
                }

                Text {
                    id: pageName
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.openPage ? root.openPage.label : ""
                    color: Theme.textStrong
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontTitle
                    font.weight: Theme.weightStrong
                }
            }

            // the open page; built fresh on each switch
            Loader {
                id: pane
                // sections folded on this window's pages (FlyoutHeading),
                // kept across page switches and dropped with the window
                property var foldedSections: []
                // the tab each tabbed page was left on (SettingsPage.tabs)
                property var pageTabs: ({})
                anchors.top: pageTitle.bottom
                anchors.topMargin: Theme.spaceXs
                anchors.bottom: parent.bottom
                width: parent.width
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
}
