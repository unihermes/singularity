// Singularity - Quickshell
// ~/.config/quickshell/services/Privacy.qml
//
// Which apps are recording the mic, camera or screen, for a bar indicator.
// From Pipewire's node list: audio/video input streams and xdph-streaming-*
// screen shares. Audio input streams are bound to read stream.capture.sink,
// as one capturing a sink's monitor (loopbacks, desktop recorders) isn't a
// mic. Apps opening /dev/video* directly aren't seen.

pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    id: root

    // The shell's own capture: cava listens to the output to draw the
    // visualizer, and that must not light the microphone indicator.
    readonly property var ignored: ["cava"]

    readonly property var inStreams: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioInStream)
    PwObjectTracker { objects: root.inStreams }

    function scan() {
        var mic = [], cam = [], screen = []
        var nodes = Pipewire.nodes.values
        for (var i = 0; i < nodes.length; i++) {
            var n = nodes[i]
            var name = n.name || ""
            if (ignored.indexOf(name) !== -1) continue
            var label = n.description || n.nickname || name
            if (name.startsWith("xdph-streaming")) screen.push("Screen share")
            else if (n.type === PwNodeType.AudioInStream) {
                if (n.ready && String(n.properties["stream.capture.sink"]) !== "true") mic.push(label)
            }
            else if (n.type === (PwNodeType.Video | PwNodeType.Stream | PwNodeType.Source)) cam.push(label)
        }
        return { mic: mic, camera: cam, screen: screen }
    }

    readonly property var state: scan()
    readonly property bool mic: state.mic.length > 0
    readonly property bool camera: state.camera.length > 0
    readonly property bool screen: state.screen.length > 0
    readonly property bool active: mic || camera || screen
}
