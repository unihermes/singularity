// Singularity - Quickshell
// ~/.config/quickshell/desktop/DesktopWidgets.qml
//
// One screen's desktop widgets, each its own surface on the layer under
// every window, where Settings.deskWidget places it (WidgetPlacement.js).
// A right-click on one opens edit mode (WidgetEditor), which draws them
// over everything while it's open; these step aside meanwhile. Under them
// the whole screen takes right-clicks, for the desktop's menu.

import Quickshell
import Quickshell.Wayland
import QtQuick
import "../services"
import "../services/WidgetPlacement.js" as Placement

Scope {
    id: root

    required property var scope
    readonly property var screen: scope.modelData
    readonly property bool editing: scope.openFlyout === "widgetedit"

    // the room from every screen edge, and between widgets (WidgetCard's)
    readonly property int margin: Theme.sp(40)
    readonly property int gap: Theme.fit(16)

    // where the desktop's menu was asked for, from the top
    property real menuY: 0
    readonly property var area: Placement.area(screen.width, screen.height, Theme.barExtent,
                                               Theme.barPosition === "bottom")

    // each widget's drawn size, as it reports it
    property var sizes: ({})
    function report(key, w, h) {
        const s = sizes[key]
        if (s && s.w === w && s.h === h) return
        const out = {}
        for (const k in sizes) out[k] = sizes[k]
        out[key] = { w: w, h: h }
        sizes = out
    }

    // on this screen: its own, or the first when it's on none connected
    function here(place) {
        const names = Quickshell.screens.map(s => s.name)
        const name = names.indexOf(place.screen) !== -1 ? place.screen : names[0]
        return name === screen.name
    }
    function shown(key) {
        const p = Settings.deskWidget(key)
        return p.on && here(p)
    }

    // the sizes of the widgets shown here, which is what places them
    readonly property var shownSizes: {
        const out = {}
        for (const k of Settings.deskWidgetKeys) if (shown(k) && sizes[k]) out[k] = sizes[k]
        return out
    }
    function rectOf(key) {
        return Placement.rectOf(key, Settings.deskWidget(key), shownSizes, area, margin, gap)
    }

    // the bare desktop's right-click, made before the widgets so it sits
    // under them
    PanelWindow {
        screen: root.screen
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "singularity-desktop"
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        anchors { top: true; left: true; right: true; bottom: true }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: mouse => {
                root.menuY = Math.min(mouse.y, height - Theme.fit(220))
                root.scope.flyoutAnchorX = mouse.x
                root.scope.flyoutSection = ""
                root.scope.openFlyout = "desktopmenu"
            }
        }
    }

    Variants {
        model: Settings.deskWidgetKeys

        PanelWindow {
            id: win
            required property string modelData
            readonly property var place: Settings.deskWidget(modelData)
            readonly property var rect: root.rectOf(modelData)
            // room round the panel for its shadow
            readonly property int pad: Theme.sp(24)

            screen: root.screen
            visible: root.shown(modelData) && !root.editing && widget.width > 0
            WlrLayershell.layer: WlrLayer.Bottom
            // the note takes typing once clicked into
            WlrLayershell.keyboardFocus: modelData === "note" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            // outside the shell's blur rule: nothing behind it is frosted
            WlrLayershell.namespace: "desktop-widget"
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            anchors { top: true; left: true }
            margins.left: Math.max(0, rect.x - pad)
            margins.top: Math.max(0, rect.y - pad)
            implicitWidth: widget.width + pad * 2
            implicitHeight: widget.height + pad * 2

            DeskWidget {
                id: widget
                key: win.modelData
                size: win.place.size
                x: win.rect.x - win.margins.left
                y: win.rect.y - win.margins.top
                onWidthChanged: root.report(key, width, height)
                onHeightChanged: root.report(key, width, height)
                Component.onCompleted: root.report(key, width, height)
            }

            MouseArea {
                anchors.fill: widget
                acceptedButtons: Qt.RightButton
                onClicked: root.scope.editWidgets()
            }
        }
    }
}
