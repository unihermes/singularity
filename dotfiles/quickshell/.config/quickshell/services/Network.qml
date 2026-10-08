// Singularity - Quickshell
// ~/.config/quickshell/services/Network.qml
//
// Wi-Fi through iwd, for the bar's network module, its flyout and the
// Control Centre's Wi-Fi toggle. Quickshell.Networking's only backend is
// NetworkManager, so this shells out to iwctl and busctl instead.
//
// A singleton, like Weather and Updates. This used to live on the bar in
// shell.qml, which is instantiated once per screen, so every poll ran once
// per connected monitor and each screen kept its own copy of the state.
//
// iwctl draws tables for humans: ANSI colour, a banner, and fixed-width
// columns. The device and status reads strip the escapes and pick fields out
// of that; the network list, where SSIDs with spaces make field splitting
// unsafe, reads iwd over D-Bus instead (see listProc).

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property string device: ""
    property string ssid: ""
    // iwd's Powered flag for the radio. Read from `device list`, not
    // `station show`: a powered-off device has no station at all
    // ("No station on device"), but still appears in the list.
    property bool powered: true
    // [{ connected, ssid, security, dbm, bars, known }], strongest first
    property var networks: []
    // every network iwd keeps a passphrase or profile for, in range or not:
    // [{ ssid, security, hidden, auto, last, path }], last joined first
    property var knownNetworks: []
    // why the list couldn't be read, or ""
    property string listError: ""
    // the SSID an iwctl connect is running for, or ""
    property string connecting: ""
    // the SSID the last connect failed for, or "" (cleared by the next one)
    property string failedSsid: ""
    // after a connect fails, with iwctl's reason ("Operation failed", ...)
    signal connectFailed(string ssid, string reason)
    readonly property bool scanning: scanProc.running

    // a network's strength by bars (1..4), as the flyout and Settings draw it
    readonly property var strengthGlyphs: ["󰤟", "󰤢", "󰤥", "󰤨"]

    function setPowered(on) {
        if (device === "") return
        powered = on    // optimistic; powerProc settles it
        if (!on) ssid = ""
        queue(powerSet, ["iwctl", "device", device, "set-property", "Powered", on ? "on" : "off"])
    }

    // Only when asked (the Rescan rows in the flyout and on the Settings
    // page), never on a timer or when the flyout opens.
    function scan() { if (device !== "" && !scanProc.running) scanProc.running = true }

    // --passphrase rather than iwd's interactive prompt, which needs a tty.
    // It does put the passphrase in this process's argv for the lifetime of
    // the call, where anything running as this user could read it out of ps.
    //
    // One connect at a time: a Process already running ignores a new
    // command, so a second click during the first would have been dropped.
    // The latest request waits and runs when the current one exits.
    property var pendingConnect: null

    // `hidden` for a network that doesn't broadcast its name, which iwd
    // won't find in a scan and has to be told to probe for.
    function connect(name, passphrase, hidden) {
        if (device === "") return
        var cmd = ["iwctl"]
        if (passphrase) cmd.push("--passphrase", passphrase)
        cmd.push("station", device, hidden ? "connect-hidden" : "connect", name)
        failedSsid = ""
        if (connectProc.running) { pendingConnect = { cmd: cmd, ssid: name }; return }
        connecting = name
        connectProc.command = cmd
        connectProc.running = true
    }

    // Drops the saved passphrase, so iwd stops auto-joining it. Forgetting
    // the network you're on disconnects it too.
    function forget(name) {
        queue(forgetProc, ["iwctl", "known-networks", name, "forget"])
    }

    // Whether iwd joins a saved network by itself when it's in range. A
    // property on its KnownNetwork object, which iwctl has no command for.
    function setAutoConnect(name, on) {
        var k = knownNetworks.find(n => n.ssid === name)
        if (!k) return
        queue(autoProc, ["busctl", "set-property", "net.connman.iwd", k.path,
            "net.connman.iwd.KnownNetwork", "AutoConnect", "b", on ? "true" : "false"])
    }

    // One command at a time per process, in order: a Process that is still
    // running ignores a new command, so a second click (the radio toggled
    // twice, two networks forgotten in a row) was dropped.
    function queue(proc, cmd) {
        proc.pending.push(cmd)
        next(proc)
    }
    function next(proc) {
        if (proc.running || proc.pending.length === 0) return
        proc.command = proc.pending.shift()
        proc.running = true
    }

    function refreshStatus() {
        if (device === "") return
        if (!statusProc.running) statusProc.running = true
        if (!powerProc.running) powerProc.running = true
    }

    function refreshList() { if (device !== "" && !listProc.running) listProc.running = true }

    Process {
        id: deviceProc
        command: ["sh", "-c",
            "iwctl device list 2>/dev/null | sed 's/\\x1b\\[[0-9;]*m//g' "
            + "| awk 'NR>4 && $5==\"station\" {print $1; exit}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.device = text.trim()
                root.refreshStatus()
                // what iwd already knows, so the list isn't empty until the
                // first click (a reload resets this singleton too)
                root.refreshList()
            }
        }
    }

    Process {
        id: statusProc
        command: ["sh", "-c",
            "iwctl station " + root.device + " show 2>/dev/null "
            + "| sed 's/\\x1b\\[[0-9;]*m//g' "
            + "| awk -F'  +' '/Connected network/ {print $3}'"]
        stdout: StdioCollector {
            onStreamFinished: root.ssid = text.trim()
        }
    }

    Process {
        id: scanProc
        command: ["sh", "-c", "iwctl station " + root.device + " scan 2>/dev/null; sleep 2"]
        onExited: {
            root.refreshStatus()
            root.refreshList()
        }
    }

    // The network list comes from iwd's D-Bus API rather than
    // `iwctl station get-networks`: that table had to be cut up by fixed
    // column offsets, which any iwd release that reflowed its columns would
    // break silently, and its signal column marks the empty bars with colour
    // alone -- stripping the escapes left every network at full signal.
    // busctl hands back JSON.
    //
    // Two calls, since the second needs a path out of the first: every iwd
    // object (names, security, connected, known), then the station's
    // networks in iwd's own order with signal strength. A failure at either
    // step lands in listError for the flyout to show, instead of an empty
    // list that looks like there's simply nothing in range.
    property var objects: ({})

    function listFailed(why) {
        console.warn("network list: " + why)
        listError = "Couldn't read networks from iwd"
        networks = []
    }

    Process {
        id: listProc
        command: ["busctl", "--json=short", "call", "net.connman.iwd", "/",
            "org.freedesktop.DBus.ObjectManager", "GetManagedObjects"]
        stdout: StdioCollector {
            onStreamFinished: {
                var objs
                try { objs = JSON.parse(text).data[0] }
                catch (e) { root.listFailed("GetManagedObjects gave no JSON"); return }
                var station = ""
                var known = []
                for (var path in objs) {
                    var kn = objs[path]["net.connman.iwd.KnownNetwork"]
                    if (kn && kn.Name) known.push({
                        ssid: kn.Name.data,
                        security: kn.Type ? kn.Type.data : "",
                        hidden: !!(kn.Hidden && kn.Hidden.data),
                        auto: !kn.AutoConnect || kn.AutoConnect.data,
                        // ISO 8601, so it sorts as a string; absent if never joined
                        last: kn.LastConnectedTime ? kn.LastConnectedTime.data : "",
                        path: path
                    })
                    var dev = objs[path]["net.connman.iwd.Device"]
                    if (dev && dev.Name.data === root.device && objs[path]["net.connman.iwd.Station"]) station = path
                }
                known.sort((a, b) => a.last < b.last ? 1 : a.last > b.last ? -1 : 0)
                root.knownNetworks = known
                if (station === "") { root.listFailed("no station object for " + root.device); return }
                root.objects = objs
                orderProc.command = ["busctl", "--json=short", "call", "net.connman.iwd", station,
                    "net.connman.iwd.Station", "GetOrderedNetworks"]
                orderProc.running = true
            }
        }
    }

    Process {
        id: orderProc
        stdout: StdioCollector {
            onStreamFinished: {
                var ordered
                try { ordered = JSON.parse(text).data[0] }
                catch (e) { root.listFailed("GetOrderedNetworks gave no JSON"); return }
                var out = []
                for (var i = 0; i < ordered.length; i++) {
                    var obj = root.objects[ordered[i][0]]
                    var net = obj && obj["net.connman.iwd.Network"]
                    if (!net || !net.Name) continue
                    // signal is in hundredths of a dBm; these are the
                    // cut-offs iwctl's own bars use
                    var dbm = ordered[i][1] / 100
                    out.push({
                        connected: !!(net.Connected && net.Connected.data),
                        ssid: net.Name.data,
                        security: net.Type ? net.Type.data : "",
                        dbm: dbm,
                        bars: dbm >= -60 ? 4 : dbm >= -67 ? 3 : dbm >= -75 ? 2 : 1,
                        known: !!net.KnownNetwork
                    })
                }
                root.listError = ""
                root.networks = out
            }
        }
    }

    Process {
        id: powerProc
        command: ["sh", "-c",
            "iwctl device list 2>/dev/null | sed 's/\\x1b\\[[0-9;]*m//g' "
            + "| awk 'NR>4 && $1==\"" + root.device + "\" {print $3; exit}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var v = text.trim()
                if (v !== "") root.powered = (v === "on")
            }
        }
    }

    // Powering the radio back on doesn't hand back an SSID at once: iwd
    // reconnects to a known network about a second later. The iwd watch
    // below catches that reconnect when it lands.
    Process {
        id: powerSet
        property var pending: []
        command: ["true"]
        onExited: {
            if (!powerProc.running) powerProc.running = true
            root.next(powerSet)
        }
    }

    Process {
        id: connectProc
        command: ["true"]
        stdout: StdioCollector { id: connectOut }
        stderr: StdioCollector { id: connectErr }
        onExited: code => {
            // a failure superseded by a newer request isn't worth reporting
            if (code !== 0 && !root.pendingConnect) {
                var reason = (connectErr.text + connectOut.text)
                    .replace(/\x1b\[[0-9;]*m/g, "").trim().split("\n").pop()
                root.failedSsid = root.connecting
                root.connectFailed(root.connecting, reason)
            }
            if (root.pendingConnect) {
                connectProc.command = root.pendingConnect.cmd
                root.connecting = root.pendingConnect.ssid
                root.pendingConnect = null
                connectProc.running = true
                return
            }
            root.connecting = ""
            root.refreshStatus()
            root.refreshList()
        }
    }

    Process {
        id: autoProc
        property var pending: []
        command: ["true"]
        onExited: {
            root.refreshList()
            root.next(autoProc)
        }
    }

    Process {
        id: forgetProc
        property var pending: []
        command: ["true"]
        onExited: {
            root.refreshStatus()
            root.refreshList()
            root.next(forgetProc)
        }
    }

    // iwd reports itself active before its interfaces are registered, so the
    // one-shot probe at startup can come back empty. Everything else is
    // gated on having a device, so without this retry that empty result
    // would stick for the whole session and the bar would insist it is
    // offline while the machine is plainly online.
    Timer {
        interval: 5000
        repeat: true
        running: root.device === ""
        onTriggered: if (!deviceProc.running) deviceProc.running = true
    }

    // The status is re-read when iwd says it changed, not on a timer: a
    // gdbus monitor on iwd's signals, filtered down to the ones that move
    // what the bar shows -- the station's State and ConnectedNetwork, the
    // device's Powered, and a station appearing or going (the radio powering
    // on or off, iwd restarting). Scanning and the BSS churn that comes with
    // it are ignored. A connect, disconnect or radio toggle made anywhere --
    // iwctl in a terminal, the network roaming on its own -- shows at once,
    // instead of up to fifteen seconds later from what used to be a poll.
    //
    // Changes arrive in bursts (State steps through connecting to connected),
    // so they're gathered for a moment and read once.
    function iwdChanged(line) {
        if (line.indexOf("InterfacesAdded") !== -1 || line.indexOf("InterfacesRemoved") !== -1) {
            if (line.indexOf("net.connman.iwd.Station") === -1 && line.indexOf("net.connman.iwd.Device") === -1) return
        } else if (line.indexOf("is now owned by") !== -1) {
            // iwd restarted: its objects, device name included, start over
            root.device = ""
        } else if (!/'(State|ConnectedNetwork|Powered)'/.test(line)) {
            return
        }
        iwdSettle.restart()
    }

    Process {
        id: iwdWatch
        command: ["gdbus", "monitor", "--system", "--dest", "net.connman.iwd"]
        running: true
        stdout: SplitParser { onRead: line => root.iwdChanged(line) }
        // gdbus itself went away; a monitor that's not running would leave
        // the status frozen, so it comes back
        onExited: iwdRewatch.restart()
    }

    Timer {
        id: iwdRewatch
        interval: 5000
        onTriggered: iwdWatch.running = true
    }

    Timer {
        id: iwdSettle
        interval: 300
        onTriggered: {
            if (root.device === "") { if (!deviceProc.running) deviceProc.running = true }
            else root.refreshStatus()
        }
    }
}
