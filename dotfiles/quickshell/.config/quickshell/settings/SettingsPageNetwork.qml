// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageNetwork.qml
//
// Wi-Fi: the radio, what it's joined to, the networks in range, and every
// network iwd has saved.
//
// The state and the iwctl calls live in services/Network.qml, shared with the
// bar module, its flyout and the Control Centre's toggle -- so a connection
// made here shows up in all three without this page telling them.
//
// What this page has that the flyout doesn't: the radio switch, the link's
// own details, the full list rather than the ten strongest, hidden networks,
// and the saved networks gathered in one place, in range or not, to stop
// auto-joining or forget. The flyout stays the quick path; this is the one
// to open when something needs explaining.
//
// The details come from `ip` and `iw` rather than the service: nothing else
// wants them, and a page is built when it's opened and destroyed when it's
// left, so the read happens while someone is looking at it and stops when
// they leave.

import Quickshell.Io
import QtQuick
import "../services"
import "../flyouts"

SettingsPage {
    id: page

    sectioned: true

    title: "Network"
    description: "Wi-Fi through iwd, which keeps the passphrases."

    // "" while browsing; the SSID whose passphrase row is open
    property string pendingSsid: ""
    // the Other network… form
    property bool hiddenOpen: false
    property bool hiddenSecured: true
    // the saved network opened for its settings, or ""
    property string openSaved: ""
    // past the strongest ten in Other networks
    property bool showAll: false
    readonly property int shortList: 10

    // the link's own details, refreshed with the list
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
    // the card shows the joined network, so the lists leave it out
    readonly property var savedNear: Network.networks.filter(n => n.known && !n.connected)
    readonly property var others: Network.networks.filter(n => !n.known && !n.connected)

    readonly property var strengthGlyphs: ["󰤟", "󰤢", "󰤥", "󰤨"]
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
            ? "Today, " + Qt.formatTime(d, "hh:mm")
            : Qt.formatDate(d, d.getFullYear() === now.getFullYear() ? "d MMM" : "d MMM yyyy")
    }

    // the card's strength: the link's own signal once read, the scan's until then
    readonly property int joinedBars: linkDbm < 0 ? barsOf(linkDbm) : joined ? joined.bars : 0

    Component.onCompleted: {
        Network.refreshStatus()
        Network.refreshList()
        details.restart()
    }

    function connectTo(ssid, passphrase, hidden) {
        Network.connect(ssid, passphrase, hidden)
        page.say("Connecting to " + ssid + "…", false)
        pendingSsid = ""
    }

    // A network's own row action: join it, or open its passphrase row. A
    // known or open network needs neither -- iwd has the key already, or
    // there is none. Clicking the open row again closes it.
    function joinOrPrompt(net) {
        if (net.connected || Network.connecting === net.ssid) return
        if (net.known || net.security === "open") {
            connectTo(net.ssid, "", false)
            return
        }
        pendingSsid = pendingSsid === net.ssid ? "" : net.ssid
    }

    // --- status ---------------------------------------------------------

    FlyoutHeading { text: "STATUS" }

    // the joined network: its strength, name and kind, and the radio switch
    Item {
        width: parent.width
        implicitHeight: Math.max(Theme.fieldHeight, cardText.implicitHeight + Theme.spaceL * 2)

        Text {
            id: cardGlyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.fontTitle * 1.4
            horizontalAlignment: Text.AlignHCenter
            text: page.online && page.joinedBars > 0 ? page.strengthGlyphs[page.joinedBars - 1]
                : page.listening ? "󰤮" : "󰤭"
            color: page.online ? Theme.textStrong : Theme.muted
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontTitle
        }

        Column {
            id: cardText
            anchors.left: cardGlyph.right
            anchors.leftMargin: Theme.spaceL
            anchors.right: radio.left
            anchors.rightMargin: Theme.spaceL
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: Network.device === "" ? "No wireless device"
                    : !Network.powered ? "Wi-Fi is off"
                    : page.online ? Network.ssid
                    : "Not connected"
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightStrong
                font.pixelSize: Theme.fontTitle
            }

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: {
                    if (Network.device === "") return "iwd has no station device"
                    if (!Network.powered) return "Turn it on to see networks"
                    if (!page.online) return "Pick a network below"
                    var parts = []
                    if (page.joined) parts.push(page.securityWord(page.joined.security))
                    if (page.linkFreq > 0) parts.push(page.bandOf(page.linkFreq))
                    if (page.joinedBars > 0) parts.push(page.strengthWord(page.joinedBars))
                    return parts.join("  ·  ")
                }
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontSmall
            }
        }

        Switch {
            id: radio
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: Network.powered
            enabled: Network.device !== ""
            onToggled: {
                Network.setPowered(!Network.powered)
                page.say(Network.powered ? "Radio off" : "Radio on", false)
            }
        }

        // keeps the card apart from the readouts under it
        Rectangle {
            visible: page.online
            anchors.bottom: parent.bottom
            width: parent.width
            height: Theme.borderWidth
            color: Theme.stroke
        }
    }

    component Detail: SettingsValue { hideEmpty: true; copyable: true }

    Detail { label: "Interface"; value: page.online ? Network.device : ""; copyable: false }
    Detail { label: "IP address"; value: page.online ? page.ipAddr : "" }
    Detail { label: "Gateway";    value: page.online ? page.gateway : "" }
    Detail { label: "MAC";        value: page.online ? page.macAddr : "" }
    Detail { label: "Speed";      value: page.online ? page.linkRate : ""; copyable: false }

    SettingsField {
        label: "Signal"
        visible: page.online && page.linkDbm < 0

        Row {
            anchors.right: parent.right
            spacing: Theme.spaceM

            Text {
                text: page.strengthGlyphs[page.barsOf(page.linkDbm) - 1]
                color: Theme.textStrong
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontBody
            }
            Text {
                text: Math.round(page.linkDbm) + " dBm"
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontBody
            }
            Text {
                text: "·  " + page.strengthWord(page.barsOf(page.linkDbm))
                color: Theme.subtext
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontBody
            }
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
            text: "SAVED NEARBY"
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
            highlighted: netRow.prompting
            trailing: netRow.connecting ? "connecting" : ""
            trailingIcons: [
                !netRow.modelData.known && netRow.modelData.security !== "open" ? "󰌾" : "",
                page.strengthGlyphs[Math.max(1, netRow.modelData.bars) - 1]
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

            SettingsNote { text: "iwd keeps the passphrase once it joins" }
        }
    }

    Repeater {
        model: page.listening ? page.savedNear : []
        NetworkRow {}
    }

    FlyoutRow {
        visible: page.savedNear.length === 0 || !page.listening
        enabled: false
        label: Network.device === "" ? "No wireless device"
            : !Network.powered ? "The radio is off"
            : Network.listError !== "" ? Network.listError
            : "No saved networks in range"
    }

    Item { width: 1; height: Theme.spaceM; visible: page.listening }

    FlyoutHeading {
        visible: page.listening
        text: "OTHER NETWORKS  " + page.others.length
    }

    Repeater {
        model: !page.listening ? []
            : page.showAll ? page.others
            : page.others.slice(0, page.shortList)
        NetworkRow {}
    }

    FlyoutRow {
        visible: page.listening && page.others.length === 0
        enabled: false
        label: Network.scanning ? "Scanning…" : "Nothing else in range"
    }

    FlyoutRow {
        visible: page.listening && page.others.length > page.shortList
        label: page.showAll ? "Show fewer" : "Show all " + Network.networks.length
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

    Repeater {
        model: Network.knownNetworks

        Column {
            id: saved
            required property var modelData
            readonly property bool isOpen: page.openSaved === modelData.ssid
            readonly property string where: Network.ssid === modelData.ssid ? "Joined"
                : Network.networks.some(n => n.ssid === modelData.ssid) ? "In range"
                : "Not nearby"

            width: parent.width

            FlyoutRow {
                label: saved.modelData.ssid
                highlighted: saved.isOpen
                trailing: saved.where + "  " + (saved.isOpen ? "󰅀" : "󰅂")
                onActivated: page.openSaved = saved.isOpen ? "" : saved.modelData.ssid
            }

            SettingsIndent {
                visible: saved.isOpen

                SettingsField {
                    label: "Auto-join"
                    hint: "Joins by itself when in range"
                    Switch {
                        anchors.right: parent.right
                        checked: saved.modelData.auto
                        onToggled: Network.setAutoConnect(saved.modelData.ssid, !saved.modelData.auto)
                    }
                }
                SettingsValue {
                    label: "Security"
                    value: page.securityWord(saved.modelData.security) + (saved.modelData.hidden ? "  ·  Hidden" : "")
                }
                SettingsValue {
                    label: "Last joined"
                    value: saved.where === "Joined" ? "Joined now" : page.lastJoined(saved.modelData.last)
                }
                FlyoutChip {
                    text: "󰆴 Forget network"
                    confirmText: "Forget " + saved.modelData.ssid + "?"
                    onClicked: {
                        Network.forget(saved.modelData.ssid)
                        page.say("Forgot " + saved.modelData.ssid, false)
                        page.openSaved = ""
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

    // Read together with the list, and again a moment after a connect
    // settles: an address arrives from DHCP a little after iwd says it has
    // joined, so reading once on connect would show the old one.
    Timer {
        id: details
        interval: 1200
        onTriggered: if (!detailsProc.running) detailsProc.running = true
    }

    Connections {
        target: Network
        function onSsidChanged() { details.restart() }
    }

    // The device name goes in as an argument rather than into the script
    // text, so a name with anything shell-significant in it can't run.
    Process {
        id: detailsProc
        command: ["sh", "-c", `
            d=$1
            [ -n "$d" ] || exit 0
            ip -4 -o addr show dev "$d" 2>/dev/null | awk '{print "ip=" $4; exit}'
            ip -4 -o route show default 2>/dev/null | awk -v d="$d" '$5 == d {print "gw=" $3; exit}'
            [ -r /sys/class/net/"$d"/address ] && echo "mac=$(cat /sys/class/net/"$d"/address)"
            iw dev "$d" link 2>/dev/null | awk '
                /tx bitrate:/ { print "rate=" $3 }
                /signal:/     { print "signal=" $2 }
                /freq:/       { print "freq=" $2 }'
        `, "sh", Network.device]
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
