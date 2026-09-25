// Singularity - Quickshell
// ~/.config/quickshell/flyouts/ReloadToast.qml
//
// Stands in for Quickshell's own reload popup: a panel tucked into the corner
// where the bar's left end meets the screen edge, flush with both. A good
// reload fades on its own; a failed one shows the error and stays until
// clicked or its longer timer runs out.
//
// inhibitReloadPopup() only takes effect when called from inside the
// reloadCompleted/reloadFailed handlers. A failed reload leaves the old
// shell running, so its handlers are the ones that catch reloadFailed.

import Quickshell
import Quickshell.Wayland
import QtQuick
import "../services"

OverlayWindow {
    id: root

    // Kept true and re-armed by the timer rather than toggling window
    // `visible` -- see LayoutToast for why an opacity fade needs the surface
    // mapped for its whole duration.
    property bool active: false
    property bool failed: false
    property string error: ""

    readonly property bool atBottom: Theme.barPosition === "bottom"

    visible: true
    layerNamespace: "singularity-toast"
    // click-through, except a failure's panel, which a click dismisses
    mask: Region { item: root.active && root.failed ? box : null }

    function show(err) {
        root.failed = err !== undefined
        root.error = root.failed ? String(err).trim() : ""
        root.active = true
        hideTimer.interval = root.failed ? 8000 : 1500
        hideTimer.restart()
    }

    Connections {
        target: Quickshell
        function onReloadCompleted() {
            Quickshell.inhibitReloadPopup()
            root.show()
        }
        function onReloadFailed(errorString) {
            Quickshell.inhibitReloadPopup()
            root.show(errorString)
        }
    }

    Timer {
        id: hideTimer
        onTriggered: root.active = false
    }

    // Clips a PanelFrame that runs past it on the bar's side, so every frame
    // style keeps its strokes along the screen edge and the open sides but
    // none against the bar. The corners on the bar and the screen edge are
    // square; only the far one is rounded.
    Item {
        id: box
        readonly property int bleed: Theme.frameInset + Theme.borderWidth * 2

        y: root.atBottom ? root.height - Theme.barExtent - height : Theme.barExtent
        width: col.width + Theme.spaceXl * 2
        height: col.implicitHeight + Theme.sp(18)
        clip: true

        PanelFrame {
            y: root.atBottom ? 0 : -box.bleed
            width: box.width
            height: box.height + box.bleed
            topLeftRadius: 0
            bottomLeftRadius: 0
        }

        opacity: root.active ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.durMedium; easing.type: Theme.ease }
        }

        Column {
            id: col
            x: Theme.spaceXl
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(Math.max(head.implicitWidth, detail.implicitWidth), Theme.fit(420))
            spacing: Theme.spaceM

            Row {
                id: head
                spacing: Theme.sp(10)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.failed ? "󰀦" : "󰑓"
                    color: root.failed ? Theme.alert : Theme.text
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.fontIconSize
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Theme.heading(root.failed ? "RELOAD FAILED" : "RELOADED")
                    color: Theme.text
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontSmall
                    font.letterSpacing: Theme.headingSpacing * 2
                    font.bold: Theme.headingBold
                }
            }

            Text {
                id: detail
                visible: root.failed && root.error !== ""
                width: col.width
                text: root.error
                color: Theme.subtext
                font.family: Theme.fontText
                font.pixelSize: Theme.fontCaption
                wrapMode: Text.Wrap
                maximumLineCount: 6
                elide: Text.ElideRight
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.failed
            cursorShape: Qt.PointingHandCursor
            onClicked: root.active = false
        }
    }
}
