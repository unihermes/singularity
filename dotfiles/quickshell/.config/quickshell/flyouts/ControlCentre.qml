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
import Quickshell.Bluetooth
import QtQuick
import "../services"
import "../bar"

FlyoutPanel {
    id: controlCentre
    flyout: "controlcentre"
    menuWidth: 230
    // first module in the bar -- run it into the left corner
    edgeMargin: 0

    required property var bar
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
    // Re-read the saved layout each time the page opens, so the
    // lists never show an order from before a reset or a hand edit.
    onPageChanged: if (page === "widgets") {
        widgetsList.refill()
    } else if (page === "apps") {
        appQuery = ""
        appSearch.text = ""
        appView.currentIndex = 0
        // after the field has become visible, or focus is refused
        Qt.callLater(appSearch.forceFocus)
    }

    // Desktop entry ids kept out of the list: system tools that
    // arrived as dependencies of something else and aren't ever
    // launched by hand. Ids rather than names, so a translation or a
    // package renaming its Name= line doesn't let one back in.
    readonly property var hiddenApps: [
        "avahi-discover", "bssh", "bvnc",   // avahi
        "lstopo",                           // hwloc
        "qv4l2", "qvidcap",                 // v4l-utils
        "xfce4-about",                      // xfce4-about
        "jconsole-java25-openjdk",          // jdk
        "jshell-java25-openjdk",
        "thunar-settings",                  // thunar extras
        "thunar-volman-settings",
        "thunar-bulk-rename",
    ]
    readonly property var pageTitles: ({
        "power": "POWER",
        "appearance": "APPEARANCE",
        "quick": "QUICK ACTIONS",
        "apps": "APPLICATIONS",
        "widgets": "BAR WIDGETS"
    })

    // Every launchable desktop entry, A-Z. Case-insensitive, or
    // lowercase names ("htop", "nvim") would all sort after Z.
    //
    // With a query, names that *start* with it come first, then any
    // other match, each group still A-Z. genericName is searched too,
    // so "browser" finds Zen and Floorp.
    function appList(query) {
        var all = DesktopEntries.applications.values
        var q = (query || "").trim().toLowerCase()
        var starts = [], rest = []
        for (var i = 0; i < all.length; i++) {
            var e = all[i]
            if (e.noDisplay || hiddenApps.indexOf(e.id) !== -1) continue
            var name = e.name.toLowerCase()
            if (q === "") { rest.push(e); continue }
            if (name.startsWith(q)) starts.push(e)
            else if (name.indexOf(q) !== -1
                || (e.genericName || "").toLowerCase().indexOf(q) !== -1) rest.push(e)
        }
        var byName = (a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase())
        starts.sort(byName)
        rest.sort(byName)
        return starts.concat(rest)
    }

    function launch(entry) {
        scope.openFlyout = ""
        // execute() runs the Exec line as-is, which for a terminal
        // app (htop, nvim) means a process with no terminal to draw
        // in -- it starts and dies unseen. Those get wrapped.
        if (entry.runInTerminal) {
            // command is a Qt list, not a JS array: concat() would
            // push it as one nested element instead of spreading it
            var cmd = ["alacritty", "-e"]
            for (var i = 0; i < entry.command.length; i++) cmd.push(entry.command[i])
            Quickshell.execDetached(cmd)
        } else
            entry.execute()
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

    // root, first group: the things that open a submenu
    Repeater {
        model: controlCentre.page === "" ? [
            { label: "Applications",   sub: "apps" },
            { label: "Power",          sub: "power" },
            { label: "Bar Widgets",    sub: "widgets" },
            { label: "Quick Actions",  sub: "quick" },
            { label: "Appearance",     sub: "appearance" },
        ] : []

        FlyoutRow {
            required property var modelData
            label: modelData.label
            trailing: "󰅂"
            onActivated: controlCentre.page = modelData.sub
        }
    }

    FlyoutDivider {
        visible: controlCentre.page === ""
    }

    // root, second group: the leaf entries
    Repeater {
        model: controlCentre.page === "" ? [
            { label: "Settings",   act: "settings" },
            { label: "System",     act: "system" },
            { label: "Keybinds",   act: "keybinds" },
        ] : []

        FlyoutRow {
            required property var modelData
            label: modelData.label
            onActivated: controlCentre.run(modelData.act)
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
        model: visible ? controlCentre.appList(controlCentre.appQuery) : []
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
                onContainsMouseChanged: if (containsMouse) appView.currentIndex = appRow.index
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
            icon: Network.powered ? "󰖩" : "󰖪"
            label: "Wi-Fi"
            status: Network.device === "" ? "No wifi device"
                : !Network.powered ? "Off"
                : (Network.ssid !== "" ? Network.ssid : "Not connected")
            enabled: Network.device !== ""
            checked: Network.powered
            onActivated: Network.setPowered(!Network.powered)
        }

        FlyoutAction {
            readonly property var adapter: Bluetooth.defaultAdapter
            icon: checked ? "󰂯" : "󰂲"
            label: "Bluetooth"
            status: !adapter ? "No adapter"
                : bar.btAdapterBlocked(adapter) ? "Blocked (rfkill)"
                : !bar.btAdapterOn(adapter) ? "Off"
                : (bar.btConnectedName() !== "" ? bar.btConnectedName() : "No device connected")
            enabled: adapter !== null
            checked: bar.btAdapterOn(adapter)
            onActivated: bar.setBtPowered(adapter, !bar.btAdapterOn(adapter))
        }

        FlyoutAction {
            icon: Audio.muted ? "󰖁" : "󰕾"
            label: "Mute"
            status: Audio.muted ? "Muted" : Audio.percent + "%"
            enabled: Audio.ready
            checked: Audio.muted
            onActivated: Audio.toggleMute()
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

        FlyoutRow {
            label: "Font"
            trailingIsValue: true
            trailing: appearancePage.label(Settings.fontFamily)
            onActivated: Settings.cycle("fontFamily")
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
