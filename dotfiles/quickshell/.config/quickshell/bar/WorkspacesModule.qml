// Singularity - Quickshell
// ~/.config/quickshell/bar/WorkspacesModule.qml
//
// One frame around the whole set, with the current
// workspace shown as a widened pill rather than a number.
// Three states read by size and weight alone: current is a
// long bright bar, occupied a short one, empty a dim stub --
// the same language as the gauges on the right, where how
// much space a thing takes up is the information.

import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../services"

ModuleFrame {
    id: wsFrame
    required property var host
    visible: Settings.widgetVisible("workspaces")
    anchors.verticalCenter: parent.verticalCenter
    spacing: Theme.spaceS
    // each mark already sits in a slot 2px wider on either side
    padH: Theme.modulePadH - 2

    // 1..workspaceCount, and any workspace past those while it exists
    // (opened by hyprctl or a script, as the binds stop at the count)
    readonly property var ids: {
        const n = Settings.workspaceCount
        const extra = Hyprland.workspaces.values.map(w => w.id).filter(id => id > n)
        return Array.from({ length: n }, (_, i) => i + 1).concat(extra.sort((a, b) => a - b))
    }

    // the scroll wheel over the marks steps through the workspaces, a
    // notch at a time, wrapping at the ends
    property real wheelAccum: 0
    function wheelStep(dy) {
        wheelAccum += dy
        if (Math.abs(wheelAccum) < 120) return
        const d = wheelAccum > 0 ? -1 : 1
        wheelAccum = 0
        const cur = Hyprland.focusedWorkspace ? ids.indexOf(Hyprland.focusedWorkspace.id) : -1
        const next = ids[((cur < 0 ? 0 : cur) + d + ids.length) % ids.length]
        Hyprland.dispatch("hl.dsp.focus({workspace=" + next + "})")
    }

    Repeater {
        // a ScriptModel, so a workspace appearing doesn't rebuild the
        // others mid-animation
        model: ScriptModel { values: wsFrame.ids }

        Item {
            required property int modelData
            readonly property int wsId: modelData
            readonly property bool current: Hyprland.focusedWorkspace
                ? Hyprland.focusedWorkspace.id === wsId
                : false
            readonly property bool occupied: host.bar.workspaceHasWindows(wsId)

            anchors.verticalCenter: parent.verticalCenter
            // a little wider than the mark so an empty
            // workspace is still a comfortable click target
            readonly property bool textual: Theme.workspaceStyle === "numbers" || Theme.workspaceStyle === "roman"
                || Theme.workspaceStyle === "names"
            // the apps style: an app open there, or null when it's empty
            readonly property var app: Theme.workspaceStyle === "apps" ? host.bar.workspaceApp(wsId) : null
            readonly property bool appMark: Theme.workspaceStyle === "apps" && app !== null
            implicitWidth: (appMark ? appBox.width : textual ? num.width : pip.width) + 4
            implicitHeight: Theme.moduleHeight - 8

            // pills, dots, lines and blocks: the same three states,
            // drawn as a pill that stretches, a dot or a short rule
            // that lights, or a square that fills
            Rectangle {
                id: pip
                readonly property bool blocks: Theme.workspaceStyle === "blocks"
                readonly property bool lines: Theme.workspaceStyle === "lines"
                visible: !parent.textual && !parent.appMark
                anchors.centerIn: parent
                height: blocks ? 10 : lines ? 3 : 7
                width: blocks ? 10 : lines ? 14 : Theme.workspaceStyle === "dots" || Theme.workspaceStyle === "apps" ? 7
                    : parent.current ? 22 : (parent.occupied ? 11 : 7)
                // fully rounded: half the height makes a pill
                // at any width, and a circle at the stub size
                radius: blocks ? Math.min(2, Theme.radiusSmall) : Theme.pill(height)
                color: parent.current ? Theme.accent
                    : blocks ? (parent.occupied ? Theme.subtext : "transparent")
                    : (parent.occupied ? Theme.subtext : Theme.muted)
                border.width: blocks && !parent.current && !parent.occupied ? Theme.borderWidth : 0
                border.color: Theme.muted

                Behavior on width {
                    NumberAnimation { duration: Theme.dur(130); easing.type: Theme.ease }
                }
                Behavior on color { ColorAnimation { duration: Theme.dur(130) } }
            }

            Text {
                id: num
                visible: parent.textual
                anchors.centerIn: parent
                // a touch wider than a digit, so the row doesn't
                // shift as the current one turns bold
                width: Math.max(implicitWidth, Theme.barFs(12))
                horizontalAlignment: Text.AlignHCenter
                text: Theme.workspaceStyle === "roman"
                    ? ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"][parent.wsId - 1] || parent.wsId
                    : Theme.workspaceStyle === "names" ? Theme.workspaceNames[parent.wsId - 1] || parent.wsId
                    : parent.wsId
                color: parent.current ? Theme.accent
                    : parent.occupied ? Theme.text : Theme.muted
                font.family: Theme.fontText
                font.pixelSize: Theme.barLabelSize
                font.weight: parent.current ? Theme.weightStrong : Theme.weightBody
            }

            // the apps style: the app's icon, an accent rule under the
            // current workspace's
            Item {
                id: appBox
                visible: parent.appMark
                anchors.centerIn: parent
                width: Theme.barFs(15)
                height: Theme.barFs(15)
                opacity: parent.current ? 1 : 0.6

                TintedIcon {
                    anchors.fill: parent
                    visible: !!parent.parent.app && parent.parent.app.source !== ""
                    source: parent.parent.app ? parent.parent.app.source : ""
                }
                Text {
                    anchors.centerIn: parent
                    visible: !!parent.parent.app && parent.parent.app.source === ""
                    text: parent.parent.app ? parent.parent.app.glyph : ""
                    color: Theme.text
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.barFs(14)
                }
                Rectangle {
                    visible: appBox.parent.current
                    anchors.top: parent.bottom
                    anchors.topMargin: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    height: Theme.indicatorWidth
                    radius: Theme.pill(height)
                    color: Theme.accent
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("hl.dsp.focus({workspace=" + parent.wsId + "})")
                onWheel: wheel => wsFrame.wheelStep(wheel.angleDelta.y)
            }
        }
    }

    // The scratchpad (SUPER+grave), only while something is in it: lit
    // when it's shown on this monitor, with a count past one window
    Item {
        id: scratchMark
        readonly property var ws: Hyprland.workspaces.values.find(w => w.name === "special:scratchpad") || null
        readonly property int count: ws
            ? ws.toplevels.values.filter(t => !Apps.isShellWindow(t)).length : 0
        readonly property var monitor: Hyprland.monitorFor(host.screenScope.modelData)
        // the monitor's own report until the first activespecial event
        readonly property bool shown: {
            const name = monitor ? monitor.name : ""
            if (name in host.shellRoot.specialShown)
                return host.shellRoot.specialShown[name] === "special:scratchpad"
            const sp = monitor && monitor.lastIpcObject && monitor.lastIpcObject.specialWorkspace
            return !!sp && sp.name === "special:scratchpad"
        }

        visible: count > 0
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: scratchRow.implicitWidth + 4
        implicitHeight: Theme.moduleHeight - 8

        Row {
            id: scratchRow
            anchors.centerIn: parent
            spacing: Theme.spaceXs

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰆍"
                color: scratchMark.shown ? Theme.accent
                    : scratchMouse.containsMouse ? Theme.text : Theme.subtext
                font.family: Theme.fontIcon
                font.pixelSize: Theme.barFs(15)
                Behavior on color { ColorAnimation { duration: Theme.dur(130) } }
            }

            Text {
                visible: scratchMark.count > 1
                anchors.verticalCenter: parent.verticalCenter
                text: scratchMark.count
                color: scratchMark.shown ? Theme.accent : Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.barFs(11)
            }
        }

        MouseArea {
            id: scratchMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Hyprland.dispatch("hl.dsp.workspace.toggle_special('scratchpad')")
        }
    }

    // the overview of every window on every workspace, as the
    // chip's last mark after a divider: the selector and the
    // pips it expands on read as one control
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.borderWidth
        height: Theme.moduleHeight - 12
        color: Theme.stroke
    }

    Item {
        id: wsOverviewBtn
        readonly property bool open: host.screenScope.openFlyout === "workspaces"
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: overviewGlyph.implicitWidth + 4
        implicitHeight: Theme.moduleHeight - 8

        Text {
            id: overviewGlyph
            anchors.centerIn: parent
            text: "󰕰"
            color: wsOverviewBtn.open ? Theme.accent
                : overviewMouse.containsMouse ? Theme.text : Theme.subtext
            font.family: Theme.fontIcon
            font.pixelSize: Theme.barFs(15)
            Behavior on color { ColorAnimation { duration: Theme.dur(130) } }
        }

        MouseArea {
            id: overviewMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: host.screenScope.toggleFlyout("workspaces", wsOverviewBtn)
        }
    }
}
