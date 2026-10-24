// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/DesktopTab.qml
//
// The Appearance page's Desktop tab: WALLPAPER, WIDGETS (which show on the
// desktop, and their edit mode), WINDOWS (gaps, borders,
// corners, shadow, tab bar), EFFECTS (opacity, dim, blur) and MOTION, with
// neighbouring steppers, switches and segments two to a line and the three
// per-part speeds folded away.

import Quickshell
import Quickshell.Widgets
import QtQuick
import "../../services"
import "../../flyouts"
import ".."

SettingsTab {
    id: desktopTab
    tabId: "desktop"

    // a row in a two-column grid, and its label's share beside a stepper
    readonly property real half: (width - Theme.spaceXl * 2) / 2
    readonly property real halfLabel: half - Theme.fit(160) - Theme.spaceL
    readonly property real switchLabel: half - Theme.switchWidth - Theme.spaceL

    // the per-part speeds, folded away; a search for one opens them
    property bool speedsOpen: false
    readonly property var speedLabels: ["Window speed", "Workspace speed", "Shell speed"]
    Connections {
        target: desktopTab.page
        function onHighlightChanged() {
            if (desktopTab.speedLabels.indexOf(desktopTab.page.highlight) !== -1) desktopTab.speedsOpen = true
        }
    }

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
        hint: "How it fills the screen"
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
            width: desktopTab.half
            labelWidth: desktopTab.half - folderChip.width - Theme.spaceL
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
            width: desktopTab.half
            labelWidth: desktopTab.half - coloursChip.width - Theme.spaceL
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
                    { key: "stats", label: "System", hint: "CPU, GPU, memory, temperature" }]

            SettingsField {
                required property var modelData
                width: desktopTab.half
                labelWidth: desktopTab.switchLabel
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
        labelWidth: parent.width - placeChip.width - Theme.spaceL
        label: "Placement"
        hint: "Drag them about on the desktop; right-clicking one does the same"
        FlyoutChip {
            id: placeChip
            anchors.right: parent.right
            text: "Edit placement"
            onClicked: Quickshell.execDetached(["qs", "ipc", "call", "widgets", "edit"])
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "WINDOWS" }

    Grid {
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl * 2

        HyprInt { width: desktopTab.half; labelWidth: desktopTab.halfLabel; label: "Window gaps"; note: "Between windows"; path: ["general"]; key: "gaps_in"; max: 20 }
        Stepper { width: desktopTab.half; labelWidth: desktopTab.halfLabel; label: "Edge gaps"; hint: Theme.barFull ? "At the screen edges" : "The bar floats in too"; key: "edgeGap"; suffix: "px" }
    }

    SettingsField {
        label: "Border width"
        hint: Settings.windowBorderWidth === "style" ? "As thick as the shell's strokes" : "Every window's border"
        Choices { key: "windowBorderWidth" }
    }

    Grid {
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl * 2

        SettingsField {
            width: desktopTab.half
            labelWidth: desktopTab.half - focusedChoices.width - Theme.spaceL
            label: "Focused border"
            hint: "The one with focus"
            Choices { id: focusedChoices; key: "windowBorderFocused" }
        }

        SettingsField {
            width: desktopTab.half
            labelWidth: desktopTab.half - unfocusedChoices.width - Theme.spaceL
            label: "Unfocused border"
            hint: "Every other window"
            Choices { id: unfocusedChoices; key: "windowBorderUnfocused" }
        }
    }

    HexColour {
        visible: Settings.windowBorderFocused === "custom"
        label: "Focused colour"
        key: "windowBorderFocusedHex"
        fallback: Theme.strokeFocus
        grayscaleOnly: false
    }

    HexColour {
        visible: Settings.windowBorderUnfocused === "custom"
        label: "Unfocused colour"
        key: "windowBorderUnfocusedHex"
        fallback: Theme.border
        grayscaleOnly: false
    }

    SettingsField {
        label: "Window corners"
        hint: Settings.windowRounding === "shell" ? "Rounded like the shell's panels" : "A rounding of their own"
        Choices { key: "windowRounding" }
    }

    Stepper { visible: Settings.windowRounding === "own"; label: "Window rounding"; hint: "Corner radius"; key: "windowRadius"; suffix: "px" }

    SettingsField {
        label: "Window shadow"
        hint: Settings.windowShadow === "style" ? (Theme.shadow === "none" ? "The style's: none, or Shadows is off" : "The style's soft shadow")
            : "Under every window"
        Choices { key: "windowShadow" }
    }

    SettingsField {
        label: "Tab bar"
        hint: "Over grouped windows: the open tab's fill"
        Choices { key: "tabBar" }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "EFFECTS" }

    Grid {
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl * 2

        Stepper { width: desktopTab.half; labelWidth: desktopTab.halfLabel; label: "Focused opacity"; key: "focusedOpacity"; step: 5; suffix: "%" }
        Stepper { width: desktopTab.half; labelWidth: desktopTab.halfLabel; label: "Unfocused opacity"; key: "unfocusedOpacity"; step: 5; suffix: "%" }
        HyprToggle { width: desktopTab.half; labelWidth: desktopTab.switchLabel; label: "Dim unfocused"; path: ["decoration"]; key: "dim_inactive" }
        HyprPercent { width: desktopTab.half; labelWidth: desktopTab.halfLabel; label: "Dim strength"; visible: page.hyprField(["decoration"], "dim_inactive").value === true; path: ["decoration"]; key: "dim_strength"; min: 0 }
    }

    HyprToggle { label: "Blur"; note: "Behind translucent windows and layers"; path: ["decoration", "blur"]; key: "enabled" }

    Grid {
        visible: page.blurOn
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceXl * 2

        HyprInt { width: desktopTab.half; labelWidth: desktopTab.halfLabel; label: "Blur size"; note: "Each pass's spread"; path: ["decoration", "blur"]; key: "size"; min: 1; max: 20 }
        HyprInt { width: desktopTab.half; labelWidth: desktopTab.halfLabel; label: "Blur passes"; note: "More is smoother"; path: ["decoration", "blur"]; key: "passes"; min: 1; max: 4; suffix: "" }
    }

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

    FlyoutRow {
        label: "Per-part speeds…"
        note: Settings.animWindows === Settings.animWorkspaces && Settings.animWindows === Settings.animShell
            ? "windows, workspaces, shell · all " + Settings.animWindows + "%"
            : "windows " + Settings.animWindows + "% · workspaces " + Settings.animWorkspaces + "% · shell " + Settings.animShell + "%"
        trailing: desktopTab.speedsOpen ? "󰅀" : "󰅂"
        highlighted: desktopTab.speedsOpen
        onActivated: desktopTab.speedsOpen = !desktopTab.speedsOpen
    }

    SettingsIndent {
        visible: desktopTab.speedsOpen

        Stepper { label: "Window speed"; hint: "Open, close, move; lower is quicker"; key: "animWindows"; step: 25; suffix: "%" }
        Stepper { label: "Workspace speed"; hint: "Switching, and the scratchpad"; key: "animWorkspaces"; step: 25; suffix: "%" }
        Stepper { label: "Shell speed"; hint: "Flyouts, hovers and meters"; key: "animShell"; step: 25; suffix: "%" }
    }

    // each tile plays its animation while the pointer is on it
    Tiles { key: "windowAnim"; label: "Window animation"; hint: "Open, close, minimize, scratchpad"; art: animArt; columns: 4; tileHeight: Theme.fs(64) }

    Component { id: animArt; ModuleArt { kind: "windowAnim" } }
}
