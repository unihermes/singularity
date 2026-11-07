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
    // compact packs the toggles into one grid of labelled discs; mini keeps
    // the discs alone in a single row
    readonly property bool compact: Theme.controlLayout !== "full"
    readonly property bool mini: Theme.controlLayout === "mini"
    // mini keeps the pages and tools behind its gear
    property bool more: false
    function toggleMore() { more = !more }
    readonly property var pageActs: [
        { icon: "󰏘", act: "", page: "appearance" },
        { icon: "󰕮", act: "", page: "widgets" },
    ]
    function footRun(a) {
        if (a.page) cc.page = a.page
        else cc.run(a.act)
    }

    width: parent.width
    spacing: compact ? Theme.spaceM : Theme.spaceL

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

    // a round toggle with its name under it (compact) or alone (mini);
    // a right click opens its details where it has any
    component Toggle: Item {
        id: tg
        property string icon: ""
        property string title: ""
        property bool lit: false
        property bool usable: true
        signal toggled()
        signal opened()
        height: dot.height + (root.mini ? 0 : name.implicitHeight + Theme.spaceXs)
        GlassDot {
            id: dot
            anchors.horizontalCenter: parent.horizontalCenter
            icon: tg.icon
            lit: tg.lit
            usable: tg.usable
            implicitWidth: Theme.fs(root.mini ? 36 : 38)
        }
        Text {
            id: name
            visible: !root.mini
            anchors.top: dot.bottom
            anchors.topMargin: Theme.spaceXs
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: tg.title
            elide: Text.ElideRight
            color: Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontCaption
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: tg.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: m => {
                if (!tg.usable) return
                if (m.button === Qt.RightButton) tg.opened()
                else tg.toggled()
            }
        }
    }

    // mini: the gear in the media chip (or alone with no player) shows the pages and tools
    component MoreButton: Item {
        implicitWidth: Theme.fs(26)
        implicitHeight: Theme.fs(26)
        width: implicitWidth
        height: implicitHeight
        GlassDot {
            anchors.fill: parent
            implicitWidth: Theme.fs(26)
            icon: "󰒓"
            lit: root.more
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleMore()
        }
    }

    // compact and mini: every toggle in one frosted card
    Rectangle {
        visible: root.compact
        width: parent.width
        height: grid.height + Theme.spaceL * 2
        radius: Theme.fs(16)
        color: Theme.washHover
        border.width: 1
        border.color: Theme.stroke

        Flow {
            id: grid
            x: Theme.spaceL
            y: Theme.spaceL
            width: parent.width - Theme.spaceL * 2
            spacing: Theme.spaceM
            // four to a line; mini runs them all along one
            readonly property int perLine: root.mini ? visibleChildren.length : 4
            readonly property real cellW: (width - spacing * (perLine - 1)) / Math.max(1, perLine)

            Toggle {
                width: grid.cellW
                icon: "󰤨"
                title: "Wi-Fi"
                lit: Network.powered
                onToggled: Network.setPowered(!Network.powered)
                onOpened: root.details("network")
            }
            Toggle {
                visible: !!root.adapter
                width: grid.cellW
                icon: "󰂯"
                title: "Bluetooth"
                lit: root.btOn
                onToggled: root.bar.setBtPowered(root.adapter, !root.btOn)
                onOpened: root.details("bluetooth")
            }
            Toggle {
                width: grid.cellW
                icon: "󰀝"
                title: "Airplane"
                lit: root.cc.airplane
                onToggled: root.cc.setAirplane(!root.cc.airplane)
            }
            Toggle {
                width: grid.cellW
                icon: Notifications.dnd ? "󰂛" : "󰂚"
                title: "Quiet"
                lit: Notifications.dnd
                onToggled: Notifications.toggleDnd()
            }
            Toggle {
                width: grid.cellW
                icon: root.cc.shellRoot.nightLight ? "󰖔" : "󰖙"
                title: "Night"
                lit: root.cc.shellRoot.nightLight
                usable: root.cc.shellRoot.hasHyprsunset
                onToggled: root.cc.shellRoot.nightLight = !root.cc.shellRoot.nightLight
            }
            Toggle {
                width: grid.cellW
                icon: root.cc.shellRoot.keepAwake ? "󰅶" : "󰾪"
                title: "Awake"
                lit: root.cc.shellRoot.keepAwake
                onToggled: root.cc.shellRoot.keepAwake = !root.cc.shellRoot.keepAwake
            }
            Toggle {
                width: grid.cellW
                icon: "󰊴"
                title: "Game"
                lit: GameMode.active
                onToggled: GameMode.toggle()
            }
            // steps the power profile; mini keeps it as a pill under its gear
            Toggle {
                visible: !root.mini && PpdProfile.profile !== ""
                width: grid.cellW
                icon: "󰓅"
                title: (PpdProfile.choices.find(c => c.value === PpdProfile.profile) || { text: "Power" }).text
                onToggled: PpdProfile.set(root.cc.nextOf(PpdProfile.choices.map(c => c.value), PpdProfile.profile))
            }
        }
    }

    // compact and mini: both levels in one card, no titles
    Rectangle {
        visible: root.compact
        width: parent.width
        height: (root.mini ? levelsRow.height : levels.height) + (root.mini ? Theme.spaceM : Theme.spaceL) * 2
        radius: Theme.fs(16)
        color: Theme.washHover
        border.width: 1
        border.color: Theme.stroke
        Row {
            id: levelsRow
            visible: root.mini
            x: Theme.spaceM
            y: Theme.spaceM
            width: parent.width - Theme.spaceM * 2
            spacing: Theme.spaceM
            GlassSlider {
                visible: Brightness.available
                width: Brightness.available ? (parent.width - parent.spacing) / 2 : 0
                icon: "󰃠"
                value: Brightness.level
                onMoved: v => Brightness.set(v)
            }
            GlassSlider {
                width: Brightness.available ? (parent.width - parent.spacing) / 2 : parent.width
                icon: Audio.muted ? "󰖁" : "󰕾"
                value: Audio.percent
                dimmed: Audio.muted
                onMoved: v => Audio.setVolume(v)
            }
        }
        Column {
            id: levels
            visible: !root.mini
            x: Theme.spaceL
            y: Theme.spaceL
            width: parent.width - Theme.spaceL * 2
            spacing: Theme.spaceM
            GlassSlider {
                visible: Brightness.available
                width: parent.width
                icon: "󰃠"
                value: Brightness.level
                onMoved: v => Brightness.set(v)
            }
            GlassSlider {
                width: parent.width
                icon: Audio.muted ? "󰖁" : "󰕾"
                value: Audio.percent
                dimmed: Audio.muted
                onMoved: v => Audio.setVolume(v)
            }
        }
    }

    Row {
        visible: !root.compact
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
        visible: !root.compact
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

    // full: tall Display and Sound capsules, the power profile beside them
    Rectangle {
        visible: !root.compact
        width: parent.width
        height: Theme.fs(120) + Theme.spaceL * 2 + Theme.fs(18)
        radius: Theme.fs(16)
        color: Theme.washHover
        border.width: 1
        border.color: Theme.stroke

        Row {
            x: Theme.spaceL
            y: Theme.spaceL
            spacing: Theme.spaceL
            Column {
                visible: Brightness.available
                spacing: Theme.spaceXs
                GlassVSlider {
                    icon: "󰃠"
                    value: Brightness.level
                    onMoved: v => Brightness.set(v)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Display"
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontCaption
                }
            }
            Column {
                spacing: Theme.spaceXs
                GlassVSlider {
                    icon: Audio.muted ? "󰖁" : "󰕾"
                    value: Audio.percent
                    dimmed: Audio.muted
                    onMoved: v => Audio.setVolume(v)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Sound"
                    color: Theme.subtext
                    font.family: Theme.fontText
                    font.pixelSize: Theme.fontCaption
                }
            }
            // the profiles, one lit
            Column {
                visible: PpdProfile.profile !== ""
                width: Math.max(Theme.fs(80), parent.parent.width - Theme.spaceL * 2 - x - Theme.spaceL)
                height: Theme.fs(120)
                spacing: Theme.spaceXs
                Repeater {
                    model: PpdProfile.choices
                    Rectangle {
                        required property var modelData
                        width: parent.width
                        height: (Theme.fs(120) - Theme.spaceXs * (PpdProfile.choices.length - 1)) / PpdProfile.choices.length
                        radius: height / 2
                        readonly property bool on: PpdProfile.profile === modelData.value
                        color: on ? (Theme.isLight ? "#2a2a2a" : "#f2f2f2") : Theme.isLight ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.12)
                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData.text
                            color: parent.on ? (Theme.isLight ? "#f2f2f2" : "#222222") : Theme.text
                            font.family: Theme.fontText
                            font.weight: Theme.weightStrong
                            font.pixelSize: Theme.fontCaption
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PpdProfile.set(parent.modelData.value)
                        }
                    }
                }
            }
        }
    }

    // what's playing
    Rectangle {
        visible: !!Media.player
        width: parent.width
        height: Theme.fs(root.mini ? 44 : root.compact ? 52 : 66)
        radius: Theme.fs(16)
        color: Theme.washHover
        border.width: 1
        border.color: Theme.stroke
        readonly property string art: (Media.artUrls(Media.player) || [])[0] || ""

        Rectangle {
            id: artBox
            x: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.fs(root.mini ? 30 : root.compact ? 38 : 48)
            height: width
            radius: Theme.fs(10)
            color: Theme.surface
            clip: true
            Image {
                anchors.fill: parent
                source: parent.parent.art
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: width * 2
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
                visible: !root.mini
                width: parent.width
                text: Media.artistOf(Media.player)
                elide: Text.ElideRight
                color: Theme.subtext
                font.family: Theme.fontText
                font.pixelSize: Theme.fontCaption
            }
        }
        MoreButton {
            visible: root.mini
            anchors.right: parent.right
            anchors.rightMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
        }
        Row {
            id: transport
            anchors.right: parent.right
            anchors.rightMargin: root.mini ? Theme.spaceL * 2 + Theme.fs(26) : Theme.spaceL
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
        visible: !root.compact || (root.mini && root.more)
        width: parent.width
        spacing: Theme.spaceM
        readonly property var shown: [
            { text: "Appearance", page: "appearance" },
            { text: "Widgets", page: "widgets" },
        ].concat(PpdProfile.profile === "" || (root.compact && !root.mini) || !root.compact ? [] : [{
            text: (PpdProfile.choices.find(c => c.value === PpdProfile.profile) || { text: "Power" }).text,
            page: "", profile: true }])
        readonly property real total: shown.reduce((a, p) => a + p.text.length + (p.profile ? 3 : 0) + 5, 0)
        Repeater {
            model: pages.shown
            Rectangle {
                required property var modelData
                // wide enough for its label: shares in proportion to the text
                readonly property real weight: modelData.text.length + (modelData.profile ? 3 : 0) + 5
                width: (pages.width - pages.spacing * (pages.shown.length - 1)) * weight / pages.total
                height: Theme.fs(32)
                radius: height / 2
                color: pillMouse.containsMouse ? Theme.washActive : Theme.washHover
                border.width: 1
                border.color: Theme.stroke
                Behavior on color { ColorAnimation { duration: Theme.durFast; easing.type: Theme.ease } }
                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spaceS
                    Text {
                        visible: parent.parent.modelData.profile === true
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰓅"
                        color: Theme.textStrong
                        font.family: Theme.fontIcon
                        font.pixelSize: Theme.fontIconSize
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        // inside the capsule whatever the label
                        width: Math.min(implicitWidth, parent.parent.width - Theme.spaceL * 2
                            - (parent.parent.modelData.profile ? Theme.fontIconSize + Theme.spaceS : 0))
                        elide: Text.ElideRight
                        text: parent.parent.modelData.text
                        color: Theme.textStrong
                        font.family: Theme.fontText
                        font.weight: Theme.weightStrong
                        font.pixelSize: Theme.fontCaption
                    }
                }
                MouseArea {
                    id: pillMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // the power pill steps to the next profile, as the tile did
                    onClicked: {
                        if (parent.modelData.profile)
                            PpdProfile.set(root.cc.nextOf(PpdProfile.choices.map(c => c.value), PpdProfile.profile))
                        else root.cc.page = parent.modelData.page
                    }
                }
            }
        }
    }

    // the tools, as round buttons spread along the foot
    Row {
        visible: !root.compact || (root.mini && root.more)
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

    Rectangle {
        visible: root.mini && !Media.player
        width: parent.width
        height: Theme.fs(44)
        radius: Theme.fs(16)
        color: Theme.washHover
        border.width: 1
        border.color: Theme.stroke
        Text {
            x: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            text: "More"
            color: Theme.subtext
            font.family: Theme.fontText
            font.pixelSize: Theme.fontBody
        }
        MoreButton {
            anchors.right: parent.right
            anchors.rightMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // compact: the tools and both pages as one row of round buttons
    Row {
        visible: root.compact && !root.mini
        width: parent.width
        readonly property var acts: root.cc.toolActions.concat(root.pageActs)
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
                    onClicked: root.footRun(parent.modelData)
                }
            }
        }
    }
}
