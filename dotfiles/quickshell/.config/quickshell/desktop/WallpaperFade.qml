// The fade between wallpapers on one screen: the old image drawn over the
// new one (which hypr/wallpaper.sh has already put up) and faded out. Sits
// on the background layer, input passing through, and is up only while the
// fade plays. Its length follows the shell's animation time.

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "../flyouts"

OverlayWindow {
    id: win
    layerNamespace: "wallpaper-fade"
    visible: false
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Background

    readonly property int fadeMs: Theme.dur(1500)

    Connections {
        target: Wallpaper
        function onFadeCountChanged() {
            if (win.fadeMs <= 0) return
            fade.stop()
            old.opacity = 1
            win.pending = true
            var src = "file://" + Wallpaper.fadeFrom
            if (old.source.toString() === src && old.status === Image.Ready) win.begin()
            else old.source = src
        }
    }

    // a fade waiting for the old image to decode, so it never shows empty
    property bool pending: false

    function begin() {
        pending = false
        visible = true
        fade.restart()
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: old.opacity
        visible: Settings.wallpaperFill !== "fill"
    }

    Image {
        id: old
        anchors.fill: parent
        asynchronous: true
        fillMode: ({ "fill": Image.PreserveAspectCrop, "fit": Image.PreserveAspectFit,
                     "center": Image.Pad, "tile": Image.Tile })[Settings.wallpaperFill]
        onStatusChanged: if (status === Image.Ready && win.pending) win.begin()
    }

    NumberAnimation {
        id: fade
        target: old
        property: "opacity"
        from: 1
        to: 0
        duration: win.fadeMs
        easing.type: Easing.InOutSine
        onFinished: win.visible = false
    }
}
