// Singularity - Quickshell
// ~/.config/quickshell/flyouts/ControlCentre.qml
//
// The control centre flyout, as quick-settings tiles. Home: who and how
// long up (with lock and power), an app search whose matches take the
// tiles' place, the tiles (each says its state; a split chevron opens its
// details in place, a 󰅂 a page), then the screen tools and the windows as
// one row of buttons. Pages: Appearance, Bar Widgets and Power, each tiles
// too. Root's state and the standalone windows come in as required
// properties; the bar button's right click asks for Power through
// scope.controlPage.

import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import QtQuick
import "../services"
import "../services/Looks.js" as Looks
import "../services/Format.js" as Format

FlyoutPanel {
    id: controlCentre
    flyout: "controlcentre"
    menuWidth: Theme.flyoutMenuWidth + 40
    // first module in the bar -- run it into the left corner
    edgeMargin: 0

    required property var shellRoot
    required property var settingsWin
    required property var systemWin
    required property var keybindsWin

    // "" is home, anything else a page drawn in the same box
    property string page: ""
    // the one tile whose details are open, "" for none
    property string expanded: ""
    function expand(name) { expanded = expanded === name ? "" : name }

    // Opened on the page the bar asked for, home otherwise; the card's
    // uptime, the airplane state and the power profile are read each time.
    function opened() {
        SystemStats.sampleUptime()
        rfkillRead.running = true
        PpdProfile.refresh()
        page = scope.controlPage
        scope.controlPage = ""
    }
    Component.onCompleted: if (open) opened()
    onOpenChanged: if (open) opened()
        else { page = ""; appSearch.text = ""; browsingApps = false; searchOpen = false }
    Connections {
        target: controlCentre.scope
        function onControlPageChanged() {
            if (!controlCentre.open || controlCentre.scope.controlPage === "") return
            controlCentre.page = controlCentre.scope.controlPage
            controlCentre.scope.controlPage = ""
        }
    }
    onPageChanged: {
        expanded = ""
        if (page === "power") Session.refresh()
    }

    readonly property var pageTitles: ({
        "power": "POWER",
        "appearance": "APPEARANCE",
        "widgets": "BAR WIDGETS"
    })

    // airplane mode: an rfkill soft block on every radio, read on open and
    // after each toggle
    property bool airplane: false

    // A Process that is still running ignores a new command, so a toggle
    // made while the last one runs waits here; only the latest one counts.
    property var airplaneNext: null

    function setAirplane(on) {
        airplane = on
        airplaneNext = on
        if (!rfkillSet.running) applyAirplane()
    }

    function applyAirplane() {
        rfkillSet.command = ["rfkill", airplaneNext ? "block" : "unblock", "all"]
        airplaneNext = null
        rfkillSet.running = true
    }

    Process {
        id: rfkillRead
        command: ["rfkill", "-rn", "-o", "SOFT"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n").filter(l => l !== "")
                controlCentre.airplane = lines.length > 0 && lines.every(l => l.trim() === "blocked")
            }
        }
    }

    Process {
        id: rfkillSet
        onExited: {
            if (controlCentre.airplaneNext !== null) controlCentre.applyAirplane()
            else rfkillRead.running = true
        }
    }

    readonly property string uptime: Format.duration(SystemStats.uptimeSec)
    readonly property string lookName: (Looks.looks[Settings.look] || {}).name || Settings.look

    FileView { id: hostFile; path: "/proc/sys/kernel/hostname"; blockLoading: true }

    // the next of a list after `now`, round to the first
    function nextOf(list, now) {
        return list[(list.indexOf(now) + 1) % list.length]
    }

    function launch(entry) {
        scope.openFlyout = ""
        Apps.launch(entry)
    }

    function run(act) {
        scope.openFlyout = ""
        if (act === "settings") settingsWin.open("")
        else if (act === "system") systemWin.open()
        else if (act === "keybinds") keybindsWin.open()
        // the pause lets the flyout unmap before slurp/hyprpicker draw
        else if (act === "screenshot")
            Quickshell.execDetached(["sh", "-c", "sleep 0.2; ~/.config/hypr/screenshot.sh"])
        else if (act === "copytext")
            Quickshell.execDetached(["sh", "-c", "sleep 0.2; ~/.config/hypr/screenshot.sh text"])
        else if (act === "colourpick")
            Quickshell.execDetached(["sh", "-c", "sleep 0.2; ~/.config/hypr/colour-pick.sh"])
        else if (act === "record")
            Recorder.recording ? Recorder.stopRecording() : Recorder.startRecordingSoon()
        else if (act === "restartshell") Session.restartShell()
        else if (act.startsWith("into:")) Session.rebootInto(act.substring(5))
        else Session.run(act)
    }

    // the modules on the bar now, of every one there is
    readonly property var widgetKeys: {
        var l = Settings.widgetLayout()
        return Settings.widgetSections.reduce((a, s) => a.concat(l[s]), [])
    }
    readonly property int widgetsShown: widgetKeys.filter(k => Settings.widgetVisible(k)).length
    // the module square under the pointer, named in the heading
    property string widgetHover: ""

    // a submenu's heading leads with CONTROL CENTRE, the way back
    FlyoutHeading {
        visible: controlCentre.page !== ""
        crumb: "CONTROL CENTRE"
        text: controlCentre.pageTitles[controlCentre.page] || ""
        onCrumbClicked: controlCentre.page = ""
        hints: controlCentre.page === "appearance"
            ? (Settings.diffs.length > 0 ? [Settings.diffs.length + " changed"] : [])
            : controlCentre.page === "widgets"
            ? [controlCentre.widgetHover !== ""
                ? (Settings.widgetMeta[controlCentre.widgetHover] || {}).label
                : controlCentre.widgetsShown + " of " + controlCentre.widgetKeys.length]
            : controlCentre.page === "power"
            ? ["up " + controlCentre.uptime + " · since " + Qt.formatTime(SystemStats.bootTime, Theme.timeFormat)]
            : []
    }

    // --- Home -------------------------------------------------

    readonly property bool home: page === ""
    readonly property bool searching: home && (appQuery !== "" || browsingApps)
    property string appQuery: ""
    property bool browsingApps: false
    // the search field is out of the way until its button or a typed character opens it
    property bool searchOpen: false
    readonly property bool searchShown: searchOpen || appQuery !== "" || browsingApps
    onKeyPressed: event => {
        if (!home || searchShown || (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
                || event.text.length !== 1 || event.text < " ") return
        searchOpen = true
        appSearch.text = event.text
        Qt.callLater(appSearch.moveToEnd)
        event.accepted = true
    }
    property point lastPointer: Qt.point(-1, -1)

    HeadCard {
        visible: controlCentre.home
        glyph: "󰣇"
        title: Quickshell.env("USER") + "@" + hostFile.text().trim()
        lines: ["up " + controlCentre.uptime]
        compact: true

        IconButton {
            icon: "󰍉"
            onClicked: {
                controlCentre.searchOpen = !controlCentre.searchOpen
                if (controlCentre.searchOpen) Qt.callLater(appSearch.forceFocus)
                else appSearch.text = ""
            }
        }
        IconButton {
            icon: "󰌾"
            onClicked: controlCentre.run("lock")
        }
        IconButton {
            icon: "󰐥"
            implicitWidth: Theme.controlSize + Theme.spaceS
            implicitHeight: Theme.controlSize + Theme.spaceS
            glyphSize: Theme.fontIconSize + Theme.spaceS
            onClicked: controlCentre.page = "power"
        }
    }

    // typing anywhere in the panel lands here; matches replace the tiles
    FlyoutInput {
        id: appSearch
        visible: controlCentre.home && controlCentre.searchShown
        glyph: "󰍉"
        actionGlyph: "󰀻"
        actionLabel: "Browse applications"
        actionActive: controlCentre.browsingApps
        placeholder: "Search apps"
        echoPassword: false
        onTextChanged: {
            controlCentre.appQuery = text
            if (text !== "") controlCentre.browsingApps = false
            appView.currentIndex = 0
        }
        onActionClicked: {
            if (controlCentre.searching) {
                text = ""
                controlCentre.browsingApps = false
            } else {
                controlCentre.browsingApps = true
                appView.currentIndex = 0
            }
            forceFocus()
        }
        // Enter launches whatever is highlighted -- the top match until the
        // arrows move it
        onAccepted: if (appView.count > 0)
            controlCentre.launch(appView.model[appView.currentIndex])
        onDownPressed: if (appView.currentIndex < appView.count - 1) appView.currentIndex++
        onUpPressed: if (appView.currentIndex > 0) appView.currentIndex--
        onEscapePressed: {
            if (text !== "") text = ""
            else if (controlCentre.browsingApps) controlCentre.browsingApps = false
            else if (controlCentre.searchOpen) controlCentre.searchOpen = false
            else scope.openFlyout = ""
        }
    }

    FlyoutRow {
        visible: controlCentre.searching && appView.count === 0
        label: "No matches"
        enabled: false
    }

    ListView {
        id: appView
        visible: controlCentre.searching
        width: parent.width
        // eight rows, or fewer if there are fewer matches
        height: visible ? Math.min(contentHeight, 8 * (Theme.rowHeightTall + spacing)) : 0

        clip: true
        spacing: Theme.spaceXs
        boundsBehavior: Flickable.StopAtBounds
        model: visible ? Apps.list(controlCentre.appQuery, controlCentre.browsingApps) : []
        // keeps the arrow-key selection scrolled into view
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        delegate: Item {
            id: appRow
            required property var modelData
            required property int index
            width: appView.width
            height: Theme.rowHeightTall

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusInner
                color: appRow.ListView.isCurrentItem ? Theme.hoverFill : "transparent"
            }

            IconImage {
                id: appIcon
                anchors.left: parent.left
                anchors.leftMargin: Theme.spaceXs
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: Theme.fs(18)
                source: Quickshell.iconPath(appRow.modelData.icon, true)
            }

            Text {
                anchors.left: appIcon.right
                anchors.leftMargin: Theme.spaceL
                anchors.right: parent.right
                anchors.rightMargin: Theme.spaceS
                anchors.verticalCenter: parent.verticalCenter
                text: appRow.modelData.name
                elide: Text.ElideRight
                color: appRow.ListView.isCurrentItem ? Theme.textStrong : Theme.text
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontBody
            }

            MouseArea {
                id: appMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // one highlight shared by mouse and keys; on position, not
                // containsMouse, so keys scrolling rows under a still
                // pointer don't pull the selection back
                onPositionChanged: mouse => {
                    var p = appMouse.mapToGlobal(mouse.x, mouse.y)
                    if (p.x === controlCentre.lastPointer.x && p.y === controlCentre.lastPointer.y) return
                    controlCentre.lastPointer = p
                    appView.currentIndex = appRow.index
                }
                onClicked: controlCentre.launch(appRow.modelData)
            }
        }
    }

    FlyoutDivider { visible: controlCentre.home && !controlCentre.searching }

    Flow {
        id: tiles
        visible: controlCentre.home && !controlCentre.searching
        width: parent.width
        spacing: Theme.spaceS
        readonly property real cell: (width - spacing) / 2

        QuickTile {
            width: tiles.cell
            icon: Notifications.dnd ? "󰂛" : "󰂚"
            title: "Quiet"
            caption: Notifications.dnd ? "Banners held" : "Off"
            lit: Notifications.dnd
            onClicked: Notifications.toggleDnd()
        }
        QuickTile {
            width: tiles.cell
            icon: shellRoot.nightLight ? "󰖔" : "󰖙"
            title: "Night Light"
            caption: shellRoot.nightLight ? Settings.nightLightKelvin + " K" : "Off"
            lit: shellRoot.nightLight
            usable: shellRoot.hasHyprsunset
            split: true
            expanded: controlCentre.expanded === "night"
            onClicked: shellRoot.nightLight = !shellRoot.nightLight
            onMoreClicked: controlCentre.expand("night")
        }
        FlyoutSliderRow {
            visible: controlCentre.expanded === "night"
            width: tiles.width
            label: "Warmth"
            suffix: "K"
            step: 250
            value: Settings.nightLightKelvin
            minimum: Settings.limits.nightLightKelvin.min
            maximum: Settings.limits.nightLightKelvin.max
            onMoved: v => Settings.set("nightLightKelvin", v)
        }
        QuickTile {
            width: tiles.cell
            icon: shellRoot.keepAwake ? "󰅶" : "󰾪"
            title: "Keep Awake"
            caption: shellRoot.keepAwake ? "No sleep" : "Off"
            lit: shellRoot.keepAwake
            onClicked: shellRoot.keepAwake = !shellRoot.keepAwake
        }
        QuickTile {
            width: tiles.cell
            icon: "󰊴"
            title: "Game Mode"
            caption: GameMode.active ? "On" : "Off"
            lit: GameMode.active
            onClicked: GameMode.toggle()
        }
        // alone on its line while power-profiles-daemon isn't answering
        QuickTile {
            width: PpdProfile.profile !== "" ? tiles.cell : tiles.width
            icon: controlCentre.airplane ? "󰀝" : "󰀞"
            title: "Airplane"
            caption: controlCentre.airplane ? "Radios off" : "Off"
            lit: controlCentre.airplane
            onClicked: controlCentre.setAirplane(!controlCentre.airplane)
        }
        // a click steps to the next profile; the chevron shows all three
        QuickTile {
            visible: PpdProfile.profile !== ""
            width: tiles.cell
            icon: "󰓅"
            title: "Power"
            caption: (PpdProfile.choices.find(c => c.value === PpdProfile.profile) || { text: "" }).text
            split: true
            expanded: controlCentre.expanded === "profile"
            onClicked: PpdProfile.set(controlCentre.nextOf(PpdProfile.choices.map(c => c.value), PpdProfile.profile))
            onMoreClicked: controlCentre.expand("profile")
        }
        FlyoutSegmented {
            visible: controlCentre.expanded === "profile" && PpdProfile.profile !== ""
            width: tiles.width
            model: PpdProfile.choices
            current: PpdProfile.profile
            onPicked: v => PpdProfile.set(v)
        }
        QuickTile {
            width: tiles.cell
            icon: "󰏘"
            title: "Appearance"
            caption: controlCentre.lookName + (Wallpaper.title !== "" ? " · " + Wallpaper.title : "")
            goes: true
            onClicked: controlCentre.page = "appearance"
        }
        QuickTile {
            width: tiles.cell
            icon: "󰕮"
            title: "Bar Widgets"
            caption: controlCentre.widgetsShown + " of " + controlCentre.widgetKeys.length + " shown"
            goes: true
            onClicked: controlCentre.page = "widgets"
        }
    }

    FlyoutDivider { visible: controlCentre.home && !controlCentre.searching }

    // the screen tools, then the windows
    Row {
        id: toolsRow
        visible: controlCentre.home && !controlCentre.searching
        width: parent.width
        spacing: Theme.spaceS
        readonly property var actions: [
            { icon: "󰹑", act: "screenshot" },
            { icon: "󰈊", act: "colourpick" },
            { icon: "󰊄", act: "copytext" },
        ].concat(!Recorder.available ? []
            : [{ icon: Recorder.recording ? "󰓛" : "󰑊", act: "record" }]
        ).concat([
            { icon: "󰒓", act: "settings" },
            { icon: "󰍛", act: "system" },
            { icon: "󰌌", act: "keybinds" },
        ])

        Repeater {
            model: toolsRow.actions

            FlyoutChip {
                required property var modelData
                width: (toolsRow.width - toolsRow.spacing * (toolsRow.actions.length - 1)) / toolsRow.actions.length
                height: Theme.fieldHeight + Theme.spaceS
                glyph: true
                text: modelData.icon
                onClicked: controlCentre.run(modelData.act)
            }
        }
    }

    // --- Appearance -------------------------------------------
    // every look as a palette card, every wallpaper, then the rest as
    // tiles (details in place) and two controls; the whole of it is a chip
    // away in Settings

    Column {
        id: appearancePage
        visible: controlCentre.page === "appearance"
        width: parent.width
        spacing: Theme.flyoutSpacing
        // its headings and rows get sections as if they sat in the panel
        readonly property bool isSectionGroup: true
        readonly property bool sectioned: true

        // a look's palette, dark to light, then its accent if it has one
        function swatches(name) {
            var l = Looks.looks[name]
            if (!l) return []
            var p = l.palette
            return [p.base, p.border, p.subtext, p.text].concat(l.accent ? [l.accent] : [])
        }

        Grid {
            id: lookGrid
            width: parent.width
            columns: 4
            spacing: Theme.spaceXs
            readonly property real cell: (width - spacing * (columns - 1)) / columns

            Repeater {
                model: Looks.order

                Rectangle {
                    id: lookCard
                    required property string modelData
                    readonly property bool isCurrent: modelData === Settings.look
                    width: lookGrid.cell
                    height: lookCol.implicitHeight + Theme.spaceS * 2
                    radius: Theme.radiusInner
                    color: lookMouse.containsMouse ? Theme.hoverFill : Theme.base
                    border.width: isCurrent ? 2 : Theme.borderWidth
                    border.color: isCurrent ? Theme.selectedStroke : Theme.stroke

                    Column {
                        id: lookCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Theme.spaceS
                        spacing: Theme.spaceXs

                        Row {
                            id: band
                            width: parent.width
                            readonly property var colours: appearancePage.swatches(lookCard.modelData)
                            Repeater {
                                model: band.colours
                                Rectangle {
                                    required property string modelData
                                    width: band.width / band.colours.length
                                    height: Theme.spaceS
                                    color: modelData
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: (Looks.looks[lookCard.modelData] || {}).name || lookCard.modelData
                            color: lookCard.isCurrent ? Theme.textStrong : Theme.text
                            font.family: Theme.fontText
                            font.weight: Theme.weightBody
                            font.pixelSize: Theme.fontCaption
                        }
                    }

                    MouseArea {
                        id: lookMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Settings.set("look", lookCard.modelData)
                    }
                }
            }
        }

        FlyoutHeading {
            text: "WALLPAPER"
            hints: [Wallpaper.title !== "" ? Wallpaper.title : "None"]
        }

        // every wallpaper, four to a line, the one showing lit; shuffle last
        Grid {
            id: strip
            width: parent.width
            columns: 4
            spacing: Theme.spaceXs
            readonly property real cell: (width - spacing * (columns - 1)) / columns
            readonly property real thumbHeight: Math.round(cell * 0.625)

            Repeater {
                model: Wallpaper.images

                ClippingRectangle {
                    id: thumb
                    required property string modelData
                    readonly property bool isCurrent: modelData === Wallpaper.current
                    width: strip.cell
                    height: strip.thumbHeight
                    radius: Theme.radiusSmall
                    color: Theme.base

                    Image {
                        anchors.fill: parent
                        source: "file://" + thumb.modelData
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        // decoded at thumbnail size, not the wallpaper's 4K
                        sourceSize.width: 128
                    }

                    // the lit groove round the current one, a stroke on hover
                    Rectangle {
                        anchors.fill: parent
                        radius: thumb.radius
                        color: "transparent"
                        border.width: thumb.isCurrent ? 2 : Theme.borderWidth
                        border.color: thumb.isCurrent ? Theme.selectedStroke
                            : thumbMouse.containsMouse ? Theme.textStrong : Theme.stroke
                    }

                    MouseArea {
                        id: thumbMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Wallpaper.set(thumb.modelData)
                    }
                }
            }

            FlyoutChip {
                width: strip.cell
                height: strip.thumbHeight
                glyph: true
                text: "󰒝"
                enabled: Wallpaper.images.length > 1
                onClicked: Wallpaper.shuffle()
            }
        }

        FlyoutDivider {}

        Flow {
            id: lookTiles
            width: parent.width
            spacing: Theme.spaceS
            readonly property real cell: (width - spacing) / 2

            // the look's own colours, or tinted by the wallpaper
            QuickTile {
                width: lookTiles.cell
                icon: "󰏘"
                title: "Colours"
                caption: Settings.colourMode === "wallpaper"
                    ? "Wallpaper · " + Settings.choiceLabel(Settings.colourScheme) + (Wallpaper.generating ? " …" : "")
                    : "From the look"
                split: true
                expanded: controlCentre.expanded === "colours"
                onClicked: Settings.set("colourMode", Settings.colourMode === "wallpaper" ? "grayscale" : "wallpaper")
                onMoreClicked: controlCentre.expand("colours")
            }
            QuickTile {
                width: lookTiles.cell
                icon: "󰕰"
                title: "Style"
                caption: Settings.choiceLabel(Settings.style, "style")
                split: true
                expanded: controlCentre.expanded === "style"
                onClicked: Settings.set("style", controlCentre.nextOf(Settings.choices.style, Settings.style))
                onMoreClicked: controlCentre.expand("style")
            }
            Column {
                visible: controlCentre.expanded === "colours"
                width: lookTiles.width
                spacing: Theme.spaceS

                FlyoutSegmented {
                    model: [{ value: "grayscale", text: "Look" }, { value: "wallpaper", text: "Wallpaper" }]
                    current: Settings.colourMode
                    onPicked: v => Settings.set("colourMode", v)
                }
                // only means anything once the colours come from the image
                FlyoutSegmented {
                    visible: Settings.colourMode === "wallpaper"
                    model: Settings.choices.colourScheme.map(v => ({ value: v, text: Settings.choiceLabel(v) }))
                    current: Settings.colourScheme
                    onPicked: v => Settings.set("colourScheme", v)
                }
            }
            FlyoutSegmented {
                visible: controlCentre.expanded === "style"
                width: lookTiles.width
                model: Settings.choices.style.map(v => ({ value: v, text: Settings.choiceLabel(v, "style") }))
                current: Settings.style
                onPicked: v => Settings.set("style", v)
            }
            // two ends only, so a click is the whole choice
            QuickTile {
                width: lookTiles.cell
                icon: Settings.barPosition === "top" ? "󰁝" : "󰁅"
                title: "Bar"
                caption: Settings.barPosition === "top" ? "At the top" : "At the bottom"
                onClicked: Settings.set("barPosition", Settings.barPosition === "top" ? "bottom" : "top")
            }
            // the slider's named points; anything between them is Settings' to set
            QuickTile {
                id: motion
                readonly property var mark: Settings.animTimeMarks.find(m => m.at === Settings.animTime)
                width: lookTiles.cell
                icon: "󰄉"
                title: "Animations"
                caption: mark ? mark.label : Settings.animTime + "%"
                split: true
                expanded: controlCentre.expanded === "motion"
                onClicked: {
                    var next = Settings.animTimeMarks.find(m => m.at > Settings.animTime) || Settings.animTimeMarks[0]
                    Settings.set("animTime", next.at)
                }
                onMoreClicked: controlCentre.expand("motion")
            }
            FlyoutSegmented {
                visible: controlCentre.expanded === "motion"
                width: lookTiles.width
                model: Settings.animTimeMarks.map(m => ({ value: m.at, text: m.label }))
                current: Settings.animTime
                onPicked: v => Settings.set("animTime", v)
            }
        }

        FlyoutSliderRow {
            label: "See-through"
            inline: true
            suffix: "%"
            // fives: nothing between two of them is visible anyway
            step: 5
            value: Settings.seeThrough
            minimum: Settings.limits.seeThrough.min
            maximum: Settings.limits.seeThrough.max
            onMoved: v => Settings.set("seeThrough", v)
        }

        // a step a click: each one rescales this panel
        FlyoutStepper {
            label: "Font size"
            suffix: "px"
            value: Settings.fontSize
            minimum: Settings.limits.fontSize.min
            maximum: Settings.limits.fontSize.max
            onStepped: d => Settings.set("fontSize", Settings.fontSize + d)
        }

        FlyoutDivider {}

        Row {
            id: wayOut
            width: parent.width
            spacing: Theme.spaceS

            FlyoutChip {
                width: (wayOut.width - wayOut.spacing) / 2
                icon: "󰕌"
                text: "Reset"
                confirmText: "Reset?"
                enabled: !Settings.isDefault
                onClicked: Settings.reset()
            }

            // everything this page leaves out
            FlyoutChip {
                width: (wayOut.width - wayOut.spacing) / 2
                icon: "󰒓"
                text: "All settings"
                onClicked: scope.openSettings("appearance/colour")
            }
        }
    }

    // --- Bar Widgets ------------------------------------------
    // every module as a square, by where it sits, dim while hidden; a
    // click hides or shows it (Settings ignores it for the locked Control
    // Centre). Order is the bar's own edit mode.

    Column {
        visible: controlCentre.page === "widgets"
        width: parent.width
        spacing: Theme.flyoutSpacing
        readonly property bool isSectionGroup: true
        readonly property bool sectioned: true
        onVisibleChanged: if (!visible) controlCentre.widgetHover = ""

        // Flat's Taskbar layout keeps an arrangement of its own
        FlyoutRow {
            visible: Settings.taskbarLayoutOn
            label: "Editing the Taskbar layout"
            enabled: false
        }

        Repeater {
            model: Settings.widgetSections

            Column {
                id: zone
                required property string modelData
                readonly property var keys: Settings.widgetLayout()[modelData]
                visible: keys.length > 0
                width: parent.width
                spacing: Theme.spaceS

                FlyoutHeading {
                    text: zone.modelData === "centre" ? "CENTRE" : zone.modelData.toUpperCase()
                    hints: [zone.keys.filter(k => Settings.widgetVisible(k)).length + " of " + zone.keys.length]
                }

                Flow {
                    id: mods
                    width: parent.width
                    spacing: Theme.spaceXs
                    readonly property real cell: (width - spacing * 6) / 7

                    Repeater {
                        model: zone.keys

                        FlyoutChip {
                            required property string modelData
                            readonly property bool shown: Settings.widgetVisible(modelData)
                            width: mods.cell
                            height: mods.cell
                            glyph: true
                            text: (Settings.widgetMeta[modelData] || { icon: "" }).icon
                            opacity: shown ? 1 : 0.4
                            onHotChanged: {
                                if (hot) controlCentre.widgetHover = modelData
                                else if (controlCentre.widgetHover === modelData) controlCentre.widgetHover = ""
                            }
                            onClicked: Settings.setWidgetVisible(modelData, !shown)
                        }
                    }
                }
            }
        }

        FlyoutDivider {}

        Row {
            id: widgetChips
            width: parent.width
            spacing: Theme.spaceS

            FlyoutChip {
                width: (widgetChips.width - widgetChips.spacing) / 2
                icon: "󰏫"
                text: "Arrange on the bar"
                onClicked: controlCentre.scope.editBar()
            }
            FlyoutChip {
                width: (widgetChips.width - widgetChips.spacing) / 2
                icon: "󰕌"
                text: "Reset"
                confirmText: "Reset?"
                enabled: !Settings.widgetsDefault
                onClicked: Settings.resetWidgets()
            }
        }
    }

    // --- Power ----------------------------------------------
    // the power menu's actions as tiles, then Restart shell; the ones
    // that end the session take a second click. Reboot's chevron offers
    // the one-off reboots (Windows, BIOS), which the power menu leaves out.

    readonly property var shortDetail: ({
        lock: "Screen only", suspend: "Wakes in a second", hibernate: "Saves to disk",
        logout: "To the login screen", reboot: "Restarts", poweroff: "Powers off"
    })
    readonly property var confirmed: ["logout", "reboot", "poweroff"]
    readonly property var powerTiles: Session.actions.concat([
        { act: "restartshell", label: "Restart Shell", icon: "󰑓", detail: "Reloads Quickshell" }
    ])

    Flow {
        id: powerGrid
        visible: controlCentre.page === "power"
        width: parent.width
        spacing: Theme.spaceS
        readonly property real cell: (width - spacing) / 2

        Repeater {
            model: controlCentre.powerTiles

            QuickTile {
                required property var modelData
                required property int index
                readonly property bool odd: controlCentre.powerTiles.length % 2 === 1
                // an odd one out runs the width
                width: odd && index === controlCentre.powerTiles.length - 1 ? powerGrid.width : powerGrid.cell
                icon: modelData.icon
                title: modelData.label
                caption: controlCentre.shortDetail[modelData.act] || modelData.detail || ""
                confirmText: controlCentre.confirmed.indexOf(modelData.act) !== -1 ? "Click again" : ""
                split: modelData.act === "reboot" && Session.rebootTargets.length > 0
                expanded: controlCentre.expanded === "reboot"
                onClicked: controlCentre.run(modelData.act)
                onMoreClicked: controlCentre.expand("reboot")
            }
        }
    }

    FlyoutHeading {
        visible: controlCentre.page === "power" && controlCentre.expanded === "reboot"
        text: "REBOOT INTO"
    }

    FlyoutChipLine {
        visible: controlCentre.page === "power" && controlCentre.expanded === "reboot"
        onPicked: act => controlCentre.run(act)
        chips: Session.rebootTargets.map(t => ({ icon: t.icon, text: t.label, act: "into:" + t.act }))
    }
}
