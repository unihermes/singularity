// The chat UI and CLI sessions have their own lifetime, independent of shell.qml.
import Quickshell
import Quickshell.Io
import QtQuick
import "services"
import "sidebar"

ShellRoot {
    Component.onCompleted: Quickshell.watchFiles = false
    IpcHandler {
        target: "chat"
        function open(tab: string, engine: string): void { Ai.openConversation(tab, engine) }
        function close(): void { Ai.close() }
        function toggle(name: string): void {
            Ai.toggle(Quickshell.screens.find(s => s.name === name) || Quickshell.screens[0])
        }
    }
    LazyLoader {
        active: Ai.used
        AiSidebar {}
    }
    FileView {
        id: status
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/singularity-ai-status.json"
        atomicWrites: true
        printErrors: false
    }
    Timer {
        interval: 200
        running: true
        repeat: true
        property string last: ""
        onTriggered: {
            var value = JSON.stringify({ shown: Ai.shown, screen: Ai.screen ? Ai.screen.name : "",
                busy: Ai.busy, asking: Ai.asking, unseen: Ai.unseen })
            if (value !== last) { status.setText(value); last = value }
        }
    }
}
