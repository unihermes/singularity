// Singularity - Quickshell
// ~/.config/quickshell/desktop/WidgetFrame.qml
//
// A desktop widget's panel: a flyout's ground, frame, padding and section
// runs, in whatever the style draws, around a column of rows.

import QtQuick
import "../services"
import "../flyouts"

PanelFrame {
    id: root

    default property alias content: column.data
    // the column's width before the padding, as a flyout's menuWidth
    property real menuWidth: Theme.flyoutMenuWidth

    readonly property int sectionGap: Theme.sectionInset - Theme.channelWidth
    readonly property int sectionPadY: Theme.spaceXs
    readonly property int padX: Theme.channelWidth * 2 + sectionGap + Theme.spaceM
    readonly property int padY: Theme.channelWidth * 2 + sectionGap + sectionPadY

    ground: Theme.surface
    width: Theme.fit(menuWidth) + (padX - Theme.panelPad) * 2
    height: column.implicitHeight + padY * 2

    SectionRuns {
        x: Theme.channelWidth + root.sectionGap
        width: root.width - x * 2
        height: root.height
        column: column
        columnY: column.y
        padY: root.sectionPadY
    }

    Column {
        id: column
        x: root.padX
        y: root.padY
        width: root.width - root.padX * 2
        spacing: Theme.flyoutSpacing
        // laid out as a flyout's page: FlyoutHeading makes room for the runs
        readonly property bool sectioned: true
        readonly property bool isFlyoutPage: true
    }
}
