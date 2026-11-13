// The Panels tab's pictures, one beside each section: the wallpaper under
// a strip of bar, and the section's panels drawn small as they're set, in
// the theme's colours. `kind`:
//   popups    a notification popup, a flyout and the level popup
//   launcher  the launcher in its layout (and position, for List, Grid and
//             One line)
//   overlays  the window switcher and the power menu over the backdrop
//   widgets   the desktop widgets that are on, and the sidebar

import Quickshell.Widgets
import QtQuick
import "../../services"

ClippingRectangle {
    id: art
    property string kind: "popups"
    readonly property real u: width / 240
    readonly property real barH: 11 * u
    readonly property var apps: ["#e66a3c", "#3c8ee6", "#5ac36e", "#c8a23c", "#9a6ad6", "#d6409f"]

    radius: Theme.radiusInner
    color: Theme.base
    border.width: Theme.borderWidth
    border.color: Theme.stroke

    Image {
        anchors.fill: parent
        source: Wallpaper.current !== "" ? "file://" + Wallpaper.current : ""
        sourceSize.width: 480
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    // a panel's ground, and a line of text as a bar
    component Ground: Rectangle { radius: 4 * art.u; color: Theme.panel; border.width: 1; border.color: Theme.stroke }
    component Line: Rectangle { height: 3 * art.u; radius: height / 2; color: Theme.overlay }
    component AppDot: Rectangle { width: 7 * art.u; height: width; radius: 2 * art.u }

    // the backdrop behind the overlays and the full launcher
    Rectangle {
        visible: art.kind === "overlays" || (art.kind === "launcher" && Settings.launcherPosition === "full" && Theme.launcherPlaced)
        anchors.fill: parent
        color: Settings.overviewBackdrop === "solid" ? Theme.base : "black"
        opacity: Settings.overviewBackdrop === "solid" ? 1 : Settings.overviewBackdrop === "dim" ? Settings.scrim / 100 : 0
    }

    Rectangle {
        width: parent.width
        height: art.barH
        color: Theme.bar
        Row {
            x: 5 * art.u
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2 * art.u
            Rectangle { width: 9 * art.u; height: 4 * art.u; radius: height / 2; color: Theme.accent }
            Rectangle { width: 4 * art.u; height: 4 * art.u; radius: height / 2; color: Theme.overlay }
            Rectangle { width: 4 * art.u; height: 4 * art.u; radius: height / 2; color: Theme.overlay }
        }
        Line { anchors.centerIn: parent; width: 26 * art.u; color: Theme.text }
    }

    // --- popups ------------------------------------------------------------

    Item {
        visible: art.kind === "popups"
        anchors.fill: parent

        // a flyout under the bar, as wide as Flyout width says
        Ground {
            x: 12 * art.u
            y: art.barH + 3 * art.u
            width: 70 * art.u * Settings.flyoutWidth / 100
            height: 46 * art.u
            Column {
                x: 6 * art.u; y: 6 * art.u
                width: parent.width - 12 * art.u
                spacing: 5 * art.u
                Line { width: parent.width * 0.4; color: Theme.accent }
                Rectangle { width: parent.width; height: 4 * art.u; radius: height / 2; color: Theme.overlay
                    Rectangle { width: parent.width * 0.6; height: parent.height; radius: parent.radius; color: Theme.accent } }
                Line { width: parent.width * 0.8 }
                Line { width: parent.width * 0.6 }
            }
        }

        // the notification popup in its style, as wide as Popup width says
        Ground {
            readonly property bool banner: Settings.notifStyle === "banner"
            readonly property bool compact: Settings.notifStyle === "compact"
            x: banner ? (art.width - width) / 2 : art.width - width - 6 * art.u
            y: art.barH + 3 * art.u
            width: banner ? art.width * 0.6 : Math.min(art.width * 0.55, 90 * art.u * Settings.notifWidth / 380)
            height: banner || compact ? 13 * art.u : 38 * art.u
            Row {
                x: 5 * art.u; y: 3 * art.u
                spacing: 4 * art.u
                AppDot { color: "#5ac36e" }
                Column {
                    spacing: 3 * art.u
                    anchors.verticalCenter: parent.verticalCenter
                    Line { width: 30 * art.u; color: Theme.text }
                    Line { visible: Settings.notifStyle === "full"; width: 44 * art.u }
                }
            }
            Row {
                visible: Settings.notifStyle === "full"
                x: 5 * art.u
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 5 * art.u
                spacing: 3 * art.u
                Rectangle { width: 16 * art.u; height: 6 * art.u; radius: 2 * art.u; color: Theme.surface }
                Rectangle { width: 16 * art.u; height: 6 * art.u; radius: 2 * art.u; color: Theme.surface }
            }
        }

        // the level popup in its style
        Ground {
            visible: Settings.levelStyle === "pill"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10 * art.u
            width: 90 * art.u
            height: 12 * art.u
            radius: height / 2
            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 20 * art.u; height: 3 * art.u; radius: height / 2; color: Theme.overlay
                Rectangle { width: parent.width * 0.62; height: parent.height; radius: parent.radius; color: Theme.accent }
            }
        }
        Ground {
            visible: Settings.levelStyle === "edge"
            anchors.right: parent.right
            anchors.rightMargin: 4 * art.u
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12 * art.u
            width: 7 * art.u
            height: 60 * art.u
            Rectangle {
                anchors.bottom: parent.bottom; anchors.bottomMargin: 2 * art.u
                anchors.horizontalCenter: parent.horizontalCenter
                width: 3 * art.u; height: (parent.height - 4 * art.u) * 0.62; radius: width / 2; color: Theme.accent
            }
        }
        Ground {
            visible: Settings.levelStyle === "number"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10 * art.u
            width: 36 * art.u
            height: 22 * art.u
            Text {
                anchors.centerIn: parent
                text: "62"
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightStrong
                font.pixelSize: 13 * art.u
            }
        }
    }

    // --- launcher ----------------------------------------------------------

    // the other layouts, as their Launcher layout tile draws them
    LauncherArt {
        visible: art.kind === "launcher" && !launcher.classic
        anchors.fill: parent
        screen: false
        barH: art.barH
        value: Settings.launcherLayout
    }

    Ground {
        id: launcher
        readonly property bool full: Settings.launcherPosition === "full"
        readonly property bool line: Settings.launcherLayout === "line"
        readonly property bool classic: ["list", "grid", "line"].indexOf(Settings.launcherLayout) !== -1
        visible: art.kind === "launcher" && classic
        x: full ? 0 : art.width * 0.2
        y: full ? art.barH : Settings.launcherPosition === "top" ? art.barH + 3 * art.u : (line ? art.height * 0.4 : art.height * 0.22)
        width: full ? art.width : art.width * 0.6
        height: full ? art.height - art.barH : line ? 16 * art.u : Math.min(art.height - y - 6 * art.u, 20 * art.u + Math.min(Settings.launcherRows, 6) * 11 * art.u)
        radius: full ? 0 : 4 * art.u

        // the search field, and a line of hits after it in One line
        Row {
            x: 5 * art.u; y: 4 * art.u
            spacing: 4 * art.u
            Rectangle {
                width: launcher.line ? 40 * art.u : launcher.width - 10 * art.u
                height: 8 * art.u
                radius: 2 * art.u
                color: "transparent"
                border.width: 1
                border.color: Theme.accent
            }
            Repeater {
                model: launcher.line ? 3 : 0
                Rectangle {
                    required property int index
                    width: 18 * art.u; height: 8 * art.u; radius: 2 * art.u
                    color: index === 0 ? Theme.accent : Theme.surface
                }
            }
        }
        Column {
            visible: Settings.launcherLayout === "list"
            x: 5 * art.u; y: 16 * art.u
            width: launcher.width - 10 * art.u
            spacing: 3 * art.u
            Repeater {
                model: Math.min(Settings.launcherRows, launcher.full ? 10 : 6)
                Rectangle {
                    required property int index
                    width: parent.width; height: 8 * art.u; radius: 2 * art.u
                    color: index === 0 ? Theme.overlay : "transparent"
                    Row {
                        x: 2 * art.u
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4 * art.u
                        AppDot { width: 5 * art.u; color: art.apps[index % 6] }
                        Line { width: 26 * art.u; color: Theme.text; anchors.verticalCenter: parent.verticalCenter }
                        Line { visible: Settings.launcherDetails; width: 34 * art.u; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
        Grid {
            visible: Settings.launcherLayout === "grid"
            x: 6 * art.u; y: 17 * art.u
            columns: launcher.full ? 10 : 6
            spacing: 5 * art.u
            Repeater {
                model: launcher.full ? 30 : 12
                AppDot { required property int index; width: 10 * art.u; color: art.apps[index % 6]; opacity: index === 0 ? 1 : 0.75 }
            }
        }
    }

    // --- overlays ----------------------------------------------------------

    Item {
        visible: art.kind === "overlays"
        anchors.fill: parent

        // the switcher in its style, over the top half
        Ground {
            anchors.horizontalCenter: parent.horizontalCenter
            y: art.barH + 10 * art.u
            width: sw.width + 10 * art.u
            height: sw.height + 10 * art.u
            Item {
                id: sw
                x: 5 * art.u; y: 5 * art.u
                width: Settings.altTabStyle === "titled" ? titled.width : tiles.width
                height: Settings.altTabStyle === "titled" ? titled.height : tiles.height
                Row {
                    id: tiles
                    visible: Settings.altTabStyle !== "titled"
                    spacing: 5 * art.u
                    Repeater {
                        model: 4
                        Rectangle {
                            required property int index
                            readonly property bool preview: Settings.altTabStyle === "previews"
                            width: (preview ? 28 : 12) * art.u
                            height: (preview ? 18 : 12) * art.u
                            radius: 2 * art.u
                            color: preview ? Theme.overlay : art.apps[index]
                            border.width: index === 0 ? 2 : 0
                            border.color: Theme.accent
                        }
                    }
                }
                Column {
                    id: titled
                    visible: Settings.altTabStyle === "titled"
                    spacing: 3 * art.u
                    Repeater {
                        model: 3
                        Row {
                            required property int index
                            spacing: 4 * art.u
                            AppDot { color: art.apps[index] }
                            Line { width: 30 * art.u; color: index === 0 ? Theme.textStrong : Theme.text; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }
        }

        // the power menu in its style, over the bottom half
        Row {
            visible: Settings.powerStyle !== "list"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14 * art.u
            spacing: (Settings.powerStyle === "full" ? 10 : 5) * art.u
            Repeater {
                model: 5
                Rectangle {
                    required property int index
                    readonly property real s: (Settings.powerStyle === "full" ? 16 : 12) * art.u
                    width: s; height: s
                    radius: Settings.powerStyle === "full" ? s / 2 : 3 * art.u
                    color: index === 0 ? Theme.accent : Theme.overlay
                }
            }
        }
        Ground {
            visible: Settings.powerStyle === "list"
            anchors.right: parent.right
            anchors.rightMargin: 6 * art.u
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8 * art.u
            width: 56 * art.u
            height: 46 * art.u
            Column {
                x: 5 * art.u; y: 5 * art.u
                spacing: 4 * art.u
                Repeater {
                    model: 4
                    Line { required property int index; width: 44 * art.u; color: index === 0 ? Theme.accent : Theme.overlay }
                }
            }
        }
    }

    // --- desktop widgets -----------------------------------------------------

    Item {
        visible: art.kind === "widgets"
        anchors.fill: parent

        Column {
            visible: Settings.deskWidget("clock").on
            x: 10 * art.u; y: art.barH + 8 * art.u
            Text {
                text: Qt.formatTime(new Date(), Theme.timeFormat)
                color: "white"
                font.family: Theme.fontText
                font.weight: Theme.weightStrong
                font.pixelSize: 22 * art.u
            }
            Line { width: 50 * art.u; color: "white"; opacity: 0.8 }
        }
        Row {
            visible: Settings.deskWidget("weather").on
            x: 10 * art.u; y: art.barH + 44 * art.u
            spacing: 4 * art.u
            Repeater { model: 5; Rectangle { width: 9 * art.u; height: 12 * art.u; radius: 2 * art.u; color: Qt.rgba(0, 0, 0, 0.4) } }
        }
        Row {
            visible: Settings.deskWidget("music").on
            x: 10 * art.u
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10 * art.u
            spacing: 4 * art.u
            Rectangle { width: 16 * art.u; height: 16 * art.u; radius: 3 * art.u; color: "#9a6ad6" }
            Line { width: 40 * art.u; color: "white"; anchors.verticalCenter: parent.verticalCenter }
        }
        Column {
            visible: Settings.deskWidget("stats").on
            anchors.right: sidebar.left
            anchors.rightMargin: 8 * art.u
            y: art.barH + 10 * art.u
            spacing: 4 * art.u
            Repeater { model: 3; Line { width: 34 * art.u; color: "white"; opacity: 0.8 } }
        }
        Column {
            visible: Settings.deskWidget("sysinfo").on
            anchors.right: sidebar.left
            anchors.rightMargin: 8 * art.u
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10 * art.u
            spacing: 4 * art.u
            Repeater { model: 2; Line { width: 40 * art.u; color: "white"; opacity: 0.7 } }
        }
        Rectangle {
            id: sidebar
            readonly property real gap: Settings.deskSidebarStyle === "floating" ? 3 * art.u : 0
            visible: Settings.deskSidebar
            anchors.right: parent.right
            anchors.rightMargin: gap
            y: art.barH + gap
            width: visible ? 22 * art.u : 0
            height: parent.height - art.barH - gap * 2
            radius: gap
            color: Qt.rgba(0, 0, 0, 0.35)
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 6 * art.u
                spacing: 6 * art.u
                Repeater { model: 4; Line { width: 12 * art.u; color: "white"; opacity: 0.7 } }
            }
        }
    }
}
