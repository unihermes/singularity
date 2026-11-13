// The Drawer layout: a panel the height of the screen under the bar, on the
// side the Control Centre is on. The modes as tabs along its top, the
// field, then one-line rows. Apps before typing run A to Z under letter
// headings, with a strip of the letters down the edge to jump with.

import QtQuick
import "../services"
import "../flyouts"

Item {
    id: view

    required property var launcher
    anchors.fill: parent

    readonly property bool alphabet: launcher.mode === "apps" && launcher.query.trim() === ""
    readonly property var rows: !launcher.open ? []
        : alphabet ? Apps.list("", true) : launcher.items
    readonly property bool onRight: launcher.controlX > width / 2
    function letterOf(e) {
        var c = (e.name || "").charAt(0).toUpperCase()
        return c >= "A" && c <= "Z" ? c : "#"
    }

    readonly property int count: list.count
    readonly property bool sideways: false
    readonly property var chords: []
    function move(dx, dy) {
        list.currentIndex = Math.max(0, Math.min(list.count - 1, list.currentIndex + dy))
    }
    function current() {
        return list.count > 0 ? { item: rows[list.currentIndex], kind: launcher.kind } : null
    }
    function chord(name) {}

    Connections {
        target: view.launcher
        function onWasReset() { list.currentIndex = 0 }
        function onWasTyped() { list.currentIndex = 0 }
    }

    PanelFrame {
        width: Theme.fit(400)
        x: view.onRight ? parent.width - width - Theme.barMargin : Theme.barMargin
        y: view.launcher.atBottom ? Theme.barMargin : Theme.flyoutOffset
        height: parent.height - Theme.flyoutOffset - Theme.barMargin

        Absorber {}

        Column {
            id: top
            x: Theme.panelPad * 2
            y: Theme.panelPad * 2
            width: parent.width - Theme.panelPad * 4
            spacing: Theme.spaceL

            FlyoutSegmented {
                width: parent.width
                model: view.launcher.modes
                labelFor: m => ({ apps: "Apps", files: "Files", clipboard: "Clipboard", calc: "Calc" })[m]
                current: view.launcher.mode
                onPicked: m => view.launcher.setMode(m)
            }

            LauncherField { launcher: view.launcher; view: view }
        }

        Item {
            x: top.x
            y: top.y + top.height + Theme.spaceL
            width: top.width
            height: parent.height - y - Theme.panelPad * 2

            LauncherEmpty { launcher: view.launcher; visible: list.count === 0 }

            ListView {
                id: list
                width: parent.width - (strip.visible ? strip.width + Theme.spaceS : 0)
                height: parent.height
                clip: true
                spacing: 1
                boundsBehavior: Flickable.StopAtBounds
                model: view.rows
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                section.property: view.alphabet ? "name" : ""
                section.criteria: ViewSection.FirstCharacter
                section.delegate: Text {
                    required property string section
                    x: Theme.spaceL
                    height: implicitHeight + Theme.spaceS
                    verticalAlignment: Text.AlignBottom
                    text: section.toUpperCase()
                    color: Theme.headingMarkColor
                    font.family: Theme.fontText
                    font.weight: Theme.weightStrong
                    font.pixelSize: Theme.fontCaption
                }

                delegate: LauncherRow {
                    required property var modelData
                    required property int index
                    launcher: view.launcher
                    item: modelData
                    oneLine: true
                    current: ListView.isCurrentItem
                    width: list.width
                    onHovered: list.currentIndex = index
                    onClicked: view.launcher.activate(modelData, view.launcher.kind)
                }
            }

            // A to Z down the edge: lit where an app starts with it, the
            // current row's letter in the accent
            Column {
                id: strip
                visible: view.alphabet
                anchors.right: parent.right
                width: Theme.fs(16)
                height: parent.height
                readonly property var letters: "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("")
                readonly property var firsts: {
                    var out = {}
                    for (var i = view.rows.length - 1; i >= 0; i--) out[view.letterOf(view.rows[i])] = i
                    return out
                }
                readonly property string currentLetter: view.alphabet && view.rows[list.currentIndex]
                    ? view.letterOf(view.rows[list.currentIndex]) : ""

                Repeater {
                    model: strip.letters
                    Text {
                        required property string modelData
                        readonly property bool has: strip.firsts[modelData] !== undefined
                        width: strip.width
                        height: strip.height / strip.letters.length
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: modelData
                        color: strip.currentLetter === modelData ? Theme.headingMarkColor
                            : has ? Theme.text : Theme.textDisabled
                        font.family: Theme.fontText
                        font.weight: strip.currentLetter === modelData ? Theme.weightStrong : Theme.weightBody
                        font.pixelSize: Theme.fontCaption
                        MouseArea {
                            anchors.fill: parent
                            enabled: parent.has
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                list.currentIndex = strip.firsts[parent.modelData]
                                list.positionViewAtIndex(list.currentIndex, ListView.Beginning)
                            }
                        }
                    }
                }
            }
        }
    }
}
