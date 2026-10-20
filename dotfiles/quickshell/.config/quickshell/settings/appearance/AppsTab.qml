// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/AppsTab.qml
//
// The Appearance page's Apps tab: how apps outside the shell look -- their
// font, icons (a few shown beside the label) and cursor with its size.

import Quickshell
import QtQuick
import "../../services/Looks.js" as Looks
import "../../services"
import "../../flyouts"
import ".."

SettingsTab {
    id: appsTab
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

        // a few apps' icons from the theme picked here
        labelExtras: Repeater {
            model: DesktopThemes.preview
            Image {
                required property string modelData
                width: Theme.fs(20)
                height: width
                sourceSize: Qt.size(width * 2, height * 2)
                source: "file://" + modelData
                asynchronous: true
            }
        }

        SettingsDropdown {
            anchors.right: parent.right
            model: DesktopThemes.icons
            current: Settings.iconTheme
            labelFor: v => DesktopThemes.label(v)
            onPicked: v => Settings.set("iconTheme", v)
        }

        Component.onCompleted: DesktopThemes.refreshPreview()
    }

    // the theme and its size on one row
    SettingsField {
        label: "Cursor"
        hint: "When apps next open"
        labelWidth: appsTab.width - cursorControls.width - Theme.spaceL

        Row {
            id: cursorControls
            anchors.right: parent.right
            spacing: Theme.spaceM

            SettingsDropdown {
                width: Theme.fit(220)
                model: DesktopThemes.cursors
                current: Settings.cursorTheme
                labelFor: v => DesktopThemes.label(v)
                onPicked: v => Settings.set("cursorTheme", v)
            }

            FlyoutStepper {
                width: Theme.fit(130)
                value: Settings.cursorSize
                minimum: Settings.limits.cursorSize.min
                maximum: Settings.limits.cursorSize.max
                suffix: "px"
                valueWidth: 48
                onStepped: d => Settings.step("cursorSize", d * 4)
            }
        }
    }
}
