// Singularity - Quickshell
// ~/.config/quickshell/flyouts/FlyoutHeading.qml
//
// Section label for a flyout: small caps, then a rule that runs out to the
// right edge -- the same "label cut into a border" motif the rest of the
// repo uses (see the fastfetch box headers).
//
// `hints` puts key hints at the rule's far end ("Enter open", "Esc close"),
// for the centred overlays that are driven from the keyboard.
//
// A heading that shares its column with another one heads a section: the
// siblings after it, up to the next heading or FlyoutDivider. Clicking it
// folds that section shut, and a chevron at the rule's end shows which way
// it is. Folded rows are moved into a hidden holder rather than hidden one
// by one, so their own `visible` bindings survive, and moved back in their
// old order. The empty spacer Item a page puts before the next heading
// stays, so folded sections keep their gaps.
//
// The first heading of a bar flyout can be drawn as its title instead
// (Theme.flyoutTitle): on a strip of ground across the panel's top, or as a
// title bar in the accent with a close box.
//
// Folding lasts while the window is open. The Settings and System windows
// keep a `foldedSections` list (by page title and heading) on an item
// above their pages, so a page left and come back to is as it was; the
// windows are torn down on close, and the list with them. A flyout is only
// hidden when it closes, so its sections unfold as it goes.

import QtQuick
import "../services"

Item {
    id: root

    property string text: ""
    property var hints: []

    readonly property bool isFlyoutHeading: true
    readonly property bool collapsible: mirrorOf ? mirrorOf.collapsible
        : hints.length === 0 && headingsBeside() > 0
    readonly property bool collapsed: mirrorOf ? mirrorOf.collapsed
        : holder.children.length > 0 || folding

    // A stand-in for another heading (StickyHeading's pinned copy): shows
    // that one's fold state, and clicking folds that one's section.
    property Item mirrorOf: null
    signal mirrorToggled()

    // set while a section starts folded, before its rows have moved
    property bool folding: false

    width: parent ? parent.width : 0
    implicitHeight: Theme.headingHeight + (asTitle ? Theme.spaceS : 0)

    // the first row of a bar flyout's column, drawn as its title
    readonly property bool asTitle: Theme.flyoutTitle !== "none" && !mirrorOf
        && !!parent && parent.isFlyoutPage === true && parent.children[0] === root
    readonly property bool titleBar: asTitle && Theme.flyoutTitle === "titlebar"
    // the panel around the column, for its corners
    readonly property Item panel: parent ? parent.parent : null
    // from the panel's edge in to the first clear pixel inside its frame
    readonly property int frameIn: Theme.frameDouble || Theme.frameChiselled ? Theme.frameInset + Theme.borderWidth
        : Theme.frameStroked ? Theme.borderWidth : 0
    readonly property color titleInk: !titleBar ? Theme.headingColor
        : Theme.hasAccent ? (Theme.accent.hslLightness > 0.55 ? "#111111" : "#ffffff") : Theme.textStrong

    function closePanel() {
        for (var p = parent; p; p = p.parent)
            if (typeof p.requestClose === "function") { p.requestClose(); return }
    }

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

    // the page (or window) this sits on, so the same heading on two pages
    // is two sections. Counts and prices are left out, so "BATTERY  80%"
    // stays the same section as the charge changes.
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
        // A Column lays out in child order and a new child goes last, so
        // everything after the heading is taken out and put back behind the
        // unfolded rows.
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

    // the title's ground, out to the panel's frame on three sides
    Rectangle {
        id: band
        visible: root.asTitle
        x: -Theme.panelPad + root.frameIn
        y: -Theme.panelPad + root.frameIn
        width: root.width + (Theme.panelPad - root.frameIn) * 2
        height: root.height - y
        topLeftRadius: root.panel ? Math.max(0, root.panel.topLeftRadius - root.frameIn) : 0
        topRightRadius: root.panel ? Math.max(0, root.panel.topRightRadius - root.frameIn) : 0
        color: root.titleBar ? (Theme.hasAccent ? Theme.accent : Theme.overlay) : Theme.surface

        Rectangle {
            visible: !root.titleBar
            anchors.bottom: parent.bottom
            width: parent.width
            height: Theme.borderWidth
            color: Theme.stroke
        }
    }

    Text {
        id: label
        anchors.left: parent.left
        anchors.verticalCenter: root.asTitle ? band.verticalCenter : parent.verticalCenter
        text: Theme.heading(root.text)
        color: root.titleInk
        font.family: Theme.fontText
        font.pixelSize: Theme.fontSmall
        font.bold: Theme.headingBold
        font.letterSpacing: Theme.headingSpacing
    }

    Rectangle {
        visible: Theme.headingRule && !root.asTitle
        anchors.left: label.right
        anchors.leftMargin: Theme.spaceL
        anchors.right: chevron.visible ? chevron.left : hintRow.left
        anchors.rightMargin: root.hints.length > 0 || chevron.visible ? Theme.spaceL : 0
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.borderWidth
        color: Theme.stroke
    }

    Text {
        id: chevron
        visible: root.collapsible
        anchors.right: closeBox.visible ? closeBox.left : parent.right
        anchors.rightMargin: closeBox.visible ? Theme.spaceM : 0
        anchors.verticalCenter: root.asTitle ? band.verticalCenter : parent.verticalCenter
        text: root.collapsed ? "󰅂" : "󰅀"
        color: foldMouse.containsMouse ? Theme.text : Theme.subtext
        font.family: Theme.fontIcon
        font.pixelSize: Theme.fontSmall
    }

    Row {
        id: hintRow
        anchors.right: closeBox.visible ? closeBox.left : parent.right
        anchors.rightMargin: closeBox.visible ? Theme.spaceM : 0
        anchors.verticalCenter: root.asTitle ? band.verticalCenter : parent.verticalCenter
        spacing: Theme.spaceXl

        Repeater {
            model: root.hints

            Text {
                required property string modelData
                text: modelData.toUpperCase()
                color: Theme.subtext
                font.family: Theme.fontText
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

    // the title bar's close box
    Rectangle {
        id: closeBox
        visible: root.titleBar
        anchors.right: parent.right
        anchors.verticalCenter: band.verticalCenter
        width: Theme.fontBody + Theme.spaceXs
        height: width
        radius: Math.min(Theme.radiusSmall, 3)
        color: closeMouse.containsMouse ? Qt.rgba(root.titleInk.r, root.titleInk.g, root.titleInk.b, 0.18) : "transparent"
        border.width: Theme.borderWidth
        border.color: root.titleInk

        Text {
            anchors.centerIn: parent
            text: "󰅖"
            color: root.titleInk
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontSmall
        }

        MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closePanel()
        }
    }
}
