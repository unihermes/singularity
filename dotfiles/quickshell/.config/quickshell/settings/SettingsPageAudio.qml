// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageAudio.qml
//
// Output and input: the default device as a card with its level, the
// others under it (a click makes one the default; outputs with nothing
// plugged in are left out). CHANNELS: Game, Chat and Media's levels, each
// with the apps playing on it under it, and the ChatMix dial; EQUALIZER:
// each one's bands, a slider a band. Then the apps playing straight on an
// output. An app is one row however many streams it plays: its level and
// the channel or output it plays on. Mute is the button before each level. Straight on Pipewire, as the bar is;
// wireplumber remembers everything. Audio's pactl finds unplugged outputs
// and moves streams; an app's row drags onto a channel to move it there.

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import "../services"
import "../flyouts"

SettingsPage {
    id: page

    sectioned: true

    title: "Audio"
    description: "Where sound goes, how loud, and each app's share."

    // ScriptModels, so a node coming or going doesn't rebuild every row
    readonly property var devices: Audio.devices
    readonly property var sinks: Audio.sinks
    readonly property var sources: Audio.sources
    readonly property var streams: Audio.streams
    readonly property var playingApps: Audio.playingApps
    readonly property var recordingApps: Audio.recordingApps

    // tracked, or volume/mute stay invalid
    PwObjectTracker {
        objects: page.devices.concat(page.streams, Channels.sinks)
    }

    // what an app is playing, as the row's hint; a path cut to its last segment
    function streamDetail(n) {
        if (!n) return ""
        var p = n.properties || {}
        var media = p["media.name"] || ""
        if (media === Audio.appName(n)) return ""
        var tail = media.substring(media.lastIndexOf("/") + 1)
        return tail !== "" ? tail : media
    }

    Binding { target: Audio; property: "pageWatching"; value: true }

    function moveTo(streams, sink) {
        if (Audio.moveApp(streams, sink))
            page.say(Audio.appName(streams[0]) + " plays on "
                + (Audio.isChannel(sink) ? Audio.nodeName(sink) : Audio.plainName(sink)), false)
    }

    // --- names -----------------------------------------------------------------

    function where(n) {
        var m = Audio.shortName(n).match(/DisplayPort (\d+)[^\[]*\[/)
        if (m) return "DisplayPort " + m[1]
        var bus = (n && n.properties) ? n.properties["device.bus"] || "" : ""
        return bus === "bluetooth" ? "Bluetooth" : bus === "usb" ? "USB" : bus === "pci" ? "Built in" : ""
    }
    function levelText(n) {
        if (!n || !n.ready || !n.audio) return "--"
        return n.audio.muted ? "Muted" : Math.round(n.audio.volume * 100) + "%"
    }
    function groupLevelText(nodes) {
        var ready = nodes.filter(n => n && n.ready && n.audio)
        if (ready.length === 0) return "--"
        if (ready.every(n => n.audio.muted)) return "Muted"
        return Math.round(Math.max(...ready.map(n => n.audio.volume)) * 100) + "%"
    }

    // --- shared rows -------------------------------------------------------------

    // The level of a node, or of an app's streams together (the loudest
    // stands for them): a mute button, the slider (grey while muted) and
    // its readout.
    component LevelControl: Row {
        id: lvl
        property var node: null
        property var nodes: node ? [node] : []
        property int sliderWidth: Theme.fit(220)
        readonly property var live: nodes.filter(n => n && n.ready && n.audio)
        readonly property bool ready: live.length > 0
        readonly property bool muted: ready && live.every(n => n.audio.muted)

        spacing: Theme.sp(10)

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            enabled: lvl.ready
            icon: lvl.muted ? "󰝟" : "󰕾"
            warn: lvl.muted
            onClicked: {
                var mute = !lvl.muted
                lvl.live.forEach(n => n.audio.muted = mute)
            }
        }
        Slider {
            width: lvl.sliderWidth
            anchors.verticalCenter: parent.verticalCenter
            value: lvl.ready ? Math.max(...lvl.live.map(n => n.audio.volume)) * 100 : 0
            fillColor: lvl.muted ? Theme.muted : Theme.meterFill
            onMoved: v => lvl.live.forEach(n => n.audio.volume = v / 100)
        }
        Text {
            width: Theme.fs(52)
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: page.groupLevelText(lvl.nodes)
            color: lvl.muted ? Theme.subtext : Theme.textStrong
            font.family: Theme.fontText
            font.weight: Theme.weightBody
            font.pixelSize: Theme.fontBody
        }
    }

    component Level: SettingsField {
        property alias node: control.node
        label: "Volume"
        LevelControl { id: control; anchors.right: parent.right }
    }

    // The default device: its icon and name large, where it is.
    component DefaultCard: HeadCard {
        property var node: null
        glyph: node ? Audio.glyph(node) : ""
        title: node ? Audio.plainName(node) : ""
        lines: [[page.where(node), "Default"].filter(t => t).join("  ·  ")]
        rule: true
    }

    // A device: its icon, plain name and where it is, its level, and the
    // Default tag; a click makes it the default.
    component DeviceRow: FlyoutRow {
        required property var modelData
        property var current: null
        signal chosen(var node)
        readonly property bool isDefault: modelData === current

        leadingIcon: Audio.glyph(modelData)
        label: Audio.plainName(modelData)
        note: Audio.unplugged.indexOf(modelData.id) >= 0 ? "nothing plugged in" : page.where(modelData)
        badge: isDefault ? "Default" : ""
        highlighted: isDefault
        trailing: page.levelText(modelData)
        onActivated: if (!isDefault) chosen(modelData)
    }

    // --- output ------------------------------------------------------------------

    // the others: the default is the card, and outputs with nothing
    // plugged in are left out
    readonly property var sinksShown: sinks.filter(n => n !== Pipewire.defaultAudioSink
        && Audio.unplugged.indexOf(n.id) < 0)
    // where an app can play: the channels, then the outputs plugged in
    readonly property var playTargets: Channels.sinks.concat(sinks.filter(n => Audio.unplugged.indexOf(n.id) < 0))

    FlyoutHeading { text: "OUTPUT" }

    DefaultCard { visible: !!Pipewire.defaultAudioSink; node: Pipewire.defaultAudioSink }
    Level { visible: !!Pipewire.defaultAudioSink; node: Pipewire.defaultAudioSink }

    Repeater {
        model: ScriptModel { values: page.sinksShown }
        DeviceRow {
            current: Pipewire.defaultAudioSink
            onChosen: node => {
                Pipewire.preferredDefaultAudioSink = node
                page.say("Output: " + Audio.plainName(node), false)
            }
        }
    }

    FlyoutRow {
        visible: page.sinks.length === 0
        enabled: false
        label: "No outputs found"
    }


    // --- input -------------------------------------------------------------------

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "INPUT" }

    DefaultCard { visible: !!Pipewire.defaultAudioSource; node: Pipewire.defaultAudioSource }
    Level { visible: !!Pipewire.defaultAudioSource; node: Pipewire.defaultAudioSource }

    Repeater {
        model: ScriptModel { values: page.sources.filter(n => n !== Pipewire.defaultAudioSource) }
        DeviceRow {
            current: Pipewire.defaultAudioSource
            onChosen: node => {
                Pipewire.preferredDefaultAudioSource = node
                page.say("Input: " + Audio.plainName(node), false)
            }
        }
    }

    FlyoutRow {
        visible: page.sources.length === 0
        enabled: false
        label: "No inputs found"
    }


    // --- channels ------------------------------------------------------------------

    Item { width: 1; height: Theme.spaceM; visible: Channels.sinks.length > 0 }
    FlyoutHeading { text: "CHANNELS"; visible: Channels.sinks.length > 0 }

    // each channel's level, then the apps playing on it under it
    Repeater {
        model: ScriptModel { values: Channels.sinks }
        Item {
            id: channel
            required property var modelData
            width: parent ? parent.width : 0
            implicitHeight: channelColumn.implicitHeight

            Column {
                id: channelColumn
                width: parent.width
                Level {
                    node: channel.modelData
                    label: Audio.nodeName(channel.modelData)
                    hint: Channels.key(channel.modelData) === "game" ? "Where games play"
                        : Channels.key(channel.modelData) === "media" ? "Where other apps play unless moved" : ""
                }
                Repeater {
                    model: ScriptModel { values: Audio.appsOn(channel.modelData) }
                    AppRow { indent: Theme.iconCell + Theme.spaceM }
                }
            }

            // an app dragged here from another channel plays here from now on
            ChannelDrop {
                anchors.fill: parent
                onAppDropped: nodes => page.moveTo(nodes, channel.modelData)
            }
        }
    }

    // the dial: Game on the left, Chat on the right
    SettingsField {
        visible: Channels.chatmix >= 0
        label: "ChatMix"
        hint: Channels.mixText
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.sp(10)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰊴"
                color: Channels.side === "game" ? Theme.textStrong : Theme.subtext
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontIconSize
            }
            BalanceMeter {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.fit(220)
                balance: Channels.balance
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰭹"
                color: Channels.side === "chat" ? Theme.textStrong : Theme.subtext
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontIconSize
            }
            Text {
                width: Theme.fs(52)
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: Channels.sideText
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontBody
            }
        }
    }

    // --- equalizer ---------------------------------------------------------------

    // A band's gain, -12..+12 dB with a tick at 0, applied while dragging.
    component EqBand: SettingsField {
        id: band
        property string channel: ""
        property var spec: null
        readonly property real range: Channels.eqRange
        readonly property real gain: Channels.eqGain(channel, spec)

        label: spec.label
        hint: spec.hint

        Row {
            anchors.right: parent.right
            spacing: Theme.sp(10)

            Item {
                width: Theme.fit(220)
                height: slider.height
                anchors.verticalCenter: parent.verticalCenter

                Slider {
                    id: slider
                    width: parent.width
                    value: (band.gain + band.range) / (band.range * 2) * 100
                    onMoved: v => {
                        var g = Math.round((v / 100 * band.range * 2 - band.range) * 2) / 2
                        if (g !== band.gain) Channels.setEq(band.channel, band.spec.band, g)
                    }
                }
                Rectangle {
                    x: parent.width / 2
                    width: Theme.borderWidth
                    height: parent.height
                    color: Theme.subtext
                    opacity: 0.7
                }
            }
            Text {
                width: Theme.fs(64)
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: (band.gain > 0 ? "+" : "") + band.gain.toFixed(1) + " dB"
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontBody
            }
        }
    }

    Item { width: 1; height: Theme.spaceM; visible: Channels.sinks.length > 0 }
    FlyoutHeading { text: "EQUALIZER"; visible: Channels.sinks.length > 0 }

    // a channel's bands under its name, Reset on the name's line once moved
    Repeater {
        model: ScriptModel { values: Channels.sinks.map(n => Channels.key(n)).filter(k => Channels.eq[k]) }

        Column {
            id: eqGroup
            required property string modelData
            readonly property bool isSectionGroup: true
            readonly property bool sectioned: true
            width: parent.width
            spacing: Theme.spaceM

            Item {
                width: parent.width
                height: Math.max(sub.implicitHeight, reset.height)

                SettingsSubhead {
                    id: sub
                    anchors.verticalCenter: parent.verticalCenter
                    caption: eqGroup.modelData
                }
                IconButton {
                    id: reset
                    visible: Channels.eqMoved(eqGroup.modelData)
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "󰑓"
                    onClicked: {
                        Channels.resetEq(eqGroup.modelData)
                        page.say(Audio.nodeName(Channels.sinks.find(n => Channels.key(n) === eqGroup.modelData))
                            + " EQ back to its defaults", false)
                    }
                }
            }

            Repeater {
                model: Channels.eq[eqGroup.modelData]
                EqBand {
                    required property var modelData
                    channel: eqGroup.modelData
                    spec: modelData
                }
            }
        }
    }

    // --- per-application mixer -------------------------------------------
    // rows come and go with the streams

    // an app, all its streams as one: icon, name over what's playing; on
    // the right the channel or output it plays on, then its level
    component AppRow: Item {
        id: app
        required property var modelData
        property bool playback: true
        // under its channel's level, set in to show it belongs there
        property int indent: 0
        readonly property var nodes: modelData.nodes
        readonly property var n: nodes[0]
        readonly property var target: Audio.playsOn[n.id] || null
        readonly property var sink: target ? page.playTargets.find(s => s.id === target.sink) || null : null
        readonly property string icon: Audio.appIcon(n)

        width: parent ? parent.width : 0
        implicitHeight: Math.max(Theme.fieldHeight, texts.implicitHeight + Theme.spaceM, right.height + Theme.spaceS)

        // dragged onto another channel, it moves there
        AppDrag {
            visible: app.playback
            anchors.fill: texts
            anchors.leftMargin: -(appImage.width + Theme.spaceM)
            nodes: app.nodes
            name: Audio.appName(app.n)
            icon: app.icon
        }

        Image {
            id: appImage
            x: app.indent
            visible: app.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.iconCell
            height: width
            sourceSize: Qt.size(width * 2, height * 2)
            source: app.icon
        }
        Text {
            visible: app.icon === ""
            anchors.centerIn: appImage
            text: app.playback ? "󰓃" : "󰍬"
            color: Theme.text
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontIconSize
        }

        Column {
            id: texts
            anchors.left: appImage.right
            anchors.leftMargin: Theme.spaceM
            anchors.right: right.left
            anchors.rightMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: Audio.appName(app.n)
                elide: Text.ElideRight
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontBody
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: app.nodes.length > 1 ? app.nodes.length + " streams" : page.streamDetail(app.n)
                elide: Text.ElideRight
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontCaption
            }
        }

        Row {
            id: right
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceL

            SettingsDropdown {
                visible: app.playback
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.fit(150)
                model: page.playTargets
                current: app.sink
                enabled: app.target !== null
                placeholder: "…"
                labelFor: s => Audio.isChannel(s) ? Audio.nodeName(s)
                    : Audio.plainName(s) + (s === Pipewire.defaultAudioSink ? "  default" : "")
                onPicked: s => { if (s !== app.sink) page.moveTo(app.nodes, s) }
            }
            LevelControl {
                anchors.verticalCenter: parent.verticalCenter
                nodes: app.nodes
                sliderWidth: Theme.fit(150)
            }
        }
    }

    Item { width: 1; height: Theme.spaceM; visible: Audio.appsElsewhere.length > 0 || Channels.sinks.length === 0 }
    // the apps on no channel: straight on an output, or all of them
    // without the channels
    FlyoutHeading {
        visible: Audio.appsElsewhere.length > 0 || Channels.sinks.length === 0
        text: "PLAYING" + (Audio.appsElsewhere.length > 0 ? "  " + Audio.appsElsewhere.length : "")
    }

    Repeater {
        model: ScriptModel { values: Audio.appsElsewhere }
        AppRow {}
    }

    FlyoutRow {
        visible: Channels.sinks.length === 0 && page.playingApps.length === 0
        enabled: false
        label: "Nothing is playing"
    }

    Item { width: 1; height: Theme.spaceM; visible: page.recordingApps.length > 0 }
    FlyoutHeading {
        text: "RECORDING" + "  " + page.recordingApps.length
        visible: page.recordingApps.length > 0
    }

    Repeater {
        model: ScriptModel { values: page.recordingApps }
        AppRow { playback: false }
    }
}
