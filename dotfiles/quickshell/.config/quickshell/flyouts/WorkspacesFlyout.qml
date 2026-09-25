// Singularity - Quickshell
// ~/.config/quickshell/flyouts/WorkspacesFlyout.qml
//
// The window-overview flyout: every window on every workspace, grouped
// under a header per workspace. Needs bar.allWindows() for its list.
//
// Drawn in the bar's workspace/window-strip language: each header carries
// a pip that's a long accent pill on the current workspace and a muted stub
// elsewhere, and each window row carries the same pip under its icon --
// accent for the focused window, with the others' icons dimmed until
// hovered. Left click focuses (header: switches workspace), middle closes.

import "../services"
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick

FlyoutPanel {
    id: panel
    flyout: "workspaces"
    menuWidth: 300

    required property var bar

    // allWindows() is sorted by workspace, so a group is a run of one id
    readonly property var groups: {
        var out = []
        var wins = bar.allWindows()
        for (var i = 0; i < wins.length; i++) {
            if (out.length === 0 || out[out.length - 1].ws !== wins[i].ws)
                out.push({ ws: wins[i].ws, windows: [] })
            out[out.length - 1].windows.push(wins[i])
        }
        return out
    }

    function wsName(id) {
        // special and named workspaces have negative ids
        if (id < 0) return "Special"
        if (Theme.workspaceStyle === "roman")
            return ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"][id - 1] || String(id)
        return String(id)
    }

    FlyoutHeading { text: "WINDOWS" }

    Repeater {
        model: panel.groups

        Column {
            id: group
            required property var modelData
            required property int index
            readonly property bool current: Hyprland.focusedWorkspace !== null
                && Hyprland.focusedWorkspace.id === modelData.ws
            width: parent ? parent.width : 0
            // air between groups, not above the first
            topPadding: index > 0 ? Theme.spaceS : 0

            // ---- workspace header ----
            Item {
                width: parent.width
                implicitHeight: Theme.rowHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: -Theme.spaceS
                    anchors.rightMargin: -Theme.spaceS
                    radius: Theme.radiusInner
                    color: headMouse.containsMouse ? Theme.hoverFill : "transparent"
                }

                Rectangle {
                    id: headPip
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: 7
                    width: group.current ? 22 : 11
                    radius: height / 2
                    color: group.current ? Theme.accent
                        : headMouse.containsMouse ? Theme.text : Theme.subtext
                    Behavior on width { NumberAnimation { duration: Theme.dur(130); easing.type: Theme.ease } }
                    Behavior on color { ColorAnimation { duration: Theme.dur(130) } }
                }

                Text {
                    anchors.left: headPip.right
                    anchors.leftMargin: Theme.spaceM
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Workspace " + panel.wsName(group.modelData.ws)
                    color: group.current || headMouse.containsMouse ? Theme.textStrong : Theme.subtext
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontSmall
                    font.bold: group.current
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: group.modelData.windows.length
                    color: Theme.muted
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontSmall
                }

                MouseArea {
                    id: headMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        panel.requestClose()
                        Hyprland.dispatch("hl.dsp.focus({workspace=" + group.modelData.ws + "})")
                    }
                }
            }

            // ---- its windows ----
            Repeater {
                model: group.modelData.windows

                Item {
                    id: row
                    required property var modelData
                    readonly property bool focused: Hyprland.activeToplevel !== null
                        && Hyprland.activeToplevel.address === modelData.address
                    readonly property bool lit: focused || rowMouse.containsMouse
                    readonly property string iconPath: Apps.iconForClass(modelData.cls)
                    width: parent.width
                    implicitHeight: Theme.rowHeightTall

                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: -Theme.spaceS
                        anchors.rightMargin: -Theme.spaceS
                        radius: Theme.radiusInner
                        color: rowMouse.containsMouse ? Theme.hoverFill : "transparent"
                    }

                    // indented to sit under the header's label, so the
                    // header pip reads as the group's spine
                    Item {
                        id: glyphBox
                        x: Theme.spaceM + 22 - width
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -(pip.height + 1) / 2
                        width: Theme.fs(16)
                        height: Theme.fs(16)
                        opacity: row.lit ? 1 : 0.55
                        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }

                        IconImage {
                            anchors.fill: parent
                            visible: row.iconPath !== ""
                            source: row.iconPath
                        }

                        // the shell's own windows, and anything else with
                        // no themed icon
                        Text {
                            anchors.centerIn: parent
                            visible: row.iconPath === ""
                            text: Apps.glyphForWindow(row.modelData.cls, row.modelData.title)
                            color: row.focused ? Theme.textStrong : Theme.text
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.fs(15)
                        }
                    }

                    Rectangle {
                        id: pip
                        anchors.top: glyphBox.bottom
                        anchors.topMargin: 1
                        anchors.horizontalCenter: glyphBox.horizontalCenter
                        height: Theme.indicatorWidth
                        radius: height / 2
                        width: row.focused ? glyphBox.width - 2 : Theme.fs(6)
                        color: row.focused ? Theme.accent
                            : rowMouse.containsMouse ? Theme.subtext : Theme.muted
                        Behavior on width { NumberAnimation { duration: Theme.dur(130); easing.type: Theme.ease } }
                        Behavior on color { ColorAnimation { duration: Theme.dur(130) } }
                    }

                    Text {
                        anchors.left: glyphBox.right
                        anchors.leftMargin: Theme.spaceM
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.title
                        elide: Text.ElideRight
                        color: row.lit ? Theme.textStrong : Theme.text
                        font.family: Theme.fontText
                        font.pixelSize: Theme.fontBody
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            var addr = "address:0x" + row.modelData.address
                            if (mouse.button === Qt.MiddleButton) {
                                Hyprland.dispatch("hl.dsp.window.close({window=\"" + addr + "\"})")
                                return
                            }
                            panel.requestClose()
                            // bring to top as well, as the bar's strip does, so
                            // a floating window buried under others surfaces
                            Hyprland.dispatch("hl.dsp.focus({window=\"" + addr + "\"})")
                            Hyprland.dispatch("hl.dsp.window.bring_to_top({window=\"" + addr + "\"})")
                        }
                    }
                }
            }
        }
    }

    FlyoutRow {
        label: "No windows open"
        enabled: false
        visible: panel.groups.length === 0
    }
}
