// Singularity - Quickshell
// ~/.config/quickshell/windows/SettingsWindow.qml
//
// Settings: a header, a search bar across the full width, and under it two
// framed panels -- the numbered Sections on the left, the open page on the
// right. Changes apply as they're made -- there is no Save -- and each page
// writes straight to the thing it controls (mimeapps.list, hyprland.lua,
// hypridle.conf, pipewire, swaync) rather than to a store of its own --
// except Appearance, whose shell half is Settings.qml, shared with the
// Control Centre's Appearance page.
//
// Its own FloatingWindow rather than a CentredWindow: that one is a single
// content-sized Column, and a fixed-size sidebar + pane doesn't fit it. The
// ground and Escape come from WindowChrome.qml, bare, since the header here
// is taller than its title row.
//
// Search: `/` (or a click) puts the cursor in the bar. Empty, the arrow keys
// walk the sections and Enter opens one; typed into, the Sections panel lists
// what matches from SettingsIndex.js instead -- whole sections and single
// settings -- and picking a setting opens its page and asks the page to
// scroll to it and ring it. Escape clears the query, then leaves the bar,
// then closes the window.
//
// No memory: every open starts on Appearance (or the page open() is asked
// for), and the page is a Loader that only exists while the window is
// visible, so nothing a page read or ran survives a close -- and nothing runs
// at all while Settings is shut.
//
// Floating and centring come from the "quickshell-windows" rule in
// hyprland.lua, as for System and Keybinds.

import Quickshell
import Quickshell.Io
import QtQuick
import "../services"
import "../settings"
import "../flyouts"
import "../services/SettingsIndex.js" as SettingsIndex

