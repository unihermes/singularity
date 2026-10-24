// Singularity - Quickshell
// ~/.config/quickshell/desktop/DesktopWidgets.qml
//
// One screen's desktop widgets, each its own surface on the layer under
// every window, where its place puts it (WidgetPlacement.js): the built-in
// ones' from Settings.deskWidget, each sticky note's ("note:" and its id)
// from Notes.
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
    // every widget that can show: the built-in ones, then the notes
    readonly property var keys: Settings.deskWidgetKeys.concat(Notes.deskIds.map(id => "note:" + id))
    function noteIndex(key) { return Notes.indexOf(key.slice(5)) }

    // where it sits: on, screen, size, fx and fy
    function placeOf(key) {
        if (key.indexOf("note:") !== 0) return Settings.deskWidget(key)
        const t = Notes.tabs[noteIndex(key)]
        if (!t || !t.desk) return { on: false, screen: "", size: "m", fx: -1, fy: -1 }
        return { on: true, screen: t.desk.screen, size: t.desk.size, fx: t.desk.fx, fy: t.desk.fy }
    }
    function setPlace(key, fields) {
        if (key.indexOf("note:") !== 0) { Settings.setDeskWidget(key, fields); return }
        if (fields.on === false) { Notes.setDesk(noteIndex(key), null); return }
        const f = {}
        for (const k in fields) if (k !== "on") f[k] = fields[k]
        Notes.setDesk(noteIndex(key), f)
    }
    function shown(key) {
        const p = placeOf(key)
        return p.on && here(p)
    }

    // A new sticky note: with its top left corner at a point (the desktop's
    // menu), or beside another widget, under it where there's room, else
    // over it, else to its left.
    readonly property var noteSize: ({ w: Theme.fit(164) * 2 + gap, h: Theme.fit(164) })
    function newNoteAt(x, y) {
        const f = Placement.fractionsOf({ x: x, y: y, w: noteSize.w, h: noteSize.h }, area)
        Notes.addOnDesk({ fx: f.fx, fy: f.fy, screen: screen.name })
    }
    function newNoteBeside(key) {
        const r = rectOf(key), n = noteSize
        const y = r.y + r.h + gap + n.h <= area.y + area.h ? r.y + r.h + gap
            : r.y - gap - n.h >= area.y ? r.y - gap - n.h : r.y
        const x = y === r.y ? r.x - gap - n.w : r.x
        newNoteAt(x, y)
    }

    // the sizes of the widgets shown here, which is what places them
    readonly property var shownSizes: {
        const out = {}
        for (const k of keys) if (shown(k) && sizes[k]) out[k] = sizes[k]
        return out
    }
    function rectOf(key) {
        return Placement.rectOf(key, placeOf(key), shownSizes, area, margin, gap)
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
        model: root.keys

        PanelWindow {
            id: win
            required property string modelData
            readonly property var place: root.placeOf(modelData)
            readonly property var rect: root.rectOf(modelData)
            // room round the panel for its shadow
            readonly property int pad: Theme.sp(24)

            screen: root.screen
            visible: root.shown(modelData) && !root.editing && widget.width > 0
            WlrLayershell.layer: WlrLayer.Bottom
            // the note takes typing once clicked into
            WlrLayershell.keyboardFocus: modelData.indexOf("note:") === 0 ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
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
                desk: root
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
