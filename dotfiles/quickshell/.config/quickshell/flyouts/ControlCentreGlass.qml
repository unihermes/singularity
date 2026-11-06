// Singularity - Quickshell
// ~/.config/quickshell/flyouts/ControlCentreGlass.qml
//
// Glass's Control Centre home, after Apple's: a connectivity card beside
// Quiet and Night Light, Keep Awake and Game Mode, thick Display and Sound
// capsules, what's playing, and the pages as pills. ControlCentre.qml shows it
// in place of the tiles while the style is Glass.

import Quickshell.Widgets
import Quickshell.Bluetooth
import QtQuick
import "../services"

Column {
    id: root

    required property var cc
    readonly property var bar: cc.scope.barWindow
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btOn: !!bar && bar.btAdapterOn(adapter)
    readonly property real cell: (width - spacing) / 2
    readonly property int tileH: Theme.fs(92)

    width: parent.width
    spacing: Theme.spaceL

    // opens a module's own flyout in place of this one
    function details(name) { cc.scope.toggleFlyout(name, bar.widgetItem(name)) }

    // a switch row inside the connectivity card
    component Link: Item {
        id: link
        property string icon: ""
        property string title: ""
        property string caption: ""
        property bool lit: false
        signal toggled()
        signal opened()
        width: parent.width
        height: Theme.fs(38)

        GlassDot {
            id: dot
            anchors.verticalCenter: parent.verticalCenter
            icon: link.icon
            lit: link.lit
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: link.toggled()
            }
        }
        Column {
            anchors.left: dot.right
            anchors.leftMargin: Theme.spaceL
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            Text {
                width: parent.width
                text: link.title
                elide: Text.ElideRight
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightStrong
                font.pixelSize: Theme.fontBody
            }
            Text {
                width: parent.width
                text: link.caption
                elide: Text.ElideRight
                color: Theme.subtext
                font.family: Theme.fontText
                font.pixelSize: Theme.fontCaption
            }
        }
        MouseArea {
            anchors.left: dot.right
            anchors.right: parent.right
            height: parent.height
            cursorShape: Qt.PointingHandCursor
            onClicked: link.opened()
        }
    }

    Row {
        width: parent.width
        spacing: root.spacing

        Rectangle {
            width: root.cell
            height: root.tileH * 2 + root.spacing
            radius: Theme.fs(16)
            color: Theme.washHover
            border.width: 1
            border.color: Theme.stroke

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spaceL
                // the rows spread down the card
                spacing: Math.max(Theme.spaceS, (height - visibleChildren.length * Theme.fs(38)) / Math.max(1, visibleChildren.length - 1))

                Link {
                    icon: "󰤨"
                    title: "Wi-Fi"
                    caption: Network.wired ? "Wired" : !Network.powered ? "Off" : Network.ssid !== "" ? Network.ssid : "Not connected"
                    lit: Network.powered
                    onToggled: Network.setPowered(!Network.powered)
                    onOpened: root.details("network")
                }
                Link {
                    visible: !!root.adapter
                    icon: "󰂯"
                    title: "Bluetooth"
                    caption: !root.btOn ? "Off" : root.adapter.devices.values.some(d => d.connected) ? "Connected" : "On"
                    lit: root.btOn
                    onToggled: root.bar.setBtPowered(root.adapter, !root.btOn)
                    onOpened: root.details("bluetooth")
                }
                Link {
                    icon: "󰀝"
                    title: "Airplane"
                    caption: root.cc.airplane ? "Radios off" : "Off"
                    lit: root.cc.airplane
                    onToggled: root.cc.setAirplane(!root.cc.airplane)
                    onOpened: root.cc.setAirplane(!root.cc.airplane)
                }
            }
        }

        Column {
            width: root.cell
            spacing: root.spacing
            GlassTile {
                width: parent.width
                height: root.tileH
                icon: Notifications.dnd ? "󰂛" : "󰂚"
                title: "Quiet"
                caption: Notifications.dnd ? "Banners held" : "Off"
                lit: Notifications.dnd
                onClicked: Notifications.toggleDnd()
            }
            GlassTile {
                width: parent.width
                height: root.tileH
                icon: root.cc.shellRoot.nightLight ? "󰖔" : "󰖙"
                title: "Night Light"
                caption: root.cc.shellRoot.nightLight ? Settings.nightLightKelvin + " K" : "Off"
                lit: root.cc.shellRoot.nightLight
                usable: root.cc.shellRoot.hasHyprsunset
                onClicked: root.cc.shellRoot.nightLight = !root.cc.shellRoot.nightLight
            }
        }
    }

    Row {
        width: parent.width
        spacing: root.spacing
        GlassTile {
            width: root.cell
            height: root.tileH
            icon: root.cc.shellRoot.keepAwake ? "󰅶" : "󰾪"
            title: "Keep Awake"
            caption: root.cc.shellRoot.keepAwake ? "No sleep" : "Off"
            lit: root.cc.shellRoot.keepAwake
            onClicked: root.cc.shellRoot.keepAwake = !root.cc.shellRoot.keepAwake
        }
        GlassTile {
            width: root.cell
            height: root.tileH
            icon: "󰊴"
            title: "Game Mode"
            caption: GameMode.active ? "On" : "Off"
            lit: GameMode.active
            onClicked: GameMode.toggle()
        }
    }

    Rectangle {
        visible: Brightness.available
        width: parent.width
        height: Theme.fs(66)
        radius: Theme.fs(16)
        color: Theme.washHover
        border.width: 1
        border.color: Theme.stroke
        Text {
            x: Theme.spaceL + 4
            y: Theme.spaceM
            text: "Display"
            color: Theme.textStrong
            font.family: Theme.fontText
            font.weight: Theme.weightStrong
            font.pixelSize: Theme.fontBody
        }
        GlassSlider {
            x: Theme.spaceL
            y: parent.height - height - Theme.spaceL
            width: parent.width - Theme.spaceL * 2
            icon: "󰃠"
            value: Brightness.level
            onMoved: v => Brightness.set(v)
        }
    }

    Rectangle {
        width: parent.width
        height: Theme.fs(66)
        radius: Theme.fs(16)
        color: Theme.washHover
        border.width: 1
        border.color: Theme.stroke
        Text {
            x: Theme.spaceL + 4
            y: Theme.spaceM
            text: "Sound"
            color: Theme.textStrong
            font.family: Theme.fontText
            font.weight: Theme.weightStrong
            font.pixelSize: Theme.fontBody
        }
        GlassSlider {
            x: Theme.spaceL
            y: parent.height - height - Theme.spaceL
            width: parent.width - Theme.spaceL * 2
            icon: Audio.muted ? "󰖁" : "󰕾"
            value: Audio.percent
            dimmed: Audio.muted
            onMoved: v => Audio.setVolume(v)
        }
    }

    // what's playing
    Rectangle {
        visible: !!Media.player
        width: parent.width
        height: Theme.fs(66)
        radius: Theme.fs(16)
        color: Theme.washHover
        border.width: 1
        border.color: Theme.stroke
        readonly property string art: (Media.artUrls(Media.player) || [])[0] || ""

        Rectangle {
            id: artBox
            x: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.fs(48)
            height: width
            radius: Theme.fs(10)
            color: Theme.surface
            clip: true
            Image {
                anchors.fill: parent
                source: parent.parent.art
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }
        Column {
            anchors.left: artBox.right
            anchors.leftMargin: Theme.spaceL
            anchors.right: transport.left
            anchors.rightMargin: Theme.spaceM
            anchors.verticalCenter: parent.verticalCenter
            Text {
                width: parent.width
                text: Media.titleOf(Media.player)
                elide: Text.ElideRight
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightStrong
                font.pixelSize: Theme.fontBody
            }
            Text {
                width: parent.width
                text: Media.artistOf(Media.player)
                elide: Text.ElideRight
                color: Theme.subtext
                font.family: Theme.fontText
                font.pixelSize: Theme.fontCaption
            }
        }
        Row {
            id: transport
            anchors.right: parent.right
            anchors.rightMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceM
            Repeater {
                model: [
                    { glyph: "󰒮", act: "previous" },
                    { glyph: Media.shownPlaying ? "󰏤" : "󰐊", act: "toggle" },
                    { glyph: "󰒭", act: "next" },
                ]
                Text {
                    required property var modelData
                    text: modelData.glyph
                    color: Theme.textStrong
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.fontIconSize + Theme.spaceS
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -Theme.spaceXs
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Media[parent.modelData.act]()
                    }
                }
            }
        }
    }

    // the pages, as capsules
    Row {
        id: pages
        width: parent.width
        spacing: Theme.spaceM
        Repeater {
            model: [
                { text: "Appearance", page: "appearance" },
                { text: "Widgets", page: "widgets" },
            ].concat(PpdProfile.profile === "" ? [] : [{
                text: (PpdProfile.choices.find(c => c.value === PpdProfile.profile) || { text: "Power" }).text,
                page: "power" }])
            Rectangle {
                required property var modelData
                width: (pages.width - pages.spacing * (pages.children.length - 2)) / (pages.children.length - 1)
                height: Theme.fs(32)
                radius: height / 2
                color: pillMouse.containsMouse ? Theme.washActive : Theme.washHover
                border.width: 1
                border.color: Theme.stroke
                Behavior on color { ColorAnimation { duration: Theme.durFast; easing.type: Theme.ease } }
                Text {
                    anchors.centerIn: parent
                    text: parent.modelData.text
                    color: Theme.textStrong
                    font.family: Theme.fontText
                    font.weight: Theme.weightStrong
                    font.pixelSize: Theme.fontBody
                }
                MouseArea {
                    id: pillMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cc.page = parent.modelData.page
                }
            }
        }
    }

    // the tools, as round buttons spread along the foot
    Row {
        width: parent.width
        readonly property var acts: root.cc.toolActions
        spacing: (width - acts.length * Theme.fs(34)) / Math.max(1, acts.length - 1)
        Repeater {
            model: parent.acts
            GlassDot {
                required property var modelData
                icon: modelData.icon
                lit: modelData.act === "record" && Recorder.recording
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cc.run(parent.modelData.act)
                }
            }
        }
    }
}
