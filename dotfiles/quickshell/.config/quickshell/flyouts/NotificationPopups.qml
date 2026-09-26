// Singularity - Quickshell
// ~/.config/quickshell/flyouts/NotificationPopups.qml
//
// Notifications as they arrive, stacked from the corner or edge Settings >
// Notifications picks, newest nearest the edge, on the focused screen only.
// Each leaves after its timeout (Notifications.timeoutFor), held while the
// pointer is on it; it stays in the history until dismissed.

import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../services"

OverlayWindow {
    id: root

    readonly property bool focused: !!Hyprland.focusedMonitor
        && Hyprland.focusedMonitor.name === scope.modelData.name
    readonly property var shown: focused ? Notifications.popups.slice(0, 5) : []
    readonly property bool atBottom: Settings.notifPositionY === "bottom"
    // the bar's thickness when the popups start from its edge
    readonly property real barGap: (Theme.barPosition === "bottom") === atBottom ? Theme.barExtent : 0
    readonly property int gap: Theme.edgeMargin

    visible: shown.length > 0
    layerNamespace: "singularity-notifications"
    // click-through except for the cards themselves
    mask: Region { item: stack }

    Column {
        id: stack
        width: Theme.fit(380)
        spacing: Theme.spaceM
        x: Settings.notifPositionX === "left" ? root.gap
            : Settings.notifPositionX === "center" ? (root.width - width) / 2
            : root.width - width - root.gap
        y: root.atBottom ? root.height - root.barGap - root.gap - height : root.barGap + root.gap

        // nearest the edge first, so at the bottom the list runs upward
        Repeater {
            model: root.atBottom ? root.shown.slice().reverse() : root.shown

            NotificationCard {
                id: card
                required property var modelData
                notification: modelData
                width: stack.width

                readonly property real timeout: Notifications.timeoutFor(modelData)

                Timer {
                    interval: card.timeout * 1000
                    running: card.timeout > 0 && !card.hovered
                    onTriggered: Notifications.hidePopup(card.modelData)
                }
            }
        }
    }
}
