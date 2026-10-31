// Singularity - Quickshell
// ~/.config/quickshell/settings/appearance/ChangesBar.qml
//
// The bar at the foot of the Appearance page while anything differs: how
// many settings differ from the baseline (the style's saved default when it
// was saved with this look, the look as designed otherwise), with Save as
// default and Reset beside it. Review opens the list of changes above it,
// each with a way to its field and a way back, and Factory reset at its end.

import Quickshell
import QtQuick
import "../../services"
import "../../flyouts"
import ".."

Column {
    id: cb
    // the Appearance page this sits on, found by walking up
    readonly property Item page: {
        for (var p = parent; p; p = p.parent)
            if (p.isSettingsPage === true) return p
        return null
    }
    property bool open: false
    readonly property string styleName: page.label(Settings.style, "style")
    readonly property string baseName: Settings.baselineIsDefault ? styleName + "'s default" : page.label(Settings.look)

    width: parent ? parent.width : 0
    spacing: Theme.spaceS

    // the changes, scrolling on their own past a handful
    Rectangle {
        visible: cb.open
        width: parent.width
        height: Math.min(changes.implicitHeight, Theme.fit(230)) + Theme.spaceS * 2
        radius: Theme.sectionRadius
        color: Theme.surface
        border.width: Theme.borderWidth
        border.color: Theme.strokeHover

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: Theme.spaceS
            anchors.leftMargin: Theme.spaceL
            anchors.rightMargin: Theme.spaceL
            contentHeight: changes.implicitHeight
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Column {
                id: changes
                width: flick.width

                Text {
                    visible: Settings.lookPristine
                    width: parent.width
                    topPadding: Theme.spaceS
                    bottomPadding: Theme.spaceS
                    wrapMode: Text.WordWrap
                    text: "No changes"
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontSmall
                }

                Repeater {
                    model: Settings.lookDiffs

                    SettingsField {
                        id: change
                        required property string modelData
                        // shares its label with the field it stands for
                        searchable: false
                        label: cb.page.keyLabels[modelData] || modelData
                        hint: cb.page.valueText(modelData, Settings.lookBaseline[modelData])
                            + "  →  " + cb.page.valueText(modelData, Settings[modelData])

                        Row {
                            anchors.right: parent.right
                            spacing: Theme.spaceS
                            FlyoutChip {
                                text: "Show"
                                onClicked: cb.page.showSetting(change.label)
                            }
                            FlyoutChip {
                                text: "Undo"
                                onClicked: Settings.resetLookKey(change.modelData)
                            }
                        }
                    }
                }

                SettingsField {
                    visible: !Settings.lookPristine
                    searchable: false
                    label: "Undo all"
                    hint: "Put every change back to " + cb.baseName

                    FlyoutChip {
                        anchors.right: parent.right
                        text: "Undo all"
                        confirmText: "Undo " + Settings.lookDiffs.length + "?"
                        onClicked: Settings.undoLookChanges()
                    }
                }

                SettingsField {
                    label: "Factory reset"
                    hint: Settings.hasUserDefault ? "Forget " + cb.styleName + "'s saved default and go back to its stock"
                        : "No saved default for " + cb.styleName + " — its stock is the default"

                    FlyoutChip {
                        anchors.right: parent.right
                        text: "Forget"
                        confirmText: "Forget it?"
                        enabled: Settings.hasUserDefault
                        onClicked: {
                            Settings.factoryReset()
                            cb.page.say(cb.styleName + "'s saved default cleared, back to stock", false)
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: Theme.rowHeightTall + Theme.spaceL
        radius: Theme.sectionRadius
        color: Theme.surface
        border.width: Theme.borderWidth
        border.color: Theme.accent

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceM

            Rectangle {
                visible: !Settings.lookPristine
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.fs(8)
                height: width
                radius: Theme.pill(width)
                color: Theme.accent
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Settings.lookPristine
                    ? (Settings.baselineIsDefault ? "As you saved " + cb.styleName + "'s default" : page.label(Settings.look) + " as designed")
                    : Settings.lookDiffs.length + " changed from " + cb.baseName
                color: Settings.lookPristine ? Theme.subtext : Theme.textStrong
                font.family: Theme.fontText
                font.pixelSize: Theme.fontSmall
                font.weight: Theme.weightBody
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: Theme.spaceS
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceS

            FlyoutChip {
                text: cb.open ? "Review  󰅀" : "Review  󰅃"
                selected: cb.open
                onClicked: cb.open = !cb.open
            }
            // two clicks: overwriting the style's old default can't be undone
            FlyoutChip {
                text: "Save as default"
                confirmText: "Replace default?"
                enabled: !Settings.isDefault
                onClicked: {
                    Settings.saveAsDefault()
                    page.say("Current appearance saved as " + cb.styleName + "'s default", false)
                }
            }
            FlyoutChip {
                text: "Reset"
                confirmText: "Reset?"
                enabled: !Settings.isDefault
                onClicked: {
                    Settings.reset()
                    page.say("Appearance reset to " + cb.styleName + "'s default", false)
                }
            }
        }
    }
}
