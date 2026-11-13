// The fade between wallpapers on one screen: the new image fades in over the
// old one (on the background layer, input passing through, above the swaybg
// already up because it is newer), and when it is whole hypr/wallpaper.sh
// puts the same image up under it. The window goes once that is done. Its
// length follows the shell's animation time.

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "../flyouts"

OverlayWindow {
    id: win
    layerNamespace: "wallpaper-fade"
    visible: Wallpaper.overlayUp
    mask: Region {}
    // each fade starts from nothing
    onVisibleChanged: if (!visible) img.opacity = 0
    WlrLayershell.layer: WlrLayer.Background

    readonly property int fadeMs: Theme.dur(1500)
    // a fade waiting for the new image to decode, so it never fades in empty
    property bool pending: false
    property int token: 0

    Connections {
        target: Wallpaper
        function onFadeCountChanged() {
            win.token = Wallpaper.fadeCount
            if (win.fadeMs <= 0) { Wallpaper.commit(win.token); return }
            fade.stop()
            win.pending = true
            var src = "file://" + Wallpaper.fadeTo
            if (img.source.toString() === src && img.status === Image.Ready) win.begin()
            else img.source = src
        }
    }

    function begin() {
        pending = false
        fade.from = img.opacity
        fade.restart()
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: img.opacity
        visible: Settings.wallpaperFill !== "fill"
    }

    Image {
        id: img
        anchors.fill: parent
        asynchronous: true
        opacity: 0
        fillMode: ({ "fill": Image.PreserveAspectCrop, "fit": Image.PreserveAspectFit,
                     "center": Image.Pad, "tile": Image.Tile })[Settings.wallpaperFill]
        onStatusChanged: if (status === Image.Ready && win.pending) win.begin()
    }

    NumberAnimation {
        id: fade
        target: img
        property: "opacity"
        to: 1
        duration: win.fadeMs
        easing.type: Easing.InOutSine
        onFinished: Wallpaper.commit(win.token)
    }
}
