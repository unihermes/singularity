// Control Centre: dashboard, Pane split navigation, and Glass mosaic.
// Detail pages share services and stay inside the same flyout.

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
    menuWidth: Theme.style === "pane" ? Theme.flyoutMenuWidth + Theme.fs(360)
        : Theme.glass ? Theme.flyoutMenuWidth + Theme.fs(60) : Theme.flyoutMenuWidth + Theme.fs(120)
    // first module in the bar -- run it into the left corner
    edgeMargin: Theme.glass ? Theme.edgeMargin : 0

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
    property bool sampledOpen: false
    function opened() {
        if (sampledOpen) return
        sampledOpen = true
        SystemStats.sampleUptime()
        rfkillRead.running = true
        PpdProfile.refresh()
        page = scope.controlPage
        scope.controlPage = ""
    }
    Component.onCompleted: if (open) opened()
    onOpenChanged: if (open) opened()
        else { sampledOpen = false; page = "" }
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
        if (page === "network") Network.refreshList()
    }

    readonly property var pageTitles: ({
        "power": "POWER",
        "appearance": "APPEARANCE",
        "widgets": "BAR WIDGETS",
        "network": "NETWORK", "bluetooth": "BLUETOOTH", "sound": "SOUND",
        "display": "DISPLAY", "focus": "FOCUS", "tools": "SCREEN TOOLS"
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
    FileView { id: osFile; path: "/etc/os-release"; blockLoading: true }
    readonly property string osName: {
        var m = osFile.text().match(/^NAME="?([^"\n]*)"?$/m)
        return m ? m[1] : ""
    }

    function openModule(name) {
        var item = scope.barWindow ? scope.barWindow.widgetItem(name) : null
        if (item) scope.toggleFlyout(name, item)
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

    readonly property bool home: page === ""

    // The screen tools and standalone windows.
    readonly property var toolActions: [
        { icon: "󰹑", act: "screenshot", name: "Screenshot" },
        { icon: "󰈊", act: "colourpick", name: "Colour picker" },
        { icon: "󰊄", act: "copytext", name: "Copy text" },
    ].concat(!Recorder.available ? []
        : [{ icon: Recorder.recording ? "󰓛" : "󰑊", act: "record", name: Recorder.recording ? "Stop recording" : "Record" }]
    ).concat([
        { icon: "󰒓", act: "settings", name: "Settings" },
        { icon: "󰍛", act: "system", name: "System" },
        { icon: "󰌌", act: "keybinds", name: "Keybinds" },
    ])
    readonly property var shortDetail: ({
        lock: "Screen only", suspend: "Wakes in a second", hibernate: "Saves to disk",
        logout: "To the login screen", reboot: "Restarts", poweroff: "Powers off"
    })
    readonly property var confirmed: ["logout", "reboot", "poweroff"]
    readonly property var powerActions: Session.actions.concat([
        { act: "restartshell", label: "Restart Shell", icon: "󰑓", detail: "Reloads Quickshell" }
    ])

    HeadCard {
        id: accountHeader
        visible: !Theme.glass
        glyph: "󰣇"
        title: Quickshell.env("USER") + "@" + hostFile.text().trim()
        lines: [[controlCentre.osName, "up " + controlCentre.uptime].filter(s => s !== "").join(" · ")]

        IconButton {
            icon: "󰒓"
            implicitWidth: Theme.controlSize + Theme.spaceS
            implicitHeight: implicitWidth
            glyphSize: Theme.fontIconSize + Theme.spaceS
            onClicked: controlCentre.run("settings")
        }
        IconButton {
            icon: "󰌾"
            implicitWidth: Theme.controlSize + Theme.spaceS
            implicitHeight: implicitWidth
            glyphSize: Theme.fontIconSize + Theme.spaceS
            onClicked: controlCentre.run("lock")
        }
        IconButton {
            icon: "󰐥"
            implicitWidth: Theme.controlSize + Theme.spaceS
            implicitHeight: implicitWidth
            glyphSize: Theme.fontIconSize + Theme.spaceS
            onClicked: controlCentre.page = "power"
        }
    }

    Item {
        width: parent.width
        height: panelRow.height
        Row {
            id: panelRow
            width: parent.width
            spacing: Theme.style === "pane" ? Theme.spaceXl : 0
            Column {
                id: navigation
                visible: Theme.style === "pane"
                width: Theme.fs(160)
                spacing: Theme.spaceXs
                Repeater {
                    model: [
                        { key: "", label: "Overview", icon: "󰕮" },
                        { key: "network", label: "Network", icon: "󰤨" },
                        { key: "bluetooth", label: "Bluetooth", icon: "󰂯" },
                        { key: "sound", label: "Sound", icon: "󰕾" },
                        { key: "display", label: "Display", icon: "󰃠" },
                        { key: "focus", label: "Focus", icon: "󰖔" },
                        { key: "power", label: "Power", icon: "󰐥" },
                        { key: "appearance", label: "Appearance", icon: "󰏘" },
                        { key: "widgets", label: "Bar Widgets", icon: "󰕮" },
                        { key: "tools", label: "Screen tools", icon: "󰹑" },
                    ]
                    FlyoutRow {
                        required property var modelData
                        label: modelData.label
                        leadingIcon: modelData.icon
                        highlighted: controlCentre.page === modelData.key
                        onActivated: controlCentre.page = modelData.key
                    }
                }
            }
            Flickable {
                id: pageScroll
                width: parent.width - (navigation.visible ? navigation.width + parent.spacing : 0)
                height: Math.min(contentHeight, Math.max(Theme.rowHeightTall,
                    controlCentre.height - controlCentre.topOffset - controlCentre.padTop - controlCentre.padBottom
                        - (accountHeader.visible ? accountHeader.height + Theme.flyoutSpacing : 0)))
                contentHeight: pageBody.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick
                Connections {
                    target: controlCentre
                    function onPageChanged() { pageScroll.contentY = 0 }
                }
                Column {
                    id: pageBody
                    width: parent.width
                    spacing: Theme.flyoutSpacing
                    FlyoutHeading {
                        id: pageHeading
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

                    ControlCentreGlass {
                        id: glassHome
                        visible: controlCentre.home && Theme.glass
                        cc: controlCentre
                    }

                    ControlCentreHome {
                        visible: controlCentre.home && !Theme.glass
                        cc: controlCentre
                    }

                    ControlCentreDetails {
                        visible: ["network", "bluetooth", "sound", "display", "focus", "tools"].indexOf(controlCentre.page) >= 0
                        cc: controlCentre
                    }

                    Column {
                        id: appearancePage
                        visible: controlCentre.page === "appearance"
                        width: parent.width
                        spacing: Theme.flyoutSpacing
                        // its headings and rows get sections as if they sat in the panel
                        readonly property bool isSectionGroup: true
                        readonly property bool sectioned: true

                        FlyoutRow {
                        visible: Theme.style !== "pane"
                        leadingIcon: "󰕮"
                        label: "Bar Widgets"
                        trailingIcons: ["󰅂"]
                        onActivated: controlCentre.page = "widgets"
                    }

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

                    Column {
                        visible: controlCentre.page === "widgets"
                        width: parent.width
                        spacing: Theme.flyoutSpacing
                        readonly property bool isSectionGroup: true
                        readonly property bool sectioned: true
                        onVisibleChanged: if (!visible) controlCentre.widgetHover = ""

                        // a style's bar layout keeps an arrangement of its own
                        FlyoutRow {
                            visible: Settings.taskbarLayoutOn
                            label: Settings.layoutKind === "menubar" ? "Editing the Menu bar layout" : "Editing the Taskbar layout"
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

                    ControlCentrePowerGlass {
                        visible: controlCentre.page === "power" && Theme.glass
                        cc: controlCentre
                        fillHeight: glassHome.height - pageHeading.height - pageBody.spacing
                    }

                    Column {
                        visible: controlCentre.page === "power" && !Theme.glass
                        width: parent.width

                        FlyoutRow {
                            visible: Battery.present
                            label: "Battery"
                            trailing: Battery.percent + "%"
                            enabled: false
                        }
                        FlyoutSegmented {
                            visible: PpdProfile.profile !== ""
                            model: PpdProfile.choices
                            current: PpdProfile.profile
                            onPicked: v => PpdProfile.set(v)
                        }

                        Repeater {
                            model: controlCentre.powerActions

                            FlyoutRow {
                                id: powerRow
                                required property var modelData
                                readonly property bool hasTargets: modelData.act === "reboot" && Session.rebootTargets.length > 0
                                leadingIcon: modelData.icon
                                label: modelData.label
                                note: armed ? "" : controlCentre.shortDetail[modelData.act] || modelData.detail || ""
                                confirmText: controlCentre.confirmed.indexOf(modelData.act) !== -1 ? "Click again" : ""
                                reserve: hasTargets ? rebootOptions.width + Theme.spaceS : 0
                                onActivated: controlCentre.run(modelData.act)

                                IconButton {
                                    id: rebootOptions
                                    visible: powerRow.hasTargets
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    icon: controlCentre.expanded === "reboot" ? "󰅀" : "󰅂"
                                    onClicked: controlCentre.expand("reboot")
                                }
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
            }
        }
        ScrollBar {
            anchors.right: parent.right
            flickable: pageScroll
        }
    }
}
