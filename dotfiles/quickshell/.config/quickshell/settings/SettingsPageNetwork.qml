// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageNetwork.qml
//
// Wi-Fi: the radio, what it's joined to, and every network in range.
//
// The state and the iwctl calls live in services/Network.qml, shared with the
// bar module, its flyout and the Control Centre's toggle -- so a connection
// made here shows up in all three without this page telling them.
//
// What this page has that the flyout doesn't: the radio switch, the link's
// own details, the full list rather than the ten strongest, and the saved
// networks gathered in one place to forget from. The flyout stays the quick
// path; this is the one to open when something needs explaining.
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

    title: "Network"
    description: "Wi-Fi through iwd. Passphrases are stored by iwd itself, not by the shell."

    // "" while browsing; an SSID while its passphrase is being typed
    property string pendingSsid: ""

    // the link's own details, refreshed with the list
    property string ipAddr: ""
    property string gateway: ""
    property string macAddr: ""
    property string linkRate: ""
    property string linkSignal: ""

    readonly property bool online: Network.ssid !== ""

    Component.onCompleted: {
        Network.refreshStatus()
        Network.refreshList()
        details.restart()
    }

    function connectTo(ssid, passphrase) {
        Network.connect(ssid, passphrase)
        page.say("Connecting to " + ssid + "…", false)
        pendingSsid = ""
        pass.text = ""
    }

    function cancelPrompt() {
        pendingSsid = ""
        pass.text = ""
    }

    // A network's own row action: join it, or ask for the passphrase first.
    // A known or open network needs neither -- iwd has the key already, or
    // there is none.
    function joinOrPrompt(net) {
        if (net.connected || Network.connecting === net.ssid) return
        if (net.known || net.security === "open") {
            connectTo(net.ssid, "")
            return
        }
        pendingSsid = net.ssid
        pass.text = ""
        pass.forceFocus()
    }

    // --- status ---------------------------------------------------------

    FlyoutHeading { text: "STATUS" }

    SettingsField {
        label: "Wi-Fi"
        hint: Network.device === "" ? "No wireless device found"
            : !Network.powered ? "The radio is off"
            : page.online ? "Joined to " + Network.ssid
            : "On, not joined to anything"

        FlyoutChip {
            anchors.right: parent.right
            text: Network.powered ? "On" : "Off"
            selected: Network.powered
            enabled: Network.device !== ""
            onClicked: {
                Network.setPowered(!Network.powered)
                page.say(Network.powered ? "Radio off" : "Radio on", false)
            }
        }
    }

    component Detail: SettingsField {
        id: detail
        property string value: ""
        visible: value !== ""
        // no verticalCenter anchor: the slot's height is its childrenRect,
        // so anchoring to it would bind the row's height to itself
        Text {
            anchors.right: parent.right
            text: detail.value
            color: Theme.textStrong
            font.family: Theme.fontText
            font.pixelSize: Theme.fontBody
        }
    }

    Detail { label: "Interface"; value: Network.device }
    Detail { label: "IP address"; value: page.ipAddr }
    Detail { label: "Gateway";    value: page.gateway }
    Detail { label: "MAC";        value: page.macAddr }
    Detail {
        label: "Link"
        value: page.linkRate === "" ? ""
            : page.linkSignal === "" ? page.linkRate
            : page.linkRate + "  ·  " + page.linkSignal
    }

    // --- passphrase -----------------------------------------------------

    Item { width: 1; height: Theme.spaceM; visible: page.pendingSsid !== "" }

    FlyoutHeading {
        visible: page.pendingSsid !== ""
        text: "PASSPHRASE FOR " + page.pendingSsid.toUpperCase()
    }

    FlyoutInput {
        id: pass
        visible: page.pendingSsid !== ""
        placeholder: "passphrase"
        onAccepted: page.connectTo(page.pendingSsid, text)
        onEscapePressed: page.cancelPrompt()
    }

    Row {
        visible: page.pendingSsid !== ""
        spacing: Theme.spaceS

        FlyoutChip {
            text: "Connect"
            onClicked: page.connectTo(page.pendingSsid, pass.text)
        }
        FlyoutChip {
            text: "Cancel"
            onClicked: page.cancelPrompt()
        }
    }

    // --- networks in range ----------------------------------------------

    Item { width: 1; height: Theme.spaceM }

    SettingsField {
        label: "Networks"
        hint: Network.listError !== "" ? Network.listError
            : Network.networks.length === 0 ? "Nothing in range yet"
            : Network.networks.length + " in range, strongest first"

        FlyoutChip {
            anchors.right: parent.right
            text: "Rescan"
            enabled: Network.device !== ""
            onClicked: {
                Network.scan()
                page.say("Scanning…", false)
                details.restart()
            }
        }
    }

    Repeater {
        model: Network.networks

        FlyoutRow {
            required property var modelData
            readonly property bool connecting: Network.connecting === modelData.ssid

            label: modelData.ssid
            busy: connecting
            highlighted: modelData.connected
            // The flyout has room for one or the other and shows the lock
            // instead of the bars. Here both fit, so a locked network still
            // says how strong it is -- which is half of why you'd open this
            // page rather than the flyout.
            trailing: {
                if (connecting) return "connecting"
                if (modelData.connected) return "󰄬"
                var bars = "•".repeat(Math.max(1, modelData.bars))
                var locked = !modelData.known && modelData.security !== "open"
                return locked ? "󰌾 " + bars : bars
            }
            actionIcon: modelData.known ? "󰆴" : ""
            actionHint: "Forget " + modelData.ssid + "?"
            onAction: {
                Network.forget(modelData.ssid)
                page.say("Forgot " + modelData.ssid, false)
            }
            onActivated: page.joinOrPrompt(modelData)
        }
    }

    Text {
        visible: Network.networks.length === 0
        text: Network.device === "" ? "No wireless device"
            : !Network.powered ? "The radio is off"
            : "None found"
        color: Theme.subtext
        font.family: Theme.fontText
        font.pixelSize: Theme.fontBody
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
                /tx bitrate:/ { print "rate=" $3 " " $4 }
                /signal:/     { print "signal=" $2 " " $3 }'
        `, "sh", Network.device]
        stdout: StdioCollector {
            onStreamFinished: {
                var got = { ip: "", gw: "", mac: "", rate: "", signal: "" }
                text.split("\n").forEach(line => {
                    var at = line.indexOf("=")
                    if (at > 0) got[line.substring(0, at)] = line.substring(at + 1).trim()
                })
                page.ipAddr = got.ip
                page.gateway = got.gw
                page.macAddr = got.mac
                page.linkRate = got.rate
                page.linkSignal = got.signal
            }
        }
    }
}
