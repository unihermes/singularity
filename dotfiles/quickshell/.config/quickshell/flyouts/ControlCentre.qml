// Singularity - Quickshell
// ~/.config/quickshell/flyouts/ControlCentre.qml
//
// The control centre flyout: its root page (the everyday toggles as tiles,
// the submenus, the screen tools, the windows) and every submenu. Root's
// state and the standalone windows come in as required properties.

import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import QtQuick
import "../services"
import "../bar"
import "../services/Looks.js" as Looks
import "../services/Styles.js" as Styles

FlyoutPanel {
    id: controlCentre
    flyout: "controlcentre"
    menuWidth: Theme.flyoutMenuWidth
    // first module in the bar -- run it into the left corner
    edgeMargin: 0

    required property var shellRoot
    required property var settingsWin
    required property var systemWin
    required property var keybindsWin

    // "" is the root list, anything else a submenu drawn in the same box
    property string page: ""
    // always reopen at the top level
    onOpenChanged: if (!open) page = ""

    property string appQuery: ""
    property point lastPointer: Qt.point(-1, -1)
    onPageChanged: if (page === "quick") {
        rfkillRead.running = true
    } else if (page === "power") {
        rebootOpen = false
        Session.refresh()
    } else if (page === "apps") {
        appQuery = ""
        appSearch.text = ""
        appView.currentIndex = 0
        // after the field has become visible, or focus is refused
        Qt.callLater(appSearch.forceFocus)
    }

    readonly property var pageTitles: ({
        "power": "POWER",
        "appearance": "APPEARANCE",
        "quick": "QUICK ACTIONS",
        "apps": "APPLICATIONS",
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

    function launch(entry) {
        scope.openFlyout = ""
        Apps.launch(entry)
    }

    function run(act) {
        scope.openFlyout = ""
        if (act === "settings") settingsWin.open()
        else if (act === "system") systemWin.open()
        else if (act === "keybinds") keybindsWin.open()
        // the pause lets the flyout unmap before slurp/hyprpicker draw
        else if (act === "screenshot")
            Quickshell.execDetached(["sh", "-c", "sleep 0.2; ~/.config/hypr/screenshot.sh"])
        else if (act === "copytext")
            Quickshell.execDetached(["sh", "-c", "sleep 0.2; ~/.config/hypr/screenshot.sh text"])
        else if (act === "colourpick")
            Quickshell.execDetached(["sh", "-c", "sleep 0.2; ~/.config/hypr/colour-pick.sh"])
        else if (act === "restartshell") Session.restartShell()
    }

    // a submenu's heading leads with CONTROL CENTRE, the way back
    FlyoutHeading {
        crumb: controlCentre.page === "" ? "" : "CONTROL CENTRE"
        text: controlCentre.page === ""
            ? "CONTROL CENTRE"
            : (controlCentre.pageTitles[controlCentre.page] || "")
        onCrumbClicked: controlCentre.page = ""
    }

    // Root: the everyday toggles as tiles, then the submenus, the screen
    // tools, and the standalone windows. `sub` opens a submenu, `act` runs.
    // Flat lists, so the sectioned frame sees the dividers.
    TileGrid {
        visible: controlCentre.page === ""
        columns: 2

        FlyoutTile {
            width: parent.cell
            clickable: true
            glyph: Notifications.dnd ? "󰂛" : "󰂚"
            title: "Do Not Disturb"
            caption: Notifications.dnd ? "On · popups held" : "Off"
            lit: Notifications.dnd
            onClicked: Notifications.toggleDnd()
        }
        FlyoutTile {
            width: parent.cell
            clickable: shellRoot.hasHyprsunset
            glyph: shellRoot.nightLight ? "󰖔" : "󰖙"
            title: "Night Light"
            caption: !shellRoot.hasHyprsunset ? "Not installed"
                : shellRoot.nightLight ? "On · " + Settings.nightLightKelvin + " K" : "Off"
            lit: shellRoot.nightLight
            dimmed: !shellRoot.hasHyprsunset
            onClicked: shellRoot.nightLight = !shellRoot.nightLight
        }
        FlyoutTile {
            width: parent.cell
            clickable: true
            glyph: shellRoot.keepAwake ? "󰅶" : "󰾪"
            title: "Keep Awake"
            caption: shellRoot.keepAwake ? "On" : "Off"
            lit: shellRoot.keepAwake
            onClicked: shellRoot.keepAwake = !shellRoot.keepAwake
        }
        FlyoutTile {
            width: parent.cell
            clickable: true
            glyph: "󰊴"
            title: "Game Mode"
            caption: GameMode.active ? "Effects and gaps off" : "Off"
            lit: GameMode.active
            onClicked: GameMode.toggle()
        }
    }

    Repeater {
        model: controlCentre.page === "" ? [
            { divider: true },
            { label: "Power",         sub: "power" },
            { label: "Applications",  sub: "apps" },
            { label: "Quick Actions", sub: "quick" },
            { label: "Appearance",    sub: "appearance" },
            { label: "Bar Widgets",   sub: "widgets" },
            { divider: true },
        ] : []

        Loader {
            id: entry
            required property var modelData
            readonly property bool isSectionBreak: modelData.divider === true
            width: parent ? parent.width : 0
            sourceComponent: isSectionBreak ? divider : row

            Component { id: divider; FlyoutDivider {} }
            Component {
                id: row
                FlyoutRow {
                    label: entry.modelData.label
                    trailing: "󰅂"
                    onActivated: controlCentre.page = entry.modelData.sub
                }
            }
        }
    }

    // the screen tools, side by side
    Row {
        visible: controlCentre.page === ""
        width: parent.width
        spacing: Theme.spaceS
        readonly property real cell: (width - spacing * 2) / 3
        FlyoutChip { width: parent.cell; icon: "󰹑"; text: "Shot"; onClicked: controlCentre.run("screenshot") }
        FlyoutChip { width: parent.cell; icon: "󰈊"; text: "Colour"; onClicked: controlCentre.run("colourpick") }
        FlyoutChip { width: parent.cell; icon: "󰊄"; text: "Text"; onClicked: controlCentre.run("copytext") }
    }

    FlyoutDivider { visible: controlCentre.page === "" }

    Repeater {
        model: controlCentre.page === "" ? [
            { label: "Settings", act: "settings" },
            { label: "System",   act: "system" },
            { label: "Keybinds", act: "keybinds" },
        ] : []

        FlyoutRow {
            required property var modelData
            label: modelData.label
            trailing: "󰁔"
            onActivated: controlCentre.run(modelData.act)
        }
    }

    // --- Applications -----------------------------------------
    // a scrolling list, as ~30 apps would run down the screen

    FlyoutInput {
        id: appSearch
        bleed: true
        visible: controlCentre.page === "apps"
        placeholder: "Search"
        echoPassword: false
        onTextChanged: {
            controlCentre.appQuery = text
            appView.currentIndex = 0
        }
        // Enter launches whatever is highlighted -- the top match
        // until the arrows move it
        onAccepted: if (appView.count > 0)
            controlCentre.launch(appView.model[appView.currentIndex])
        onDownPressed: if (appView.currentIndex < appView.count - 1) appView.currentIndex++
        onUpPressed: if (appView.currentIndex > 0) appView.currentIndex--
        onEscapePressed: scope.openFlyout = ""
    }

    FlyoutRow {
        visible: controlCentre.page === "apps" && appView.count === 0
        label: "No matches"
        enabled: false
    }

    ListView {
        id: appView
        visible: controlCentre.page === "apps"
        width: parent.width
        // 14 rows, or fewer if there are fewer apps
        height: visible ? Math.min(contentHeight, 14 * (Theme.rowHeightTall + spacing)) : 0

        clip: true
        spacing: Theme.spaceXs
        boundsBehavior: Flickable.StopAtBounds
        model: visible ? Apps.list(controlCentre.appQuery, true) : []
        // keeps the arrow-key selection scrolled into view
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        // back to the top each time the page opens
        onVisibleChanged: if (visible) positionViewAtBeginning()

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

    // --- Bar Widgets ------------------------------------------

    Column {
        visible: controlCentre.page === "widgets"
        width: parent.width
        spacing: Theme.flyoutSpacing

        // Flat's Taskbar layout keeps an arrangement of its own
        FlyoutRow {
            visible: Settings.taskbarLayoutOn
            label: "Taskbar layout, kept apart from yours"
            enabled: false
        }

        BarWidgetList {
            meta: Settings.widgetMeta
        }

        FlyoutDivider {}

        FlyoutRow {
            leadingIcon: "󰏫"
            label: "Edit on the bar"
            onActivated: controlCentre.scope.editBar()
        }

        FlyoutRow {
            label: "Reset to defaults"

            enabled: !Settings.widgetsDefault
            onActivated: Settings.resetWidgets()
        }
    }

    // --- Quick Actions ----------------------------------------
    // toggles stay open; the two momentary actions close the menu

    Column {
        visible: controlCentre.page === "quick"
        width: parent.width
        spacing: Theme.flyoutSpacing

        FlyoutAction {
            icon: controlCentre.airplane ? "󰀝" : "󰀞"
            label: "Airplane Mode"
            status: controlCentre.airplane ? "Wi-Fi and Bluetooth off" : ""
            checked: controlCentre.airplane
            onActivated: controlCentre.setAirplane(!controlCentre.airplane)
        }

        FlyoutAction {
            icon: shellRoot.keepAwake ? "󰅶" : "󰾪"
            label: "Keep Awake"
            checked: shellRoot.keepAwake
            onActivated: shellRoot.keepAwake = !shellRoot.keepAwake
        }

        FlyoutAction {
            icon: shellRoot.nightLight ? "󰖔" : "󰖙"
            label: "Night Light"
            status: !shellRoot.hasHyprsunset ? "hyprsunset not installed" : ""
            enabled: shellRoot.hasHyprsunset
            checked: shellRoot.nightLight
            onActivated: shellRoot.nightLight = !shellRoot.nightLight
        }

        // Do Not Disturb lives here as well as on the notification
        // module's right-click, since that module can be hidden
        FlyoutAction {
            icon: Notifications.dnd ? "󰂛" : "󰂚"
            label: "Do Not Disturb"
            checked: Notifications.dnd
            onActivated: Notifications.toggleDnd()
        }

        FlyoutAction {
            icon: "󰊴"
            label: "Game Mode"
            status: GameMode.active ? "Effects and gaps off" : ""
            checked: GameMode.active
            onActivated: GameMode.toggle()
        }

        // Only while it's on: a warmth control for a light that's off
        // is a setting you can't see the effect of.
        FlyoutStepper {
            visible: shellRoot.nightLight
            label: "Warmth"
            labelInset: Theme.iconCell + Theme.spaceL
            valueWidth: 52
            suffix: "K"
            value: Settings.nightLightKelvin
            minimum: Settings.limits.nightLightKelvin.min
            maximum: Settings.limits.nightLightKelvin.max
            // minus is warmer, which is the way the kelvin number goes
            // anyway, so the buttons need no inversion
            onStepped: d => Settings.step("nightLightKelvin", d * 250)
        }

        FlyoutDivider {}

        FlyoutAction {
            checkable: false
            icon: "󰹑"
            label: "Screenshot region"
            onActivated: controlCentre.run("screenshot")
        }

        FlyoutAction {
            checkable: false
            icon: "󰊄"
            label: "Copy text from region"
            onActivated: controlCentre.run("copytext")
        }

        FlyoutAction {
            checkable: false
            icon: "󰈊"
            label: "Colour picker"
            onActivated: controlCentre.run("colourpick")
        }

        FlyoutAction {
            checkable: false
            icon: "󰑓"
            label: "Restart shell"
            onActivated: controlCentre.run("restartshell")
        }
    }

    // --- Appearance -------------------------------------------
    // quick changes only (look, style, wallpaper, colours, bar, text size,
    // motion); the rest is a chip away in Settings > Appearance

    Column {
        id: appearancePage
        visible: controlCentre.page === "appearance"
        width: parent.width
        spacing: Theme.flyoutSpacing
        // its headings and rows get sections as if they sat in the panel
        readonly property bool isSectionGroup: true
        readonly property bool sectioned: true

        readonly property var styleOrder: Settings.choices.style
        function styleStep(d) {
            var n = styleOrder.length
            Settings.set("style", styleOrder[(styleOrder.indexOf(Settings.style) + d + n) % n])
        }
        readonly property var schemes: Settings.choices.colourScheme
        // the colours each mode gives, dark to light then the accent; the
        // wallpaper's only once matugen has made them for this image
        readonly property var ownColours: {
            var l = Looks.looks[Settings.look]
            if (!l) return []
            var p = l.palette
            return [p.base, p.border, p.subtext, p.text].concat(l.accent ? [l.accent] : [])
        }
        readonly property var wallColours: {
            var c = Wallpaper.wanted ? Wallpaper.palette
                : Wallpaper.cacheValid(Wallpaper.cache) && Wallpaper.cache.image === Wallpaper.current ? Wallpaper.cache.colors
                : null
            return c ? [c.base, c.muted, c.subtext, c.text, c.bright] : []
        }

        // one open list at a time; closed on the way out
        QtObject { id: selects; property var open: null }
        onVisibleChanged: if (!visible) selects.open = null

        // --- Look ---

        FlyoutHeading { text: "LOOK" }

        LookStepper { group: selects }

        FlyoutStepper {
            label: "Style"
            wrap: true
            valueWidth: 76
            displayValue: Settings.choiceLabel(Settings.style, "style")
            onStepped: d => appearancePage.styleStep(d)
        }

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: Styles.get(Settings.style).hint
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontCaption
        }

        // --- Wallpaper ---

        FlyoutHeading { text: "WALLPAPER" }

        // The picture is the control: click it for the next wallpaper, or
        // use the chips in its corner.
        ClippingRectangle {
            width: parent.width
            height: Math.round(width / 2)
            radius: Theme.radiusInner
            color: Theme.base
            border.width: Theme.borderWidth
            border.color: previewMouse.containsMouse ? Theme.strokeFocus : Theme.stroke

            Image {
                anchors.fill: parent
                source: Wallpaper.current !== "" ? "file://" + Wallpaper.current : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                // decoded at preview size, not the wallpaper's own 4K,
                // which would hold tens of MB for a thumbnail
                sourceSize.width: 480
            }

            MouseArea {
                id: previewMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Wallpaper.step(1)
            }

            // the name and the transport along the bottom, on a scrim so
            // they read over any image
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Theme.chipHeight + Theme.spaceS * 2
                color: Theme.captionScrim

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spaceM
                    anchors.right: transport.left
                    anchors.rightMargin: Theme.spaceS
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: Wallpaper.title !== "" ? Wallpaper.title : "No wallpaper"
                    color: Theme.textStrong
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontCaption
                }

                Row {
                    id: transport
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spaceS
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spaceXs
                    readonly property bool many: Wallpaper.images.length > 1

                    FlyoutChip { glyph: true; text: "󰒮"; enabled: transport.many; onClicked: Wallpaper.step(-1) }
                    FlyoutChip { glyph: true; text: "󰒝"; enabled: transport.many; onClicked: Wallpaper.shuffle() }
                    FlyoutChip { glyph: true; text: "󰒭"; enabled: transport.many; onClicked: Wallpaper.step(1) }
                }
            }
        }

        // every wallpaper, six to a line, the one showing lit
        Grid {
            id: strip
            visible: Wallpaper.images.length > 1
            width: parent.width
            columns: 6
            spacing: Theme.spaceXs
            readonly property real cell: (width - spacing * (columns - 1)) / columns

            Repeater {
                model: Wallpaper.images

                ClippingRectangle {
                    id: thumb
                    required property string modelData
                    readonly property bool isCurrent: modelData === Wallpaper.current
                    width: strip.cell
                    height: Math.round(strip.cell * 0.625)
                    radius: Theme.radiusSmall
                    color: Theme.base

                    Image {
                        anchors.fill: parent
                        source: "file://" + thumb.modelData
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 96
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
        }

        // colours: the look's own, or tinted by the picture above
        Row {
            id: colourTiles
            width: parent.width
            spacing: Theme.spaceS

            Repeater {
                model: [
                    { value: "grayscale", text: "Look's own", colours: appearancePage.ownColours },
                    { value: "wallpaper", text: "Wallpaper", colours: appearancePage.wallColours },
                ]

                Rectangle {
                    id: tile
                    required property var modelData
                    readonly property bool isCurrent: Settings.colourMode === modelData.value
                    width: (colourTiles.width - colourTiles.spacing) / 2
                    height: tileCol.implicitHeight + Theme.spaceS * 2
                    radius: Theme.radiusInner
                    color: tileMouse.containsMouse && !isCurrent ? Theme.hoverFill : Theme.fieldFill
                    border.width: isCurrent ? 2 : Theme.borderWidth
                    border.color: isCurrent ? Theme.selectedStroke
                        : tileMouse.containsMouse ? Theme.strokeHover : Theme.stroke

                    Column {
                        id: tileCol
                        x: Theme.spaceM
                        y: Theme.spaceS
                        width: parent.width - Theme.spaceM * 2
                        spacing: Theme.spaceXs

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: tile.modelData.text
                            color: tile.isCurrent ? Theme.textStrong : Theme.text
                            font.family: Theme.fontText
                            font.weight: Theme.weightBody
                            font.pixelSize: Theme.fontCaption
                        }

                        // its palette, or the picture itself until there is one
                        ClippingRectangle {
                            width: parent.width
                            height: Theme.fs(10)
                            radius: Theme.radiusSmall
                            color: Theme.base

                            Row {
                                visible: tile.modelData.colours.length > 0
                                anchors.fill: parent

                                Repeater {
                                    model: tile.modelData.colours

                                    Rectangle {
                                        required property var modelData
                                        width: parent.width / tile.modelData.colours.length
                                        height: parent.height
                                        color: modelData
                                    }
                                }
                            }

                            Image {
                                visible: tile.modelData.colours.length === 0
                                anchors.fill: parent
                                source: Wallpaper.current !== "" ? "file://" + Wallpaper.current : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 160
                            }
                        }
                    }

                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Settings.set("colourMode", tile.modelData.value)
                    }
                }
            }
        }

        // only means anything once the colours come from the image
        FlyoutStepper {
            visible: Settings.colourMode === "wallpaper"
            label: "Intensity"
            wrap: true
            valueWidth: 84
            displayValue: Settings.choiceLabel(Settings.colourScheme) + (Wallpaper.generating ? " …" : "")
            onStepped: d => {
                var n = appearancePage.schemes.length
                Settings.set("colourScheme", appearancePage.schemes[(appearancePage.schemes.indexOf(Settings.colourScheme) + d + n) % n])
            }
        }

        // --- Bar ---

        FlyoutHeading { text: "BAR" }

        FlyoutSegmented {
            label: "Position"
            model: [{ value: "top", text: "Top" }, { value: "bottom", text: "Bottom" }]
            current: Settings.barPosition
            onPicked: v => Settings.set("barPosition", v)
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

        // --- Text & motion ---

        FlyoutHeading { text: "TEXT & MOTION" }

        // a step a click: each one rescales this panel
        FlyoutStepper {
            label: "Font size"
            suffix: "px"
            value: Settings.fontSize
            minimum: Settings.limits.fontSize.min
            maximum: Settings.limits.fontSize.max
            onStepped: d => Settings.set("fontSize", Settings.fontSize + d)
        }

        // the slider's named points, across the line under the label;
        // anything between them is Settings' to set
        Text {
            text: "Animations"
            color: Theme.text
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontBody
        }

        FlyoutSegmented {
            model: Settings.animTimeMarks.map(m => ({ value: m.at, text: m.label }))
            current: Settings.animTime
            onPicked: v => Settings.set("animTime", v)
        }

        // --- the way out ---

        FlyoutDivider {}

        Row {
            id: wayOut
            width: parent.width
            spacing: Theme.spaceS

            FlyoutChip {
                width: (wayOut.width - wayOut.spacing) / 2
                icon: "󰕌"
                text: "Reset"
                confirmText: "Reset look?"
                enabled: !Settings.lookPristine
                onClicked: Settings.resetLook()
            }

            // everything this page leaves out
            FlyoutChip {
                width: (wayOut.width - wayOut.spacing) / 2
                text: "Settings  󰁔"
                onClicked: scope.openSettings("appearance")
            }
        }
    }

    // --- Power ----------------------------------------------
    // the power menu's glyphs; Reboot's chevron adds one-off reboots (Windows,
    // BIOS), which the power menu leaves out
    property bool rebootOpen: false

    Repeater {
        model: {
            if (controlCentre.page !== "power") return []
            const list = []
            for (const a of Session.actions) {
                list.push(a)
                if (a.act === "reboot" && controlCentre.rebootOpen)
                    for (const t of Session.rebootTargets)
                        list.push({ act: t.act, label: "Into " + t.label, icon: t.icon, into: true })
            }
            return list
        }

        FlyoutAction {
            id: powerRow
            required property var modelData
            readonly property bool hasMore: modelData.act === "reboot" && Session.rebootTargets.length > 0
            x: modelData.into ? Theme.iconCell : 0
            width: parent ? parent.width - x : 0
            checkable: false
            icon: modelData.icon
            label: modelData.label
            trailingInset: hasMore ? more.width : 0
            onActivated: {
                scope.openFlyout = ""
                if (modelData.into) Session.rebootInto(modelData.act)
                else Session.run(modelData.act)
            }

            IconButton {
                id: more
                visible: powerRow.hasMore
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: controlCentre.rebootOpen ? "󰅃" : "󰅀"
                onClicked: controlCentre.rebootOpen = !controlCentre.rebootOpen
            }
        }
    }
}
