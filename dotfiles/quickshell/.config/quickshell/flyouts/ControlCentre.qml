// Singularity - Quickshell
// ~/.config/quickshell/flyouts/ControlCentre.qml
//
// The control centre flyout, split out of shell.qml: every page, menu
// entry, and submenu it drills into. Needs the bar and root's state
// (network/bluetooth/volume readouts, Keep Awake, Night Light) and the
// shell's standalone windows, so those come in as required properties
// rather than being looked up by id -- this file can't see ids declared
// in shell.qml.

import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Io
import QtQuick
import "../services"
import "../bar"

FlyoutPanel {
    id: controlCentre
    flyout: "controlcentre"
    menuWidth: 230
    // first module in the bar -- run it into the left corner
    edgeMargin: 0

    required property var shellRoot
    required property var settingsWin
    required property var systemWin
    required property var keybindsWin

    // Drill-down rather than nested pop-out panels: "" is the root
    // list and anything else is a submenu drawn in the same box. A
    // second floating panel would have to track the first one's
    // geometry and its own click-off, for a menu this size.
    property string page: ""
    // always reopen at the top level
    onOpenChanged: if (!open) page = ""
    keyboardExclusive: open && page === "apps"

    property string appQuery: ""
    property point lastPointer: Qt.point(-1, -1)
    // Re-read the saved layout each time the page opens, so the
    // lists never show an order from before a reset or a hand edit.
    onPageChanged: if (page === "quick") {
        rfkillRead.running = true
    } else if (page === "widgets") {
        widgetsList.refill()
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

    // Airplane mode is an rfkill soft block on every radio. Read on open
    // and after each toggle rather than watched: nothing else here
    // changes it often enough to be worth a poll.
    property bool airplane: false

    function setAirplane(on) {
        airplane = on
        rfkillSet.command = ["rfkill", on ? "block" : "unblock", "all"]
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
        onExited: rfkillRead.running = true
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
        else if (act === "lock") Quickshell.execDetached(["hyprlock"])
        else if (act === "suspend") Quickshell.execDetached(["systemctl", "suspend"])
        // hl.dsp.exit() only kills the compositor -- start-hyprland (the
        // hyprland package's own session wrapper, PID 1 of the logind
        // session scope) treats that as a crash and immediately relaunches
        // it, so nothing ever visibly closes. Killing the whole logind
        // session scope instead ends everything in it and drops back to
        // the ly login screen.
        else if (act === "logout") Quickshell.execDetached(["sh", "-c", "loginctl terminate-session \"$XDG_SESSION_ID\""])
        else if (act === "reboot") Quickshell.execDetached(["systemctl", "reboot"])
        else if (act === "poweroff") Quickshell.execDetached(["systemctl", "poweroff"])
        // The pause lets the flyout's surface unmap first. slurp and
        // hyprpicker both draw on the overlay layer too, and without
        // it the menu is still on screen for their first frame --
        // in the picker's case, close enough to pick its own pixels.
        else if (act === "screenshot")
            Quickshell.execDetached(["sh", "-c", "sleep 0.2; ~/.config/hypr/screenshot.sh"])
        else if (act === "colourpick")
            Quickshell.execDetached(["sh", "-c", "sleep 0.2; ~/.config/hypr/colour-pick.sh"])
        // relaunched the way hyprland.lua starts it, so the log stays in one place
        else if (act === "restartshell")
            Quickshell.execDetached(["sh", "-c", "qs kill; sleep 0.3; exec quickshell > ~/.cache/quickshell.log 2>&1"])
    }

    FlyoutHeading {
        text: controlCentre.page === ""
            ? "CONTROL CENTRE"
            : (controlCentre.pageTitles[controlCentre.page] || "")
    }

    FlyoutRow {
        visible: controlCentre.page !== ""
        label: "󰅁  Back"
        onActivated: controlCentre.page = ""
    }

    // root: everyday things, then customising the shell, then the
    // standalone windows, and Power on its own at the bottom where it
    // can't be hit on the way to something else. `sub` opens a submenu,
    // `act` runs straight away.
    Repeater {
        model: controlCentre.page === "" ? [
            [
                { label: "Quick Actions", sub: "quick" },
                { label: "Applications",  sub: "apps" },
            ], [
                { label: "Appearance",    sub: "appearance" },
                { label: "Bar Widgets",   sub: "widgets" },
            ], [
                { label: "Settings",      act: "settings" },
                { label: "System",        act: "system" },
                { label: "Keybinds",      act: "keybinds" },
            ], [
                { label: "Power",         sub: "power" },
            ],
        ] : []

        Column {
            id: group
            required property var modelData
            required property int index
            width: parent.width
            spacing: controlCentre.contentColumn.spacing

            FlyoutDivider { visible: group.index > 0 }

            Repeater {
                model: group.modelData

                FlyoutRow {
                    required property var modelData
                    label: modelData.label
                    trailing: modelData.sub ? "󰅂" : ""
                    onActivated: modelData.sub
                        ? controlCentre.page = modelData.sub
                        : controlCentre.run(modelData.act)
                }
            }
        }
    }

    // --- Applications -----------------------------------------
    // A list rather than rows in the column: at ~30 apps the panel
    // would run most of the way down the screen, so it scrolls
    // inside a fixed-height window instead.

    FlyoutInput {
        id: appSearch
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
        model: visible ? Apps.list(controlCentre.appQuery) : []
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
                anchors.leftMargin: 9
                anchors.right: parent.right
                anchors.rightMargin: Theme.spaceS
                anchors.verticalCenter: parent.verticalCenter
                text: appRow.modelData.name
                elide: Text.ElideRight
                color: appRow.ListView.isCurrentItem ? Theme.textStrong : Theme.text
                font.family: Theme.fontText
                font.pixelSize: Theme.fontBody
            }

            MouseArea {
                id: appMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // one highlight shared by mouse and keys: hovering
                // moves the selection rather than drawing a second one
                // position, not containsMouse: arrow keys scroll rows under a
                // still pointer, which would otherwise pull the selection back
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
        spacing: Theme.spaceM

        BarWidgetList {
            id: widgetsList
            meta: Settings.widgetMeta
        }

        FlyoutDivider {}

        FlyoutRow {
            label: "Reset to Defaults"

            enabled: !Settings.widgetsDefault
            onActivated: {
                Settings.resetWidgets()
                widgetsList.refill()
            }
        }
    }

    // --- Quick Actions ----------------------------------------
    // Toggles stay open after a click, so you can flip several in a
    // row and watch each switch settle. The two momentary actions
    // close the menu, since both need the screen clear.

    Column {
        visible: controlCentre.page === "quick"
        width: parent.width
        spacing: Theme.spaceM

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
        // module's right-click, because that module hides itself when
        // nothing is unread -- this is the one place it's always reachable.
        FlyoutAction {
            icon: Notifications.dnd ? "󰂛" : "󰂚"
            label: "Do Not Disturb"
            status: !Notifications.available ? "swaync not running" : ""
            enabled: Notifications.available
            checked: Notifications.dnd
            onActivated: Notifications.toggleDnd()
        }

        // Only while it's on: a warmth control for a light that's off
        // is a setting you can't see the effect of.
        FlyoutStepper {
            visible: shellRoot.nightLight
            label: "Warmth"
            labelInset: 28
            valueWidth: 44
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
            label: "Screenshot Region"
            onActivated: controlCentre.run("screenshot")
        }

        FlyoutAction {
            checkable: false
            icon: "󰈊"
            label: "Colour Picker"
            onActivated: controlCentre.run("colourpick")
        }

        FlyoutAction {
            checkable: false
            icon: "󰑓"
            label: "Restart Shell"
            onActivated: controlCentre.run("restartshell")
        }
    }

    // --- Appearance -------------------------------------------
    // One Column per page, so its rows share a single visibility
    // switch.

    Column {
        id: appearancePage
        visible: controlCentre.page === "appearance"
        width: parent.width
        spacing: Theme.spaceM

        function label(v) { return Settings.choiceLabel(v) }

        FlyoutHeading { text: "LOOK" }

        Item {
            width: parent.width
            height: Theme.chipHeight

            Text {
                anchors.left: parent.left
                anchors.right: lookButtons.left
                anchors.rightMargin: Theme.spaceL
                anchors.verticalCenter: parent.verticalCenter
                text: appearancePage.label(Settings.look) + (Settings.lookPristine ? "" : " *")
                elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.fontText
                font.pixelSize: Theme.fontBody
            }

            Row {
                id: lookButtons
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spaceS

                FlyoutChip { glyph: true; text: "󰒮"; onClicked: Settings.cycle("look", -1) }
                FlyoutChip { glyph: true; text: "󰒭"; onClicked: Settings.cycle("look", 1) }
            }
        }

        FlyoutRow {
            label: "Frames"
            trailingIsValue: true
            trailing: appearancePage.label(Settings.frameStyle)
            onActivated: Settings.cycle("frameStyle")
        }

        FlyoutRow {
            label: "Density"
            trailingIsValue: true
            trailing: appearancePage.label(Settings.density)
            onActivated: Settings.cycle("density")
        }

        // arrows rather than click-to-cycle: with a dozen fonts, going back
        // one shouldn't mean clicking through all the others
        Item {
            width: parent.width
            height: Theme.chipHeight

            Text {
                id: fontLabel
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Font"
                color: Theme.text
                font.family: Theme.fontText
                font.pixelSize: Theme.fontBody
            }

            Text {
                anchors.left: fontLabel.right
                anchors.leftMargin: Theme.spaceL
                anchors.right: fontButtons.left
                anchors.rightMargin: Theme.spaceS
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: appearancePage.label(Settings.fontFamily)
                elide: Text.ElideRight
                color: Theme.subtext
                font.family: Theme.fontText
                font.pixelSize: Theme.fontBody
            }

            Row {
                id: fontButtons
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spaceS

                FlyoutChip { glyph: true; text: "󰒮"; onClicked: Settings.cycle("fontFamily", -1) }
                FlyoutChip { glyph: true; text: "󰒭"; onClicked: Settings.cycle("fontFamily", 1) }
            }
        }

        FlyoutHeading { text: "WALLPAPER" }

        // click-through preview: the fastest way to flick through
        ClippingRectangle {
            width: parent.width
            height: Math.round(width * 9 / 16)
            radius: Theme.radiusInner
            color: Theme.base
            border.width: Theme.borderWidth
            border.color: previewMouse.containsMouse ? Theme.strokeFocus : Theme.stroke

            Image {
                anchors.fill: parent
                source: Wallpaper.current !== "" ? "file://" + Wallpaper.current : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                // decoded at preview size, not the wallpaper's own
                // 4K, which would hold tens of MB for a thumbnail
                sourceSize.width: 480
            }

            MouseArea {
                id: previewMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Wallpaper.step(1)
            }
        }

        Item {
            width: parent.width
            height: Theme.chipHeight

            Text {
                anchors.left: parent.left
                anchors.right: wpButtons.left
                anchors.rightMargin: Theme.spaceL
                anchors.verticalCenter: parent.verticalCenter
                text: Wallpaper.name !== "" ? Wallpaper.name : "No wallpaper"
                elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.fontText
                font.pixelSize: Theme.fontBody
            }

            Row {
                id: wpButtons
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spaceS

                FlyoutChip { glyph: true; text: "󰒮"; enabled: Wallpaper.images.length > 1; onClicked: Wallpaper.step(-1) }
                FlyoutChip { glyph: true; text: "󰒝"; enabled: Wallpaper.images.length > 1; onClicked: Wallpaper.shuffle() }
                FlyoutChip { glyph: true; text: "󰒭"; enabled: Wallpaper.images.length > 1; onClicked: Wallpaper.step(1) }
            }
        }

        FlyoutRow {
            // Random: a different wallpaper every login. Static: the
            // one showing now, kept until you pick another.
            label: "At Login"
            trailingIsValue: true
            trailing: Settings.wallpaperShuffle ? "Random" : "Static"
            onActivated: Settings.setWallpaperShuffle(!Settings.wallpaperShuffle)
        }

        FlyoutHeading { text: "COLOURS" }

        FlyoutRow {
            label: "Palette"
            trailingIsValue: true
            trailing: appearancePage.label(Settings.colourMode)
            onActivated: Settings.cycle("colourMode")
        }

        // only means anything once the colours come from the image
        FlyoutRow {
            label: "Intensity"
            trailingIsValue: true
            visible: Settings.colourMode === "wallpaper"
            trailing: Wallpaper.generating ? "…" : appearancePage.label(Settings.colourScheme)
            onActivated: Settings.cycle("colourScheme")
        }

        FlyoutHeading { text: "BAR" }

        FlyoutRow {
            label: "Position"
            trailingIsValue: true
            trailing: Settings.barPosition === "bottom" ? "Bottom" : "Top"
            onActivated: Settings.set("barPosition",
                Settings.barPosition === "top" ? "bottom" : "top")
        }

        FlyoutStepper {
            label: "Height"
            value: Settings.barHeight
            minimum: Settings.limits.barHeight.min
            maximum: Settings.limits.barHeight.max
            onStepped: d => Settings.step("barHeight", d)
        }

        FlyoutStepper {
            label: "Module Gap"
            value: Settings.moduleGap
            minimum: Settings.limits.moduleGap.min
            maximum: Settings.limits.moduleGap.max
            onStepped: d => Settings.step("moduleGap", d)
        }

        FlyoutStepper {
            label: "Corner Radius"
            value: Settings.radius
            minimum: Settings.limits.radius.min
            maximum: Settings.limits.radius.max
            onStepped: d => Settings.step("radius", d)
        }

        FlyoutStepper {
            label: "Opacity"
            value: Settings.barOpacity
            minimum: Settings.limits.barOpacity.min
            maximum: Settings.limits.barOpacity.max
            suffix: "%"
            valueWidth: 44
            onStepped: d => Settings.step("barOpacity", d * 5)
        }

        FlyoutHeading { text: "TEXT & MOTION" }

        FlyoutStepper {
            label: "Font Size"
            value: Settings.fontSize
            minimum: Settings.limits.fontSize.min
            maximum: Settings.limits.fontSize.max
            suffix: "px"
            valueWidth: 44
            onStepped: d => Settings.step("fontSize", d)

        }

        FlyoutRow {
            label: "Animations"
            trailingIsValue: true
            trailing: appearancePage.label(Settings.animSpeed)
            onActivated: Settings.cycle("animSpeed")
        }

        FlyoutDivider {}

        FlyoutRow {
            label: "Reset Look"
            enabled: !Settings.lookPristine
            onActivated: Settings.resetLook()
        }

        // Save the current appearance as the default Reset returns to. Asks
        // twice, like FlyoutRow's other destructive actions: the first click
        // arms it, a second within a few seconds saves.
        FlyoutRow {
            id: saveDefaultRow
            property bool armed: false
            label: armed ? "Click again to save" : "Set as Default"
            trailing: Settings.isDefault ? "saved" : ""
            enabled: !Settings.isDefault
            onActivated: {
                if (!armed) { armed = true; saveDisarm.restart(); return }
                armed = false
                Settings.saveAsDefault()
            }
            Timer { id: saveDisarm; interval: 3000; onTriggered: saveDefaultRow.armed = false }
        }

        FlyoutRow {
            label: "Reset to Default"

            // greyed out when there is nothing to reset, so the row
            // doubles as a "this is the default" indicator
            enabled: !Settings.isDefault
            onActivated: Settings.reset()
        }

        FlyoutRow {
            label: "Factory Reset"
            visible: Settings.hasUserDefault
            onActivated: Settings.factoryReset()
        }


        // the full page: every wallpaper at once, and Hyprland's windows
        FlyoutRow {
            label: "More in Settings"
            trailing: "󰁔"
            onActivated: {
                scope.openFlyout = ""
                settingsWin.open("appearance")
            }
        }
    }

    // --- Power ----------------------------------------------
    Repeater {
        model: controlCentre.page === "power" ? [
            { label: "Lock",      act: "lock" },
            { label: "Suspend",   act: "suspend" },
            { label: "Log Out",   act: "logout" },
            { label: "Reboot",    act: "reboot" },
            { label: "Shut Down", act: "poweroff" },
        ] : []

        FlyoutRow {
            required property var modelData
            label: modelData.label
            onActivated: controlCentre.run(modelData.act)
        }
    }
}
