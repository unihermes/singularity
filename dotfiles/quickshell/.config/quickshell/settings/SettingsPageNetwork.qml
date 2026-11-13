// LINKS: the cable and Wi-Fi as rows (In use on the one carrying the
// traffic, Wi-Fi's power button on its row), the picked one's readings as
// chips under them (from `ip`, `iw` and sysfs, read while the page is
// open). Then one list of what's in range (joined and saved first), hidden
// networks, and every saved network with Auto-join and Forget as chips on
// its row; on Network.qml shared with the bar.

import Quickshell
import Quickshell.Io
import QtQuick
import "../services"
import "../flyouts"

SettingsPage {
    id: page

    sectioned: true

    title: "Network"

    // "" while browsing; the SSID whose passphrase row is open
    property string pendingSsid: ""
    // the Other network… form
    property bool hiddenOpen: false
    property bool hiddenSecured: true
    // past the strongest ten in Other networks
    property bool showAll: false
    readonly property int shortList: 10

    // the link whose readings show: the cable while it's up, else Wi-Fi
    property string link: Network.wired ? "wired" : "wifi"
    readonly property string linkDevice: link === "wired" ? Network.wiredDevice : Network.device
    onLinkChanged: {
        ipAddr = ""; gateway = ""; macAddr = ""; linkRate = ""
        details.restart()
    }

    // the picked link's readings, and Wi-Fi's signal and band
    property string ipAddr: ""
    property string gateway: ""
    property string macAddr: ""
    property string linkRate: ""
    property real linkDbm: 0
    property real linkFreq: 0

    readonly property bool online: Network.ssid !== ""
    readonly property bool listening: Network.device !== "" && Network.powered
    // the joined network's own entry in the scan, for its security and bars
    readonly property var joined: Network.networks.find(n => n.connected) || null
    // the joined network first, then the other saved ones
    readonly property var savedNear: Network.networks.filter(n => n.known)
        .sort((a, b) => (b.connected ? 1 : 0) - (a.connected ? 1 : 0))
    readonly property var others: Network.networks.filter(n => !n.known && !n.connected)

    function barsOf(dbm) { return dbm >= -60 ? 4 : dbm >= -67 ? 3 : dbm >= -75 ? 2 : 1 }
    function strengthWord(bars) { return ["", "Weak", "Fair", "Good", "Strong"][bars] }
    function securityWord(type) {
        return type === "open" ? "Open" : type === "8021x" ? "Enterprise" : "Secured"
    }
    function bandOf(mhz) {
        return mhz <= 0 ? "" : mhz < 3000 ? "2.4 GHz" : mhz < 5925 ? "5 GHz" : "6 GHz"
    }
    // iwd's last-joined time: the clock time today, the date before that
    function lastJoined(iso) {
        if (iso === "") return "Never"
        var d = new Date(iso)
        var now = new Date()
        return d.toDateString() === now.toDateString()
            ? "Today, " + Qt.formatTime(d, Theme.timeFormat)
            : Qt.formatDate(d, d.getFullYear() === now.getFullYear() ? "d MMM" : "d MMM yyyy")
    }

    // the Wi-Fi row's strength: the link's own signal once read, the scan's until then
    readonly property int joinedBars: linkDbm < 0 ? barsOf(linkDbm) : joined ? joined.bars : 0

    Component.onCompleted: {
        Network.refreshStatus()
        Network.refreshList()
        detailsProc.running = true
    }

    Connections {
        target: Network
        function onConnectFailed(ssid, reason) {
            page.say("Couldn't join " + ssid + (reason ? " — " + reason : ""), true)
        }
    }

    function connectTo(ssid, passphrase, hidden) {
        Network.connect(ssid, passphrase, hidden)
        page.say("Connecting to " + ssid + "…", false)
        pendingSsid = ""
    }

    // join a known or open network, else toggle its passphrase row
    function joinOrPrompt(net) {
        if (net.connected || Network.connecting === net.ssid) return
        if (net.known || net.security === "open") {
            connectTo(net.ssid, "", false)
            return
        }
        pendingSsid = pendingSsid === net.ssid ? "" : net.ssid
    }

    // --- links ----------------------------------------------------------

    FlyoutHeading { text: "LINKS"; keepAll: true }

    // A way onto the network: its icon, name, In use on the one carrying
    // the traffic, what it's doing, and (Wi-Fi) the radio's power button.
    // A click shows its readings in the chips under the rows.
    component LinkRow: Item {
        id: link
        property string kind: ""
        property string glyph: ""
        property string name: ""
        property string detail: ""
        property bool inUse: false
        property bool dim: false
        default property alias trailing: end.data
        readonly property bool picked: page.link === kind
        readonly property bool lit: picked || hover.hovered

        width: parent ? parent.width : 0
        implicitHeight: Math.max(Theme.fieldHeight, texts.implicitHeight + Theme.spaceM, end.height + Theme.spaceS)

        HoverHandler { id: hover }

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -Theme.spaceS
            anchors.rightMargin: -Theme.spaceS
            radius: Theme.radiusInner
            color: link.lit ? Theme.hoverFill : "transparent"
        }
        Rectangle {
            visible: link.picked
            x: -Theme.spaceS
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.indicatorWidth
            height: parent.height - Theme.spaceM
            radius: Theme.pill(width)
            color: Theme.accent
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: page.link = link.kind
        }

        Text {
            id: icon
            x: Theme.spaceS
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.iconCell
            horizontalAlignment: Text.AlignHCenter
            text: link.glyph
            color: link.dim ? Theme.muted : Theme.textStrong
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontIconSize
        }
        Column {
            id: texts
            anchors.left: icon.right
            anchors.leftMargin: Theme.spaceM
            anchors.right: end.left
            anchors.rightMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Row {
                width: parent.width
                spacing: Theme.spaceM
                Text {
                    id: nameText
                    width: Math.min(implicitWidth, parent.width - (use.visible ? use.width + parent.spacing : 0))
                    elide: Text.ElideRight
                    text: link.name
                    color: link.dim ? Theme.subtext : Theme.textStrong
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontBody
                }
                Rectangle {
                    id: use
                    visible: link.inUse
                    anchors.verticalCenter: nameText.verticalCenter
                    width: useText.implicitWidth + Theme.spaceM * 2
                    height: useText.implicitHeight + 2
                    radius: Theme.pill(height)
                    color: Theme.selectedFill
                    border.width: Theme.borderWidth
                    border.color: Theme.accent
                    Text {
                        id: useText
                        anchors.centerIn: parent
                        text: "In use"
                        color: Theme.textStrong
                        font.family: Theme.fontText
                        font.weight: Theme.weightBody
                        font.pixelSize: Theme.fontCaption
                    }
                }
            }
            Text {
                width: parent.width
                visible: text !== ""
                elide: Text.ElideRight
                text: link.detail
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontCaption
            }
        }
        Row {
            id: end
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spaceM
        }
    }

    // the cable, on a machine with a port: only its state, as networkd
    // configures it by itself and there is nothing here to switch
    LinkRow {
        visible: Network.wiredDevice !== ""
        kind: "wired"
        glyph: "󰛳"
        name: "Ethernet"
        dim: !Network.wired
        inUse: Network.wired
        detail: Network.wired ? "Connected  ·  " + Network.wiredDevice
            : Network.wiredState === "no-carrier" || Network.wiredState === "off" ? "Unplugged"
            : "No address yet"
    }

    // the joined network: its strength, name and kind, and the radio
    LinkRow {
        kind: "wifi"
        glyph: page.online && page.joinedBars > 0 ? Network.strengthGlyphs[page.joinedBars - 1]
            : page.listening ? "󰤮" : "󰤭"
        name: Network.device === "" ? "No wireless device"
            : !Network.powered ? "Wi-Fi is off"
            : page.online ? "Wi-Fi  ·  " + Network.ssid
            : "Wi-Fi, not connected"
        dim: !page.online
        inUse: page.online && !Network.wired
        detail: {
            if (Network.device === "") return "iwd has no station device"
            if (!Network.powered) return "Turn it on to see networks"
            if (!page.online) return "Pick a network below"
            var parts = [Network.wired ? "Standing by" : "Connected"]
            if (page.joined) parts.push(page.securityWord(page.joined.security))
            if (page.linkFreq > 0) parts.push(page.bandOf(page.linkFreq))
            if (page.joinedBars > 0) parts.push(page.strengthWord(page.joinedBars))
            return parts.join("  ·  ")
        }

        PowerButton {
            size: Theme.controlSize
            on: Network.powered
            enabled: Network.device !== ""
            onClicked: {
                // setPowered flips `powered` at once, so it reads the new state
                Network.setPowered(!Network.powered)
                page.say(Network.powered ? "Radio on" : "Radio off", false)
            }
        }
    }

    // the picked link's readings; a click copies one
    Flow {
        width: parent.width
        visible: page.ipAddr !== "" || page.macAddr !== ""
        spacing: Theme.spaceS

        StatChip { label: "Interface";  value: page.linkDevice; copyable: false }
        StatChip { label: "IP address"; value: page.ipAddr }
        StatChip { label: "Gateway";    value: page.gateway }
        StatChip { label: "MAC";        value: page.macAddr }
        StatChip { label: "Speed";      value: page.linkRate; copyable: false }
        StatChip {
            label: "Signal"
            value: page.link === "wifi" && page.linkDbm < 0
                ? Math.round(page.linkDbm) + " dBm  ·  " + page.strengthWord(page.barsOf(page.linkDbm)) : ""
            copyable: false
        }
        StatChip {
            label: "Band"
            value: page.link === "wifi" && page.linkFreq > 0 ? page.bandOf(page.linkFreq) : ""
            copyable: false
        }
    }

    // --- networks in range ----------------------------------------------

    Item { width: 1; height: Theme.spaceM }

    // the heading shares its line with Rescan
    Item {
        readonly property bool isSectionBreak: true
        readonly property bool sectioned: true
        width: parent.width
        height: Math.max(Theme.controlSize, nearHeading.implicitHeight)

        FlyoutHeading {
            id: nearHeading
            firstInColumn: false
            anchors.left: parent.left
            anchors.right: rescan.left
            anchors.rightMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            text: "IN RANGE  " + (page.savedNear.length + page.others.length)
        }

        FlyoutChip {
            id: rescan
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: nearHeading.lift
            text: Network.scanning ? "󰑐 Scanning…" : "Rescan"
            enabled: page.listening && !Network.scanning
            onClicked: {
                Network.scan()
                details.restart()
            }
        }
    }

    // A network in range, and the passphrase row it opens under itself.
    component NetworkRow: Column {
        id: netRow
        required property var modelData
        readonly property bool connecting: Network.connecting === modelData.ssid
        readonly property bool prompting: page.pendingSsid === modelData.ssid

        width: parent ? parent.width : 0

        FlyoutRow {
            label: netRow.modelData.ssid
            busy: netRow.connecting
            highlighted: netRow.prompting || netRow.modelData.connected
            trailing: netRow.connecting ? "connecting"
                : Network.failedSsid === netRow.modelData.ssid ? "failed" : ""
            tag: netRow.modelData.connected ? "Joined" : netRow.modelData.known ? "Saved" : ""
            iconsNote: page.strengthWord(Math.max(1, netRow.modelData.bars))
            trailingIcons: [
                !netRow.modelData.known && netRow.modelData.security !== "open" ? "󰌾" : "",
                Network.strengthGlyphs[Math.max(1, netRow.modelData.bars) - 1]
            ]
            onActivated: page.joinOrPrompt(netRow.modelData)
        }

        SettingsIndent {
            visible: netRow.prompting
            onVisibleChanged: if (visible) Qt.callLater(pass.forceFocus)

            Item {
                width: parent.width
                height: pass.implicitHeight

                FlyoutInput {
                    id: pass
                    anchors.left: parent.left
                    anchors.right: join.left
                    anchors.rightMargin: Theme.spaceM
                    glyph: "󰌾"
                    hints: ["Enter join"]
                    placeholder: "passphrase for " + netRow.modelData.ssid
                    onAccepted: page.connectTo(netRow.modelData.ssid, text, false)
                    onEscapePressed: page.pendingSsid = ""
                }
                FlyoutChip {
                    id: join
                    anchors.right: cancel.left
                    anchors.rightMargin: Theme.spaceS
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Connect"
                    selected: true
                    onClicked: page.connectTo(netRow.modelData.ssid, pass.text, false)
                }
                FlyoutChip {
                    id: cancel
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Cancel"
                    onClicked: page.pendingSsid = ""
                }
            }
        }
    }

    // One list, saved networks first, each strongest first. Matched by
    // SSID: each list refresh brings new objects, and rebuilding the rows
    // would drop a passphrase being typed into one
    Repeater {
        model: ScriptModel { values: page.listening ? page.savedNear : []; objectProp: "ssid" }
        NetworkRow {}
    }

    Repeater {
        model: ScriptModel {
            objectProp: "ssid"
            values: !page.listening ? []
                : page.showAll ? page.others
                : page.others.slice(0, page.shortList)
        }
        NetworkRow {}
    }

    FlyoutRow {
        visible: !page.listening || page.savedNear.length + page.others.length === 0
        enabled: false
        label: Network.device === "" ? "No wireless device"
            : !Network.powered ? "The radio is off"
            : Network.listError !== "" ? Network.listError
            : Network.scanning ? "Scanning…" : "Nothing in range"
    }

    FlyoutRow {
        visible: page.listening && page.others.length > page.shortList
        label: page.showAll ? "Show fewer" : "Show all " + page.others.length
        trailing: page.showAll ? "󰅀" : (page.others.length - page.shortList) + " more  󰅂"
        onActivated: page.showAll = !page.showAll
    }

    // a network that doesn't broadcast its name, so no scan finds it
    FlyoutRow {
        visible: page.listening
        label: "Other network…"
        highlighted: page.hiddenOpen
        trailing: "󰐕"
        onActivated: {
            page.hiddenOpen = !page.hiddenOpen
            if (page.hiddenOpen) Qt.callLater(hiddenName.forceFocus)
        }
    }

    SettingsIndent {
        visible: page.listening && page.hiddenOpen

        FlyoutInput {
            id: hiddenName
            placeholder: "network name (SSID)"
            echoPassword: false
            onAccepted: hiddenJoin.clicked()
            onEscapePressed: page.hiddenOpen = false
        }

        Item {
            width: parent.width
            height: Math.max(hiddenKind.implicitHeight, hiddenPass.implicitHeight)

            FlyoutSegmented {
                id: hiddenKind
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                fill: false
                model: [{ value: false, text: "Open" }, { value: true, text: "Passphrase" }]
                current: page.hiddenSecured
                onPicked: v => page.hiddenSecured = v
            }
            FlyoutInput {
                id: hiddenPass
                visible: page.hiddenSecured
                anchors.left: hiddenKind.right
                anchors.leftMargin: Theme.spaceM
                anchors.right: hiddenJoin.left
                anchors.rightMargin: Theme.spaceM
                anchors.verticalCenter: parent.verticalCenter
                placeholder: "passphrase"
                onAccepted: hiddenJoin.clicked()
                onEscapePressed: page.hiddenOpen = false
            }
            FlyoutChip {
                id: hiddenJoin
                anchors.right: hiddenCancel.left
                anchors.rightMargin: Theme.spaceS
                anchors.verticalCenter: parent.verticalCenter
                text: "Join"
                selected: enabled
                enabled: hiddenName.text.trim() !== ""
                onClicked: {
                    if (hiddenName.text.trim() === "") return
                    page.connectTo(hiddenName.text.trim(), page.hiddenSecured ? hiddenPass.text : "", true)
                    page.hiddenOpen = false
                    hiddenName.text = ""
                    hiddenPass.text = ""
                }
            }
            FlyoutChip {
                id: hiddenCancel
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Cancel"
                onClicked: page.hiddenOpen = false
            }
        }
    }

    // --- saved ----------------------------------------------------------

    Item { width: 1; height: Theme.spaceM }

    FlyoutHeading { text: "SAVED" + "  " + Network.knownNetworks.length }

    // each on one row: where it is and when it last joined, then Auto-join
    // (lit while on) and Forget (two clicks) as chips
    Repeater {
        model: Network.knownNetworks

        SettingsField {
            id: saved
            required property var modelData
            readonly property string where: Network.ssid === modelData.ssid ? "Joined"
                : Network.networks.some(n => n.ssid === modelData.ssid) ? "In range"
                : "Not nearby"

            label: modelData.ssid
            hint: [where, page.securityWord(modelData.security), modelData.hidden ? "Hidden" : "",
                   where === "Joined" ? "" : "last " + page.lastJoined(modelData.last)].filter(t => t).join("  ·  ")

            Row {
                anchors.right: parent.right
                spacing: Theme.spaceS

                FlyoutChip {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: saved.modelData.auto ? "󰄬" : ""
                    text: "Auto-join"
                    selected: saved.modelData.auto
                    onClicked: Network.setAutoConnect(saved.modelData.ssid, !saved.modelData.auto)
                }
                FlyoutChip {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Forget"
                    confirmText: "Forget it?"
                    onClicked: {
                        Network.forget(saved.modelData.ssid)
                        page.say("Forgot " + saved.modelData.ssid, false)
                    }
                }
            }
        }
    }

    FlyoutRow {
        visible: Network.knownNetworks.length === 0
        enabled: false
        label: "No saved networks"
    }

    // re-read a moment after a connect, once DHCP has given an address
    Timer {
        id: details
        interval: 1200
        onTriggered: if (!detailsProc.running) detailsProc.running = true
    }

    Connections {
        target: Network
        function onSsidChanged() { details.restart() }
        function onWiredStateChanged() { details.restart() }
    }

    // The picked link's device ($1) and the Wi-Fi device ($2) go in as
    // arguments rather than into the script text, so a name with anything
    // shell-significant in it can't run. A cable's speed is sysfs's.
    Process {
        id: detailsProc
        command: ["sh", "-c", `
            d=$1 w=$2
            if [ -n "$d" ]; then
                ip -4 -o addr show dev "$d" 2>/dev/null | awk '{print "ip=" $4; exit}'
                ip -4 -o route show default 2>/dev/null | awk -v d="$d" '$5 == d {print "gw=" $3; exit}'
                [ -r /sys/class/net/"$d"/address ] && echo "mac=$(cat /sys/class/net/"$d"/address)"
                [ "$d" != "$w" ] && s=$(cat /sys/class/net/"$d"/speed 2>/dev/null) && [ "$s" -gt 0 ] 2>/dev/null && echo "rate=$s"
            fi
            [ -n "$w" ] && iw dev "$w" link 2>/dev/null | awk -v same="$([ "$d" = "$w" ] && echo 1)" '
                /tx bitrate:/ { if (same) print "rate=" $3 }
                /signal:/     { print "signal=" $2 }
                /freq:/       { print "freq=" $2 }'
        `, "sh", page.linkDevice, Network.device]
        stdout: StdioCollector {
            onStreamFinished: {
                var got = { ip: "", gw: "", mac: "", rate: "", signal: "", freq: "" }
                text.split("\n").forEach(line => {
                    var at = line.indexOf("=")
                    if (at > 0) got[line.substring(0, at)] = line.substring(at + 1).trim()
                })
                page.ipAddr = got.ip
                page.gateway = got.gw
                page.macAddr = got.mac
                page.linkRate = got.rate === "" ? "" : Math.round(parseFloat(got.rate)) + " Mbit/s"
                page.linkDbm = parseFloat(got.signal) || 0
                page.linkFreq = parseFloat(got.freq) || 0
            }
        }
    }
}
