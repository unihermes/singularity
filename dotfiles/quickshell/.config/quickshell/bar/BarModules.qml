// Singularity - Quickshell
// ~/.config/quickshell/bar/BarModules.qml
//
// The bar's 18 modules (and the widgetItems registry shell.qml's Bar
// Widgets reordering keys off of), split out of shell.qml so the bar's
// layout plumbing isn't buried under every module's own logic.
//
// Non-visual on purpose: shell.qml's PanelWindow reparents every module
// here into its left/centre/right slot the moment this component
// finishes constructing (see its Component.onCompleted), so where these
// are declared doesn't matter -- only that they exist and keep the ids
// widgetItems below points at.

import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import QtQuick
import "../services"

Item {
    id: barModules

    required property var bar
    required property var screenScope
    // the tray icon's right-click opens this flyout, which lives outside
    // the bar entirely (it's a sibling flyout in the screen's Scope). It's
    // the flyout's LazyFlyout loader: ensure() builds it if needed.
    required property var trayMenu

    readonly property var widgetItems: ({
        controlcentre: ccBtn, workspaces: wsFrame, overview: wsOverviewBtn,
        windows: windowIcons, clock: clock, bluetooth: btBtn,
        network: netBtn, volume: volBtn, brightness: brightBtn,
        battery: battBtn, tray: trayFrame, media: mediaBtn,
        visualizer: vizFrame, weather: weatherBtn,
        notifications: notifBtn, privacy: privacyBtn,
        failed: failedBtn, updates: updatesBtn })

    // Control centre. Sits left of the workspaces, where a
    // distro/menu button conventionally lives.
    BarModule {
        id: ccBtn
        icon: "󰣇"
        padH: 14
        active: screenScope.openFlyout === "controlcentre"
        onActivated: screenScope.toggleFlyout("controlcentre", ccBtn)
    }

    // One frame around the whole set, with the current
    // workspace shown as a widened pill rather than a number.
    // Three states read by size and weight alone: current is a
    // long bright bar, occupied a short one, empty a dim stub --
    // the same language as the gauges on the right, where how
    // much space a thing takes up is the information.
    ModuleFrame {
        id: wsFrame
        visible: Settings.widgetVisible("workspaces")
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceS
        padH: 8

        Repeater {
            model: Settings.workspaceCount

            Item {
                required property int index
                readonly property int wsId: index + 1
                readonly property bool current: Hyprland.focusedWorkspace
                    ? Hyprland.focusedWorkspace.id === wsId
                    : false
                readonly property bool occupied: barModules.bar.workspaceHasWindows(wsId)

                anchors.verticalCenter: parent.verticalCenter
                // a little wider than the pill so an empty
                // workspace is still a comfortable click target
                implicitWidth: pip.width + 4
                implicitHeight: Theme.moduleHeight - 8

                Rectangle {
                    id: pip
                    anchors.centerIn: parent
                    height: 7
                    width: parent.current ? 22 : (parent.occupied ? 11 : 7)
                    // fully rounded: half the height makes a pill
                    // at any width, and a circle at the stub size
                    radius: height / 2
                    color: parent.current ? Theme.accent
                        : (parent.occupied ? Theme.subtext : Theme.muted)

                    Behavior on width {
                        NumberAnimation { duration: Theme.dur(130); easing.type: Theme.ease }
                    }
                    Behavior on color { ColorAnimation { duration: Theme.dur(130) } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("hl.dsp.focus({workspace=" + parent.wsId + "})")
                }
            }
        }
    }

    // overview of every window on every workspace
    BarModule {
        id: wsOverviewBtn
        visible: Settings.widgetVisible("overview")
        anchors.verticalCenter: parent.verticalCenter
        icon: "󰕰"
        active: screenScope.openFlyout === "workspaces"
        dimmed: screenScope.openFlyout !== "workspaces"
        onActivated: screenScope.toggleFlyout("workspaces", wsOverviewBtn)
    }

    // icons for whatever is open on the focused workspace,
    // trailing the overview button. One frame around the whole
    // row rather than one per icon: they're a single group, and
    // a chip each would read as six separate modules.
    ModuleFrame {
        id: windowIcons
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceM
        // an empty chip on a bare workspace would be a floating
        // rectangle with nothing in it
        visible: iconRepeater.count > 0 && Settings.widgetVisible("windows")

        Repeater {
            id: iconRepeater
            model: barModules.bar.focusedWorkspaceIcons()

            IconImage {
                required property var modelData
                anchors.verticalCenter: parent.verticalCenter
                source: modelData.source
                implicitSize: Theme.fs(18)

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // focus and bring to top -- so floating windows stay
                        // accessible even when behind a monocle-maximized window
                        var addr = "address:0x" + parent.modelData.address
                        Hyprland.dispatch("hl.dsp.focus({window=\"" + addr + "\"})")
                        Hyprland.dispatch("hl.dsp.window.bring_to_top({window=\"" + addr + "\"})")
                    }
                }
            }
        }
    }

    // Time and date in one chip, which briefly shows volume, layout, track
    // and notification changes instead (see ClockIsland.qml).
    ClockIsland {
        id: clock
        visible: Settings.widgetVisible("clock")
        screenScope: barModules.screenScope
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
        // solid, and the thin one read as a different weight
        icon: Network.ssid !== "" ? "󰤨" : "󰤮"
        active: screenScope.openFlyout === "network"
        dimmed: Network.ssid === ""
        onActivated: {
            // scan on open rather than on a timer: the radio
            // should not sweep while nobody is looking at it
            Network.scan()
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

    BarModule {
        id: brightBtn
        visible: Brightness.available && Settings.widgetVisible("brightness")
        fixedWidth: Theme.moduleWidth
        icon: "󰃠"
        fillValue: Brightness.level / 100
        active: screenScope.openFlyout === "brightness"
        acceptWheel: true
        onActivated: screenScope.toggleFlyout("brightness", brightBtn)
        onWheeled: d => Brightness.set(Brightness.level + d * 5)
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
            return Theme.muted
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

    // system tray: one frame around every app's icon, like the
    // open-windows strip. Left activates, right opens the app's
    // menu in a flyout, middle is the app's secondary action.
    ModuleFrame {
        id: trayFrame
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceM
        visible: trayRepeater.count > 0 && Settings.widgetVisible("tray")
        active: screenScope.openFlyout === "traymenu"

        Repeater {
            id: trayRepeater
            model: SystemTray.items.values

            IconImage {
                id: trayIcon
                required property var modelData
                anchors.verticalCenter: parent.verticalCenter
                source: modelData.icon
                implicitSize: Theme.fs(16)

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        var item = trayIcon.modelData
                        if (mouse.button === Qt.MiddleButton) {
                            item.secondaryActivate()
                        } else if (mouse.button === Qt.RightButton || item.onlyMenu) {
                            if (!item.hasMenu) return
                            var menu = barModules.trayMenu.ensure()
                            menu.item = item
                            menu.stack = []
                            screenScope.toggleFlyout("traymenu", trayIcon)
                        } else {
                            item.activate()
                        }
                    }
                }
            }
        }
    }

    BarModule {
        id: mediaBtn
        readonly property var player: Media.player
        visible: player !== null && Settings.widgetVisible("media")
        icon: player && player.isPlaying ? "󰏤" : "󰐊"
        label: !player ? ""
            : (player.trackArtist ? player.trackArtist + " – " : "") + (player.trackTitle || player.identity)
        labelMaxWidth: 220
        active: screenScope.openFlyout === "media"
        onActivated: screenScope.toggleFlyout("media", mediaBtn)
        onMiddleClicked: if (player && player.canTogglePlaying) player.togglePlaying()
    }

    // audio spectrum: thin pills growing from the middle, in the
    // same shape language as the workspace indicator
    ModuleFrame {
        id: vizFrame
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceXs
        padH: 8
        visible: Visualizer.playing && Settings.widgetVisible("visualizer")

        Repeater {
            model: Visualizer.barCount

            Item {
                required property int index
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 3
                implicitHeight: Theme.moduleHeight - 10

                Rectangle {
                    anchors.centerIn: parent
                    width: 3
                    radius: 1.5
                    readonly property real v: (Visualizer.bars[parent.index] || 0) / 100
                    height: Math.max(3, parent.height * v)
                    color: Theme.text
                    Behavior on height { NumberAnimation { duration: Theme.dur(60) } }
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
        // always shown, so the panel is one click away even when
        // it's empty; dimmed when there's nothing unread
        visible: Settings.widgetVisible("notifications")
        icon: Notifications.dnd ? "󰂛" : "󰂚"
        label: Notifications.count > 0 ? String(Notifications.count) : ""
        dimmed: Notifications.dnd || Notifications.count === 0 || !Notifications.available
        // left: swaync's panel; right: Do Not Disturb
        onActivated: Notifications.togglePanel()
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
        visible: Updates.count > 0 && Settings.widgetVisible("updates")
        icon: "󰚰"
        label: String(Updates.count)
        active: screenScope.openFlyout === "updates"
        onActivated: screenScope.toggleFlyout("updates", updatesBtn)
    }
}
