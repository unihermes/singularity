// Singularity - Quickshell
// ~/.config/quickshell/sidebar/AiDiff.qml
//
// The Desktop tab's staged changes as one coloured diff: each file's path,
// then its hunks; git's other header lines are left out.

import QtQuick
import "../services"
import "../flyouts"

Item {
    id: root

    property string diff: ""

    function displayPath(p) {
        return p === ".live/appearance.json" ? "Shell settings" : p
    }

    readonly property var lines: {
        var l = diff.split("\n").filter(s => !/^(index |--- |\+\+\+ |new file|deleted file|similarity|rename )/.test(s))
        // a rewritten file can run to thousands of lines; this is a review,
        // not an editor
        return l.length > 1500 ? l.slice(0, 1500).concat(["… " + (l.length - 1500) + " more lines"]) : l
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusInner
        color: Theme.fieldFill
    }

    ListView {
        id: view
        anchors.fill: parent
        anchors.margins: Theme.spaceM
        anchors.rightMargin: Theme.scrollGutter
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.lines

        delegate: Text {
            required property string modelData
            readonly property bool file: modelData.indexOf("diff --git") === 0
            readonly property string c: modelData.charAt(0)
            width: view.width
            topPadding: file ? Theme.spaceM : 0
            text: file ? root.displayPath((modelData.match(/ b\/(.*)$/) || [0, modelData])[1]) : modelData
            wrapMode: Text.WrapAnywhere
            color: file ? Theme.textStrong
                : c === "@" ? Theme.subtext
                : c === "+" ? Theme.good
                : c === "-" ? Theme.alert : Theme.text
            font.family: Theme.fontText
            font.weight: file ? Theme.weightStrong : Theme.weightBody
            font.pixelSize: Theme.fontCaption
        }
    }

    ScrollBar {
        flickable: view
        anchors.right: parent.right
        anchors.rightMargin: 2
    }
}
