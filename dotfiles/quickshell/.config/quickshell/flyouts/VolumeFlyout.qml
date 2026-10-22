// Singularity - Quickshell
// ~/.config/quickshell/flyouts/VolumeFlyout.qml
//
// Sound on one panel, the level first: the output's level large with the
// device beside it (a click there opens the outputs in place to switch),
// its slider, the microphone's level, the Game, Chat and Media channels'
// levels (a click on a name mutes it) and the ChatMix dial, then each app playing right now with
// a level of its own (an app with several streams, like a browser's tabs,
// gets one level for them all). Outputs with nothing plugged in are left
// out. The Audio page in Settings has the rest: those outputs, recording
// apps, and moving an app to another output.

import "../services"
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

FlyoutPanel {
    id: volumeFlyout
    flyout: "volume"
    menuWidth: Theme.flyoutMenuWidth

    // the outputs list, opened from the device under the level
    property bool picking: false
    onOpenChanged: {
        picking = false
        if (open) Audio.refreshPorts()
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool sourceReady: !!source && source.ready && !!source.audio
    readonly property int micPercent: sourceReady ? Math.round(source.audio.volume * 100) : 0
    readonly property bool micMuted: sourceReady && source.audio.muted

    // outputs with nothing plugged in stay out of the list, unless chosen
    readonly property var sinksShown: Audio.sinks.filter(n => Audio.unplugged.indexOf(n.id) < 0 || n === sink)

    // audio.volume / audio.muted stay invalid until a node is tracked
    PwObjectTracker {
        objects: volumeFlyout.open ? Audio.devices.concat(Audio.streams, Channels.sinks) : []
    }

    // --- output: the level large, the device beside it --------------------------

    FlyoutHeading { text: "VOLUME" }

    Item {
        width: parent.width
        implicitHeight: Math.max(level.implicitHeight, device.implicitHeight)

        Row {
            id: level
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceXs
            Text {
                id: levelText
                text: Audio.percent
                color: Audio.muted ? Theme.subtext : Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightStrong
                font.pixelSize: Theme.fontHero
            }
            Text {
                anchors.baseline: levelText.baseline
                text: Audio.muted ? "% muted" : "%"
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontBody
            }
        }

        // the output; a click opens the others in place
        Item {
            id: device
            anchors.right: parent.right
            anchors.left: level.right
            anchors.leftMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: deviceText.implicitHeight
            height: implicitHeight

            Column {
                id: deviceText
                width: parent.width
                spacing: 1

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    text: volumeFlyout.sink ? Audio.plainName(volumeFlyout.sink) : "No output"
                    color: deviceMouse.containsMouse ? Theme.textStrong : Theme.text
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontBody
                }
                Text {
                    visible: volumeFlyout.sinksShown.length > 1
                    width: parent.width
                    horizontalAlignment: Text.AlignRight
                    text: "Output " + (volumeFlyout.picking ? "󰅃" : "󰅀")
                    color: deviceMouse.containsMouse ? Theme.text : Theme.subtext
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontSmall
                }
            }

            MouseArea {
                id: deviceMouse
                anchors.fill: parent
                enabled: volumeFlyout.sinksShown.length > 1
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: volumeFlyout.picking = !volumeFlyout.picking
            }
        }
    }

    Repeater {
        model: ScriptModel { values: volumeFlyout.picking ? volumeFlyout.sinksShown : [] }
        FlyoutRow {
            required property var modelData
            leadingIcon: Audio.glyph(modelData)
            label: Audio.plainName(modelData)
            highlighted: modelData === volumeFlyout.sink
            onActivated: {
                Pipewire.preferredDefaultAudioSink = modelData
                volumeFlyout.picking = false
            }
        }
    }

    // muted keeps the level on show, dimmed, as the volume toast does
    Slider {
        width: parent.width
        value: Audio.percent
        opacity: Audio.muted ? 0.5 : 1
        onMoved: v => Audio.setVolume(v)
    }

    FlyoutAction {
        icon: Audio.muted ? "󰖁" : "󰕾"
        label: "Mute"
        checked: Audio.muted
        onActivated: Audio.toggleMute()
    }

    // --- the microphone ----------------------------------------------------------

    FlyoutHeading {
        visible: volumeFlyout.sourceReady
        text: "MICROPHONE"
    }

    Row {
        visible: volumeFlyout.sourceReady
        width: parent.width
        spacing: Theme.spaceS
        Slider {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - micText.width - parent.spacing
            value: volumeFlyout.micPercent
            opacity: volumeFlyout.micMuted ? 0.5 : 1
            onMoved: v => volumeFlyout.source.audio.volume = v / 100
        }
        Text {
            id: micText
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.fit(40)
            horizontalAlignment: Text.AlignRight
            text: volumeFlyout.micMuted ? "Off" : volumeFlyout.micPercent + "%"
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
    }

    FlyoutAction {
        visible: volumeFlyout.sourceReady
        icon: volumeFlyout.micMuted ? "󰍭" : "󰍬"
        label: "Mute microphone"
        checked: volumeFlyout.micMuted
        onActivated: volumeFlyout.source.audio.muted = !volumeFlyout.micMuted
    }

    // --- channels -----------------------------------------------------------------

    FlyoutHeading {
        visible: Channels.sinks.length > 0
        text: "CHANNELS"
    }

    Repeater {
        model: ScriptModel { values: Channels.sinks }

        Item {
            id: channel
            required property var modelData
            readonly property bool ready: modelData.ready && !!modelData.audio
            readonly property bool muted: ready && modelData.audio.muted
            readonly property int percent: ready ? Math.round(modelData.audio.volume * 100) : 0
            readonly property string key: Channels.key(modelData)
            width: parent ? parent.width : 0
            implicitHeight: Theme.rowHeight

            Item {
                id: channelName
                width: Theme.fit(110)
                height: parent.height
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.fontBody
                    text: channel.key === "game" ? "󰊴" : channel.key === "chat" ? "󰭹" : "󰝚"
                    color: Theme.subtext
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.fontBody
                }
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.fontBody + Theme.spaceM
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: Audio.nodeName(channel.modelData) + (channel.muted ? " 󰖁" : "")
                    color: channel.muted ? Theme.subtext : channelMouse.containsMouse ? Theme.textStrong : Theme.text
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontBody
                }
                MouseArea {
                    id: channelMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (channel.ready) channel.modelData.audio.muted = !channel.muted
                }
            }

            Slider {
                anchors.left: channelName.right
                anchors.leftMargin: Theme.spaceS
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                value: channel.percent
                opacity: channel.muted ? 0.5 : 1
                onMoved: v => { if (channel.ready) channel.modelData.audio.volume = v / 100 }
            }
        }
    }

    // the ChatMix dial, Game against Chat, while a headset reports one
    Item {
        visible: Channels.chatmix >= 0 && Channels.sinks.length > 0
        width: parent.width
        implicitHeight: Theme.rowHeight

        Item {
            id: mixName
            width: Theme.fit(110)
            height: parent.height
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.fontBody
                text: Channels.sideIcon
                color: Theme.subtext
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontBody
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.fontBody + Theme.spaceM
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: "ChatMix"
                color: Theme.text
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontBody
            }
        }

        BalanceMeter {
            anchors.left: mixName.right
            anchors.leftMargin: Theme.spaceS
            anchors.right: mixSide.left
            anchors.rightMargin: Theme.spaceS
            anchors.verticalCenter: parent.verticalCenter
            balance: Channels.balance
        }
        Text {
            id: mixSide
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.fit(40)
            horizontalAlignment: Text.AlignRight
            text: Channels.sideText
            color: Theme.subtext
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontSmall
        }
    }

    // --- apps ----------------------------------------------------------------------

    FlyoutHeading {
        text: "APPS" + (Audio.playingApps.length > 0 ? "  " + Audio.playingApps.length : "")
    }

    Repeater {
        model: ScriptModel { values: Audio.playingApps }

        Item {
            id: app
            required property var modelData
            readonly property var nodes: modelData.nodes.filter(n => n.ready && !!n.audio)
            readonly property bool ready: nodes.length > 0
            readonly property bool muted: ready && nodes.every(n => n.audio.muted)
            // the loudest stream's level stands for the app
            readonly property int percent: ready ? Math.round(Math.max(...nodes.map(n => n.audio.volume)) * 100) : 0
            readonly property string icon: Audio.appIcon(modelData.nodes[0])
            width: parent ? parent.width : 0
            implicitHeight: Theme.rowHeight

            // the app's icon and name; a click mutes all its streams
            Item {
                id: appName
                width: Theme.fit(110)
                height: parent.height
                Image {
                    id: appImg
                    visible: app.icon !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.fontBody
                    height: width
                    sourceSize: Qt.size(width * 2, height * 2)
                    source: app.icon
                    opacity: app.muted ? 0.45 : 1
                }
                Text {
                    visible: app.icon === ""
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.fontBody
                    text: "󰓃"
                    color: Theme.subtext
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.fontBody
                }
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.fontBody + Theme.spaceM
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: app.muted ? app.modelData.name + " 󰖁" : app.modelData.name
                    color: app.muted ? Theme.subtext : nameMouse.containsMouse ? Theme.textStrong : Theme.text
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontBody
                }
                MouseArea {
                    id: nameMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var mute = !app.muted
                        app.nodes.forEach(n => n.audio.muted = mute)
                    }
                }
            }

            Slider {
                anchors.left: appName.right
                anchors.leftMargin: Theme.spaceS
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                value: app.percent
                opacity: app.muted ? 0.5 : 1
                onMoved: v => app.nodes.forEach(n => n.audio.volume = v / 100)
            }
        }
    }

    FlyoutRow {
        visible: Audio.playingApps.length === 0
        enabled: false
        label: "Nothing is playing"
    }

    FlyoutDivider {}

    FlyoutChipLine {
        chips: [{ icon: "󰒓", text: "Settings", act: "settings" }]
        onPicked: scope.openSettings("audio")
    }
}
