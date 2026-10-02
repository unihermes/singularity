// Singularity - Quickshell
// ~/.config/quickshell/flyouts/StickyHeading.qml
//
// Keeps the heading of the section being read pinned to the top of a
// scrolling page: once a FlyoutHeading in `column` has scrolled up past the
// top of `flickable`, a copy of it stays there, on the panel's colour at full
// strength so rows pass under it rather than showing through a translucent
// panel. The next heading pushes it up and out as it arrives, then takes
// its place.
//
// Only the column's own headings count, not ones nested deeper (a card's
// title inside a row). The copy folds and unfolds the section it stands for,
// and scrolls back to that heading, so a section folded from here doesn't
// leave the page scrolled past its end.
//
// Place it over the flickable, at its top-left, the same width.

import QtQuick
import "../services"

Item {
    id: root

    required property Flickable flickable
    required property Item column
    // where the column sits in the flickable's content, for one nested in
    // another (a tab's column in the page's)
    property real columnY: 0
    property real columnX: column.x

    // [the heading whose section is on screen, the one after it]
    readonly property var pair: {
        var top = flickable.contentY - columnY
        var cur = null
        var next = null
        var kids = column.children
        for (var i = 0; i < kids.length; i++) {
            var k = kids[i]
            if (k.isFlyoutHeading !== true || !k.visible) continue
            if (k.y <= top) cur = k
            else { next = k; break }
        }
        return [cur, next]
    }
    readonly property Item current: pair[0]

    // the copy's own top edge, dragged up by the next heading coming in
    readonly property real slide: pair[1]
        ? Math.min(0, pair[1].y + columnY - flickable.contentY - height) : 0

    visible: current !== null && flickable.contentY > 0
    height: copy.height + column.spacing
    clip: true

    Rectangle {
        y: root.slide
        width: parent.width
        height: root.height
        color: Theme.panel

        FlyoutHeading {
            id: copy
            x: root.columnX
            width: root.column.width
            text: root.current ? root.current.text : ""
            mirrorOf: root.current
            onMirrorToggled: {
                var h = root.current
                if (!h) return
                var max = Math.max(0, root.flickable.contentHeight - root.flickable.height)
                root.flickable.contentY = Math.max(0, Math.min(max, h.y + root.columnY))
            }
        }
    }
}
