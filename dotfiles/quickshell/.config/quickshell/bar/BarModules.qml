// Singularity - Quickshell
// ~/.config/quickshell/bar/BarModules.qml
//
// The bar's 20 modules (and the widgetItems registry shell.qml's Bar
// Widgets reordering keys off of). The three big ones have files of their
// own: WorkspacesModule, WindowsModule and TrayModule, each handed this
// item as `host`.
//
// Non-visual on purpose: shell.qml's PanelWindow reparents every module
// here into its left/centre/right slot the moment this component
// finishes constructing (see its Component.onCompleted), so where these
// are declared doesn't matter -- only that they exist and keep the ids
// widgetItems below points at.

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
    // the tray icon's right-click opens this flyout, which lives outside
    // the bar entirely (it's a sibling flyout in the screen's Scope). It's
    // the flyout's LazyFlyout loader: ensure() builds it if needed.
    required property var trayMenu
    // same, for the open-windows strip's right-click menu
    required property var windowMenu

    readonly property var widgetItems: ({
        controlcentre: ccBtn, workspaces: wsFrame,
        windows: windowIcons, clock: clock, bluetooth: btBtn,
        network: netBtn, volume: volBtn, brightness: brightBtn,
        battery: battBtn, tray: trayFrame, media: mediaBtn,
        visualizer: vizFrame, weather: weatherBtn,
        notifications: notifBtn, privacy: privacyBtn,
        failed: failedBtn, updates: updatesBtn, claude: claudeBtn,
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

    // Temperatures and fans, desktops only (services/Cooling.qml). A plain
    // icon like Bluetooth's; it only turns the alert colour when the CPU or
    // GPU runs hot.
    BarModule {
        id: coolingBtn
        visible: Cooling.available
        icon: "󰈐"
        iconColor: Cooling.hottest >= Cooling.hotC ? Theme.alert : "transparent"
        active: screenScope.openFlyout === "cooling"
        onActivated: screenScope.toggleFlyout("cooling", coolingBtn)
    }

    BarModule {
        id: btBtn
        visible: Settings.widgetVisible("bluetooth")
        readonly property var adapter: Bluetooth.defaultAdapter
        icon: barModules.bar.btAdapterOn(adapter) ? "󰂯" : "󰂲"
        active: screenScope.openFlyout === "bluetooth"
        dimmed: !barModules.bar.btAdapterOn(adapter)
        onActivated: screenScope.toggleFlyout("bluetooth", btBtn)
    }

    BarModule {
        id: netBtn
        visible: Settings.widgetVisible("network")
        // the filled strength glyph, not the outlined md-wifi
        // arcs: its neighbours (volume, battery, power) are all
        // solid, and the thin one read as a different weight.
        // A cable that's up wins: it's the route out when both are.
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
        // the bar carries the level now, so the icon only has
        // to say muted or not -- and those two glyphs are the
        // same width, so the chip no longer resizes as you scroll
        icon: Audio.muted ? "󰖁" : "󰕾"
        fillValue: Audio.muted ? 0 : Audio.percent / 100
        active: screenScope.openFlyout === "volume"
        acceptWheel: true
        onActivated: screenScope.toggleFlyout("volume", volBtn)
        onMiddleClicked: Audio.toggleMute()
        onWheeled: d => Audio.setVolume(Audio.percent + d * 5)
    }

    // The monitor under this bar, over DDC/CI when it answers
    // (DdcBrightness), else the backlight (Brightness) -- a laptop's panel,
    // or every screen on a machine with no DDC monitor.
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
    // Everything below except weather and the tray appears only
    // while it has something to say: media while a player is
    // open, the visualizer while sound is playing, and the
    // alert-style ones (privacy, failed units, updates, unread
    // notifications) only when there's something to act on.
    // Bar Widgets can still turn any of them off entirely.

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

    // audio spectrum, in the meter colour, drawn as Theme.vizStyle: thin
    // pills growing from the middle (the workspace indicator's shape
    // language), bars rising from the bottom, stacked dots, or one line.
    // No easing between cava's frames: a tween as long as a frame never
    // stops, so the bar redrew at every monitor's refresh rate the whole
    // time sound played, where now it redraws only on each of cava's 20
    // frames a second (cava's own noise_reduction already smooths them).
    ModuleFrame {
        id: vizFrame
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceXs
        visible: Visualizer.playing && Settings.widgetVisible("visualizer")

        readonly property string style: Theme.vizStyle
        readonly property int bandW: Theme.barFs(3)
        readonly property int bandH: Theme.moduleHeight - 10

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
        // packages in the label, Singularity's commits to pull in the badge
        label: Updates.count > 0 ? String(Updates.count) : ""
        badge: Updates.repoBehind
        active: screenScope.openFlyout === "updates"
        onActivated: screenScope.toggleFlyout("updates", updatesBtn)
    }

    // Claude, editing the desktop itself (services/ClaudeShell.qml). The
    // label says it's working, then how many files are waiting for review;
    // the icon takes the accent while there's a reply or a diff not yet seen.
    BarModule {
        id: claudeBtn
        visible: ClaudeShell.available && Settings.widgetVisible("claude")
        icon: "󰚩"
        label: ClaudeShell.running ? spinner.frames[spinner.frame]
            : ClaudeShell.hasChanges ? String(ClaudeShell.files.length) : ""
        iconColor: ClaudeShell.unseen || ClaudeShell.hasChanges ? Theme.accent : "transparent"
        active: screenScope.openFlyout === "claude"
        onActivated: screenScope.toggleFlyout("claude", claudeBtn)

        Timer {
            id: spinner
            readonly property var frames: ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
            property int frame: 0
            interval: 90
            repeat: true
            running: ClaudeShell.running && claudeBtn.visible
            onTriggered: frame = (frame + 1) % frames.length
        }
    }

    // Show desktop, as on Windows: a slim button at the end of its group,
    // set off by a hairline, whose rounded end is the group's own corner.
    // Without groups it's a slim chip of the style's own, with a short bar
    // in it. A click hides every window on every workspace and screen, at
    // once with no animation (singularityShowDesktop() in windows.lua, also
    // SUPER+D); it lights with the accent while they're hidden, and a
    // second click brings them back.
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

        implicitWidth: grouped ? Theme.sp(8) : chip.implicitWidth
        implicitHeight: Theme.barHeight

        ModuleFrame {
            id: chip
            visible: !desktopBtn.grouped
            anchors.centerIn: parent
            padH: Theme.modulePadH / 2

            Rectangle {
                width: Theme.sp(3)
                height: Theme.iconSize - 2
                radius: Theme.pill(width)
                color: desktopBtn.shown ? Theme.accent
                    : desktopMouse.containsMouse ? Theme.text : Theme.muted
            }
        }

        Rectangle {
            id: cap
            visible: desktopBtn.grouped
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
