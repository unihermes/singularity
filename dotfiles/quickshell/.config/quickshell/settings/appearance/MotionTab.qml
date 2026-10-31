// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/MotionTab.qml
//
// Appearance's Motion tab, as a timeline. SPEED is the one dial for
// everything. ANIMATIONS is a track per part (windows, workspaces, the
// shell) over a ruler in ms, each bar as long as that part's animations
// take now; dragging a bar's end sets its speed, and a track's own choice
// sits at its end (the window animation, how flyouts open). The window
// animations follow as tiles that play while hovered. Nothing folds away.

import Quickshell
import QtQuick
import "../../services"
import "../../flyouts"
import ".."

SettingsTab {
    tabId: "motion"

    FlyoutHeading { text: "SPEED" }

    SettingsField {
        label: "Animations"
        hint: Settings.animTime === 0 ? "Off: everything is instant" : "The shell's and Hyprland's, every track at once"
        FlyoutSliderRow {
            anchors.right: parent.right
            width: Theme.fit(300)
            label: ""
            suffix: "%"
            value: Settings.animTime
            minimum: Settings.limits.animTime.min
            maximum: Settings.limits.animTime.max
            marks: Settings.animTimeMarks
            onMoved: v => Settings.set("animTime", v)
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "ANIMATIONS" }

    SettingsNote { text: "A track per part, as long as its animations take; drag a bar's end to set its speed" }

    // the ruler over the lanes, lined up with them
    Item {
        width: parent.width
        height: Theme.fontCaption + Theme.spaceXs

        Item {
            x: windowsTrack.labelWidth
            width: parent.width - x - windowsTrack.trailingWidth - Theme.spaceL
            height: parent.height

            Repeater {
                model: 5
                Text {
                    required property int index
                    x: Math.min(parent.width - width, Math.max(0, parent.width * index / 4 - width / 2))
                    text: index * 100 + (index === 4 ? " ms" : "")
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontCaption
                }
            }
        }
    }

    SpeedTrack {
        id: windowsTrack
        label: "Window speed"
        hint: "Open, close, move"
        key: "animWindows"
        base: 200

        SettingsDropdown {
            anchors.right: parent.right
            width: parent.width
            model: Settings.choices.windowAnim
            current: Settings.windowAnim
            labelFor: v => Settings.choiceLabel(v, "windowAnim")
            onPicked: v => Settings.set("windowAnim", v)
        }
    }

    SpeedTrack {
        label: "Workspace speed"
        hint: "Switching, and the scratchpad"
        key: "animWorkspaces"
        base: 200
    }

    SpeedTrack {
        label: "Shell speed"
        hint: Theme.flyoutGrown ? "Flyouts, hovers; grown flyouts fade" : "Flyouts, hovers and meters"
        key: "animShell"
        base: 150

        SettingsDropdown {
            anchors.right: parent.right
            width: parent.width
            model: Settings.choices.flyoutAnim
            current: Settings.flyoutAnim
            labelFor: v => Settings.choiceLabel(v, "flyoutAnim")
            onPicked: v => Settings.set("flyoutAnim", v)
        }
    }

    // each tile plays its animation while the pointer is on it
    Tiles { key: "windowAnim"; label: "Window animation"; hint: "Open, close, minimize, scratchpad; hover to play"; art: animArt; columns: 4; tileHeight: Theme.fs(64) }

    Component { id: animArt; ModuleArt { kind: "windowAnim" } }
}
