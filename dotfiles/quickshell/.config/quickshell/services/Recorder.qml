// Singularity - Quickshell
// ~/.config/quickshell/services/Recorder.qml
//
// Screen recording and instant replay, both through gpu-screen-recorder
// (encoded on the GPU) in AV1 where the GPU encodes it and Settings asks
// for it, else H.264, with the game and chat (the default output) and the
// mic mixed into one track:
//   recording  the focused screen until stopped, into
//              ~/Videos/Recordings/<what had focus as it started>
//   replay     the last Settings.replaySeconds kept in RAM while a game is
//              open, armed when one takes focus; save() writes it out to
//              ~/Videos/Replays/<game>
// `qs ipc call recorder toggle|save`, from SUPER+SHIFT+S and SUPER+R, which
// stay live in games (game-keys.lua). Each says what it did in a toast.

pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    readonly property bool available: probe.found
    readonly property string recordDir: Quickshell.env("HOME") + "/Videos/Recordings"
    readonly property string replayDir: Quickshell.env("HOME") + "/Videos/Replays"

    readonly property bool recording: recordProc.running
    // seconds since the recording started, ticking while it runs
    property int elapsed: 0
    readonly property bool replaying: replayProc.running
    // the game the running replay is of, which names its folder
    property string replayGame: ""

    // what was just done, for the focused screen's toast (shell.qml)
    signal toast(string icon, string text)

    // Steam's games, gamescope, Minecraft and anything that says it's a game,
    // as game-keys.lua tells them
    function isGame(t) {
        var o = t ? t.lastIpcObject : null
        if (!o) return false
        var c = o.class || ""
        return /^steam_app_\d+$/.test(c) || c === "gamescope" || /^Minecraft/.test(c)
            || o.contentType === "game"
    }

    // the folder a window's files go in: a game's title ("Overwatch"),
    // another app's name, less anything a path can't hold
    function folderFor(t) {
        var o = t ? t.lastIpcObject : null
        if (!o) return "Desktop"
        var entry = isGame(t) ? null : Apps.byClass(o.class || "").entry
        var name = isGame(t) ? t.title : entry ? entry.name : String(o.class || "").replace(/^.*\./, "")
        return String(name || "").replace(/[\/\\:*?"<>|]/g, "").trim() || "Desktop"
    }

    readonly property var focusedGame: isGame(Hyprland.activeToplevel) ? Hyprland.activeToplevel : null
    readonly property bool anyGame: Hyprland.toplevels.values.some(t => isGame(t))
    readonly property bool wantReplay: available && Settings.replayOn

    onFocusedGameChanged: armReplay()
    onWantReplayChanged: wantReplay ? armReplay() : stopReplay()
    onAnyGameChanged: if (!anyGame) stopReplay()
    // a new length or codec takes a fresh buffer
    function restartReplay() {
        if (!replayProc.running) return
        replayProc.rearm = true
        stopReplay()
    }
    Connections {
        target: Settings
        function onReplaySecondsChanged() { root.restartReplay() }
    }
    onCodecChanged: restartReplay()

    // whether this GPU encodes AV1, from the recorder's --info
    property bool av1Supported: false
    readonly property string codec: av1Supported && Settings.recordCodec === "av1" ? "av1" : "h264"

    onAvailableChanged: if (available) info.running = true
    Process {
        id: info
        command: ["gpu-screen-recorder", "--info"]
        stdout: StdioCollector {
            onStreamFinished: root.av1Supported = text.split("\n").indexOf("av1") !== -1
        }
    }

    function capture(monitor) {
        return ["-w", monitor, "-f", "60", "-k", codec, "-q", "very_high", "-c", "mp4",
                "-a", "default_output|default_input", "-ac", "aac"]
    }

    // gpu-screen-recorder in a shell that makes its folder first; exec, so
    // signals reach the recorder itself
    function launch(proc, dir, args) {
        proc.command = ["sh", "-c", 'mkdir -p "$0" && exec gpu-screen-recorder "$@"', dir].concat(args)
        proc.running = true
    }

    // --- recording ---

    function toggleRecording() { recording ? stopRecording() : startRecording() }

    function startRecording() {
        var mon = Hyprland.focusedMonitor
        if (!available || recording || !mon) return
        var t = Hyprland.activeToplevel
        var dir = recordDir + "/" + folderFor(t && t.monitor === mon ? t : null)
        recordProc.file = dir + "/recording_" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".mp4"
        elapsed = 0
        launch(recordProc, dir, capture(mon.name).concat(["-o", recordProc.file]))
        toast("󰑊", "Recording")
    }

    // from a flyout: once it's out of the picture
    function startRecordingSoon() { recordDelay.restart() }
    Timer { id: recordDelay; interval: 300; onTriggered: root.startRecording() }

    // SIGINT: finish the file and quit
    function stopRecording() { if (recording) recordProc.signal(2) }

    Process {
        id: recordProc
        property string file: ""
        stderr: StdioCollector { id: recordErr }
        onExited: code => {
            if (code === 0) {
                root.toast("󰓛", "Recording saved")
                root.announce("Recording saved", file)
            }
            else root.failed("Recording failed", recordErr.text)
        }
    }

    Timer {
        running: root.recording
        interval: 1000
        repeat: true
        onTriggered: root.elapsed++
    }

    // --- instant replay ---

    function armReplay() {
        var g = focusedGame
        if (!wantReplay || !g || replayProc.running || !g.monitor) return
        replayGame = folderFor(g)
        launch(replayProc, replayDir + "/" + replayGame, capture(g.monitor.name)
            .concat(["-r", String(Settings.replaySeconds), "-replay-storage", "ram",
                     "-o", replayDir + "/" + replayGame]))
    }

    // SIGINT ends a replay without saving it
    function stopReplay() { if (replayProc.running) replayProc.signal(2) }

    // SIGUSR1 writes the buffer out; the recorder prints the file's path
    function save() {
        if (replayProc.running) replayProc.signal(10)
        else toast("󰑙", !available ? "Recorder not installed" : wantReplay ? "No game to replay" : "Instant replay off")
    }

    Process {
        id: replayProc
        // stopped for a new length, so started again on exit
        property bool rearm: false
        stdout: SplitParser {
            onRead: line => {
                if (!/\.mp4$/.test(line.trim())) return
                root.toast("󰑙", "Replay saved")
                root.announce("Replay saved", line.trim())
            }
        }
        stderr: StdioCollector { id: replayErr }
        onExited: code => {
            if (code !== 0) root.failed("Instant replay stopped", replayErr.text)
            if (rearm) {
                rearm = false
                root.armReplay()
            }
        }
    }

    // --- telling ---

    // a notification with the file; Open plays it, Show in folder opens its folder
    function announce(title, file) {
        Quickshell.execDetached(["sh", "-c",
            'c=$(notify-send -a Recorder -i video-x-generic -A open=Open -A folder="Show in folder" "$0" "${1##*/}") || exit 0\n'
            + 'case $c in open) xdg-open "$1" ;; folder) xdg-open "${1%/*}" ;; esac', title, file])
    }

    function failed(title, err) {
        var lines = String(err).trim().split("\n").filter(l => l !== "")
        Quickshell.execDetached(["notify-send", "-a", "Recorder", "-u", "critical", title,
            lines.length ? lines[lines.length - 1] : "gpu-screen-recorder quit"])
    }

    CommandProbe { id: probe; name: "gpu-screen-recorder" }

    IpcHandler {
        target: "recorder"
        function toggle(): void { root.toggleRecording() }
        function save(): void { root.save() }
        function status(): string {
            return (root.recording ? "recording " + root.elapsed + "s" : "idle")
                + (root.replaying ? ", replay of " + root.replayGame : "")
        }
    }
}
