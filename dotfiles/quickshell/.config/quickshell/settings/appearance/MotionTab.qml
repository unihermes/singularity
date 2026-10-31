// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/MotionTab.qml
//
// Appearance's Motion tab: SPEED (one dial for everything, the three
// per-part speeds behind its Advanced) and ANIMATIONS (how windows and
// flyouts come and go).

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

    SettingsAdvanced {
        Stepper { label: "Window speed"; hint: "Open, close, move; lower is quicker"; key: "animWindows"; step: 25; suffix: "%" }
        Stepper { label: "Workspace speed"; hint: "Switching, and the scratchpad"; key: "animWorkspaces"; step: 25; suffix: "%" }
        Stepper { label: "Shell speed"; hint: "Flyouts, hovers and meters"; key: "animShell"; step: 25; suffix: "%" }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "ANIMATIONS" }

    // each tile plays its animation while the pointer is on it
    Tiles { key: "windowAnim"; label: "Window animation"; hint: "Open, close, minimize, scratchpad"; art: animArt; columns: 4; tileHeight: Theme.fs(64) }

    SettingsField {
        label: "Flyouts open"
        hint: Theme.flyoutGrown ? "Expanded flyouts always fade" : ""
        Choice { key: "flyoutAnim" }
    }

    Component { id: animArt; ModuleArt { kind: "windowAnim" } }
}
