// The chat UI and CLI sessions have their own lifetime, independent of shell.qml.
import Quickshell
import Quickshell.Io
import QtQuick
import "services"
import "sidebar"

ShellRoot {
    id: root
    readonly property string statusText: JSON.stringify({ shown: Ai.shown,
        screen: Ai.screen ? Ai.screen.name : "", busy: Ai.busy, asking: Ai.asking, unseen: Ai.unseen })
    onStatusTextChanged: publish.restart()
    Component.onCompleted: Quickshell.watchFiles = false
    IpcHandler {
        target: "chat"
        function open(tab: string, engine: string): void { Ai.openConversation(tab, engine) }
        function close(): void { Ai.close() }
        function pin(on: bool): void { Ai.pinned = on }
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
        id: publish
        interval: 200
        running: true
        onTriggered: status.setText(root.statusText)
    }
}
