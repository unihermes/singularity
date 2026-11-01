// Singularity - Quickshell
// ~/.config/quickshell/scripts/ArtifactViewer.qml
//
// A sidebar artifact's page in a window of its own, run by artifact.py
// through Qt's qml tool (not the shell): qml ArtifactViewer.qml -- URL TITLE BG
// Links open in the browser. Ctrl+R reloads, Ctrl+W or Escape closes.

import QtQuick
import QtQuick.Window
import QtWebEngine

Window {
    id: win

    readonly property var args: {
        var a = Qt.application.arguments
        return a.slice(a.indexOf("--") + 1)
    }

    width: 960
    height: 720
    visible: true
    title: (args[1] || "Artifact") + " — Artifact"
    color: args[2] || "#1e1e2e"

    WebEngineView {
        id: view
        anchors.fill: parent
        url: win.args[0] || ""
        backgroundColor: win.color
        settings.localContentCanAccessRemoteUrls: true
        settings.javascriptCanAccessClipboard: true

        onNavigationRequested: request => {
            if (request.navigationType === WebEngineNavigationRequest.LinkClickedNavigation
                    && request.url.toString().indexOf("http") === 0) {
                Qt.openUrlExternally(request.url)
                request.reject()
            }
        }
        onNewWindowRequested: request => Qt.openUrlExternally(request.requestedUrl)
    }

    Shortcut { sequence: "Ctrl+R"; onActivated: view.reload() }
    Shortcut { sequences: ["Ctrl+W", "Escape"]; onActivated: win.close() }
}
