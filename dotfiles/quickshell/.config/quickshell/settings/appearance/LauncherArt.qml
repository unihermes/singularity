// A small screen with the launcher drawn in one layout (`value`, else the
// tile's `parent.value`): the Launcher layout tiles, and PanelArt's picture
// for the layouts it doesn't draw itself. `screen: false` leaves out the
// ground and bar, for drawing over a picture that has its own.

import QtQuick
import "../../services"

Item {
    id: art

    property string value: parent && parent.value !== undefined ? parent.value : ""
    property bool screen: true
    property real barH: height * 0.09
    readonly property real u: width / 100
    readonly property var apps: ["#e66a3c", "#3c8ee6", "#5ac36e", "#c8a23c", "#9a6ad6", "#d6409f"]

    width: Theme.fs(112)
    height: Theme.fs(63)

    component Box: Rectangle { radius: 2 * art.u; color: Theme.glass ? Theme.panelTone : Theme.panel; border.width: 1; border.color: Theme.stroke }
    component Ln: Rectangle { height: 2 * art.u; radius: height / 2; color: Theme.overlay }
    component Field: Rectangle { height: 5 * art.u; radius: 1.5 * art.u; color: "transparent"; border.width: 1; border.color: Theme.accent }
    component Dot: Rectangle { property int n: 0; width: 6 * art.u; height: width; radius: 1.5 * art.u; color: art.apps[n % 6] }
    // rows of lines, the first lit
    component Rows: Column {
        property int count: 4
        property real lineWidth: 30 * art.u
        spacing: 2.5 * art.u
        Repeater {
            model: parent.count
            Ln { required property int index; width: parent.lineWidth * (index % 2 ? 0.8 : 1); color: index === 0 ? Theme.subtext : Theme.overlay }
        }
    }
    component Dots: Grid {
        property int count: 8
        spacing: 3 * art.u
        Repeater { model: parent.count; Dot { required property int index; n: index } }
    }

    Rectangle {
        visible: art.screen
        anchors.fill: parent
        radius: 3 * art.u
        color: Theme.glass ? Theme.barTone : Theme.base
        border.width: 1
        border.color: Theme.stroke
    }
    Rectangle {
        visible: art.screen
        x: 1; y: 1
        width: parent.width - 2
        height: art.barH
        radius: 3 * art.u
        color: Theme.glass ? Theme.barTone : Theme.bar
    }

    // list, grid, line, home: a centred box
    Box {
        visible: ["list", "grid", "home"].indexOf(art.value) !== -1
        x: 25 * art.u; y: art.barH + 6 * art.u
        width: 50 * art.u; height: art.height - y - 6 * art.u
        Column {
            x: 4 * art.u; y: 4 * art.u
            spacing: 3 * art.u
            Field { width: 42 * art.u }
            Rows { visible: art.value === "list"; count: 5 }
            Dots { visible: art.value !== "list"; columns: 5; count: art.value === "home" ? 5 : 10 }
            Rows { visible: art.value === "home"; count: 2; lineWidth: 36 * art.u }
        }
    }
    Box {
        visible: art.value === "line"
        x: 20 * art.u; y: art.height * 0.42
        width: 60 * art.u; height: 10 * art.u
        Row {
            x: 2.5 * art.u; anchors.verticalCenter: parent.verticalCenter
            spacing: 2.5 * art.u
            Field { width: 18 * art.u }
            Repeater { model: 3; Rectangle { required property int index; width: 10 * art.u; height: 5 * art.u; radius: 1.5 * art.u; color: index === 0 ? Theme.accent : Theme.overlay } }
        }
    }

    // spotlight: a big field high up, the hits under labels
    Box {
        visible: art.value === "spotlight"
        x: 20 * art.u; y: art.barH + 7 * art.u
        width: 60 * art.u; height: 30 * art.u
        Rectangle { x: 4 * art.u; y: 3 * art.u; width: 30 * art.u; height: 3 * art.u; radius: height / 2; color: Theme.text }
        Rectangle { y: 9 * art.u; width: parent.width; height: 1; color: Theme.stroke }
        Column {
            x: 4 * art.u; y: 12 * art.u
            spacing: 2.5 * art.u
            Row {
                spacing: 2 * art.u
                Dot { n: 1; width: 7 * art.u }
                Ln { width: 22 * art.u; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
            }
            Ln { width: 12 * art.u; height: 1.2 * art.u; color: Theme.muted }
            Rows { count: 2; lineWidth: 40 * art.u }
        }
    }

    // start: hung under the bar's corner, groups down its side
    Box {
        visible: art.value === "start"
        x: 2 * art.u; y: art.barH + 1.5 * art.u
        width: 56 * art.u; height: art.height - y - 6 * art.u
        Field { x: 3 * art.u; y: 3 * art.u; width: 50 * art.u }
        Rows { x: 3 * art.u; y: 12 * art.u; count: 6; lineWidth: 11 * art.u; spacing: 2 * art.u }
        Rectangle { x: 17 * art.u; y: 10 * art.u; width: 1; height: parent.height - 18 * art.u; color: Theme.stroke }
        Dots { x: 21 * art.u; y: 12 * art.u; columns: 4; count: 8 }
        Rectangle { y: parent.height - 6 * art.u; width: parent.width; height: 1; color: Theme.stroke }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 3 * art.u
            y: parent.height - 4 * art.u
            spacing: 1.5 * art.u
            Repeater { model: 3; Rectangle { width: 2.5 * art.u; height: width; radius: width / 2; color: Theme.subtext } }
        }
    }

    // drawer: the height of the screen along its side
    Box {
        visible: art.value === "drawer"
        x: 1; y: art.barH + 1
        width: 34 * art.u; height: art.height - y - 1
        radius: 0
        Row {
            x: 3 * art.u; y: 3 * art.u
            spacing: 1 * art.u
            Repeater { model: 4; Rectangle { required property int index; width: 6.5 * art.u; height: 3 * art.u; radius: 1 * art.u; color: index === 0 ? Theme.accent : Theme.overlay } }
        }
        Field { x: 3 * art.u; y: 9 * art.u; width: 28 * art.u }
        Column {
            x: 3 * art.u; y: 17 * art.u
            spacing: 2 * art.u
            Repeater {
                model: 2
                Column {
                    spacing: 2 * art.u
                    Rectangle { width: 2 * art.u; height: 2 * art.u; color: Theme.headingMarkColor }
                    Rows { count: 3; lineWidth: 22 * art.u; spacing: 2 * art.u }
                }
            }
        }
        Column {
            anchors.right: parent.right; anchors.rightMargin: 1.5 * art.u
            y: 17 * art.u
            spacing: 1.6 * art.u
            Repeater { model: 10; Rectangle { width: 1.2 * art.u; height: width; color: Theme.muted } }
        }
    }

    // bar: the field on the bar, the hits dropping from it
    Field {
        visible: art.value === "bar"
        x: 30 * art.u; y: 1
        width: 40 * art.u; height: art.barH - 1
    }
    Box {
        visible: art.value === "bar"
        x: 30 * art.u; y: art.barH
        width: 40 * art.u; height: 26 * art.u
        radius: 0
        Column {
            x: 3 * art.u; y: 3 * art.u
            spacing: 2.5 * art.u
            Repeater {
                model: 5
                Row {
                    required property int index
                    spacing: 2 * art.u
                    Rectangle { width: 3 * art.u; height: 2 * art.u; color: Theme.muted }
                    Ln { width: 22 * art.u; color: parent.index === 0 ? Theme.subtext : Theme.overlay }
                }
            }
        }
    }

    // mosaic: the desktop dimmed, tiles of three sizes
    Rectangle {
        visible: art.value === "mosaic"
        x: 1; y: art.barH; width: parent.width - 2; height: parent.height - y - 1
        color: "black"
        opacity: 0.35
    }
    Field {
        visible: art.value === "mosaic"
        x: 32 * art.u; y: art.barH + 3 * art.u
        width: 36 * art.u; radius: height / 2
    }
    Repeater {
        // [x, y, w, h] in cells of 10 x 8
        model: art.value === "mosaic"
            ? [[0, 0, 2, 2], [2, 0, 2, 2], [4, 0, 2, 1], [6, 0, 2, 1], [4, 1, 2, 1], [6, 1, 2, 1],
               [0, 2, 1, 1], [1, 2, 1, 1], [2, 2, 1, 1], [3, 2, 1, 1], [4, 2, 1, 1], [5, 2, 1, 1], [6, 2, 1, 1], [7, 2, 1, 1]]
            : []
        Rectangle {
            required property var modelData
            required property int index
            x: 10 * art.u + modelData[0] * 10 * art.u
            y: art.barH + 12 * art.u + modelData[1] * 12 * art.u
            width: modelData[2] * 10 * art.u - 1.5 * art.u
            height: modelData[3] * 12 * art.u - 1.5 * art.u
            radius: 1.5 * art.u
            color: Theme.glass ? Theme.panelTone : Theme.panel
            border.width: 1
            border.color: index === 0 ? Theme.accent : Theme.stroke
            Dot { x: 1.5 * art.u; y: 1.5 * art.u; n: parent.index; width: parent.modelData[3] > 1 ? 7 * art.u : 4 * art.u }
        }
    }
}
