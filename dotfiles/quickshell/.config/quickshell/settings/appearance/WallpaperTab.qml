// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/WallpaperTab.qml
//
// The Wallpaper & Desktop page: WALLPAPER (the image, how it changes and
// fits, its folder, colours from it) and WIDGETS (which show on the
// desktop, the sidebar, and their edit mode), switches two to a line.

import Quickshell
import Quickshell.Widgets
import QtQuick
import "../../services"
import "../../flyouts"
import ".."

SettingsTab {
    id: wallpaperTab
    tabId: "wallpaper"

    // a row in a two-column grid, and its label's share beside a stepper
    readonly property real half: (width - Theme.spaceXl * 2) / 2
    readonly property real halfLabel: half - Theme.fit(160) - Theme.spaceL
    readonly property real switchLabel: half - Theme.switchWidth - Theme.spaceL

    FlyoutHeading { text: "WALLPAPER" }

    // the current image beside its name and the arrows
    Item {
        width: parent.width
        height: Math.max(currentThumb.height, currentField.implicitHeight)

        ClippingRectangle {
            id: currentThumb
            visible: Wallpaper.current !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: visible ? Math.round(height * 16 / 9) : 0
            height: Theme.fs(48)
            radius: Theme.radiusInner
            color: Theme.base
            border.width: 2
            border.color: Theme.accent

            Image {
                anchors.fill: parent
                source: Wallpaper.current !== "" ? "file://" + Wallpaper.current : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 240
            }
        }

        SettingsField {
            id: currentField
            anchors.verticalCenter: parent.verticalCenter
            x: currentThumb.visible ? currentThumb.width + Theme.spaceL : 0
            width: parent.width - x
            label: "Current"
            hint: Wallpaper.title !== "" ? Wallpaper.title : "No wallpaper"

            Row {
                anchors.right: parent.right
                spacing: Theme.spaceS

                FlyoutChip { glyph: true; text: "󰒮"; enabled: Wallpaper.images.length > 1; onClicked: Wallpaper.step(-1) }
                FlyoutChip { glyph: true; text: "󰒝"; enabled: Wallpaper.images.length > 1; onClicked: Wallpaper.shuffle() }
                FlyoutChip { glyph: true; text: "󰒭"; enabled: Wallpaper.images.length > 1; onClicked: Wallpaper.step(1) }
            }
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

    SettingsField {
        label: "Fit"
        Choices { key: "wallpaperFill" }
    }

    // every image, six to a row; click one to show it
    Flow {
        id: grid
        width: parent.width
        spacing: Theme.spaceM

        readonly property int columns: 6
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
                    sourceSize.width: 240
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

    Grid {
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl * 2

        SettingsField {
            width: wallpaperTab.half
            labelWidth: wallpaperTab.half - folderChip.width - Theme.spaceL
            label: "Folder"
            hint: Wallpaper.images.length + " images in wallpapers/"
            FlyoutChip {
                id: folderChip
                anchors.right: parent.right
                text: "Open folder"
                onClicked: Quickshell.execDetached(["xdg-open", Wallpaper.folder])
            }
        }

        SettingsField {
            width: wallpaperTab.half
            labelWidth: wallpaperTab.half - coloursChip.width - Theme.spaceL
            label: "Colours from it"
            hint: Settings.colourMode === "wallpaper" ? "The palette follows it" : "A palette from its tones"
            FlyoutChip {
                id: coloursChip
                anchors.right: parent.right
                text: Settings.colourMode === "wallpaper" ? "Back to grayscale" : "Use its colours"
                onClicked: Settings.set("colourMode", Settings.colourMode === "wallpaper" ? "grayscale" : "wallpaper")
            }
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "WIDGETS" }

    Grid {
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl * 2

        Repeater {
            model: [{ key: "clock", label: "Clock", hint: "The day, the time and the week" },
                    { key: "weather", label: "Weather", hint: "Now and the next five days" },
                    { key: "music", label: "Now playing", hint: "The Music module's player" },
                    { key: "stats", label: "System", hint: "CPU, GPU, memory, temperature" },
                    { key: "sysinfo", label: "System info", hint: "Distro, kernel, uptime, IP" }]

            SettingsField {
                required property var modelData
                width: wallpaperTab.half
                labelWidth: wallpaperTab.switchLabel
                label: modelData.label
                hint: modelData.hint
                Switch {
                    anchors.right: parent.right
                    checked: Settings.deskWidget(modelData.key).on
                    onToggled: Settings.setDeskWidget(modelData.key, { on: !checked })
                }
            }
        }
    }

    SettingsField {
        label: "Sidebar"
        hint: "System readings down the right edge of the main display"
        Switch {
            anchors.right: parent.right
            checked: Settings.deskSidebar
            onToggled: Settings.set("deskSidebar", !checked)
        }
    }

    SettingsField {
        labelWidth: parent.width - placeChip.width - Theme.spaceL
        label: "Placement"
        hint: "Drag widgets to reposition them"
        FlyoutChip {
            id: placeChip
            anchors.right: parent.right
            text: "Edit placement"
            onClicked: Quickshell.execDetached(["qs", "ipc", "call", "widgets", "edit"])
        }
    }
}
