// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/LookCard.qml
//
// One card in the Look tab's carousel: a miniature of the look drawn with
// the look's own values rather than Theme's -- its bar with three chips in
// its module style, and a flyout with a heading, a lit row and a meter, in
// its palette, accent, corners, strokes and font.

import Quickshell
import Quickshell.Widgets
import QtQuick
import "../../services/Styles.js" as Styles
import "../../services"
import "../../flyouts"
import ".."

ClippingRectangle {
    id: pv
    required property var look
    readonly property var pal: look.palette
    // the look's settings with what its style draws (Styles.resolve)
    readonly property var ls: Object.assign({}, look.settings, Styles.resolve(look.settings))
    readonly property color accent: look.accent || pal.bright
    readonly property int r: ls.radius
    readonly property int bw: ls.borderWidth
    readonly property bool floating: ls.barStyle === "floating"
    // islands: no one bar ground, just what's behind the chips
    readonly property bool groundless: ls.barStyle === "islands"
    readonly property bool inset: ls.barStyle !== "full"
    readonly property bool atBottom: ls.barPosition === "bottom"
    readonly property string mod: ls.moduleStyle
    readonly property bool bevelled: ls.frameStyle === "bevel"
    readonly property bool stroked: !bevelled && ls.frameStyle !== "none"
    readonly property var bv: look.bevel || { light: Qt.lighter(pal.border, 1.8), dark: Qt.darker(pal.border, 1.8) }

    // the desktop behind it: the look's deepest ground
    color: pal.base

    // bar
    Rectangle {
        id: miniBar
        x: pv.inset ? 5 : 0
        y: pv.atBottom ? parent.height - height - x : x
        width: parent.width - x * 2
        height: Theme.fs(18)
        radius: pv.floating ? Math.min(pv.r, height / 2) : 0
        color: pv.groundless ? "transparent" : pv.pal.bar
        border.width: pv.floating && !pv.bevelled ? pv.bw : 0
        border.color: pv.pal.border

        Bevel {
            visible: pv.floating && pv.bevelled
            anchors.fill: parent
            light: pv.bv.light
            dark: pv.bv.dark
            thickness: pv.bw
        }

        Rectangle {
            visible: !pv.inset && !pv.bevelled
            y: pv.atBottom ? 0 : parent.height - height
            width: parent.width
            height: pv.bw
            color: pv.pal.border
        }

        Bevel {
            visible: !pv.inset && pv.bevelled
            anchors.fill: parent
            light: pv.bv.light
            dark: pv.bv.dark
            thickness: pv.bw
        }

        // an island: its own ground around the chips
        Rectangle {
            visible: pv.ls.barStyle === "islands"
            x: miniChips.x - 3
            width: miniChips.width + 6
            height: parent.height
            radius: Math.min(pv.r, height / 2)
            color: pv.pal.bar
            border.width: pv.bw
            border.color: pv.pal.border
        }

        Row {
            id: miniChips
            anchors.verticalCenter: parent.verticalCenter
            x: pv.ls.barStyle === "islands" ? 6 : 4
            spacing: 3
            Repeater {
                model: [false, true, false]
                Rectangle {
                    required property bool modelData
                    width: modelData ? 22 : 14
                    height: miniBar.height - 6
                    radius: pv.mod === "pill" ? height / 2 : Math.min(pv.r, 4)
                    readonly property bool bare: pv.mod === "bracket" || pv.mod === "underline" || pv.mod === "cornered"
                    // the styles whose open chip fills with the accent
                    readonly property bool openFill: pv.mod === "filled" || pv.mod === "pill" || pv.mod === "boxed"
                    color: bare ? "transparent"
                        : modelData ? (openFill ? pv.accent : pv.pal.overlay)
                        : pv.mod === "outline" || pv.mod === "ghost" ? "transparent"
                        : pv.mod === "boxed" ? pv.pal.bar : pv.pal.surface
                    border.width: pv.mod === "outline" || pv.mod === "boxed" ? pv.bw : 0
                    border.color: pv.mod === "boxed" ? pv.pal.text : modelData ? pv.accent : pv.pal.border
                    Rectangle {
                        visible: pv.mod === "underline" && parent.modelData
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 2
                        color: pv.accent
                    }
                    CornerMarks {
                        visible: pv.mod === "cornered"
                        length: 4
                        thickness: 1
                        color: parent.modelData ? pv.accent : pv.pal.muted
                    }
                    Text {
                        visible: pv.mod === "bracket"
                        anchors.centerIn: parent
                        text: "[" + " ".repeat(parent.modelData ? 2 : 1) + "]"
                        color: parent.modelData ? pv.accent : pv.pal.muted
                        font.family: pv.ls.fontFamily
                        font.pixelSize: parent.height
                    }
                }
            }
        }
    }

    // flyout
    Rectangle {
        id: miniPanel
        x: pv.inset ? 14 : 10
        // hangs off the bar, on whichever edge it's on
        y: pv.atBottom ? miniBar.y - height - (pv.inset ? 5 : 0)
            : miniBar.y + miniBar.height + (pv.inset ? 5 : 0)
        width: parent.width * 0.62
        height: miniCol.implicitHeight + 12
        radius: pv.r
        color: pv.pal.panel
        opacity: 1
        border.width: pv.stroked ? pv.bw : 0
        border.color: pv.ls.frameStyle === "ledger" ? pv.pal.text
            : pv.ls.frameStyle === "corners" ? Qt.alpha(pv.pal.border, 0.6) : pv.pal.border

        Bevel {
            visible: pv.bevelled
            anchors.fill: parent
            raised: true
            light: pv.bv.light
            dark: pv.bv.dark
            thickness: pv.bw
        }

        Rectangle {
            visible: pv.ls.frameStyle === "double"
            anchors.fill: parent
            anchors.margins: 3
            radius: Math.max(0, pv.r - 3)
            color: "transparent"
            border.width: 1
            border.color: pv.pal.muted
        }

        Bevel {
            visible: pv.bevelled
            anchors.fill: parent
            anchors.margins: 2
            raised: false
            light: pv.pal.surface
            dark: pv.pal.base
            thickness: pv.bw
        }

        Column {
            id: miniCol
            x: 7
            y: 6
            width: parent.width - 14
            spacing: 3

            Row {
                spacing: 4
                Text {
                    text: (pv.ls.headingPrefix ? pv.ls.headingPrefix + " " : "") + (pv.ls.headingUpper ? "SOUND" : "Sound")
                    color: pv.pal.bright
                    font.family: Fonts.resolve(pv.ls.fontFamily)
                    font.pixelSize: Theme.fs(10)
                    font.weight: Theme.weightStrong
                    font.letterSpacing: pv.ls.headingUpper ? 0.5 : 0
                }
            }
            // a lit row: hover fill and the accent tick
            Rectangle {
                width: parent.width
                height: Theme.fs(12)
                radius: Math.max(0, pv.r - 2)
                color: pv.pal.overlay
                Rectangle { width: 2; height: parent.height - 4; y: 2; color: pv.accent }
                Text {
                    x: 5
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Speakers"
                    color: pv.pal.bright
                    font.family: Fonts.resolve(pv.ls.fontFamily)
                    font.pixelSize: Theme.fs(9)
                }
            }
            Text {
                text: "Headphones"
                color: pv.pal.text
                font.family: Fonts.resolve(pv.ls.fontFamily)
                font.pixelSize: Theme.fs(9)
            }
            // meter
            Rectangle {
                width: parent.width
                height: 4
                radius: Math.min(2, pv.r)
                color: pv.pal.base
                Rectangle {
                    width: parent.width * 0.65
                    height: parent.height
                    radius: parent.radius
                    color: pv.ls.levelColour === "good" ? pv.look.good : pv.ls.levelColour === "text" ? pv.pal.text : pv.accent
                }
            }
        }
    }
}
