// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/DesktopTab.qml
//
// The Appearance page's Desktop tab: the wallpaper, how Hyprland draws
// windows, and motion.

import Quickshell
import Quickshell.Widgets
import QtQuick
import "../../services"
import "../../flyouts"
import ".."

SettingsTab {
    tabId: "desktop"

    FlyoutHeading { text: "WALLPAPER" }

    SettingsField {
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
    FlyoutHeading { text: "WINDOWS" }

    HyprInt { label: "Gaps between windows"; path: ["general"]; key: "gaps_in"; max: 20 }
    Stepper { label: "Gaps at screen edges"; hint: Theme.barFull ? "" : "The bar floats this far in too"; key: "edgeGap"; suffix: "px" }
    Stepper { label: "Focused opacity"; key: "focusedOpacity"; step: 5; suffix: "%" }
    Stepper { label: "Unfocused opacity"; key: "unfocusedOpacity"; step: 5; suffix: "%" }
    HyprToggle { label: "Dim unfocused"; path: ["decoration"]; key: "dim_inactive" }
    HyprPercent { label: "Dim strength"; visible: page.hyprField(["decoration"], "dim_inactive").value === true; path: ["decoration"]; key: "dim_strength"; min: 0 }
    HyprToggle { label: "Blur"; note: "Behind translucent windows and layers"; path: ["decoration", "blur"]; key: "enabled" }
    HyprInt { label: "Blur size"; visible: page.blurOn; note: "How far each pass spreads"; path: ["decoration", "blur"]; key: "size"; min: 1; max: 20 }
    HyprInt { label: "Blur passes"; visible: page.blurOn; note: "More is smoother and costs more"; path: ["decoration", "blur"]; key: "passes"; min: 1; max: 4; suffix: "" }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "MOTION" }

    SettingsField {
        label: "Animations"
        hint: "The shell's and Hyprland's"
        FlyoutSliderRow {
            anchors.right: parent.right
            width: Theme.fit(260)
            label: ""
            suffix: "%"
            value: Settings.animTime
            minimum: Settings.limits.animTime.min
            maximum: Settings.limits.animTime.max
            marks: Settings.animTimeMarks
            onMoved: v => Settings.set("animTime", v)
        }
    }

    SettingsField {
        label: "Window animation"
        hint: "Open, close, minimize, scratchpad"
        Choice { key: "windowAnim" }
    }
}
