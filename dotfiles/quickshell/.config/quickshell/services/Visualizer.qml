// Singularity - Quickshell
// ~/.config/quickshell/services/Visualizer.qml
//
// Audio spectrum bars from cava, for a bar module that only appears while
// sound is actually playing.
//
// cava runs in raw mode, printing one line per frame of semicolon-separated
// bar heights (0-100). It's only started while some app has an audio output
// stream open -- no stream, no sound to draw -- and the module hides after
// two seconds of silence, since plenty of apps (browsers especially) hold a
// stream open while playing nothing.
//
// The config is written to a temp file at launch rather than shipped in
// ~/.config/cava, so an interactive cava keeps its own settings.

pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    id: root

    readonly property int barCount: 10
    // 20, not 30: at a 20px-tall bar the difference isn't visible, and cava's
    // CPU use scales with it (about 4% of a core at 30)
    readonly property int fps: 20
    property var bars: []
    readonly property bool hasCava: cavaProbe.found
    // sound in the last couple of seconds
    property bool playing: false

    readonly property bool streamOpen: {
        var nodes = Pipewire.nodes.values
        for (var i = 0; i < nodes.length; i++)
            if (nodes[i].type === PwNodeType.AudioOutStream) return true
        return false
    }

    CommandProbe { id: cavaProbe; name: "cava" }

    Process {
        id: cava
        running: root.hasCava && root.streamOpen
        command: ["sh", "-c",
            "cfg=$(mktemp /tmp/singularity-cava.XXXXXX) && trap 'rm -f \"$cfg\"' EXIT && "
            + "printf '[general]\\nbars = " + root.barCount + "\\nframerate = " + root.fps + "\\n"
            + "[input]\\nmethod = pipewire\\nsource = auto\\n"
            + "[output]\\nmethod = raw\\nraw_target = /dev/stdout\\ndata_format = ascii\\n"
            + "ascii_max_range = 100\\nbar_delimiter = 59\\nframe_delimiter = 10\\n"
            + "[smoothing]\\nnoise_reduction = 60\\n' > \"$cfg\" && cava -p \"$cfg\""]
        stdout: SplitParser {
            onRead: line => {
                var v = line.split(";").filter(x => x !== "").map(Number)
                if (v.length === 0) return
                root.bars = v
                if (v.some(x => x > 2)) {
                    root.playing = true
                    silence.restart()
                }
            }
        }
        onRunningChanged: if (!running) { root.bars = []; root.playing = false }
    }

    Timer {
        id: silence
        interval: 2000
        onTriggered: root.playing = false
    }
}