FloatingWindow {
    id: root

    readonly property string defaultPage: "appearance"
    property string currentPage: defaultPage
    // the setting a search result picked, for the page to scroll to and ring
    property string highlight: ""

    // scaled with Font Size, since the pages' own columns are
    readonly property int sidebarWidth: Theme.fs(240)
    // Keybinds' list is laid out for 720; the page frame adds its margin
    readonly property int paneWidth: Theme.fs(740)
    readonly property int paneHeight: Theme.windowBodyHeight

    visible: false
    title: "Settings"
    color: "transparent"

    implicitWidth: Theme.windowPad * 2 + sidebarWidth + Theme.spaceXl + paneWidth + Theme.panelPad * 2
    implicitHeight: panels.y + panels.height + Theme.windowPad

    // an unknown or empty page opens the default one
    function open(page) {
        currentPage = pages.some(p => p.id === page) ? page : defaultPage
        highlight = ""
        field.text = ""
        visible = true
    }
    function close() { visible = false }

    // the compositor closing it has to clear visible, or the next open()
    // would be a no-op
    onClosed: visible = false
    onVisibleChanged: if (visible) chrome.keySink.forceActiveFocus()

    readonly property var pages: [
        { id: "appearance",    label: "Appearance",    icon: "󰏘", blurb: "Look, colours and bar",             source: "../settings/SettingsPageAppearance.qml" },
        { id: "display",       label: "Display",       icon: "󰍹", blurb: "Resolution and scale",              source: "../settings/SettingsPageDisplay.qml" },
        { id: "audio",         label: "Audio",         icon: "󰕾", blurb: "Outputs and inputs",                source: "../settings/SettingsPageAudio.qml" },
        { id: "network",       label: "Network",       icon: "󰤨", blurb: "Wi-Fi and the link",               source: "../settings/SettingsPageNetwork.qml" },
        { id: "bluetooth",     label: "Bluetooth",     icon: "󰂯", blurb: "Adapter and devices",              source: "../settings/SettingsPageBluetooth.qml" },
        { id: "input",         label: "Input",         icon: "󰌌", blurb: "Keyboard and pointer",              source: "../settings/SettingsPageInput.qml" },
        { id: "power",         label: "Power & Idle",  icon: "󰂄", blurb: "Profile, idle and sleep",           source: "../settings/SettingsPagePower.qml" },
        { id: "notifications", label: "Notifications", icon: "󰂚", blurb: "Do Not Disturb, popups",            source: "../settings/SettingsPageNotifications.qml" },
        { id: "windowrules",   label: "Window Rules",  icon: "󰖲", blurb: "Layouts and app rules",             source: "../settings/SettingsPageWindowRules.qml" },
        { id: "keybinds",      label: "Keybinds",      icon: "󰘳", blurb: "Shortcuts and presets",             source: "../settings/SettingsPageKeybinds.qml" },
        { id: "shell",         label: "Terminal",      icon: "󰆍", blurb: "Alacritty and aliases",             source: "../settings/SettingsPageShell.qml" },
        { id: "filetypes",     label: "File Types",    icon: "󰈔", blurb: "Default apps",                      source: "../settings/SettingsPageFileTypes.qml" },
    ]

    function select(pageId) {
        highlight = ""
        currentPage = pageId
        // a page's field may have had focus; give Escape back to the window
        chrome.keySink.forceActiveFocus()
    }

    // --- search ------------------------------------------------------------

    readonly property string query: field.text.trim()
    readonly property var index: SettingsIndex.build(pages)
    // the Sections panel's rows: the sections themselves, or what matched
    readonly property var rows: query === ""
        ? pages.map((p, i) => ({ page: p.id, label: p.label, blurb: p.blurb, icon: p.icon, number: SettingsIndex.number(i), isPage: true }))
        : SettingsIndex.search(index, query, 30).map(e => ({
            page: e.page, label: e.label, icon: e.icon, number: e.number, isPage: e.isPage,
            blurb: e.isPage ? "Section"
                : e.section === "" ? e.pageLabel : e.pageLabel + " · " + e.section,
            entry: e }))
    // the row the arrow keys are on; only drawn while the bar has focus
    property int cursor: 0
    readonly property bool searchFocused: field.activeFocus

    function focusSearch() {
        field.forceActiveFocus()
        field.selectAll()
        cursor = query === "" ? Math.max(0, pages.findIndex(p => p.id === currentPage)) : 0
    }

    function moveCursor(delta) {
        if (rows.length === 0) return
        cursor = (cursor + delta + rows.length) % rows.length
        list.reveal(cursor)
    }

    function activate(row) {
        if (row.isPage) select(row.page)
        else reveal(row.entry)
        field.text = ""
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

    // the distribution's own name for itself, for the subtitle
    FileView {
        id: osRelease
        path: "/etc/os-release"
        printErrors: false
        blockLoading: true
    }
    readonly property string osName: {
        var m = /^PRETTY_NAME="?([^"\n]*)"?$/m.exec(osRelease.text())
        return m ? m[1] : "Linux"
    }

    WindowChrome {
        id: chrome
        window: root
        bare: true

        // `/` anywhere in the window, as long as no page field is typing:
        // the sink only sees keys nothing more local wanted, same as Escape
        Keys.onPressed: event => {
            if (event.text === "/") {
                root.focusSearch()
                event.accepted = true
            }
        }
    }

    // --- header ------------------------------------------------------------

    WindowHeader {
        id: header
        window: root
        eyebrow: "DESKTOP CONFIGURATION"
        title: "Settings"
        subtitle: root.osName + " / common desktop controls"
    }

    // --- search bar --------------------------------------------------------

    Rectangle {
        id: searchBar
        anchors.top: header.bottom
        anchors.topMargin: Theme.spaceXl
        x: Theme.windowPad
        width: root.width - Theme.windowPad * 2
        height: Theme.rowHeightTall + Theme.spaceM
        radius: Theme.radiusInner
        color: Theme.fieldFill
        border.width: Theme.borderWidth
        border.color: field.activeFocus ? Theme.strokeFocus : Theme.stroke

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onClicked: root.focusSearch()
        }

        Text {
            id: slash
            x: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            text: "/"
            color: field.activeFocus ? Theme.accent : Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontBody
        }

        Text {
            anchors.left: field.left
            anchors.verticalCenter: parent.verticalCenter
            visible: field.text === ""
            text: "Search settings and sections"
            color: Theme.textDisabled
            font.family: Theme.fontText
            font.pixelSize: Theme.fontBody
        }

        TextInput {
            id: field
            anchors.left: slash.right
            anchors.leftMargin: Theme.spaceL
            anchors.right: hints.left
            anchors.rightMargin: Theme.spaceXl
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            color: Theme.textStrong
            selectionColor: Theme.muted
            selectedTextColor: Theme.textStrong
            font.family: Theme.fontText
            font.pixelSize: Theme.fontBody

            onTextChanged: root.cursor = 0
            Keys.onDownPressed: root.moveCursor(1)
            Keys.onUpPressed: root.moveCursor(-1)
            Keys.onTabPressed: root.moveCursor(1)
            Keys.onBacktabPressed: root.moveCursor(-1)
            onAccepted: if (root.rows.length > 0) root.activate(root.rows[root.cursor])
            // first clear the query, then leave the bar; the window's own
            // Escape closes it after that
            Keys.onEscapePressed: {
                if (text !== "") text = ""
                else chrome.keySink.forceActiveFocus()
            }
        }

        Row {
            id: hints
            anchors.right: parent.right
            anchors.rightMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceXl

            Repeater {
                model: ["Up/Down navigate", "Enter select"]

                Text {
                    required property string modelData
                    text: modelData.toUpperCase()
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontEyebrow
                    font.letterSpacing: 1
                }
            }
        }
    }

    // --- panels ------------------------------------------------------------

    Item {
        id: panels
        anchors.top: searchBar.bottom
        anchors.topMargin: Theme.spaceXl
        x: Theme.windowPad
        width: root.width - Theme.windowPad * 2
        height: root.paneHeight + Theme.panelPad * 2

        // sections, or what the search matched
        WindowPanel {
            id: sidebar
            width: root.sidebarWidth
            height: parent.height

            FlyoutHeading {
                id: listHeading
                x: Theme.panelPad
                y: Theme.panelPad
                width: parent.width - Theme.panelPad * 2
                text: root.query === "" ? "SECTIONS"
                    : root.rows.length === 1 ? "1 RESULT" : root.rows.length + " RESULTS"
            }

            Text {
                anchors.top: listHeading.bottom
                anchors.topMargin: Theme.spaceL
                x: Theme.panelPad + Theme.spaceL
                visible: root.rows.length === 0
                text: "Nothing matches"
                color: Theme.subtext
                font.family: Theme.fontText
                font.pixelSize: Theme.fontSmall
            }

            Flickable {
                id: list
                anchors.top: listHeading.bottom
                anchors.topMargin: Theme.spaceL
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.panelPad
                x: Theme.panelPad
                width: parent.width - Theme.panelPad * 2
                contentHeight: listCol.implicitHeight
                interactive: contentHeight > height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                // keep the arrow keys' row on screen; rows are all one height
                function reveal(i) {
                    if (listCol.children.length === 0) return
                    var h = listCol.children[0].height + listCol.spacing
                    var top = i * h
                    if (top < contentY) contentY = top
                    else if (top + h > contentY + height) contentY = top + h - height
                }

                Column {
                    id: listCol
                    width: list.width
                    spacing: Theme.spaceXs

                    Repeater {
                        model: root.rows

                        SettingsSectionRow {
                            required property var modelData
                            required property int index
                            icon: modelData.icon
                            number: modelData.number
                            label: modelData.label
                            blurb: modelData.blurb
                            selected: modelData.isPage && root.currentPage === modelData.page
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

        // the open page
        WindowPanel {
            id: content
            anchors.left: sidebar.right
            anchors.leftMargin: Theme.spaceXl
            anchors.right: parent.right
            height: parent.height

            Loader {
                id: pane
                x: Theme.panelPad
                y: Theme.panelPad
                width: root.paneWidth
                height: root.paneHeight
                active: root.visible
                onLoaded: if (item && root.highlight !== "") item.highlight = root.highlight
                source: {
                    var p = root.pages.find(p => p.id === root.currentPage)
                    return p && p.source ? p.source : ""
                }
            }
        }
    }
}
