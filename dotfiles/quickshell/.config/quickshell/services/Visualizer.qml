// Singularity - Quickshell
// ~/.config/quickshell/services/Visualizer.qml
//
// Spectrum bars from cava (raw mode, 0-100 per bar, Settings.vizBars of
// them), run only while the Music module and its visualizer are on and
// the player it follows (Media.player) is playing, so other sound (a
// browser tab, which has no MPRIS player) never moves it;
// `playing` drops after two seconds of silence. Config in a temp file,
// leaving cava's own alone.

pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    id: root

    readonly property int barCount: Settings.vizBars
    // a new count needs cava started again with it
    property bool restarting: false
    onBarCountChanged: {
        restarting = true
        Qt.callLater(() => restarting = false)
    }
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
        running: root.hasCava && root.streamOpen && !!Media.player && Media.player.isPlaying
            && Settings.widgetVisible("visualizer") && Settings.vizShown && !root.restarting
        command: ["sh", "-c",
            "cfg=$(mktemp /tmp/singularity-cava.XXXXXX) && trap 'rm -f \"$cfg\"' EXIT && "
            + "printf '[general]\\nbars = " + root.barCount + "\\nframerate = " + root.fps + "\\n"
            + "[input]\\nmethod = pipewire\\nsource = auto\\n"
            + "[output]\\nmethod = raw\\nchannels = mono\\nraw_target = /dev/stdout\\ndata_format = ascii\\n"
            + "ascii_max_range = 100\\nbar_delimiter = 59\\nframe_delimiter = 10\\n"
            + "[smoothing]\\nnoise_reduction = 60\\n' > \"$cfg\" && cava -p \"$cfg\""]
        stdout: SplitParser {
            id: frames
            // a frame like the last one (silence, mostly) changes nothing
            property string last: ""
            property bool loud: false
            onRead: line => {
                if (line !== last) {
                    last = line
                    var v = line.split(";").filter(x => x !== "").map(Number)
                    if (v.length === 0) return
                    root.bars = v
                    loud = v.some(x => x > 2)
                }
                if (loud) {
                    root.playing = true
                    silence.restart()
                }
            }
        }
        onRunningChanged: if (!running) { root.bars = []; root.playing = false; frames.last = "" }
    }

    Timer {
        id: silence
        interval: 2000
        onTriggered: root.playing = false
    }
}
