// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/SpeedTrack.qml
//
// One part's speed on the Motion tab's timeline: a lane from 0 to
// `scale` ms with a bar as long as the part's animations take (its `base`
// ms, scaled by Animations and by its own Settings[key] percent). Dragging
// or clicking along the lane sets the percent, in steps of 25, written
// when the drag ends; `trailing` holds the part's own choice at the end.

import QtQuick
import "../../services"
import "../../flyouts"
import ".."

SettingsField {
    id: tr

    property string key: ""
    property int base: 200
    property int scale: 400
    // the lane's room at the end of each track, so every lane lines up
    property real trailingWidth: Theme.fit(150)
    default property alias trailing: end.data

    readonly property real master: Settings.animTime / 100
    readonly property bool off: master <= 0
    // the percent under the pointer while dragging, else -1
    property int dragged: -1
    readonly property int pct: dragged >= 0 ? dragged : (Settings[key] || 100)
    readonly property int ms: Math.round(base * master * pct / 100)

    defaultKey: key
    labelWidth: Theme.fit(170)

    function pctAt(x) {
        var want = Math.max(0, Math.min(1, x / lane.width)) * scale
        var p = Math.round(want / Math.max(1, base * master) * 100 / 25) * 25
        var lim = Settings.limits[key] || { min: 25, max: 200 }
        return Math.max(lim.min, Math.min(lim.max, p))
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        height: Theme.controlSize

        Rectangle {
            id: lane
            anchors.left: parent.left
            anchors.right: end.left
            anchors.rightMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            height: Theme.controlSize
            radius: Theme.radiusInner
            color: Theme.base
            border.width: Theme.borderWidth
            border.color: Theme.stroke
            opacity: tr.off ? 0.4 : 1

            // a tick every 100 ms
            Repeater {
                model: Math.floor(tr.scale / 100) - 1
                Rectangle {
                    required property int index
                    x: lane.width * (index + 1) * 100 / tr.scale
                    width: 1
                    height: lane.height
                    color: Theme.stroke
                }
            }

            Rectangle {
                id: clip
                x: Theme.spaceXs
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(Theme.spaceL, Math.min(lane.width, lane.width * tr.ms / tr.scale) - Theme.spaceXs * 2)
                height: lane.height - Theme.spaceXs * 2
                radius: Math.max(0, lane.radius - Theme.spaceXs)
                color: Theme.accent

                Text {
                    x: Theme.spaceS
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Theme.spaceS * 2
                    elide: Text.ElideRight
                    text: tr.off ? "Off" : tr.ms + " ms  ·  " + tr.pct + "%"
                    color: Theme.textOnAccent
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontCaption
                }
            }
            // the end to drag
            Rectangle {
                visible: !tr.off
                x: clip.x + clip.width - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.fs(4)
                height: lane.height
                radius: width / 2
                color: Theme.textStrong
            }

            MouseArea {
                anchors.fill: parent
                enabled: !tr.off
                cursorShape: Qt.SizeHorCursor
                onPressed: mouse => tr.dragged = tr.pctAt(mouse.x)
                onPositionChanged: mouse => { if (pressed) tr.dragged = tr.pctAt(mouse.x) }
                onReleased: {
                    if (tr.dragged >= 0 && tr.dragged !== Settings[tr.key]) Settings.set(tr.key, tr.dragged)
                    tr.dragged = -1
                }
                onCanceled: tr.dragged = -1
            }
        }

        Item {
            id: end
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: tr.trailingWidth
            height: childrenRect.height
        }
    }
}
