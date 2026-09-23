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
    } else if (page === "power") {
        hibernateCheck.running = true
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

    // Hibernate is only offered once logind says it can: that needs a
    // swapfile, the resume hook and resume= on the cmdline (install.sh's
    // hibernation step), none of which link.sh alone sets up.
    property bool canHibernate: false

    Process {
        id: hibernateCheck
        command: ["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1",
                  "org.freedesktop.login1.Manager", "CanHibernate"]
        stdout: StdioCollector {
            onStreamFinished: controlCentre.canHibernate = text.trim() === 's "yes"'
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
        else if (act === "lock") Quickshell.execDetached(["hyprlock"])
        else if (act === "suspend") Quickshell.execDetached(["systemctl", "suspend"])
        else if (act === "hibernate") Quickshell.execDetached(["systemctl", "hibernate"])
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
                anchors.leftMargin: Theme.spaceL
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
    // Quick changes only -- the few things worth flipping without opening
    // a window: the look, the wallpaper and the colours it feeds, where the
    // bar sits and how solid it is, text size and motion. Everything else
    // (bar and module styles, frames, fonts, geometry, defaults) is on
    // Settings > Appearance, one row away at the bottom.
    //
    // Short choices are segmented strips, so every option is one click and
    // on show; the looks are a FlyoutSelect, which opens in place with each
    // look's palette beside its name; numbers are sliders.

    Column {
        id: appearancePage
        visible: controlCentre.page === "appearance"
        width: parent.width
        spacing: Theme.spaceM

        function label(v) { return Settings.choiceLabel(v) }
        function seg(key) {
            return (Settings.choices[key] || []).map(v => ({ value: v, text: label(v) }))
        }
        // a look's palette, dark to light, then its accent if it has one
        function swatches(name) {
            var l = LookStore.looks[name]
            if (!l) return []
            var p = l.palette
            return [p.base, p.border, p.subtext, p.text].concat(l.accent ? [l.accent] : [])
        }

        // one open select at a time; closed on the way out
        QtObject { id: selects; property var open: null }
        onVisibleChanged: if (!visible) selects.open = null

        // --- Look ---

        FlyoutHeading { text: "LOOK" }

        FlyoutSelect {
            label: "Preset"
            group: selects
            model: LookStore.order
            current: Settings.look
            // a look with hand edits on top of it is no longer quite that look
            valueSuffix: Settings.lookPristine ? "" : " *"
            labelFor: v => LookStore.looks[v] ? LookStore.looks[v].name : v
            swatchesFor: v => appearancePage.swatches(v)
            onPicked: v => Settings.set("look", v)
        }

        // The preview is the control: click it for the next wallpaper, or
        // use the chips in its corner.
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
                    text: Wallpaper.name !== "" ? Wallpaper.name : "No wallpaper"
                    color: Theme.textStrong
                    font.family: Theme.fontText
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

        // colours: grey, or taken from the image above
        FlyoutSegmented {
            model: appearancePage.seg("colourMode")
            current: Settings.colourMode
            onPicked: v => Settings.set("colourMode", v)
        }

        // only means anything once the colours come from the image
        FlyoutSelect {
            visible: Settings.colourMode === "wallpaper"
            label: "Intensity"
            group: selects
            enabled: !Wallpaper.generating
            model: Settings.choices.colourScheme
            current: Settings.colourScheme
            labelFor: v => appearancePage.label(v)
            valueSuffix: Wallpaper.generating ? " …" : ""
            onPicked: v => Settings.set("colourScheme", v)
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
            label: "Opacity"
            suffix: "%"
            // fives: nothing between two of them is visible anyway
            step: 5
            value: Settings.barOpacity
            minimum: Settings.limits.barOpacity.min
            maximum: Settings.limits.barOpacity.max
            onMoved: v => Settings.set("barOpacity", v)
        }

        // --- Text & motion ---

        FlyoutHeading { text: "TEXT & MOTION" }

        FlyoutSliderRow {
            label: "Font size"
            suffix: "px"
            value: Settings.fontSize
            minimum: Settings.limits.fontSize.min
            maximum: Settings.limits.fontSize.max
            onMoved: v => Settings.set("fontSize", v)
        }

        FlyoutSegmented {
            model: appearancePage.seg("animSpeed")
            current: Settings.animSpeed
            onPicked: v => Settings.set("animSpeed", v)
        }

        // --- the way out ---

        FlyoutDivider {}

        FlyoutRow {
            label: "Reset Look"
            enabled: !Settings.lookPristine
            onActivated: Settings.resetLook()
        }

        // everything this page leaves out
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
        ].concat(controlCentre.canHibernate ? [
            { label: "Hibernate", act: "hibernate" },
        ] : []).concat([
            { label: "Log Out",   act: "logout" },
            { label: "Reboot",    act: "reboot" },
            { label: "Shut Down", act: "poweroff" },
        ]) : []

        FlyoutRow {
            required property var modelData
            label: modelData.label
            onActivated: controlCentre.run(modelData.act)
        }
    }
}
