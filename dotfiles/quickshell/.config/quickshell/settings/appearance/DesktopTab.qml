// Appearance's Desktop tab: what sits on the screen under the windows.
// WALLPAPER: the arrows on the heading, every image, New wallpaper, Fit and
// the folder. DESKTOP WIDGETS: each widget as a lit chip beside a picture of
// them as set, the sidebar and where they stand. Nothing folds away.

import Quickshell
import Quickshell.Widgets
import QtQuick
import "../../services"
import "../../flyouts"
import ".."

SettingsTab {
    tabId: "desktop"

    // --- wallpaper ------------------------------------------------------

    // the heading shares its line with the current image's name and arrows
    Item {
        readonly property bool isSectionBreak: true
        readonly property bool sectioned: true
        width: parent.width
        height: Math.max(Theme.controlSize, wpHeading.implicitHeight)

        FlyoutHeading {
            id: wpHeading
            anchors.left: parent.left
            anchors.right: arrows.left
            anchors.rightMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            text: "WALLPAPER" + (Wallpaper.title !== "" ? "  " + Wallpaper.title : "")
        }

        Row {
            id: arrows
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: wpHeading.lift
            spacing: Theme.spaceS

            FlyoutChip { glyph: true; text: "󰒮"; enabled: Wallpaper.images.length > 1; onClicked: Wallpaper.step(-1) }
            FlyoutChip { glyph: true; text: "󰒝"; enabled: Wallpaper.images.length > 1; onClicked: Wallpaper.shuffle() }
            FlyoutChip { glyph: true; text: "󰒭"; enabled: Wallpaper.images.length > 1; onClicked: Wallpaper.step(1) }
        }
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
        hint: "How it fills the screen"
        Choices { key: "wallpaperFill" }
    }

    SettingsField {
        labelWidth: parent.width - folderChip.width - Theme.spaceL
        label: "Folder"
        hint: Wallpaper.images.length + " images in wallpapers/"
        FlyoutChip {
            id: folderChip
            anchors.right: parent.right
            text: "Open folder"
            onClicked: Quickshell.execDetached(["xdg-open", Wallpaper.folder])
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "DESKTOP WIDGETS" }

    Beside {
        kind: "widgets"

        Repeater {
            model: [{ key: "clock", label: "Clock", hint: "The day, the time and the week" },
                    { key: "weather", label: "Weather", hint: "Now and the next five days" },
                    { key: "music", label: "Now playing", hint: "The Music module's player" },
                    { key: "stats", label: "System", hint: "CPU, GPU, memory, temperature" },
                    { key: "sysinfo", label: "System info", hint: "Distro, kernel, uptime, IP" }]

            SettingsField {
                id: widget
                required property var modelData
                readonly property bool on: Settings.deskWidget(modelData.key).on
                labelWidth: parent.labelWidth
                label: modelData.label
                hint: modelData.hint
                OnChip { on: widget.on; onClicked: Settings.setDeskWidget(widget.modelData.key, { on: !widget.on }) }
            }
        }

        SettingsField {
            labelWidth: parent.labelWidth
            label: "Sidebar"
            hint: "System readings down the right edge"
            OnChip { on: Settings.deskSidebar; onClicked: Settings.set("deskSidebar", !Settings.deskSidebar) }
        }

        SettingsField {
            visible: Settings.deskSidebar
            labelWidth: parent.labelWidth
            label: "Sidebar style"
            hint: Settings.deskSidebarStyle === "floating" ? "A card like the widgets, clear of the edges" : "Flush down the screen's edge"
            FlyoutSegmented {
                anchors.right: parent.right
                fill: false
                model: [{ value: "edge", text: "Edge" }, { value: "floating", text: "Floating" }]
                current: Settings.deskSidebarStyle
                onPicked: v => Settings.set("deskSidebarStyle", v)
            }
        }

        SettingsField {
            labelWidth: parent.labelWidth
            label: "Placement"
            hint: "Drag them about on the desktop"
            FlyoutChip {
                anchors.right: parent.right
                text: "Edit placement"
                onClicked: Quickshell.execDetached(["qs", "ipc", "call", "widgets", "edit"])
            }
        }
    }
}
