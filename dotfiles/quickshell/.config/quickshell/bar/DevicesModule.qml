// The Devices module: one slot per device with a battery, the phone first
// and then every peripheral (Peripherals), each its glyph and level (a bolt
// while charging, red when it runs low). A click on a slot opens the Devices
// flyout under it, with that device picked (the phone's tray open, a
// peripheral's row marked); middle on the phone mirrors it. The phone's slot
// carries a green dot while it's on screen, and its glyph goes red while it
// waits for USB debugging to be allowed.

import QtQuick
import "../services"

ModuleFrame {
    id: root
    required property var host
    anchors.verticalCenter: parent.verticalCenter
    spacing: 0
    hoverWhole: false
    padH: Math.max(0, Theme.modulePadH - Theme.spaceS)

    readonly property bool phoneOn: Phone.connected || PhoneLink.connected
    // each { key, glyph, name, level (-1 none), charging }
    readonly property var slots: (Phone.shown ? [{
            key: "phone", glyph: "󰄜", name: Phone.shownName || "Phone",
            level: phoneOn ? Phone.shownBattery : -1, charging: Phone.shownCharging
        }] : []).concat(Peripherals.devices)

    visible: slots.length > 0 && Settings.widgetVisible("devices")
    active: host.screenScope.openFlyout === "devices"

    // the slot the open flyout hangs from, if it's one of these
    function opens(slot) {
        var s = host.screenScope
        if (s.openFlyout === "devices" && s.flyoutAnchorItem === slot) {
            s.openFlyout = ""
            return
        }
        if (s.openFlyout === "devices") s.openFlyout = ""
        s.toggleFlyout("devices", slot)
    }

    Repeater {
        model: root.slots

        Item {
            id: slot
            required property var modelData
            // read by DevicesFlyout to pick this device
            readonly property string deviceKey: modelData.key
            readonly property bool opened: root.host.screenScope.openFlyout === "devices"
                && root.host.screenScope.flyoutAnchorItem === slot
            readonly property bool low: Peripherals.isLow(modelData)

            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: content.implicitWidth + Theme.spaceS * 2
            implicitHeight: Theme.moduleHeight

            Rectangle {
                visible: mouse.containsMouse || slot.opened
                anchors.centerIn: parent
                width: parent.width
                height: Theme.iconHoverHeight
                radius: Theme.moduleStyle === "grouped" ? Theme.radius : Theme.radiusSmall
                color: Theme.overlay
                border.width: slot.opened ? Theme.borderWidth : 0
                border.color: Theme.strokeFocus
            }

            Row {
                id: content
                anchors.centerIn: parent
                spacing: Theme.spaceXs

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: slot.modelData.glyph
                    color: slot.modelData.key === "phone" && Phone.unauthorized ? Theme.alert
                        : slot.modelData.level < 0 ? Theme.subtext : Theme.text
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.iconSize
                }

                Text {
                    visible: slot.modelData.level >= 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: (slot.modelData.charging ? "󱐋" : "") + slot.modelData.level + "%"
                    color: slot.low ? Theme.alert : slot.modelData.charging ? Theme.good : Theme.text
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.barLabelSize
                }
            }

            // the phone on screen
            Rectangle {
                visible: slot.modelData.key === "phone" && Phone.mirroring
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Theme.spaceXs
                width: Theme.spaceM
                height: width
                radius: width / 2
                color: Theme.good
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: m => {
                    if (m.button === Qt.MiddleButton) {
                        if (slot.modelData.key === "phone") Phone.toggleMirror()
                        return
                    }
                    root.opens(slot)
                }
            }
        }
    }
}
