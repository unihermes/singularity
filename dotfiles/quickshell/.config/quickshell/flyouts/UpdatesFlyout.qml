// Singularity - Quickshell
// ~/.config/quickshell/flyouts/UpdatesFlyout.qml
//
// Split out of shell.qml. Self-contained: only needs the Updates singleton.
// Packages first, then Singularity's own commits waiting upstream, while
// there are any.

import QtQuick
import "../services"

FlyoutPanel {
    flyout: "updates"
    menuWidth: 300

    FlyoutHeading {
        text: "UPDATES  " + Updates.count
            + (Updates.aurCount > 0 ? "  (" + Updates.aurCount + " AUR)" : "")
    }

    FlyoutRow {
        visible: Updates.count === 0
        label: Updates.checking ? "Checking…"
            : Updates.lastChecked === null ? "Not checked yet" : "Everything is up to date"
        enabled: false
    }

    ListView {
        id: updList
        visible: count > 0
        width: parent.width
        height: Math.min(contentHeight, 12 * Theme.rowHeightDense)
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        model: Updates.packages

        delegate: Item {
            required property var modelData
            width: updList.width
            height: Theme.rowHeightDense

            Text {
                anchors.left: parent.left
                anchors.right: ver.left
                anchors.rightMargin: Theme.spaceL
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.name + (modelData.aur ? "  ·aur" : "")
                elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontBody
            }
            Text {
                id: ver
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, Theme.fs(150))

                horizontalAlignment: Text.AlignRight
                text: modelData.to
                elide: Text.ElideLeft
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }
        }
    }

    // Singularity's clone, behind its upstream
    FlyoutDivider { visible: Updates.repoBehind > 0 }

    FlyoutHeading {
        visible: Updates.repoBehind > 0
        text: "SINGULARITY  " + Updates.repoBehind
            + (Updates.repoBehind === 1 ? " commit" : " commits") + " to pull"
    }

    Repeater {
        model: Updates.repoBehind > 0 ? Updates.repoCommits.slice(0, 3) : []

        FlyoutRow {
            required property var modelData
            enabled: false
            leadingIcon: "󰜘"
            label: modelData.subject
        }
    }

    FlyoutRow {
        visible: Updates.repoCommits.length > 3
        enabled: false
        label: "and " + (Updates.repoCommits.length - 3) + " more"
    }

    // a fast-forward only, as in Settings, so not past local commits
    FlyoutRow {
        visible: Updates.repoBehind > 0
        label: Updates.repoUpdating ? "Pulling…"
            : Updates.repoAhead > 0 ? "Local commits in the way" : "Pull now"
        trailing: "󰇚"
        busy: Updates.repoUpdating
        enabled: Updates.repoAhead === 0 && !Updates.repoUpdating
        onActivated: {
            Updates.updateRepo()
            scope.openFlyout = ""
        }
    }

    FlyoutDivider {}

    FlyoutRow {
        label: Updates.repoBehind > 0 ? "Update packages" : "Update now"
        trailing: "󰚰"
        enabled: Updates.count > 0
        onActivated: {
            Updates.update()
            scope.openFlyout = ""
        }
    }

    FlyoutRow {
        label: Updates.checking || Updates.repoChecking ? "Checking…" : "Check again"
        trailing: Updates.lastChecked ? Qt.formatTime(Updates.lastChecked, Theme.timeFormat) : ""
        busy: Updates.checking || Updates.repoChecking
        onActivated: Updates.refresh()
    }

    FlyoutRow {
        label: "More in Settings"
        trailing: "󰁔"
        onActivated: scope.openSettings("updates")
    }
}
