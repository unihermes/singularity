// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/AppsTab.qml
//
// The Appearance page's Apps tab: how apps outside the shell look.

import Quickshell
import QtQuick
import "../../services/Looks.js" as Looks
import "../../services"
import "../../flyouts"
import ".."

SettingsTab {
    tabId: "apps"

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

    // a few apps' icons from the theme picked above
    Row {
        x: parent.width - width
        spacing: Theme.spaceL
        visible: DesktopThemes.preview.length > 0
        Repeater {
            model: DesktopThemes.preview
            Image {
                required property string modelData
                width: Theme.fs(28)
                height: width
                sourceSize: Qt.size(width * 2, height * 2)
                source: "file://" + modelData
                asynchronous: true
            }
        }
        Component.onCompleted: DesktopThemes.refreshPreview()
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

    SettingsField {
        label: "Follow the style"
        hint: Settings.appsFollowStyle ? "Corners, density and frames, as the shell" : "Apps keep their theme's own shapes"
        Switch {
            anchors.right: parent.right
            checked: Settings.appsFollowStyle
            onToggled: Settings.set("appsFollowStyle", !Settings.appsFollowStyle)
        }
    }

    Stepper { label: "Terminal opacity"; hint: "Also on the Terminal page"; key: "terminalOpacity"; step: 5; suffix: "%" }
}
