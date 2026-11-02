// Machine policy and hardware from the same resolver used by provisioning.
pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var inventory: ({})

    function refresh() { if (!probe.running) probe.running = true }

    function has(capability) { return !!(inventory.hardware || {})[capability] }
    function allows(feature) { return !!(inventory.features || {})[feature] }

    Process {
        id: probe
        running: true
        command: [Quickshell.env("HOME") + "/.config/singularity/platform.sh", "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.inventory = JSON.parse(text) }
                catch (e) { root.inventory = ({}) }
            }
        }
    }
    FileView {
        path: Paths.stateDir + "/machine"
        watchChanges: true
        printErrors: false
        onFileChanged: { reload(); probe.running = true }
    }
}
