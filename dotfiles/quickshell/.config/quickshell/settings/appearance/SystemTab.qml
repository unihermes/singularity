// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/SystemTab.qml
//
// The Appearance page's System tab.

import Quickshell
import QtQuick
import "../../services/Looks.js" as Looks
import "../../services"
import "../../flyouts"
import ".."

SettingsTab {
    tabId: "system"

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

    SettingsField {
        label: "Flyouts open"
        hint: Theme.flyoutGrown ? "Grown flyouts always fade" : "How flyouts appear"
        Choice { key: "flyoutAnim" }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "APPS OUTSIDE THE SHELL" }

    // GTK/Qt apps' own font -- independent of the shell's Font under Text. Every
    // choice here is always installed (see Looks.systemFonts), so there's no
    // pending/restart state to show like the shell font has.
    SettingsField {
        label: "System font"
        hint: "GTK and Qt apps outside the shell"

        SettingsDropdown {
            anchors.right: parent.right
            model: Looks.systemFonts
            current: Settings.systemFontFamily
            labelFor: v => page.label(v)
            fontFor: v => v
            onPicked: v => Settings.set("systemFontFamily", v)
        }
    }

    SettingsField {
        label: "Icons"
        hint: "GTK now, Qt when next opened"

        SettingsDropdown {
            anchors.right: parent.right
            model: DesktopThemes.icons
            current: Settings.iconTheme
            labelFor: v => DesktopThemes.label(v)
            onPicked: v => Settings.set("iconTheme", v)
        }
    }

    SettingsField {
        label: "Cursor"
        hint: "Apps pick it up when next opened"

        SettingsDropdown {
            anchors.right: parent.right
            model: DesktopThemes.cursors
            current: Settings.cursorTheme
            labelFor: v => DesktopThemes.label(v)
            onPicked: v => Settings.set("cursorTheme", v)
        }
    }

    Stepper { label: "Cursor size"; key: "cursorSize"; step: 4; suffix: "px" }

}
