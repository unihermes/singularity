// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsTab.qml
//
// One tab's content on a tabbed SettingsPage, showing while it's the page's
// `tab`. List the tab in the page's `tabs` and point `stickyColumn` at it.

import QtQuick
import "../services"

Column {
    required property string tabId
    required property Item page
    readonly property bool isSettingsTab: true
    // FlyoutHeading and FlyoutDivider make room for the sections
    readonly property bool sectioned: page.channelled
    visible: page.tab === tabId
    width: parent ? parent.width : 0
    spacing: Theme.spaceM
}
