// Singularity - Quickshell
// ~/.config/quickshell/bar/Dock.qml
//
// Glass's Dock: a frosted pill floating along the screen's bottom with the
// pinned apps and whatever else is open, a dot under each running one. Icons
// swell toward the pointer. Click raises an app's window (again for the
// next), or starts it; middle click starts another. Shown while Settings.dockOn; it reserves its own strip.

import "../services"
import "../flyouts"
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick

PanelWindow {
    id: dock

    required property var screenScope
    screen: dock.screenScope.modelData

    visible: Settings.dockOn
    anchors.bottom: true
    color: "transparent"

    readonly property int iconSize: Theme.sp(46)
    readonly property int gap: Math.round(iconSize * 0.3)
    readonly property int pad: Theme.sp(8)
    readonly property int margin: Theme.sp(8)
    // room above the pill for swollen icons and the name label
    readonly property int headroom: Theme.sp(56)
    // how far the pointer's pull reaches, and the largest icon's scale
    readonly property real reach: iconSize * 1.1
    readonly property real swell: 0.4

    implicitWidth: pill.width
    implicitHeight: pill.height + margin + headroom
    exclusiveZone: pill.height + margin + Theme.sp(4)
    onExclusiveZoneChanged: refit.restart()
    // the strip the Dock reserves reaches Hyprland, then the windows re-tile
    Timer {
        id: refit
        interval: 250
        onTriggered: Quickshell.execDetached(["hyprctl", "eval", "singularityRefitWindows()"])
    }
    // only the pill and the icons swelling out of it take the pointer
    mask: Region { item: hit }

    // Pinned apps first, then the other open ones; each as { key, name,
    // source, entry, windows, pinned }, windows being Hyprland toplevels.
    readonly property var items: {
        var out = [], byId = {}
        var pins = Apps.pinned
        for (var i = 0; i < pins.length; i++) {
            var e = pins[i]
            byId[e.id] = { key: "p:" + e.id, name: e.name, source: e.icon ? Quickshell.iconPath(e.icon, true) : "",
                           entry: e, windows: [], pinned: true }
            out.push(byId[e.id])
        }
        var extra = [], byClass = {}
        var tls = Hyprland.toplevels.values
        for (var j = 0; j < tls.length; j++) {
            var tl = tls[j], ipc = tl.lastIpcObject
            if (!ipc || !ipc.class || Apps.isShellWindow(tl) || Apps.isBackTabToplevel(tl)) continue
            var tags = ipc.tags || []
            if (tags.indexOf("menu") >= 0 || tags.indexOf("menu*") >= 0) continue
            var cls = ipc.class
            var ent = Apps.byClass(cls).entry
            var it = ent && byId[ent.id] ? byId[ent.id] : byClass[cls]
            if (!it) {
                it = byClass[cls] = { key: "c:" + cls, name: Apps.nameForWindow(cls, ipc.title),
                                      source: Apps.iconForClass(cls), entry: ent || null, windows: [], pinned: false }
                extra.push(it)
            }
            it.windows.push(tl)
        }
        return out.concat(extra)
    }

    // raise the app's next window, on whatever workspace it's on
    function open(item) {
        if (item.windows.length === 0) {
            if (item.entry) Apps.launch(item.entry)
            return
        }
        var at = item.windows.indexOf(Hyprland.activeToplevel)
        var win = item.windows[(at + 1) % item.windows.length]
        Hyprland.dispatch("hl.dsp.focus({window=\"address:0x" + win.address + "\"})")
        Hyprland.dispatch("hl.dsp.window.bring_to_top()")
    }

    Item {
        id: hit
        x: pill.x
        width: pill.width
        y: pill.y - dock.iconSize * dock.swell
        height: pill.height + dock.iconSize * dock.swell
    }

    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: dock.margin
        width: strip.width + dock.pad * 2
        height: dock.iconSize + dock.pad * 2 + Theme.sp(6)
        radius: Theme.radius + Theme.sp(6)
        color: Qt.rgba(Theme.bar.r, Theme.bar.g, Theme.bar.b, Theme.barOpacity)
        border.width: 1
        border.color: Theme.isLight ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(1, 1, 1, 0.2)

        Shadow { radius: pill.radius }

        // the pointer's x in the strip, far off while it's away
        HoverHandler {
            onHoveredChanged: if (!hovered) strip.pull = -10000
            onPointChanged: if (hovered) strip.pull = point.position.x - dock.pad
        }

        Row {
            id: strip
            x: dock.pad
            y: dock.pad
            height: dock.iconSize
            spacing: dock.gap

            property real pull: -10000

            Repeater {
                model: dock.items

                Item {
                    id: slot
                    required property var modelData
                    required property int index
                    readonly property bool lead: index > 0 && dock.items[index - 1].pinned && !modelData.pinned
                    readonly property bool running: modelData.windows.length > 0
                    readonly property real centreX: x + width / 2
                    readonly property real pulled: Math.exp(-Math.pow((centreX - strip.pull) / dock.reach, 2))
                    width: dock.iconSize
                    height: dock.iconSize

                    // a hairline between the pinned apps and the others
                    Rectangle {
                        visible: slot.lead
                        x: -dock.gap / 2 - width / 2
                        y: Theme.sp(4)
                        width: 1
                        height: parent.height - Theme.sp(8)
                        color: Theme.stroke
                    }

                    Item {
                        width: parent.width
                        height: parent.height
                        scale: 1 + dock.swell * slot.pulled
                        transformOrigin: Item.Bottom

                        IconImage {
                            anchors.fill: parent
                            visible: slot.modelData.source !== ""
                            source: slot.modelData.source
                        }
                        // no icon found: a tile with the app's initial
                        Rectangle {
                            anchors.fill: parent
                            visible: slot.modelData.source === ""
                            radius: Theme.radius
                            color: Theme.surface
                            Text {
                                anchors.centerIn: parent
                                text: slot.modelData.name.charAt(0).toUpperCase()
                                color: Theme.text
                                font.family: Theme.fontText
                                font.pixelSize: dock.iconSize / 2
                            }
                        }
                    }

                    // the app's name over the icon pointed at
                    Rectangle {
                        visible: slot.pulled > 0.85
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: -height - dock.iconSize * dock.swell - Theme.sp(8)
                        width: tip.implicitWidth + Theme.sp(16)
                        height: tip.implicitHeight + Theme.sp(8)
                        radius: Theme.radius
                        color: Qt.rgba(Theme.bar.r, Theme.bar.g, Theme.bar.b, Math.min(1, Theme.barOpacity + 0.25))
                        border.width: 1
                        border.color: pill.border.color
                        Text {
                            id: tip
                            anchors.centerIn: parent
                            text: slot.modelData.name
                            color: Theme.text
                            font.family: Theme.fontText
                            font.pixelSize: Theme.barLabelSize
                        }
                    }

                    // running
                    Rectangle {
                        visible: slot.running
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height + Theme.sp(3)
                        width: Theme.sp(4)
                        height: width
                        radius: width / 2
                        color: Theme.text
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -dock.gap / 2
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (mouse.button === Qt.MiddleButton) {
                                if (slot.modelData.entry) Apps.launch(slot.modelData.entry)
                            } else dock.open(slot.modelData)
                        }
                    }
                }
            }
        }
    }
}
