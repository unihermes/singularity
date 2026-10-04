// Singularity - Quickshell
// ~/.config/quickshell/settings/LockPreview.qml
//
// A small picture of the lock screen, for the Lock Screen page's tiles. It's
// laid out in a 1920×1200 screen and scaled down, with the clock, the info
// line and the password field where hyprlock puts them (AppearanceSync.qml
// writes the positions; hyprlock.conf has the field's).

import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import "../services"

ClippingRectangle {
    id: root

    // "wallpaper", "screenshot" or "plain"
    property string kind: "wallpaper"
    property int blur: 0
    // percent
    property int dim: 0
    // the page's clock choice: "24", "12", "seconds", "date" ("" for one set by hand)
    property string clock: "24"
    property string size: Settings.lockClockSize
    property string place: Settings.lockClockPlace
    property bool info: Settings.lockDate || Settings.lockMedia || Settings.lockNotifs

    readonly property real k: width / 1920
    readonly property int clockPx: ({ small: 40, large: 64, huge: 110 })[size] || 64

    implicitHeight: width * 10 / 16
    radius: Theme.radiusInner
    color: Theme.base

    // the background: the wallpaper, or a desktop standing in for the
    // screenshot hyprlock takes
    Item {
        id: ground
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Image {
            anchors.fill: parent
            source: "file://" + Quickshell.env("HOME") + "/.local/state/singularity/current-wallpaper"
            sourceSize.width: 480
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Item {
            visible: root.kind === "screenshot"
            anchors.fill: parent
            Rectangle { width: parent.width; height: 44 * root.k; color: Theme.bar }
            Rectangle {
                x: 120 * root.k; y: 110 * root.k; width: 980 * root.k; height: 620 * root.k
                color: Theme.panel; border.width: 1; border.color: Theme.muted; radius: Theme.panelFrameRadius * root.k
            }
            Rectangle {
                x: 1160 * root.k; y: 110 * root.k; width: 640 * root.k; height: 940 * root.k
                color: Theme.panel; border.width: 1; border.color: Theme.muted; radius: Theme.panelFrameRadius * root.k
            }
        }
    }

    Rectangle { anchors.fill: parent; color: Theme.base }

    MultiEffect {
        visible: root.kind !== "plain"
        anchors.fill: parent
        source: ground
        blurEnabled: root.blur > 0
        blurMax: 12
        blur: Math.min(1, root.blur * 0.25)
        autoPaddingEnabled: false
    }

    Rectangle {
        visible: root.kind !== "plain"
        anchors.fill: parent
        color: "black"
        opacity: root.dim / 100
    }

    Item {
        id: space
        width: 1920
        height: 1200
        scale: root.k
        transformOrigin: Item.TopLeft

        Text {
            id: clockText
            text: Qt.formatDateTime(new Date(), ({ "12": "h:mm AP", "seconds": "HH:mm:ss",
                "date": "ddd d MMM  HH:mm" })[root.clock] || "HH:mm")
            color: Theme.bright
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: root.clockPx
            x: root.place === "corner" ? 60 : (space.width - width) / 2
            y: root.place === "top" ? 60
                : root.place === "corner" ? space.height - 92 - height
                : 600 - (50 + root.clockPx * 0.6) - height / 2
        }

        // the info line, drawn as a bar: text this small would only smudge
        Rectangle {
            visible: root.info
            width: 360
            height: 14
            radius: 7
            color: Theme.subtext
            x: root.place === "corner" ? 62 : (space.width - width) / 2
            y: root.place === "top" ? 60 + root.clockPx * 1.5
                : root.place === "corner" ? space.height - 60 - height
                : 600 - 34 - height / 2
        }

        Rectangle {
            x: 830
            y: 598
            width: 260
            height: 44
            radius: Theme.radius
            color: Theme.surface
            border.width: 2
            border.color: Theme.border
        }
    }
}
