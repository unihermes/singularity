// Singularity - Quickshell
// ~/.config/quickshell/services/Bongo.qml
//
// Key presses for the bar's Bongo Cat, from scripts/bongo.py, which reads
// every keyboard's events and reports a tap per press, never the key. It
// needs the user in the input group; until then `ready` stays false and
// the module hides. Runs only while the module is shown.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property bool wanted: Settings.widgetVisible("bongo")
    // a keyboard can be read
    property bool ready: false
    // the paw that came down last, and whether one is down now
    property bool leftPaw: false
    property bool down: false

    Process {
        running: root.wanted
        command: [Quickshell.shellPath("scripts/bongo.py")]
        stdout: SplitParser {
            onRead: line => {
                if (line === "tap") {
                    root.leftPaw = !root.leftPaw
                    root.down = true
                    lift.restart()
                } else {
                    root.ready = line === "ready"
                }
            }
        }
        onExited: root.ready = false
    }

    // paws back up once typing pauses
    Timer {
        id: lift
        interval: 160
        onTriggered: root.down = false
    }
}
