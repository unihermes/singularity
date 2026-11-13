// The bar's modules and the widgetItems registry Bar Widgets keys off. The
// big ones have files of their own (WorkspacesModule, WindowsModule,
// TrayModule), each handed this item as `host`. Bar.qml reparents every
// module into its section's slot, so only the ids widgetItems names matter.

import Quickshell
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Widgets
import Quickshell.Services.UPower
import QtQuick
import "../services"
import "../flyouts"

Item {
    id: barModules

    required property var bar
    required property var screenScope
    // for specialShown, which follows Hyprland's events once for all bars
    required property var shellRoot
    // the tray menu's LazyFlyout (ensure() builds it)
    required property var trayMenu

    readonly property var widgetItems: ({
        controlcentre: ccBtn, workspaces: wsFrame,
        windows: windowIcons, activeapp: activeApp, search: searchBtn, taskview: taskViewBtn, clock: clock, bluetooth: btBtn,
        network: netBtn, volume: volBtn, brightness: brightBtn,
        battery: battBtn, tray: trayFrame,
        visualizer: musicFrame, weather: weatherBtn,
        notifications: notifBtn, privacy: privacyBtn, recorder: recorderBtn, phone: phoneBtn, vpn: vpnBtn, claude: claudeBtn,
        failed: failedBtn, updates: updatesBtn, drives: drivesBtn,
        desktop: desktopBtn })

    // Control centre (the Start button under the taskbar). Sits left of the workspaces, where a
    // distro/menu button conventionally lives.
    BarModule {
        id: ccBtn
        icon: Theme.controlGlyph
        // one size whichever glyph is chosen, a little over the other modules'
        iconSize: Math.min(Theme.moduleHeight - 4, Theme.iconSize + 4)
        fixedWidth: Theme.moduleTaskbar ? Theme.buttonWidth : Theme.sp(42)
        active: screenScope.openFlyout === (Theme.moduleTaskbar ? "launcher" : "controlcentre")
        // the taskbar's Start button opens the Start menu; the Control Centre
        // is its right-click
        onActivated: if (Theme.moduleTaskbar) barModules.shellRoot.launcherToggled("apps")
                     else screenScope.toggleFlyout("controlcentre", ccBtn)
        // straight to Power, or there from whichever page is open
        onRightClicked: {
            screenScope.controlPage = "power"
            if (screenScope.openFlyout !== "controlcentre")
                screenScope.toggleFlyout("controlcentre", ccBtn)
        }
        onMiddleClicked: Session.run("lock")
    }

    WorkspacesModule {
        id: wsFrame
        host: barModules
    }

    WindowsModule {
        id: windowIcons
        host: barModules
    }

    // The Menu bar's app name: the focused window's app, beside the menu
    // button; pointing at the workspaces flyout lists every window.
    BarModule {
        id: activeApp
        readonly property var focused: Hyprland.activeToplevel
        readonly property var info: focused ? focused.lastIpcObject : null
        visible: Settings.widgetVisible("activeapp") && !!info && !!info.class && !Apps.isShellWindow(focused)
        label: info && info.class ? Apps.nameForWindow(info.class, info.title) : ""
        labelMaxWidth: Theme.sp(180)
        labelBold: true
        active: screenScope.openFlyout === "workspaces"
        onActivated: screenScope.toggleFlyout("workspaces", activeApp)
    }

    // Search: the Windows taskbar's search box, or the menu bar's magnifier
    // (which opens the launcher). The box is typed into: a click opens
    // BarSearchFlyout, whose keys show here as the box's text.
    Item {
        id: searchBtn
        visible: Settings.widgetVisible("search")
        readonly property bool box: Theme.moduleTaskbar
        readonly property bool typing: box && screenScope.openFlyout === "barsearch"
        property bool slideX: false
        signal activated()
        onActivated: {
            if (!box) barModules.shellRoot.launcherToggled("apps")
            else if (!typing) screenScope.toggleFlyout("barsearch", searchBtn)
        }

        implicitWidth: box ? Theme.sp(240) : Theme.buttonWidth
        implicitHeight: Theme.barHeight

        // the box is a light field on the dark bar, as Windows draws it;
        // white with an accent edge while it's being typed into
        Rectangle {
            visible: searchBtn.box
            anchors.fill: parent
            color: searchBtn.typing ? "white" : searchMouse.containsMouse ? Theme.bright : Qt.darker(Theme.bright, 1.08)
            border.width: Theme.borderWidth
            border.color: searchMouse.containsMouse && !searchBtn.typing ? Theme.accent : "transparent"
            Rectangle {
                visible: searchBtn.typing
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 2
                color: Theme.accent
            }
        }
        Rectangle {
            visible: !searchBtn.box && searchMouse.containsMouse
            anchors.centerIn: parent
            width: Theme.moduleHeight
            height: Theme.moduleHeight
            radius: Theme.radiusSmall
            color: Theme.overlay
        }
        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: searchBtn.box ? Theme.sp(12) : Math.round((parent.width - width) / 2)
            spacing: Theme.sp(10)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰍉"
                color: searchBtn.box ? Theme.base : Theme.text
                font.family: Theme.fontIcon
                font.pixelSize: Theme.iconSize
            }
            Text {
                id: boxText
                visible: searchBtn.box
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, searchBtn.width - Theme.sp(12) * 2 - Theme.iconSize - Theme.sp(10) - caret.width)
                elide: Text.ElideLeft
                text: searchBtn.typing && screenScope.searchQuery !== "" ? screenScope.searchQuery : "Type here to search"
                color: searchBtn.typing && screenScope.searchQuery !== "" ? Theme.base : Qt.lighter(Theme.base, 2.2)
                font.family: Theme.fontText
                font.pixelSize: Theme.barLabelSize
            }
        }
        // the caret, after the typed text (before the hint)
        Rectangle {
            id: caret
            visible: searchBtn.typing
            x: searchBtn.typing && screenScope.searchQuery !== ""
                ? Theme.sp(12) + Theme.iconSize + Theme.sp(10) + boxText.width + 1
                : Theme.sp(12) + Theme.iconSize + Theme.sp(10) - 1
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: Theme.barLabelSize + Theme.spaceS
            color: Theme.base
            SequentialAnimation on opacity {
                running: caret.visible
                loops: Animation.Infinite
                NumberAnimation { to: 0; duration: 500; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutQuad }
            }
        }
        MouseArea {
            id: searchMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: searchBtn.box ? Qt.IBeamCursor : Qt.PointingHandCursor
            onClicked: searchBtn.activated()
        }
    }

    // Task View: the workspace grid, from the Windows taskbar's button
    BarModule {
        id: taskViewBtn
        visible: Settings.widgetVisible("taskview")
        icon: "󰕮"
        fixedWidth: Theme.buttonWidth
        active: screenScope.openFlyout === "workspaceoverlay"
        onActivated: barModules.shellRoot.workspaceOverlayToggled()
    }

    // Time and date in one chip, which briefly shows volume, brightness and
    // layout changes instead (see ClockIsland.qml).
    ClockIsland {
        id: clock
        visible: Settings.widgetVisible("clock")
        screenScope: barModules.screenScope
    }

    BarModule {
        id: btBtn
        // no adapter, nothing to show
        visible: !!adapter && Settings.widgetVisible("bluetooth")
        readonly property var adapter: Bluetooth.defaultAdapter
        // the connected glyph while a device is on
        readonly property bool linked: !!adapter && !!adapter.devices
            && adapter.devices.values.some(d => d.connected)
        icon: !barModules.bar.btAdapterOn(adapter) ? "󰂲" : linked ? "󰂱" : "󰂯"
        active: screenScope.openFlyout === "bluetooth"
        dimmed: !barModules.bar.btAdapterOn(adapter)
        onActivated: screenScope.toggleFlyout("bluetooth", btBtn)
    }

    BarModule {
        id: netBtn
        visible: Settings.widgetVisible("network")
        // filled glyphs to match the solid neighbours; a cable that's up wins
        icon: Network.wired ? "󰛳" : Network.ssid !== "" ? "󰤨" : "󰤮"
        active: screenScope.openFlyout === "network"
        dimmed: !Network.wired && Network.ssid === ""
        onActivated: {
            // the networks iwd already knows of; a fresh scan
            // only from the flyout's Rescan row
            Network.refreshList()
            screenScope.toggleFlyout("network", netBtn)
        }
    }

    BarModule {
        id: volBtn
        visible: Settings.widgetVisible("volume")
        fixedWidth: Theme.moduleWidth
        // the bar shows the level; the icon says muted, else where the
        // sound goes: headphones or speakers. Headphones whose headset is
        // switched off (its dongle still there) show crossed out and dim.
        readonly property bool headsetOff: Audio.onHead(Audio.sink) && Channels.headset === "off"
        icon: Audio.muted ? "󰖁" : headsetOff ? "󰟎" : Audio.onHead(Audio.sink) ? "󰋋" : "󰕾"
        dimmed: headsetOff
        fillValue: Audio.muted ? 0 : Audio.percent / 100
        active: screenScope.openFlyout === "volume"
        acceptWheel: true
        onActivated: screenScope.toggleFlyout("volume", volBtn)
        onMiddleClicked: Audio.toggleMute()
        onWheeled: d => Audio.setVolume(Audio.percent + d * 5)
    }

    // the monitor under this bar over DDC/CI, else the backlight
    BarModule {
        id: brightBtn
        readonly property string output: screenScope.modelData.name
        readonly property bool ddc: DdcBrightness.has(output)
        readonly property int level: ddc ? DdcBrightness.level(output) : Brightness.level
        visible: (ddc ? level >= 0 : Brightness.available) && Settings.widgetVisible("brightness")
        fixedWidth: Theme.moduleWidth
        // the moon while Night Light is on
        icon: shellRoot.nightLight ? "󰖔" : "󰃠"
        fillValue: level / 100
        active: screenScope.openFlyout === "brightness"
        acceptWheel: true
        onActivated: screenScope.toggleFlyout("brightness", brightBtn)
        onWheeled: d => ddc ? DdcBrightness.set(output, level + d * 5) : Brightness.set(level + d * 5)
    }

    BarModule {
        id: battBtn
        fixedWidth: Theme.moduleWidth
        visible: Battery.present && Settings.widgetVisible("battery")
        // charging is all the glyph still needs to say; the
        // level is the bar's job
        icon: UPower.onBattery ? "󰁹" : "󰂄"
        fillValue: Battery.percent / 100
        // Charging wins over the low warning on purpose: at 8%
        // and plugged in, the useful fact is that it's recovering.
        fillColor: {
            if (!UPower.onBattery) return Theme.good
            if (Battery.percent <= 20) return Theme.alert
            return Theme.gaugeFill
        }
        active: screenScope.openFlyout === "battery"
        onActivated: {
            PpdProfile.refresh()
            screenScope.toggleFlyout("battery", battBtn)
        }
    }

    // ---- contextual modules ---------------------------------
    // all but weather and the tray show only while they have something to
    // say; Bar Widgets can still turn any off

    TrayModule {
        id: trayFrame
        host: barModules
    }

    // the Music module (under the old visualizer's key): the audio spectrum
    // of the followed player's app (Spectrum, Visualizer) and the track's title, each as Settings
    // says; the player's icon only without the spectrum, and with neither a
    // play/pause mark. Shown while a player is
    // open, or only while it sounds with vizHideSilent. A click opens the
    // Media flyout, a middle click plays or pauses.
    ModuleFrame {
        id: musicFrame
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceXs
        readonly property var player: Media.player
        readonly property bool sounding: Settings.vizShown ? Visualizer.playing : Media.shownPlaying
        visible: Settings.widgetVisible("visualizer") && (player !== null || Visualizer.playing)
            && (sounding || !Settings.vizHideSilent)

        readonly property int bandW: Theme.barFs(3)
        readonly property int bandH: Theme.moduleHeight - 10
        readonly property string playerIcon: player
            ? Apps.iconForClass(player.desktopEntry || String(player.identity).toLowerCase()) : ""
        active: screenScope.openFlyout === "media"

        Item {
            visible: musicFrame.player !== null && !Settings.vizShown
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: Theme.iconSize + Theme.spaceXs
            implicitHeight: Theme.iconSize

            IconImage {
                visible: musicFrame.playerIcon !== ""
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: Theme.iconSize
                source: musicFrame.playerIcon
            }
            Text {
                visible: musicFrame.playerIcon === ""
                anchors.verticalCenter: parent.verticalCenter
                text: "󰝚"
                color: Theme.text
                font.family: Theme.fontIcon
                font.pixelSize: Theme.iconSize
            }
        }

        // neither the spectrum nor the title: whether it's playing
        Text {
            visible: !Settings.vizShown && !Settings.musicTitle
            anchors.verticalCenter: parent.verticalCenter
            text: Media.shownPlaying ? "󰏤" : "󰐊"
            color: Theme.text
            font.family: Theme.fontIcon
            font.pixelSize: Theme.iconSize
        }

        Spectrum {
            visible: Settings.vizShown
            anchors.verticalCenter: parent.verticalCenter
            spacing: musicFrame.spacing
            bandW: musicFrame.bandW
            bandH: musicFrame.bandH
        }

        Text {
            visible: Settings.musicTitle && musicFrame.player !== null
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: Theme.spaceXs
            width: Math.min(implicitWidth, Theme.fit(220))
            elide: Text.ElideRight
            text: !musicFrame.player ? ""
                : (Media.artistOf(musicFrame.player) ? Media.artistOf(musicFrame.player) + " – " : "")
                    + (Media.titleOf(musicFrame.player) || musicFrame.player.identity)
            color: Theme.text
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.barLabelSize
        }
    }

    MouseArea {
        parent: musicFrame
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) screenScope.toggleFlyout("media", musicFrame)
            else if (Media.controllable(musicFrame.player) && musicFrame.player.canTogglePlaying) musicFrame.player.togglePlaying()
        }
    }

    BarModule {
        id: weatherBtn
        visible: Weather.ready && Settings.widgetVisible("weather")
        icon: Weather.iconFor(Weather.code, Weather.isNight)
        label: Weather.temp(Weather.tempF, Weather.tempC)
        active: screenScope.openFlyout === "weather"
        onActivated: screenScope.toggleFlyout("weather", weatherBtn)
    }

    BarModule {
        id: notifBtn
        // always shown, so the history is one click away; the badge is
        // only what's arrived since it was last opened
        visible: Settings.widgetVisible("notifications")
        icon: Notifications.dnd ? "󰂛" : "󰂚"
        badge: Notifications.unread
        dimmed: Notifications.dnd || Notifications.unread === 0
        active: Notifications.shown && Notifications.screen === screenScope.modelData
        // left: the history; right: Do Not Disturb
        onActivated: Notifications.toggle(screenScope.modelData)
        onRightClicked: Notifications.toggleDnd()
    }

    // Devices (the phone's key, so saved layouts keep it): the phone and
    // the peripherals with a battery. The devices glyph while the phone's
    // connected, the mouse without it; a word while the phone waits to be
    // allowed over USB or asks to pair; a red dot while one runs low, else
    // a green one while the phone's on screen.
    BarModule {
        id: phoneBtn
        readonly property bool phoneOn: Phone.connected || PhoneLink.connected
        readonly property bool phoneLow: phoneOn && Phone.shownBattery >= 0
            && Phone.shownBattery <= Peripherals.warnLevels[0] && !Phone.shownCharging
        visible: (Phone.shown || Peripherals.devices.length > 0) && Settings.widgetVisible("phone")
        icon: phoneOn ? "󰾰" : "󰍽"
        label: PhoneLink.request ? "Pair" : Phone.unauthorized ? "Allow" : ""
        iconColor: Phone.unauthorized ? Theme.alert : PhoneLink.request ? Theme.accent : "transparent"
        readonly property bool low: Peripherals.low || phoneLow
        dot: low || Phone.mirroring
        dotColor: low ? Theme.alert : Theme.good
        active: screenScope.openFlyout === "devices"
        onActivated: screenScope.toggleFlyout("devices", phoneBtn)
        onMiddleClicked: Phone.toggleMirror()
    }

    // The Claude sidebar (Ai): turning while it works, lit while a prompt
    // waits or a reply is unread; a click puts the sidebar out on this
    // screen or away
    BarModule {
        id: claudeBtn
        visible: Ai.available && Settings.widgetVisible("claude")
        icon: "󰚩"
        label: Ai.busy && !Ai.asking ? spinner.frames[spinner.frame] : ""
        iconColor: Ai.asking || (Ai.unseen && !Ai.shown) ? Theme.accent : "transparent"
        active: Ai.shown && Ai.screen === screenScope.modelData
        onActivated: Ai.toggle(screenScope.modelData)

        Timer {
            id: spinner
            readonly property var frames: ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
            property int frame: 0
            interval: 90
            repeat: true
            running: Ai.busy && claudeBtn.visible
            onTriggered: frame = (frame + 1) % frames.length
        }
    }

    // The VPN, once a server's imported: lit while it's up (the alert colour
    // while the server doesn't answer), dim while off
    BarModule {
        id: vpnBtn
        visible: Vpn.available && Vpn.servers.length > 0 && Settings.widgetVisible("vpn")
        icon: Vpn.up ? "󰦝" : "󰖂"
        dimmed: !Vpn.up
        iconColor: Vpn.stalled ? Theme.alert : "transparent"
        active: screenScope.openFlyout === "vpn"
        onActivated: screenScope.toggleFlyout("vpn", vpnBtn)
        onMiddleClicked: Vpn.toggle()
    }

    // While recording: a red dot and the time, a click stops it. While a
    // replay is held for a game: the replay glyph, a click saves it.
    BarModule {
        id: recorderBtn
        visible: (Recorder.recording || Recorder.replaying) && Settings.widgetVisible("recorder")
        icon: Recorder.recording ? "󰑊" : "󰑙"
        label: Recorder.recording
            ? Math.floor(Recorder.elapsed / 60) + ":" + String(Recorder.elapsed % 60).padStart(2, "0") : ""
        iconColor: Recorder.recording ? Theme.alert : "transparent"
        onActivated: Recorder.recording ? Recorder.stopRecording() : Recorder.save()
    }

    BarModule {
        id: privacyBtn
        visible: Privacy.active && Settings.widgetVisible("privacy")
        // a recording dot, then one glyph per kind of capture in progress
        icon: ["󰑊", Privacy.mic ? "󰍬" : "", Privacy.camera ? "󰄀" : "", Privacy.screen ? "󰍹" : ""]
            .filter(g => g !== "").join(" ")
        // filled with the palette's alert hue, on purpose: this is the
        // one module that exists to be noticed
        fillValue: 1
        fillColor: Theme.alert
        iconColor: Theme.base
        active: screenScope.openFlyout === "privacy"
        onActivated: screenScope.toggleFlyout("privacy", privacyBtn)
    }

    // only while a removable drive is plugged in; a badge past one
    BarModule {
        id: drivesBtn
        visible: Drives.count > 0 && Settings.widgetVisible("drives")
        icon: "󰕓"
        badge: Drives.count > 1 ? Drives.count : 0
        active: screenScope.openFlyout === "drives"
        onActivated: screenScope.toggleFlyout("drives", drivesBtn)
    }

    BarModule {
        id: failedBtn
        visible: FailedUnits.count > 0 && Settings.widgetVisible("failed")
        icon: "󰀦"
        iconColor: Theme.alert
        badge: FailedUnits.count
        badgeAlert: true
        active: screenScope.openFlyout === "failed"
        onActivated: {
            FailedUnits.refresh()
            screenScope.toggleFlyout("failed", failedBtn)
        }
    }

    // always there: the packages waiting as a count beside the icon,
    // Singularity's commits as a badge, the icon dimmed when there's nothing,
    // the icon turning while an update runs
    BarModule {
        id: updatesBtn
        readonly property bool busy: Updates.updating || Updates.repoUpdating
        visible: Settings.widgetVisible("updates")
        icon: busy ? "󰑓" : "󰚰"
        spinning: busy
        label: Updates.count > 0 ? String(Updates.count) : ""
        badge: Updates.repoBehind
        dimmed: !busy && Updates.count === 0 && Updates.repoBehind === 0
        active: screenScope.openFlyout === "updates"
        onActivated: screenScope.toggleFlyout("updates", updatesBtn)
    }

    // Show desktop: a slim slot past a hairline ending its group, whatever
    // the chips; hides every window at once (singularityShowDesktop()), lit
    // while they're hidden
    Item {
        id: desktopBtn
        visible: Settings.widgetVisible("desktop")
        readonly property bool grouped: Theme.moduleGrouped
        // a window it hid, on any workspace, is still hidden
        readonly property bool shown: Hyprland.toplevels.values.some(t => {
            var tags = t.lastIpcObject ? t.lastIpcObject.tags || [] : []
            return tags.indexOf("showdesktop") !== -1
        })

        signal activated()
        onActivated: Quickshell.execDetached(["hyprctl", "eval", "singularityShowDesktop()"])

        // shell.qml sets it on every module; this one never slides or
        // fades, whatever the animation settings
        property bool slideX: false

        implicitWidth: Theme.sp(8)
        implicitHeight: Theme.barHeight

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: desktopBtn.grouped ? Theme.groupHeight - Theme.channelWidth * 2 : Theme.moduleHeight
            topRightRadius: desktopBtn.grouped ? Theme.radius : Theme.radiusSmall
            bottomRightRadius: topRightRadius
            color: desktopBtn.shown ? Theme.accent
                : desktopMouse.containsMouse ? Theme.overlay : "transparent"

            Rectangle {
                width: Theme.borderWidth
                height: parent.height
                color: desktopBtn.shown ? Theme.accent : Theme.stroke
            }
        }

        MouseArea {
            id: desktopMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: desktopBtn.activated()
        }
    }
}
