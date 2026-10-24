// Singularity - Quickshell
// ~/.config/quickshell/services/Vpn.qml
//
// Proton VPN over WireGuard, without NetworkManager: Proton's own WireGuard
// files (imported from Downloads into the state dir, as they hold the key),
// brought up as the interface "proton" by singularity-vpn through pkexec.
// Either everything goes through it, with an optional kill switch, or only
// qBittorrent, bound to the interface so it can't use anything else.
//
// The forwarded port is asked of Proton's NAT-PMP gateway every 45 s (the
// lease is 60) and set in qBittorrent: over its Web UI on 127.0.0.1 while
// it runs, else in its config file. What's up is read from
// /run/singularity-vpn and the link's counters, so a reload picks it up.

pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "VpnConf.js" as VpnConf

Singleton {
    id: root

    readonly property bool available: wgProbe.found && helperProbe.found
    // why it isn't, for the flyout and Settings
    readonly property string missing: !wgProbe.found ? "wireguard-tools isn't installed"
        : !helperProbe.found ? "Its helper isn't installed; run install.sh" : ""
    readonly property string iface: "proton"
    readonly property string dir: Settings.stateDir + "/vpn"
    readonly property string qbitConf: Quickshell.env("HOME") + "/.config/qBittorrent/qBittorrent.conf"
    readonly property int qbitWebPort: 8089

    // [{ id, name, country, pf, gateway }], by name
    property var servers: []
    readonly property var picked: servers.find(s => s.id === Settings.vpnServer) || servers[0] || null

    // --- what's up ---

    property bool up: false
    // "full" or "split"
    property string mode: ""
    property string upServer: ""
    property bool killSwitchOn: false
    // the server has answered (bytes back through the tunnel)
    property bool answered: false
    // up a while with nothing back
    property bool stalled: false
    property double upSince: 0
    readonly property bool connected: up && answered
    readonly property var current: servers.find(s => s.id === upServer) || null
    readonly property string currentName: current ? current.name : upServer
    readonly property bool busy: helper.running
    property string error: ""

    // the forwarded port, 0 while there's none
    property int port: 0
    property string portError: ""

    // --- connecting ---

    function connect(id) {
        var s = servers.find(x => x.id === id)
        if (!s || busy) return
        Settings.setVpnServer(id)
        Settings.setVpnWanted(true)
        error = ""
        port = 0
        portError = ""
        var args = [Settings.vpnFull ? "full" : "split", id]
        if (Settings.vpnFull && Settings.vpnKillSwitch) args.push("killswitch")
        run(["sh", "-c", 'exec pkexec /usr/local/bin/singularity-vpn up "$@" < "$0"',
            dir + "/" + id + ".conf"].concat(args))
    }

    function disconnect() {
        if (busy) return
        Settings.setVpnWanted(false)
        error = ""
        run(["pkexec", "/usr/local/bin/singularity-vpn", "down"])
    }

    function toggle() {
        if (up) disconnect()
        else if (picked) connect(picked.id)
    }

    // A change of route takes a reconnect
    function setFull(on) {
        Settings.setVpnFull(on)
        if (up && !busy && (mode === "full") !== !!on) connect(upServer)
    }

    function setKillSwitch(on) {
        Settings.setVpnKillSwitch(on)
        if (up && mode === "full" && !busy)
            run(["pkexec", "/usr/local/bin/singularity-vpn", "killswitch", on ? "on" : "off"])
    }

    function run(cmd) {
        helper.command = cmd
        helper.running = true
    }

    Process {
        id: helper
        stderr: StdioCollector { id: helperErr }
        onExited: code => {
            // 126: the password prompt was dismissed
            if (code !== 0 && code !== 126) {
                var why = helperErr.text.trim().split("\n").pop() || "singularity-vpn failed"
                root.error = why
                Quickshell.execDetached(["notify-send", "-a", "VPN", "-u", "critical", "VPN", why])
            }
            status.run()
        }
    }

    // --- reading what's up ---

    Timer {
        running: root.available
        interval: 3000
        repeat: true
        triggeredOnStart: true
        onTriggered: status.run()
    }

    // once a start, after the servers are read: back on (at login, or after
    // a reload) if it was on when last left
    property bool restored: false
    property bool listed: false

    Process {
        id: status
        function run() { if (!running) running = true }
        command: ["sh", "-c",
            'd=/run/singularity-vpn; echo "mode=$(cat $d/mode 2>/dev/null)"; echo "server=$(cat $d/server 2>/dev/null)"\n'
            + '[ -e $d/killswitch ] && echo ks=1\n'
            + 'echo "rx=$(cat /sys/class/net/' + root.iface + '/statistics/rx_bytes 2>/dev/null)"']
        stdout: StdioCollector {
            onStreamFinished: {
                var v = {}
                text.split("\n").forEach(l => { var i = l.indexOf("="); if (i > 0) v[l.slice(0, i)] = l.slice(i + 1) })
                var wasUp = root.up
                root.up = (v.rx || "") !== ""
                root.mode = root.up ? v.mode || "" : ""
                root.upServer = root.up ? v.server || "" : ""
                root.killSwitchOn = v.ks === "1"
                root.answered = root.up && parseInt(v.rx) > 0
                if (root.up && !wasUp) root.upSince = Date.now()
                root.stalled = root.up && !root.answered && Date.now() - root.upSince > 20000
                if (!root.up) root.port = 0
                if (!root.restored && root.listed && !root.busy) {
                    root.restored = true
                    if (!root.up && Settings.vpnAtLogin && Settings.vpnWanted && root.picked)
                        root.connect(root.picked.id)
                }
            }
        }
    }

    // --- the servers ---

    function reload() { listProc.running = true }

    // Moves every WireGuard file in Downloads in (they hold the key), named
    // to what singularity-vpn takes; reports how many in importCount
    property int importCount: -1
    function importDownloads() {
        importCount = -1
        importProc.running = true
    }

    function remove(id) {
        Quickshell.execDetached(["rm", "-f", "--", dir + "/" + id + ".conf"])
        servers = servers.filter(s => s.id !== id)
    }

    Component.onCompleted: reload()

    Process {
        id: listProc
        command: ["sh", "-c", 'for f in "$0"/*.conf; do [ -f "$f" ] || continue; b=${f##*/}; printf "\\036%s\\n" "${b%.conf}"; cat "$f"; done', root.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                text.split("\x1e").forEach(chunk => {
                    var nl = chunk.indexOf("\n")
                    if (nl < 0) return
                    var s = VpnConf.parse(chunk.slice(0, nl), chunk.slice(nl + 1))
                    if (s) out.push(s)
                })
                out.sort((a, b) => (a.country + a.name).localeCompare(b.country + b.name))
                root.servers = out
                root.listed = true
                status.run()
            }
        }
    }

    Process {
        id: importProc
        command: ["sh", "-c",
            'dest=$0; src=$(xdg-user-dir DOWNLOAD 2>/dev/null); [ -d "$src" ] || src=$HOME/Downloads\n'
            + 'mkdir -p "$dest" && chmod 700 "$dest" || exit 1; n=0\n'
            + 'for f in "$src"/*.conf; do\n'
            + '  [ -f "$f" ] && grep -qi "^\\[Peer\\]" "$f" && grep -qi "^PrivateKey" "$f" || continue\n'
            + '  b=${f##*/}; b=$(printf %s "${b%.conf}" | tr -c "A-Za-z0-9._#+-" _ | cut -c1-60)\n'
            + '  install -m 600 "$f" "$dest/$b.conf" && rm -f "$f" && n=$((n+1))\n'
            + 'done; echo $n', root.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                root.importCount = parseInt(text.trim()) || 0
                root.reload()
            }
        }
    }

    // --- the forwarded port ---

    readonly property bool forwarding: connected && !!current && current.pf !== false

    Timer {
        running: root.forwarding && natpmpProbe.found
        interval: 45000
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!natpmp.running) natpmp.running = true
    }

    onForwardingChanged: if (!forwarding) port = 0

    Process {
        id: natpmp
        command: ["sh", "-c",
            'timeout 10 natpmpc -g "$0" -a 1 0 udp 60 >/dev/null && timeout 10 natpmpc -g "$0" -a 1 0 tcp 60',
            root.current ? root.current.gateway : "10.2.0.1"]
        stdout: StdioCollector {
            onStreamFinished: {
                var m = text.match(/Mapped public port (\d+)/)
                root.port = m ? parseInt(m[1]) : 0
                root.portError = m ? "" : "The server gave no port"
            }
        }
    }

    // --- qBittorrent ---

    // "" (not kept, or not installed) | "set" (it runs on the tunnel) |
    // "saved" (closed; applies when it starts) | "restart" (running from
    // before this was set up: quit it once)
    property string qbitState: ""

    Timer {
        running: Settings.vpnQbit && qbitProbe.found
        interval: 15000
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!qbitCheck.running) qbitCheck.running = true
    }

    onPortChanged: if (Settings.vpnQbit && port > 0 && !qbitCheck.running) qbitCheck.running = true

    Connections {
        target: Settings
        function onVpnQbitChanged() {
            if (Settings.vpnQbit) return
            root.qbitState = ""
            root.qbitApply(false)
        }
    }

    // its preferences over the Web UI, else whether it's running at all
    Process {
        id: qbitCheck
        command: ["sh", "-c",
            'curl -sf --max-time 2 "http://127.0.0.1:$0/api/v2/app/preferences" && exit\n'
            + 'pgrep -x qbittorrent >/dev/null && echo running || echo closed', String(root.qbitWebPort)]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.trim()
                if (t === "closed") { root.qbitWrite(true); return }
                if (t === "running") { root.qbitState = "restart"; return }
                var p
                try { p = JSON.parse(t) } catch (e) { return }
                if (p.current_network_interface !== root.iface || (root.port > 0 && p.listen_port !== root.port))
                    root.qbitApply(true)
                else root.qbitState = "set"
            }
        }
    }

    // On the tunnel (with the port once there is one), or let go of it
    function qbitApply(on) {
        var prefs = on ? { current_network_interface: root.iface, current_interface_name: root.iface }
                       : { current_network_interface: "", current_interface_name: "" }
        if (on && port > 0) { prefs.listen_port = port; prefs.random_port = false }
        qbitSet.command = ["sh", "-c",
            'curl -sf --max-time 2 "http://127.0.0.1:$0/api/v2/app/setPreferences" --data-urlencode "json=$1" && echo ok',
            String(qbitWebPort), JSON.stringify(prefs)]
        qbitSet.on = on
        qbitSet.running = true
    }

    Process {
        id: qbitSet
        property bool on: true
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "ok") { if (qbitSet.on) root.qbitState = "set" }
                else if (!qbitSet.on) root.qbitWrite(false)
            }
        }
    }

    // its config file, while it's closed (it writes the file as it quits).
    // The Web UI on 127.0.0.1 only, without a password from there, so the
    // shell can set the port while it runs. It won't start the Web UI with
    // no login set, so one goes in where there's none: a random password
    // nobody knows, as only its hash was kept.
    function qbitWrite(on) {
        AtomicFileWrite.write({
            path: qbitConf,
            transform: text => {
                if (!on) {
                    text = VpnConf.iniSet(text, "BitTorrent", "Session\\Interface", null)
                    return VpnConf.iniSet(text, "BitTorrent", "Session\\InterfaceName", null)
                }
                var keys = [
                    ["BitTorrent", "Session\\Interface", root.iface],
                    ["BitTorrent", "Session\\InterfaceName", root.iface],
                    ["Preferences", "WebUI\\Enabled", "true"],
                    ["Preferences", "WebUI\\Address", "127.0.0.1"],
                    ["Preferences", "WebUI\\Port", String(root.qbitWebPort)],
                    ["Preferences", "WebUI\\LocalHostAuth", "false"],
                ]
                if (!/^WebUI\\Password_PBKDF2=/m.test(text)) {
                    keys.push(["Preferences", "WebUI\\Username", "singularity"])
                    keys.push(["Preferences", "WebUI\\Password_PBKDF2", '"@ByteArray(Y4YZVcMTo1OqEPGs/vILGA==:HmhjZ/toCxwBXExVze4QQSrsrfPAzlC3UzMO9tVBQsIu6ZxN0fHNR5vzT/UmzAWdMZF1c6AWvnuyl8EENlkjfA==)"'])
                }
                if (root.port > 0) keys.push(["BitTorrent", "Session\\Port", String(root.port)])
                keys.forEach(k => { text = VpnConf.iniSet(text, k[0], k[1], k[2]) })
                return text
            },
            done: st => { if (on && (st === "ok" || st === "unchanged")) root.qbitState = "saved" },
        })
    }

    CommandProbe { id: wgProbe; name: "wg-quick" }
    CommandProbe { id: helperProbe; name: "singularity-vpn" }
    CommandProbe { id: natpmpProbe; name: "natpmpc" }
    CommandProbe { id: qbitProbe; name: "qbittorrent" }
    readonly property bool hasQbit: qbitProbe.found
    readonly property bool hasNatpmp: natpmpProbe.found

    IpcHandler {
        target: "vpn"
        function toggle(): void { root.toggle() }
        function status(): string {
            if (!root.up) return "off"
            return root.currentName + " (" + (root.mode === "full" ? "everything" : "qBittorrent only") + ")"
                + (root.stalled ? ", no answer" : "") + (root.port > 0 ? ", port " + root.port : "")
        }
    }
}
