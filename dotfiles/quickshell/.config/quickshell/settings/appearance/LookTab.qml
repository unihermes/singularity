// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/LookTab.qml
//
// The Appearance page's Look tab.

import Quickshell
import Quickshell.Widgets
import QtQuick
import "../../services/Looks.js" as Looks
import "../../services"
import "../../flyouts"
import ".."

SettingsTab {
    tabId: "look"

    FlyoutHeading { text: "LOOK" }

    Item {
        id: carousel
        width: parent.width
        height: lookStrip.height + Theme.spaceL + dots.height

        readonly property int cardWidth: Theme.fit(210)
        // tall enough for the preview, the name and two lines of description,
        // so no card ends in an empty line
        readonly property int previewHeight: Math.round((cardWidth - Theme.spaceS * 2) * 0.48)
        readonly property int cardHeight: Theme.spaceS + previewHeight + Theme.spaceS
            + Math.ceil(nameMetrics.height) + Theme.spaceXs + Math.ceil(blurbMetrics.height) * 2 + Theme.spaceL + Theme.spaceS

        FontMetrics { id: nameMetrics; font.family: Theme.fontText; font.pixelSize: Theme.fontBody }
        FontMetrics { id: blurbMetrics; font.family: Theme.fontText; font.pixelSize: Theme.fontSmall }

        ListView {
            id: lookStrip
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: prevChip.width + Theme.spaceS
            anchors.rightMargin: nextChip.width + Theme.spaceS
            height: carousel.cardHeight
            orientation: ListView.Horizontal
            spacing: Theme.spaceL
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            highlightFollowsCurrentItem: false
            // every card built up front, so none is created mid-scroll
            cacheBuffer: count * step
            model: LookStore.order
            // open on the current look
            Component.onCompleted: positionViewAtIndex(Math.max(0, LookStore.order.indexOf(Settings.look)), ListView.Center)

            readonly property real step: carousel.cardWidth + spacing
            readonly property real maxX: originX + Math.max(0, contentWidth - width)

            NumberAnimation on contentX {
                id: glide
                running: false
                duration: Theme.durSlow
                easing.type: Theme.ease
            }

            function glideTo(x) {
                glide.stop()
                glide.to = Math.max(originX, Math.min(maxX, x))
                glide.start()
            }

            // a page is one card: from the first card wholly in view, which
            // at the end of the strip isn't the one at its left edge
            function page(d) {
                var first = Math.ceil((contentX - originX) / step - 0.01)
                glideTo(originX + (first + d) * step)
            }

            // scroll just far enough to show card i whole
            function reveal(i) {
                var x = originX + i * step
                if (x < contentX) glideTo(x)
                else if (x + carousel.cardWidth > contentX + width) glideTo(x + carousel.cardWidth - width)
            }

            // A plain mouse wheel, or a touchpad's vertical two-finger
            // swipe, has no x component -- repurpose that into scrolling
            // the strip sideways, so the page's own vertical scroll
            // doesn't have to be escaped first to reach it.
            //
            // A genuine horizontal swipe already carries an x component,
            // and is left alone here (event.accepted = false) so it falls
            // through to the ListView's own wheel handling -- the same
            // handling every vertical Flickable in the shell uses, which
            // is what makes swiping left move the view left there. Routing
            // it through the line above instead applied vertical's sign
            // convention to a horizontal gesture, which is backwards for it.
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    if (event.angleDelta.x !== 0) { event.accepted = false; return }
                    glide.stop()
                    lookStrip.contentX = Math.max(lookStrip.originX, Math.min(lookStrip.maxX,
                        lookStrip.contentX - event.angleDelta.y))
                }
            }

            delegate: Rectangle {
                id: card
                required property string modelData
                required property int index
                readonly property var look: LookStore.looks[modelData]
                readonly property bool current: Settings.look === modelData

                width: carousel.cardWidth
                height: lookStrip.height
                radius: Theme.radius
                color: Theme.surface
                border.width: current ? 2 : Theme.borderWidth
                border.color: current ? Theme.accent
                    : cardMouse.containsMouse ? Theme.strokeFocus : Theme.stroke

                LookCard {
                    id: preview
                    look: card.look
                    x: Theme.spaceS
                    y: Theme.spaceS
                    width: parent.width - Theme.spaceS * 2
                    height: carousel.previewHeight
                    radius: Theme.radiusInner
                }

                Column {
                    anchors.top: preview.bottom
                    anchors.topMargin: Theme.spaceS
                    x: Theme.spaceL
                    width: parent.width - Theme.spaceL * 2
                    spacing: Theme.spaceXs

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: card.look.name + (card.current ? (Settings.lookPristine ? "  ·  in use" : "  ·  adjusted") : "")
                        color: card.current ? Theme.textStrong : Theme.text
                        font.family: Fonts.resolve(card.look.settings.fontFamily)
                        font.pixelSize: Theme.fontBody
                        font.bold: true
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        text: card.look.description
                        color: Theme.subtext
                        font.family: Theme.fontText
                        font.weight: Theme.weightBody
                        font.pixelSize: Theme.fontSmall
                    }
                }

                MouseArea {
                    id: cardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Settings.set("look", card.modelData)
                        page.say(card.look.name + " look applied", false)
                    }
                }

                // Remove, in the preview's corner: two clicks, since it
                // deletes the look from looks.json and there's no undo short
                // of git. Its own ground, so it reads over any preview.
                Rectangle {
                    id: removeBox
                    visible: LookStore.removable(card.modelData)
                             && (cardMouse.containsMouse || removeHover.hovered || removeChip.armed)
                    anchors.right: preview.right
                    anchors.top: preview.top
                    anchors.margins: Theme.spaceXs
                    width: removeChip.width
                    height: removeChip.height
                    radius: Theme.radiusInner
                    color: Theme.surface

                    HoverHandler { id: removeHover }

                    FlyoutChip {
                        id: removeChip
                        glyph: true
                        text: "󰅖"
                        confirmText: "Remove"
                        onClicked: page.removeLook(card.modelData)
                    }
                }
            }
        }

        FlyoutChip {
            id: prevChip
            anchors.left: parent.left
            y: (lookStrip.height - height) / 2
            glyph: true
            text: "󰅁"
            enabled: !lookStrip.atXBeginning
            onClicked: lookStrip.page(-1)
        }

        FlyoutChip {
            id: nextChip
            anchors.right: parent.right
            y: (lookStrip.height - height) / 2
            glyph: true
            text: "󰅂"
            enabled: !lookStrip.atXEnd
            onClicked: lookStrip.page(1)
        }

        // one dot per look, the current one lit; click to jump
        Row {
            id: dots
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            spacing: Theme.spaceS
            Repeater {
                model: LookStore.order
                Rectangle {
                    required property string modelData
                    required property int index
                    width: Settings.look === modelData ? Theme.fs(14) : Theme.fs(6)
                    height: Theme.fs(6)
                    radius: Theme.fs(3)
                    color: Settings.look === modelData ? Theme.accent : Theme.muted
                    Behavior on width { NumberAnimation { duration: Theme.durFast; easing.type: Theme.ease } }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: lookStrip.reveal(parent.index)
                    }
                }
            }
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "WALLPAPER" }

    SettingsField {
        label: "Current"
        hint: Wallpaper.name !== "" ? Wallpaper.name : "No wallpaper"

        Row {
            anchors.right: parent.right
            spacing: Theme.spaceS

            FlyoutChip { glyph: true; text: "󰒮"; enabled: Wallpaper.images.length > 1; onClicked: Wallpaper.step(-1) }

            FlyoutChip { glyph: true; text: "󰒝"; enabled: Wallpaper.images.length > 1; onClicked: Wallpaper.shuffle() }
            FlyoutChip { glyph: true; text: "󰒭"; enabled: Wallpaper.images.length > 1; onClicked: Wallpaper.step(1) }
        }
    }

    SettingsField {
        label: "One per look"
        hint: Settings.wallpaperPerLook ? "Each look keeps its own wallpaper"
            : "Every look shares this wallpaper"

        Switch {
            anchors.right: parent.right
            checked: Settings.wallpaperPerLook
            onToggled: Settings.setWallpaperPerLook(!Settings.wallpaperPerLook)
        }
    }

    // One choice over two settings: whether login picks a random wallpaper
    // (Settings.wallpaperShuffle, which wallpaper.sh reads) and whether one
    // is picked on a timer while logged in (wallpaperInterval). A timer
    // implies a random one at login too.
    SettingsField {
        label: "New wallpaper"
        hint: Settings.wallpaperInterval > 0 ? "Random at login, then on this interval"
            : Settings.wallpaperShuffle ? "A random one every login"
            : "Stays until you pick another"

        FlyoutSegmented {
            anchors.right: parent.right
            fill: false
            model: [{ value: "never", text: "Never" }, { value: "login", text: "At login" },
                    { value: 15, text: "15 min" }, { value: 30, text: "30 min" },
                    { value: 60, text: "1 hour" }, { value: 180, text: "3 hours" }]
            current: Settings.wallpaperInterval > 0 ? Settings.wallpaperInterval
                : Settings.wallpaperShuffle ? "login" : "never"
            onPicked: v => {
                Settings.setWallpaperShuffle(v !== "never")
                Settings.set("wallpaperInterval", typeof v === "number" ? v : 0)
            }
        }
    }

    // Every image, four to a row; click one to show it.
    Flow {
        id: grid
        width: parent.width
        spacing: Theme.spaceL

        readonly property int columns: 4
        readonly property real cellWidth: (width - spacing * (columns - 1)) / columns

        Repeater {
            model: Wallpaper.images

            ClippingRectangle {
                id: thumb
                required property string modelData
                readonly property bool current: modelData === Wallpaper.current

                width: grid.cellWidth
                height: Math.round(width * 9 / 16)
                radius: Theme.radiusInner
                color: Theme.base
                border.width: current ? 2 : Theme.borderWidth
                border.color: current ? Theme.accent
                    : thumbMouse.containsMouse ? Theme.strokeFocus : Theme.stroke

                Image {
                    anchors.fill: parent
                    source: "file://" + thumb.modelData
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    // decoded at thumbnail size, not the image's own 4K
                    sourceSize.width: 360
                }

                MouseArea {
                    id: thumbMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Wallpaper.set(thumb.modelData)
                }
            }
        }
    }

    Text {
        visible: Wallpaper.images.length === 0
        text: "No images in the repo's wallpapers/ folder"
        color: Theme.subtext
        font.family: Theme.fontText
        font.weight: Theme.weightBody
        font.pixelSize: Theme.fontBody
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading {
        text: Settings.lookPristine ? "CHANGES" : "CHANGES  " + Settings.lookDiffs.length
    }

    LookChanges {}

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "SAVED DEFAULT" }

    SettingsField {
        id: saveField
        label: "Set as default"
        // two clicks: overwriting the old default can't be undone
        hint: saveChip.armed ? "Click again to replace the saved default"
            : Settings.isDefault ? "This is the default"
            : "Make everything as it is now what Reset returns to"

        FlyoutChip {
            id: saveChip
            anchors.right: parent.right
            text: "Save"
            confirmText: "Confirm"
            enabled: !Settings.isDefault
            onClicked: {
                Settings.saveAsDefault()
                page.say("Current appearance saved as the default", false)
            }
        }
    }

    SettingsField {
        label: "Reset to default"
        hint: Settings.isDefault ? "Already at the default"
            : Settings.hasUserDefault ? "Back to the appearance you saved as default"
            : "Back to stock: the " + page.label(Looks.fallback) + " look as designed"

        FlyoutChip {
            anchors.right: parent.right
            text: "Reset"
            confirmText: "Reset?"
            enabled: !Settings.isDefault
            onClicked: {
                Settings.reset()
                page.say("Appearance reset to the default", false)
            }
        }
    }

    SettingsField {
        label: "Factory reset"
        hint: Settings.hasUserDefault ? "Forget the saved default and go back to stock"
            : "No saved default — stock is the default"

        FlyoutChip {
            anchors.right: parent.right
            text: "Forget"
            confirmText: "Forget it?"
            enabled: Settings.hasUserDefault
            onClicked: {
                Settings.factoryReset()
                page.say("Saved default cleared, back to stock", false)
            }
        }
    }

}
