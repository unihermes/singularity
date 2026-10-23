// Singularity - Quickshell
// ~/.config/quickshell/services/Visualizer.qml
//
// Spectrum bars from cava (raw mode, 0-100 per bar, Settings.vizBars of
// them), run only while the Music module and its visualizer are on and
// an app's audio stream is open; `playing` drops after two seconds of
// silence. Config in a temp file, leaving cava's own alone. cava's node
// isn't connected anywhere by itself: every app's stream but the excluded
// ones is linked into it, so their sound (Floorp's tabs) never moves it.

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

    // apps whose sound is left out, by binary or application name
    readonly property var excluded: ["floorp"]
    // cava's capture node, named so streams can be linked into it
    readonly property string nodeName: "singularity-viz"

    // the apps' streams it listens to: not the channels' own streams into
    // the output (each app's sound already passes through a channel), not
    // an excluded app's
    readonly property var feeds: Pipewire.nodes.values.filter(n => {
        if (n.type !== PwNodeType.AudioOutStream || /^channel\./.test(n.name || "") || !n.ready) return false
        var p = n.properties || {}
        var app = [p["application.process.binary"], p["application.name"], n.name]
            .map(x => String(x || "").toLowerCase())
        return !excluded.some(e => app.indexOf(e) !== -1)
    })
    readonly property bool streamOpen: feeds.length > 0
    // a stream's properties arrive once it's tracked
    PwObjectTracker { objects: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioOutStream) }
    readonly property bool nodeUp: Pipewire.nodes.values.some(n => n.name === nodeName)

    // links every feed into cava's node, once it's up and whenever the
    // feeds change; pw-link refuses one that's already there
    function relink() { linkTimer.restart() }
    onFeedsChanged: relink()
    onNodeUpChanged: relink()
    Timer {
        id: linkTimer
        interval: 200
        onTriggered: {
            if (!cava.running || !root.nodeUp || root.feeds.length === 0) return
            Quickshell.execDetached(["sh", "-c", "for id; do pw-link \"$id\" " + root.nodeName + " 2>/dev/null; done", "sh"]
                .concat(root.feeds.map(n => String(n.id))))
        }
    }

    CommandProbe { id: cavaProbe; name: "cava" }

    Process {
        id: cava
        running: root.hasCava && root.streamOpen && Settings.widgetVisible("visualizer") && Settings.vizShown && !root.restarting
        // not connected to the default output's monitor, as cava would be
        environment: ({ PIPEWIRE_PROPS: "{ node.autoconnect = false node.name = " + root.nodeName + " }" })
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
