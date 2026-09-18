// Singularity - Quickshell
// ~/.config/quickshell/services/Audio.qml
//
// The default output sink's volume and mute, bound live so anything
// watching `percent` / `muted` (the OSD, the bar chip) catches a change
// from anywhere -- hardware keys, a slider, scroll-on-chip -- without each
// call site having to announce it.

pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool ready: !!sink && sink.ready && !!sink.audio
    readonly property int percent: ready ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool muted: ready ? sink.audio.muted : false

    function setVolume(pct) {
        if (!ready) return
        sink.audio.volume = Math.max(0, Math.min(1, pct / 100))
    }

    function toggleMute() {
        if (ready) sink.audio.muted = !sink.audio.muted
    }

    // Pipewire nodes are unbound by default: audio.volume / audio.muted stay
    // invalid until the node is tracked, so the sink has to be listed here
    // for anything to read or write it at all.
    PwObjectTracker {
        objects: [root.sink]
    }
}
