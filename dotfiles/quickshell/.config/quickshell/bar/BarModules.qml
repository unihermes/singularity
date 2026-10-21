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
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Shapes
import "../services"

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
        battery: battBtn, tray: trayFrame, media: mediaBtn,
        visualizer: vizFrame, weather: weatherBtn,
        notifications: notifBtn, privacy: privacyBtn,
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
        visible: Settings.widgetVisible("bluetooth")
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
        // the bar shows the level; the icon only says muted or not
        icon: Audio.muted ? "󰖁" : "󰕾"
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
        icon: "󰃠"
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

    BarModule {
        id: mediaBtn
        readonly property var player: Media.player
        visible: player !== null && Settings.widgetVisible("media")
        icon: player && player.isPlaying ? "󰏤" : "󰐊"
        label: !player ? ""
            : (player.trackArtist ? player.trackArtist + " – " : "") + (player.trackTitle || player.identity)
        labelMaxWidth: Theme.fit(220)
        active: screenScope.openFlyout === "media"
        onActivated: screenScope.toggleFlyout("media", mediaBtn)
        onMiddleClicked: if (player && player.canTogglePlaying) player.togglePlaying()
    }

    // audio spectrum in the meter colour, per Theme.vizStyle; no easing, so
    // it redraws only on cava's 20 frames a second. With the Media module
    // off it stands in for it: the note leads it, and a click opens Media.
    ModuleFrame {
        id: vizFrame
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceXs
        visible: Visualizer.playing && Settings.widgetVisible("visualizer")

        readonly property string style: Theme.vizStyle
        readonly property int bandW: Theme.barFs(3)
        readonly property int bandH: Theme.moduleHeight - 10
        readonly property bool forMedia: !Settings.widgetVisible("media") && Media.player !== null
        active: forMedia && screenScope.openFlyout === "media"

        Text {
            visible: vizFrame.forMedia
            anchors.verticalCenter: parent.verticalCenter
            rightPadding: Theme.spaceXs
            text: "󰝚"
            color: Theme.text
            font.family: Theme.fontIcon
            font.pixelSize: Theme.iconSize
        }

        Repeater {
            model: vizFrame.style === "line" ? 0 : Visualizer.barCount

            Item {
                id: band
                required property int index
                readonly property real v: Math.max(0, Math.min(1, (Visualizer.bars[index] || 0) / 100))
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: vizFrame.bandW
                implicitHeight: vizFrame.bandH

                Rectangle {
                    visible: vizFrame.style !== "dots"
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: vizFrame.style === "mirror" ? parent.verticalCenter : undefined
                    anchors.bottom: vizFrame.style === "rise" ? parent.bottom : undefined
                    width: vizFrame.bandW
                    radius: vizFrame.style === "rise" ? Math.min(1, Theme.radiusSmall) : Theme.pill(vizFrame.bandW)
                    height: Math.max(3, parent.height * band.v)
                    color: Theme.meterFill
                }

                // four dots from the bottom, lit up to the band's level
                Column {
                    visible: vizFrame.style === "dots"
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.max(1, (vizFrame.bandH - vizFrame.bandW * 4) / 3)
                    Repeater {
                        model: 4
                        Rectangle {
                            required property int index
                            width: vizFrame.bandW
                            height: vizFrame.bandW
                            radius: Theme.pill(width)
                            color: Theme.meterFill
                            // index 0 is the top dot; the bottom one is always lit
                            opacity: band.v * 4 >= 3 - index || index === 3 ? 1 : 0.18
                        }
                    }
                }
            }
        }

        // the line style: one stroke through every band's level
        Shape {
            visible: vizFrame.style === "line"
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: Visualizer.barCount * (vizFrame.bandW + vizFrame.spacing) - vizFrame.spacing
            implicitHeight: vizFrame.bandH
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Theme.meterFill
                strokeWidth: Math.max(1.5, Theme.borderWidth * 1.5)
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathPolyline {
                    path: {
                        var pts = [], n = Visualizer.barCount
                        var w = vizFrame.style === "line" ? n * (vizFrame.bandW + vizFrame.spacing) - vizFrame.spacing : 0
                        var h = vizFrame.bandH
                        for (var i = 0; i < n; i++) {
                            var v = Math.max(0, Math.min(1, (Visualizer.bars[i] || 0) / 100))
                            pts.push(Qt.point(n > 1 ? i * w / (n - 1) : 0, h - 1 - v * (h - 2)))
                        }
                        return pts
                    }
                }
            }
        }
    }

    MouseArea {
        parent: vizFrame
        anchors.fill: parent
        enabled: vizFrame.forMedia
        cursorShape: Qt.PointingHandCursor
        onClicked: screenScope.toggleFlyout("media", vizFrame)
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

    BarModule {
        id: privacyBtn
        visible: Privacy.active && Settings.widgetVisible("privacy")
        // one glyph per kind of capture in progress
        icon: [Privacy.mic ? "󰍬" : "", Privacy.camera ? "󰄀" : "", Privacy.screen ? "󰍹" : ""]
            .filter(g => g !== "").join(" ")
        // the palette's alert hue, on purpose: this is the one
        // module that exists to be noticed
        iconColor: Theme.alert
        active: screenScope.openFlyout === "privacy"
        onActivated: screenScope.toggleFlyout("privacy", privacyBtn)
    }

    BarModule {
        id: failedBtn
        visible: FailedUnits.count > 0 && Settings.widgetVisible("failed")
        icon: "󰀦"
        iconColor: Theme.alert
        label: String(FailedUnits.count)
        active: screenScope.openFlyout === "failed"
        onActivated: {
            FailedUnits.refresh()
            screenScope.toggleFlyout("failed", failedBtn)
        }
    }

    BarModule {
        id: updatesBtn
        visible: (Updates.count > 0 || Updates.repoBehind > 0) && Settings.widgetVisible("updates")
        icon: "󰚰"
        // what's waiting as a badge: packages, else Singularity's commits
        badge: Updates.count > 0 ? Updates.count : Updates.repoBehind
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
