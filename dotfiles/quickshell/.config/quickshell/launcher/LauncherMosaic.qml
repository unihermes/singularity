// The Mosaic layout: full screen over the dimmed desktop, the field at the
// top and everything as tiles packed below it (services/Mosaic.js). Apps
// are sized by use, the two most launched largest and the next four wide;
// typing fades the apps that don't match rather than moving any, so each
// stays where you expect it. Files show pictures as large previews, the
// newest clipboard entries show their text, and calc its answer large beside the
// syntax. The arrows move to the nearest tile that way.

import Quickshell
import Quickshell.Widgets
import QtQuick
import "../services"
import "../flyouts"
import "../services/Mosaic.js" as Mosaic

Item {
    id: view

    required property var launcher
    anchors.fill: parent

    readonly property int columns: 8
    readonly property var imageExt: /\.(png|jpe?g|gif|webp|bmp|svg|avif)$/i

    // [{ item, kind, w, h, on }]: on is whether it matches what's typed
    readonly property var tiles: {
        if (!launcher.open) return []
        var q = launcher.query.trim().toLowerCase(), m = launcher.mode, out = []
        if (m === "apps") {
            var hits = q === "" ? null : Apps.list(q)
            Apps.list("").forEach((e, r) => out.push({ item: e, kind: "app",
                w: r < 6 ? 2 : 1, h: r < 2 ? 2 : 1, on: !hits || hits.indexOf(e) !== -1 }))
        } else if (m === "clipboard") {
            // the history runs to hundreds: the newest matches only
            launcher.items.slice(0, 120).forEach(e => out.push({ item: e, kind: "clip",
                w: 2, h: !e.isImage && e.preview.length > 60 ? 2 : 1, on: true }))
        } else {
            launcher.items.forEach(e => {
                var big = m === "files" ? imageExt.test(e.name || "") : e.kind === "result"
                out.push({ item: e, kind: launcher.kind, w: big && m === "calc" ? 4 : 2, h: big ? 2 : 1, on: true })
            })
        }
        return out
    }
    readonly property var rects: Mosaic.pack(tiles.map(t => [t.w, t.h]), columns)
    property int sel: 0
    function firstOn() {
        for (var i = 0; i < tiles.length; i++) if (tiles[i].on) return i
        return 0
    }

    readonly property int count: tiles.filter(t => t.on).length
    readonly property bool sideways: true
    readonly property var chords: []
    function move(dx, dy) {
        sel = Mosaic.step(rects, sel, dx, dy, i => view.tiles[i].on)
        flick.show(rects[sel])
    }
    function current() {
        var t = tiles[sel]
        return t && t.on ? { item: t.item, kind: t.kind } : null
    }
    function chord(name) {}

    Connections {
        target: view.launcher
        function onWasReset() { view.sel = 0; flick.contentY = 0 }
        function onWasTyped() {
            view.sel = view.firstOn()
            flick.show(view.rects[view.sel])
        }
    }

    LauncherField {
        id: field
        launcher: view.launcher
        view: view
        width: Theme.fit(560)
        x: Math.round((parent.width - width) / 2)
        y: (view.launcher.atBottom ? 0 : Theme.barExtent) + Theme.spaceXl * 2
        height: Theme.fs(44)
        hints: [view.launcher.modeNames[view.launcher.mode]]
    }

    Flickable {
        id: flick
        readonly property real gap: Theme.spaceM
        readonly property real cellW: (width - gap * (view.columns - 1)) / view.columns
        readonly property real cellH: Theme.fit(84)
        // scrolls a tile into view
        function show(r) {
            if (!r) return
            var top = r.y * (cellH + gap), bottom = top + r.h * (cellH + gap) - gap
            if (top < contentY) contentY = top
            else if (bottom > contentY + height) contentY = bottom - height
        }
        x: Theme.fit(80)
        y: field.y + field.height + Theme.spaceXl * 2
        width: parent.width - x * 2
        height: parent.height - y - Theme.spaceXl * 2 - (view.launcher.atBottom ? Theme.barExtent : 0)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        contentHeight: view.rects.reduce((m, r) => Math.max(m, r.y + r.h), 0) * (cellH + gap)

        LauncherEmpty {
            launcher: view.launcher
            visible: view.count === 0
            x: Math.round((flick.width - implicitWidth) / 2)
            width: implicitWidth
        }

        Repeater {
            model: view.tiles

            Rectangle {
                id: tile
                required property var modelData
                required property int index
                readonly property var r: view.rects[index] || { x: 0, y: 0, w: 1, h: 1 }
                readonly property bool current: view.sel === index && modelData.on
                readonly property bool big: r.h > 1
                readonly property bool picture: modelData.kind === "file" && big
                x: r.x * (flick.cellW + flick.gap)
                y: r.y * (flick.cellH + flick.gap)
                width: r.w * (flick.cellW + flick.gap) - flick.gap
                height: r.h * (flick.cellH + flick.gap) - flick.gap
                radius: Theme.radiusInner
                color: Theme.panelFill
                border.width: tile.current ? Theme.borderWidth * 2 : Theme.borderWidth
                border.color: tile.current ? Theme.accent : mouse.containsMouse && modelData.on ? Theme.strokeHover : Theme.stroke
                opacity: modelData.on ? 1 : 0.15
                Behavior on opacity { NumberAnimation { duration: Theme.durFast } }

                // a picture fills its tile
                ClippingRectangle {
                    visible: tile.picture
                    anchors.fill: parent
                    anchors.margins: tile.border.width
                    radius: Math.max(0, tile.radius - tile.border.width)
                    color: "transparent"
                    Image {
                        anchors.fill: parent
                        source: tile.picture ? "file://" + tile.modelData.item.path : ""
                        sourceSize.width: 480
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }

                // an app: its icon, larger in the large tiles
                IconImage {
                    visible: tile.modelData.kind === "app"
                    x: Theme.spaceL
                    y: Theme.spaceL
                    implicitSize: tile.big ? Theme.fs(56) : Theme.fs(28)
                    source: visible ? Apps.iconPath(tile.modelData.item.icon || "", true) : ""
                }

                Text {
                    visible: ["file", "clip", "calc"].indexOf(tile.modelData.kind) !== -1 && !tile.picture
                        && !(tile.modelData.kind === "calc" && tile.big)
                    x: Theme.spaceL
                    y: Theme.spaceL
                    text: tile.modelData.kind === "calc" ? "󰘧"
                        : tile.modelData.kind === "file" ? (tile.modelData.item.isDir ? "󰉋" : "󰈔")
                        : tile.modelData.item.isImage ? "󰋩" : "󰅍"
                    color: Theme.subtext
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.fontIconSize
                }

                // a copied text, as much as fits
                Text {
                    visible: tile.modelData.kind === "clip" && !tile.modelData.item.isImage
                    x: Theme.spaceL + Theme.iconCell + Theme.spaceS
                    y: Theme.spaceL
                    width: parent.width - x - Theme.spaceL
                    height: parent.height - y - Theme.spaceL
                    text: tile.modelData.item.preview || ""
                    textFormat: Text.PlainText
                    wrapMode: Text.WrapAnywhere
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontSmall
                }

                // calc's answer, large
                Text {
                    visible: tile.modelData.kind === "calc" && tile.big
                    anchors.centerIn: parent
                    width: parent.width - Theme.spaceL * 2
                    horizontalAlignment: Text.AlignHCenter
                    text: tile.modelData.item.text || ""
                    elide: Text.ElideRight
                    color: tile.modelData.item.ok ? Theme.textStrong : Theme.subtext
                    font.family: Theme.fontText
                    font.weight: Theme.weightStrong
                    font.pixelSize: Theme.fs(40)
                }

                // the name, and what it is, along the bottom
                Rectangle {
                    visible: tile.picture
                    anchors.fill: label
                    anchors.margins: -Theme.spaceS
                    radius: Theme.radiusSmall
                    color: Theme.panelFill
                    opacity: 0.85
                }
                Column {
                    id: label
                    visible: !(tile.modelData.kind === "calc" && tile.big) && !(tile.modelData.kind === "clip" && !tile.modelData.item.isImage)
                    x: Theme.spaceL
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.spaceM
                    width: parent.width - Theme.spaceL * 2
                    spacing: 1
                    Text {
                        width: parent.width
                        text: tile.modelData.kind === "clip" ? "Image"
                            : tile.modelData.kind === "calc" ? tile.modelData.item.text
                            : tile.modelData.kind === "app" ? Apps.displayName(tile.modelData.item)
                            : tile.modelData.item.name || ""
                        elide: Text.ElideRight
                        color: tile.current ? Theme.textStrong : Theme.text
                        font.family: Theme.fontText
                        font.weight: Theme.weightBody
                        font.pixelSize: tile.big && tile.modelData.kind === "app" ? Theme.fontHeadingSize : Theme.fontBody
                    }
                    Text {
                        visible: text !== "" && tile.r.w > 1 && Theme.launcherDetails
                        width: parent.width
                        text: (tile.modelData.kind === "app" ? tile.modelData.item.genericName || tile.modelData.item.comment
                            : tile.modelData.kind === "file" ? Files.pretty(tile.modelData.item.dir || "")
                            : tile.modelData.kind === "calc" ? tile.modelData.item.hint : "") || ""
                        elide: tile.modelData.kind === "file" ? Text.ElideLeft : Text.ElideRight
                        color: Theme.subtext
                        font.family: Theme.fontText
                        font.weight: Theme.weightBody
                        font.pixelSize: Theme.fontCaption
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    enabled: tile.modelData.on
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPositionChanged: m => {
                        if (view.launcher.pointerMoved(mouse, m.x, m.y)) view.sel = tile.index
                    }
                    onClicked: view.launcher.activate(tile.modelData.item, tile.modelData.kind)
                }
            }
        }
    }

    ScrollBar {
        visible: overflow > 0
        anchors.left: flick.right
        anchors.leftMargin: Theme.spaceM
        y: flick.y
        height: flick.height
        flickable: flick
    }
}
