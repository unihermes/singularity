// Singularity - Quickshell
// ~/.config/quickshell/bar/BarModules.qml
//
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
        windows: windowIcons, clock: clock, bluetooth: btBtn,
        network: netBtn, volume: volBtn, brightness: brightBtn,
        battery: battBtn, tray: trayFrame,
        visualizer: musicFrame, weather: weatherBtn,
        notifications: notifBtn, privacy: privacyBtn, recorder: recorderBtn, phone: phoneBtn, vpn: vpnBtn,
        failed: failedBtn, updates: updatesBtn,
        cooling: coolingBtn, desktop: desktopBtn })

    // Control centre. Sits left of the workspaces, where a
    // distro/menu button conventionally lives.
    BarModule {
        id: ccBtn
        icon: Theme.controlGlyph
        // one size whichever glyph is chosen, a little over the other modules'
        iconSize: Math.min(Theme.moduleHeight - 4, Theme.iconSize + 4)
        fixedWidth: Theme.moduleWidth
        active: screenScope.openFlyout === "controlcentre"
        onActivated: screenScope.toggleFlyout("controlcentre", ccBtn)
    }

    WorkspacesModule {
        id: wsFrame
        host: barModules
    }

    WindowsModule {
        id: windowIcons
        host: barModules
    }

    // Time and date in one chip, which briefly shows volume, brightness and
    // layout changes instead (see ClockIsland.qml).
    ClockIsland {
        id: clock
        visible: Settings.widgetVisible("clock")
        screenScope: barModules.screenScope
    }

    // temperatures and fans, desktops only; alert colour when CPU or GPU runs hot
    BarModule {
        id: coolingBtn
        visible: Cooling.available && Settings.widgetVisible("cooling")
        icon: "󰈐"
        iconColor: Cooling.hottest >= Cooling.hotC ? Theme.alert : "transparent"
        active: screenScope.openFlyout === "cooling"
        onActivated: screenScope.toggleFlyout("cooling", coolingBtn)
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
        readonly property bool sounding: Settings.vizShown ? Visualizer.playing : !!player && player.isPlaying
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
            text: musicFrame.player && musicFrame.player.isPlaying ? "󰏤" : "󰐊"
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
                : (musicFrame.player.trackArtist ? musicFrame.player.trackArtist + " – " : "")
                    + (musicFrame.player.trackTitle || musicFrame.player.identity)
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
            else if (musicFrame.player && musicFrame.player.canTogglePlaying) musicFrame.player.togglePlaying()
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
        active: screenScope.openFlyout === "notifications"
        // left: the history; right: Do Not Disturb
        onActivated: screenScope.toggleFlyout("notifications", notifBtn)
        onRightClicked: Notifications.toggleDnd()
    }

    // The phone, only while one's connected over adb (USB or Wi-Fi): its
    // battery beside it, or a warning while it waits to be allowed
    BarModule {
        id: phoneBtn
        visible: (Phone.connected || Phone.unauthorized) && Settings.widgetVisible("phone")
        icon: Phone.mirroring ? "󰍹" : Phone.charging ? "󱊥" : "󰄜"
        label: Phone.connected && Phone.battery >= 0 ? Phone.battery + "%" : Phone.unauthorized ? "Allow" : ""
        iconColor: Phone.unauthorized ? Theme.alert : "transparent"
        active: screenScope.openFlyout === "phone"
        onActivated: screenScope.toggleFlyout("phone", phoneBtn)
        onMiddleClicked: Phone.toggleMirror()
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
