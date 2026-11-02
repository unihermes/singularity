// Singularity - Quickshell
// ~/.config/quickshell/launcher/LauncherRow.qml
//
// One launcher result as a row, for any kind (app, file, clip, calc): its
// icon or glyph, the name, and the details (what the app is, where the file
// is, what the syntax does) under it, or at the right end when `oneLine`.
// The current row is lit as Settings' search hits are. `number` puts a key
// label before the icon; `large` is Spotlight's top hit; `hug` sizes the
// row to its name (One line) with no chevron.

import Quickshell
import Quickshell.Widgets
import QtQuick
import "../services"

Item {
    id: row

    required property var launcher
    required property var item
    property string kind: launcher.kind
    property bool current: false
    property bool oneLine: false
    property bool large: false
    property bool hug: false
    property string number: ""
    signal hovered()
    signal clicked()

    readonly property bool isResult: kind === "calc" && item.kind === "result"
    // `|| ""`: switching mode can briefly hand a row the other mode's data
    readonly property string name: (kind === "clip" ? (item.isImage ? "Image" : item.preview)
        : kind === "calc" ? item.text : item.name) || ""
    readonly property string note: !launcher.details ? ""
        : (kind === "file" ? Files.pretty(item.dir || "")
            : kind === "calc" ? item.hint
            : kind === "clip" ? ""
            : item.genericName || item.comment) || ""

    width: parent ? parent.width : 0
    implicitWidth: Math.min(Theme.fit(240), iconCell.width + nameText.implicitWidth + Theme.spaceL * 2 + Theme.spaceM)
    height: large ? Theme.fs(56) : oneLine ? launcher.lineHeight : launcher.rowHeight

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusInner
        color: row.current ? Theme.selectedFill : "transparent"
        border.width: Theme.borderWidth
        border.color: row.current ? Theme.strokeHover : "transparent"
    }

    Rectangle {
        visible: row.current
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.indicatorWidth
        height: parent.height - 6
        radius: Theme.pill(width)
        color: Theme.accent
    }

    Text {
        id: numberText
        visible: row.number !== ""
        x: Theme.spaceL
        anchors.verticalCenter: parent.verticalCenter
        width: visible ? Theme.fs(34) : 0
        text: row.number
        color: row.current ? Theme.text : Theme.textDisabled
        font.family: Theme.fontText
        font.pixelSize: Theme.fontCaption
    }

    Item {
        id: iconCell
        x: Theme.spaceL + numberText.width
        width: row.large ? Theme.fs(36) : Theme.iconCell
        height: parent.height

        IconImage {
            id: appIcon
            visible: row.kind === "app"
            anchors.centerIn: parent
            implicitSize: iconCell.width
            source: visible ? Quickshell.iconPath(row.item.icon || "", true) : ""
        }

        Text {
            visible: !appIcon.visible
            anchors.centerIn: parent
            text: row.kind === "calc" ? (row.item.kind === "ref" ? "󰘧" : "󰃬")
                : row.kind === "file" ? (row.item.isDir ? "󰉋" : "󰈔")
                : row.item.isImage ? "󰋩" : "󰅍"
            color: row.current ? Theme.textStrong : Theme.subtext
            font.family: Theme.fontIcon
            font.pixelSize: row.large ? Theme.fs(28) : Theme.fontIconSize
        }
    }

    Column {
        anchors.left: iconCell.right
        anchors.leftMargin: Theme.spaceM
        anchors.right: row.hug ? parent.right : inlineNote.visible ? inlineNote.left : chevron.left
        anchors.rightMargin: row.hug ? Theme.spaceL : Theme.spaceS
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            id: nameText
            width: parent.width
            text: row.name
            // a copied page's HTML shows as its markup, not as rich text
            // with the images missing
            textFormat: Text.PlainText
            elide: Text.ElideRight
            maximumLineCount: 1
            color: row.isResult && !row.item.ok ? Theme.subtext
                : row.current || row.isResult ? Theme.textStrong : Theme.text
            font.family: Theme.fontText
            font.pixelSize: row.large ? Theme.fontHeadingSize + 2 : Theme.fontBody
            font.weight: row.isResult || row.large ? Theme.weightStrong : Theme.weightBody
        }

        Text {
            visible: !row.oneLine && !row.hug && row.note !== ""
            width: parent.width
            text: row.note
            elide: row.kind === "file" ? Text.ElideLeft : Text.ElideRight
            maximumLineCount: 1
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontCaption
        }
    }

    // one line: the details at the right end
    Text {
        id: inlineNote
        visible: row.oneLine && row.note !== ""
        anchors.right: chevron.left
        anchors.rightMargin: Theme.spaceM
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, row.width * 0.4)
        text: row.note
        elide: row.kind === "file" ? Text.ElideLeft : Text.ElideRight
        color: Theme.subtext
        font.family: Theme.fontText
        font.weight: Theme.weightBody
        font.pixelSize: Theme.fontCaption
    }

    Text {
        id: chevron
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceL
        anchors.verticalCenter: parent.verticalCenter
        text: "󰅂"
        visible: !row.hug
        opacity: row.current ? 1 : 0
        color: Theme.subtext
        font.family: Theme.fontIcon
        font.pixelSize: Theme.fontSmall
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPositionChanged: m => {
            if (row.launcher.pointerMoved(mouse, m.x, m.y)) row.hovered()
        }
        onClicked: row.clicked()
    }
}
