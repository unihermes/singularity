// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageNetwork.qml
//
// The wired link, then Wi-Fi: the radio, the joined network with its link
// details in a grid (from `ip` and `iw`, read while the page is open), one
// list of what's in range (saved first), hidden networks, and every saved
// network with Auto-join and Forget on its row; on Network.qml shared with
// the bar.

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

    // the card's strength: the link's own signal once read, the scan's until then
    readonly property int joinedBars: linkDbm < 0 ? barsOf(linkDbm) : joined ? joined.bars : 0

    Component.onCompleted: {
        Network.refreshStatus()
        Network.refreshList()
        details.restart()
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

    // --- status ---------------------------------------------------------

    FlyoutHeading { text: "STATUS" }

    // the cable, on a machine with a port: only its state, as networkd
    // configures it by itself and there is nothing here to switch
    HeadCard {
        visible: Network.wiredDevice !== ""
        glyph: "󰛳"
        glyphColor: Network.wired ? Theme.textStrong : Theme.muted
        title: Network.wired ? "Ethernet connected"
            : Network.wiredState === "no-carrier" || Network.wiredState === "off" ? "Ethernet unplugged"
            : "Ethernet has no address yet"
        lines: [Network.wiredDevice]
        rule: true
    }

    // the joined network: its strength, name and kind, and the radio switch
    HeadCard {
        glyph: page.online && page.joinedBars > 0 ? Network.strengthGlyphs[page.joinedBars - 1]
            : page.listening ? "󰤮" : "󰤭"
        glyphColor: page.online ? Theme.textStrong : Theme.muted
        title: Network.device === "" ? "No wireless device"
            : !Network.powered ? "Wi-Fi is off"
            : page.online ? Network.ssid
            : "Not connected"
        lines: {
            if (Network.device === "") return ["iwd has no station device"]
            if (!Network.powered) return ["Turn it on to see networks"]
            if (!page.online) return ["Pick a network below"]
            var parts = []
            if (page.joined) parts.push(page.securityWord(page.joined.security))
            if (page.linkFreq > 0) parts.push(page.bandOf(page.linkFreq))
            if (page.joinedBars > 0) parts.push(page.strengthWord(page.joinedBars))
            return [parts.join("  ·  ")]
        }
        rule: page.online

        Switch {
            checked: Network.powered
            enabled: Network.device !== ""
            onToggled: {
                // setPowered flips `powered` at once, so it reads the new state
                Network.setPowered(!Network.powered)
                page.say(Network.powered ? "Radio on" : "Radio off", false)
            }
        }
    }

    // the link's details, two to a line
    component Detail: SettingsValue {
        width: (detailGrid.width - detailGrid.columnSpacing) / 2
        labelWidth: Theme.fit(120)
        hideEmpty: true
        copyable: true
    }

    Grid {
        id: detailGrid
        width: parent.width
        visible: page.online
        columns: 2
        columnSpacing: Theme.spaceXl * 2

        Detail { label: "Interface"; value: page.online ? Network.device : ""; copyable: false }
        Detail { label: "IP address"; value: page.online ? page.ipAddr : "" }
        Detail { label: "Gateway";    value: page.online ? page.gateway : "" }
        Detail { label: "MAC";        value: page.online ? page.macAddr : "" }
        Detail { label: "Speed";      value: page.online ? page.linkRate : ""; copyable: false }

        SettingsField {
            label: "Signal"
            width: (detailGrid.width - detailGrid.columnSpacing) / 2
            labelWidth: Theme.fit(120)
            visible: page.online && page.linkDbm < 0

            Row {
                anchors.right: parent.right
                spacing: Theme.spaceM

                Text {
                    text: Network.strengthGlyphs[page.barsOf(page.linkDbm) - 1]
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
            highlighted: netRow.prompting
            trailing: netRow.connecting ? "connecting"
                : Network.failedSsid === netRow.modelData.ssid ? "failed" : ""
            tag: netRow.modelData.known ? "Saved" : ""
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

    // each on one row: where it is and when it last joined, Auto-join, and
    // Forget on hover
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

            HoverHandler { id: savedHover }

            Row {
                anchors.right: parent.right
                spacing: Theme.spaceL

                IconButton {
                    id: forget
                    anchors.verticalCenter: parent.verticalCenter
                    visible: savedHover.hovered || armed
                    icon: "󰆴"
                    confirm: true
                    onClicked: {
                        Network.forget(saved.modelData.ssid)
                        page.say("Forgot " + saved.modelData.ssid, false)
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: forget.armed ? "Click again to forget" : "Auto-join"
                    color: forget.armed ? Theme.alert : Theme.subtext
                    font.family: Theme.fontText
                    font.weight: Theme.weightBody
                    font.pixelSize: Theme.fontSmall
                }
                Switch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: saved.modelData.auto
                    onToggled: Network.setAutoConnect(saved.modelData.ssid, !saved.modelData.auto)
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
