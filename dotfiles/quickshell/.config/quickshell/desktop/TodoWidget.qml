// Singularity - Quickshell
// ~/.config/quickshell/desktop/TodoWidget.qml
//
// A Google Tasks list on the desktop (services/Tasks.qml): its title in
// the accent with ‹ › for the other lists, the open tasks then the done
// ones, a circle to tick each off (or back on), × on the one under the
// pointer to delete it, and a line to add one (not when small). Signed
// out, it offers to sign in.

import QtQuick
import "../services"

WidgetCard {
    id: root

    readonly property var tasks: Tasks.list ? Tasks.list.tasks : []

    Item {
        id: top
        width: parent.width
        height: title.height

        WidgetText {
            id: title
            width: parent.width - arrows.width - Theme.fit(8)
            card: root
            px: Theme.fit(13)
            text: (Tasks.list ? Tasks.list.title : "To-do").toUpperCase()
            color: root.accent
            font.weight: Font.Bold
            font.letterSpacing: 1
        }
        Row {
            id: arrows
            visible: Tasks.lists.length > 1
            anchors.right: parent.right
            anchors.verticalCenter: title.verticalCenter
            spacing: Theme.fit(12)
            WidgetGlyph { card: root; px: Theme.fit(14); text: "󰅁"; onClicked: Tasks.showList(-1) }
            WidgetGlyph { card: root; px: Theme.fit(14); text: "󰅂"; onClicked: Tasks.showList(1) }
        }
    }

    // signed out: how to sign in
    Column {
        visible: !Tasks.connected
        anchors.top: top.bottom
        anchors.topMargin: Theme.fit(10)
        width: parent.width
        spacing: Theme.fit(6)

        WidgetText {
            width: parent.width
            card: root
            px: Theme.fit(14)
            wrapMode: Text.Wrap
            text: Tasks.signingIn ? "Waiting for the browser…"
                : Tasks.hasClient ? "Sign in to show your Google Tasks."
                : "Google Tasks needs a sign-in client first: see Settings › Appearance › Desktop."
            color: root.fgDim
        }
        WidgetGlyph {
            visible: Tasks.hasClient && !Tasks.signingIn
            card: root
            px: Theme.fit(14)
            text: "󰍂  Sign in"
            font.family: root.font
            color: root.accent
            onClicked: Tasks.signIn()
        }
    }

    ListView {
        id: listView
        visible: Tasks.connected
        anchors.top: top.bottom
        anchors.topMargin: Theme.fit(8)
        anchors.bottom: adder.visible ? adder.top : parent.bottom
        anchors.bottomMargin: adder.visible ? Theme.fit(8) : 0
        width: parent.width
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.tasks
        spacing: Theme.fit(4)

        footer: WidgetText {
            visible: root.tasks.length === 0
            height: visible ? implicitHeight : 0
            card: root
            px: Theme.fit(14)
            text: Tasks.loading ? "Loading…" : "Nothing to do"
            color: root.fgFaint
        }

        delegate: Item {
            id: row
            required property var modelData
            width: listView.width
            height: Math.max(check.height, label.implicitHeight)

            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }
            WidgetGlyph {
                id: check
                card: root
                px: Theme.fit(16)
                text: row.modelData.done ? "󰄵" : "󰄱"
                color: row.modelData.done ? root.fgFaint : root.fg
                active: row.modelData.id !== ""
                onClicked: Tasks.toggle(row.modelData)
            }
            WidgetText {
                id: label
                anchors.left: check.right
                anchors.leftMargin: Theme.fit(8)
                anchors.right: del.left
                anchors.rightMargin: Theme.fit(6)
                anchors.verticalCenter: check.verticalCenter
                card: root
                px: Theme.fit(14)
                text: row.modelData.title
                color: row.modelData.done ? root.fgFaint : root.fg
                font.strikeout: row.modelData.done
            }
            WidgetGlyph {
                id: del
                anchors.right: parent.right
                anchors.verticalCenter: check.verticalCenter
                visible: hover.containsMouse && row.modelData.id !== ""
                card: root
                px: Theme.fit(13)
                text: "󰅖"
                color: root.fgDim
                onClicked: Tasks.remove(row.modelData)
            }
        }
    }

    // a new task, at the top of the list
    Item {
        id: adder
        visible: Tasks.connected && !root.small && !!Tasks.list
        anchors.bottom: parent.bottom
        width: parent.width
        height: input.implicitHeight + Theme.fit(6)

        TextInput {
            id: input
            width: parent.width
            color: root.fg
            selectionColor: root.accent
            selectedTextColor: "#000000"
            font.family: root.font
            font.weight: Font.DemiBold
            font.pixelSize: Theme.fit(14)
            clip: true
            onAccepted: { Tasks.add(text); text = "" }
            Keys.onEscapePressed: { text = ""; focus = false }

            WidgetText {
                visible: input.text === ""
                card: root
                px: Theme.fit(14)
                text: "󰐕  Add a task"
                color: root.fgFaint
            }
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: input.activeFocus ? root.accent : root.track
        }
    }

    WidgetText {
        visible: Tasks.connected && Tasks.error !== ""
        anchors.right: parent.right
        anchors.verticalCenter: top.verticalCenter
        anchors.rightMargin: arrows.visible ? arrows.width + Theme.fit(10) : 0
        card: root
        px: Theme.fit(12)
        text: Tasks.error
        color: Theme.alert
    }
}
