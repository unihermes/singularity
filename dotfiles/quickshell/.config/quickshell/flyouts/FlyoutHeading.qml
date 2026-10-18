// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FlyoutHeading.qml
//
// A section heading: the label, then a rule to the right edge. `hints`
// puts key hints at the rule's end; `control` a control (such a heading
// doesn't fold); `crumb` the page above, quieter, clickable as the way
// back (crumbClicked). A heading sharing its column with another folds its
// section (up to the next heading or FlyoutDivider) on click, by moving the
// rows into a hidden holder. Settings and System keep folds in a
// `foldedSections` list while open; flyouts unfold as they close.

import QtQuick
import "../services"

Item {
    id: root

    property string text: ""
    // a name after the text, shown as written whatever the heading case
    // (a network's name, which is case-sensitive)
    property string asWritten: ""
    property var hints: []
    property string crumb: ""
    signal crumbClicked()
    property Component control: null

    readonly property bool isFlyoutHeading: true
    readonly property bool collapsible: mirrorOf ? mirrorOf.collapsible
        : hints.length === 0 && control === null && headingsBeside() > 0
    readonly property bool collapsed: mirrorOf ? mirrorOf.collapsed
        : holder.children.length > 0 || folding

    // A stand-in for another heading (StickyHeading's pinned copy): shows
    // that one's fold state, and clicking folds that one's section.
    property Item mirrorOf: null
    signal mirrorToggled()

    // set while a section starts folded, before its rows have moved
    property bool folding: false

    width: parent ? parent.width : 0
    implicitHeight: Math.max(Theme.headingHeight, controlBox.active ? controlBox.height : 0) + sectionRoom * (firstInColumn ? 1 : 2)

    // in a sectioned flyout, room round the heading for the sections' frames:
    // below it, and above it too unless it opens the column
    readonly property int sectionRoom: !parent || parent.sectioned !== true ? 0
        : inFlyout ? Theme.flyoutSpacing : Theme.spaceM
    readonly property bool inFlyout: {
        for (var p = parent; p; p = p.parent)
            if (p.isFlyoutPage === true) return true
        return false
    }
    property bool firstInColumn: !!parent && parent.children[0] === root && (parent.isSectionGroup !== true || parent.opensPage === true)
    readonly property real lift: firstInColumn ? -sectionRoom / 2 : 0

    // other headings showing in the same column; while this one is hidden
    // (a flyout that's shut) there's no telling, so all of them count
    function headingsBeside() {
        if (!parent) return 0
        var n = 0
        var kids = parent.children
        for (var i = 0; i < kids.length; i++)
            if (kids[i] !== root && kids[i].isFlyoutHeading === true && (kids[i].visible || !root.visible)) n++
        return n
    }

    // the section's key: the page plus the text without counts or prices
    function key() {
        var name = text.replace(/[\d$%.,·:-]+/g, "").replace(/\s+/g, " ").trim()
        for (var p = parent; p; p = p.parent)
            if (typeof p.title === "string" && p.title !== "") return p.title + "/" + name
        return name
    }

    function sectionItems() {
        var kids = parent.children
        var out = []
        var i = 0
        while (i < kids.length && kids[i] !== root) i++
        var endsAtHeading = false
        for (i++; i < kids.length; i++) {
            var c = kids[i]
            if (c.isFlyoutHeading === true) { endsAtHeading = true; break }
            if (c.isSectionBreak === true) break
            out.push(c)
        }
        if (endsAtHeading && out.length > 0 && /^QQuickItem\(/.test(String(out[out.length - 1])))
            out.pop()
        return out
    }

    function collapse() {
        folding = false
        if (!collapsible || holder.children.length > 0) return
        var items = sectionItems()
        for (var i = 0; i < items.length; i++) items[i].parent = holder
    }

    function expand() {
        folding = false
        var col = parent
        var moving = []
        for (var i = 0; i < holder.children.length; i++) moving.push(holder.children[i])
        if (moving.length === 0) return
        // everything after the heading is re-added behind the unfolded rows
        // (a Column lays out in child order)
        var kids = col.children
        var at = 0
        while (at < kids.length && kids[at] !== root) at++
        var tail = []
        for (var k = at + 1; k < kids.length; k++) tail.push(kids[k])
        for (var j = 0; j < moving.length; j++) moving[j].parent = col
        for (var t = 0; t < tail.length; t++) {
            tail[t].parent = holder
            tail[t].parent = col
        }
    }

    // the nearest foldedSections list above, or null
    function memory() {
        for (var p = parent; p; p = p.parent)
            if (Array.isArray(p.foldedSections)) return p
        return null
    }

    function toggle() {
        if (collapsed) expand()
        else collapse()
        var m = memory()
        if (!m) return
        var k = key()
        var list = m.foldedSections.filter(x => x !== k)
        if (collapsed) list.push(k)
        m.foldedSections = list
    }

    onVisibleChanged: if (!visible && !mirrorOf && !memory()) expand()

    Component.onCompleted: {
        var m = memory()
        if (m && m.foldedSections.indexOf(key()) >= 0) {
            folding = true
            // after the rest of the page has been built
            Qt.callLater(collapse)
        }
    }

    Item {
        id: holder
        visible: false
        width: root.width
    }

    // the look's mark before every heading (Theme.headingPrefix)
    Text {
        id: prefix
        visible: text !== ""
        anchors.left: parent.left
        anchors.verticalCenter: label.verticalCenter
        text: Theme.headingPrefix
        color: Theme.headingMarkColor
        font: label.font
    }

    Row {
        id: crumbRow
        visible: root.crumb !== ""
        anchors.left: prefix.visible ? prefix.right : parent.left
        anchors.leftMargin: prefix.visible ? Theme.spaceS : 0
        anchors.verticalCenter: label.verticalCenter
        spacing: Theme.spaceXs

        Text {
            anchors.verticalCenter: parent.verticalCenter
            // smaller and unspaced, so both names fit a narrow flyout
            text: Theme.heading(root.crumb)
            color: crumbMouse.containsMouse ? Theme.headingColor : Theme.subtext
            font.family: Theme.fontHeading
            font.pixelSize: Theme.fontCaption
            font.weight: label.font.weight

            MouseArea {
                id: crumbMouse
                anchors.fill: parent
                anchors.margins: -Theme.spaceXs
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.crumbClicked()
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰅂"
            color: Theme.subtext
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontCaption
        }
    }

    Text {
        id: label
        anchors.left: crumbRow.visible ? crumbRow.right : prefix.visible ? prefix.right : parent.left
        anchors.leftMargin: crumbRow.visible ? Theme.spaceXs : prefix.visible ? Theme.spaceM : 0
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.lift
        text: Theme.heading(root.text) + (root.asWritten !== "" ? "  " + root.asWritten : "")
        color: Theme.headingColor
        font.family: Theme.fontHeading
        font.pixelSize: Theme.fontHeadingSize
        font.weight: Theme.headingBold ? Theme.weightStrong : Theme.weightBody
        // tighter beside a crumb, which shares the line
        font.letterSpacing: root.crumb !== "" ? Theme.headingSpacing / 2 : Theme.headingSpacing
    }

    Rectangle {
        visible: Theme.headingRule
        anchors.left: label.right
        anchors.leftMargin: Theme.spaceL
        anchors.right: controlBox.active ? controlBox.left : chevron.visible ? chevron.left : hintRow.left
        anchors.rightMargin: root.hints.length > 0 || chevron.visible || controlBox.active ? Theme.spaceL : 0
        anchors.verticalCenter: label.verticalCenter
        height: Theme.borderWidth
        color: Theme.stroke
    }

    Text {
        id: chevron
        visible: root.collapsible
        anchors.right: parent.right
        anchors.verticalCenter: label.verticalCenter
        text: root.collapsed ? "󰅂" : "󰅀"
        // only while the pointer is on the heading, or the section is
        // folded and needs finding again; the rule keeps its length either way
        opacity: root.collapsed || foldMouse.containsMouse ? 1 : 0
        color: foldMouse.containsMouse ? Theme.text : Theme.subtext
        font.family: Theme.fontIcon
        font.pixelSize: Theme.fontSmall
    }

    Row {
        id: hintRow
        anchors.right: parent.right
        anchors.verticalCenter: label.verticalCenter
        spacing: Theme.spaceXl

        Repeater {
            model: root.hints

            Text {
                required property string modelData
                text: modelData.toUpperCase()
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontEyebrow
                font.letterSpacing: 1
            }
        }
    }

    MouseArea {
        id: foldMouse
        anchors.fill: parent
        enabled: root.collapsible
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.mirrorOf) {
                root.mirrorOf.toggle()
                root.mirrorToggled()
            } else {
                root.toggle()
            }
        }
    }

    Loader {
        id: controlBox
        active: root.control !== null
        sourceComponent: root.control
        anchors.right: parent.right
        anchors.verticalCenter: label.verticalCenter
    }
}
