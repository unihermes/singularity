// Singularity - Quickshell
// ~/.config/quickshell/settings/SettingsPageDevices.qml
//
// Everything plugged in or linked, a section each. PHONE: the Android
// phone in a card with what it can do now, then pairing adb for Wi-Fi
// through a QR code the phone scans (services/Phone.qml), then the phone
// link (services/PhoneLink.qml): its switch, and the phones the KDE Connect
// app shows from, to pair or unpair. HEADSET: the settings headsetcontrol can
// send it, only the ones it has (Peripherals). MOUSE: what a mouse keeps
// on itself (DPI, report rate, its buttons) through libratbag (Mice), only
// for one it knows. WIRELESS: what UPower
// reports with a battery. DRIVES: removable drives to mount, open and
// eject (Drives). USB: every device plugged in, read from sysfs while the
// page is open.

import Quickshell
import Quickshell.Io
import QtQuick
import "../services"
import "../services/Format.js" as Format
import "../flyouts"

SettingsPage {
    id: page

    sectioned: true

    title: "Devices"
    description: "Your phone, headset, peripherals and drives."

    // the code is only good while this page shows it
    onVisibleChanged: {
        if (!visible) Phone.cancelPair()
        else Mice.refresh()
    }

    readonly property bool phoneOn: Phone.connected || PhoneLink.connected
    readonly property bool headsetOn: Channels.headset === "on"
    readonly property var wireless: Peripherals.devices.filter(d => d.key !== "headset")

    // --- pieces --------------------------------------------------------------

    // a headset level (0..max), sent when the drag ends; "—" until picked
    component HeadsetLevel: SettingsField {
        id: hl
        property string key: ""
        property int max: 128
        readonly property var saved: Peripherals.headsetValue(key)
        property real dragged: NaN
        readonly property real shown: !isNaN(dragged) ? dragged : saved !== undefined ? saved : 0
        visible: Peripherals.headsetCan(key)

        Row {
            anchors.right: parent.right
            spacing: Theme.sp(10)

            Slider {
                width: Theme.fit(220)
                anchors.verticalCenter: parent.verticalCenter
                value: hl.shown / hl.max * 100
                onMoved: v => hl.dragged = Math.round(v / 100 * hl.max)
                onReleased: {
                    if (!isNaN(hl.dragged)) Peripherals.setHeadset(hl.key, hl.dragged)
                    hl.dragged = NaN
                }
            }
            Text {
                width: Theme.fs(52)
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: hl.saved === undefined && isNaN(hl.dragged) ? "—" : Math.round(hl.shown / hl.max * 100) + "%"
                color: Theme.textStrong
                font.family: Theme.fontText
                font.weight: Theme.weightBody
                font.pixelSize: Theme.fontBody
            }
        }
    }

    component HeadsetSwitch: SettingsField {
        id: hs
        property string key: ""
        visible: Peripherals.headsetCan(key)

        Switch {
            anchors.right: parent.right
            checked: Peripherals.headsetValue(hs.key) === true
            onToggled: Peripherals.setHeadset(hs.key, Peripherals.headsetValue(hs.key) !== true)
        }
    }

    component HeadsetChoice: SettingsField {
        id: hc
        property string key: ""
        property var choices: []
        visible: Peripherals.headsetCan(key)

        FlyoutSegmented {
            anchors.right: parent.right
            fill: false
            model: hc.choices
            current: Peripherals.headsetValue(hc.key)
            onPicked: v => Peripherals.setHeadset(hc.key, v)
        }
    }

    // a readout at a row's end in the value's weight
    component Readout: Text {
        anchors.right: parent.right
        color: Theme.textStrong
        font.family: Theme.fontText
        font.weight: Theme.weightBody
        font.pixelSize: Theme.fontBody
    }

    // --- phone ---------------------------------------------------------------

    SettingsNote {
        visible: !Phone.available
        text: "scrcpy and android-tools aren't installed"
        alert: true
    }

    FlyoutHeading { text: "PHONE" }

    HeadCard {
        glyph: "󰄜"
        glyphColor: page.phoneOn ? Theme.textStrong : Theme.muted
        title: page.phoneOn ? Phone.shownName || "Phone"
            : Phone.unauthorized ? "Allow USB debugging on the phone"
            : Phone.reachable ? "Wireless debugging on"
            : "No phone"
        lines: [page.phoneOn || Phone.reachable
            ? [Phone.connected ? (Phone.device.wifi ? "Over Wi-Fi" : "Over USB")
                   : Phone.reachable ? "Over Wi-Fi when used" : "",
               PhoneLink.connected ? "Linked" : "",
               Phone.shownBattery >= 0 ? Phone.shownBattery + "%" + (Phone.shownCharging ? " charging" : "") : "",
               Phone.mirroring ? "On screen" : ""].filter(t => t).join("  ·  ")
            : "Plug it in, or pair it over Wi-Fi below"]

        FlyoutChip {
            visible: Phone.reachable
            icon: Phone.mirroring ? "󰓛" : "󰍹"
            text: Phone.mirroring ? "Stop" : "Mirror"
            selected: Phone.mirroring
            onClicked: Phone.toggleMirror()
        }
        FlyoutChip {
            visible: Phone.reachable
            icon: "󰹑"
            text: "Screenshot"
            onClicked: Phone.screenshot()
        }
        FlyoutChip {
            visible: PhoneLink.connected
            icon: "󰂞"
            text: "Ring"
            onClicked: PhoneLink.ring()
        }
        FlyoutChip {
            visible: PhoneLink.connected && PhoneLink.canPick
            icon: "󰒊"
            text: "Send file"
            onClicked: PhoneLink.pickFiles()
        }
    }

    SettingsSubhead { caption: "WIRELESS DEBUGGING" }

    SettingsField {
        label: "Pair over Wi-Fi"
        hint: Phone.pairState === "waiting" ? "Scan the code from the phone"
            : Phone.pairState === "pairing" ? "Pairing…"
            : Phone.pairState === "done" ? "Paired"
            : Phone.pairState === "failed" ? Phone.pairError
            : "Once per phone, with the phone on this Wi-Fi"

        FlyoutChip {
            anchors.right: parent.right
            enabled: Phone.available
            icon: Phone.pairState === "waiting" || Phone.pairState === "pairing" ? "󰅖" : "󰐲"
            text: Phone.pairState === "waiting" || Phone.pairState === "pairing" ? "Cancel" : "Show code"
            onClicked: Phone.pairState === "waiting" || Phone.pairState === "pairing" ? Phone.cancelPair() : Phone.pair()
        }
    }

    // the code, white round it as scanners like, with where to find the scanner
    Column {
        visible: Phone.pairState === "waiting" && Phone.pairQr !== ""
        width: parent.width
        spacing: Theme.spaceS

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.fit(200)
            height: width
            radius: Theme.radiusInner
            color: "white"

            Image {
                anchors.fill: parent
                anchors.margins: Theme.spaceS
                source: Phone.pairQr
                smooth: false
                fillMode: Image.PreserveAspectFit
                cache: false
            }
        }

        SettingsNote {
            horizontalAlignment: Text.AlignHCenter
            text: "Developer options › Wireless debugging › Pair device with QR code"
        }
    }

    SettingsSubhead { caption: "KDE CONNECT" }

    // the linked phone's Unpair and the Look chip sit on the switch's row;
    // other phones KDE Connect shows get a row each
    SettingsField {
        label: "Phone link"
        hint: !Settings.phoneLinkOn ? "Off"
            : PhoneLink.error !== "" ? PhoneLink.error
            : PhoneLink.connected ? "Linked to " + PhoneLink.device.name
            : "Open KDE Connect on the phone to find " + (PhoneLink.hostName || "this computer")

        Row {
            anchors.right: parent.right
            spacing: Theme.spaceS

            FlyoutChip {
                anchors.verticalCenter: parent.verticalCenter
                visible: Settings.phoneLinkOn && PhoneLink.running && !PhoneLink.connected
                icon: "󰑐"
                text: "Look again"
                onClicked: PhoneLink.refresh()
            }
            FlyoutChip {
                anchors.verticalCenter: parent.verticalCenter
                visible: PhoneLink.connected
                text: "Unpair"
                confirmText: "Unpair?"
                onClicked: PhoneLink.unpair(PhoneLink.device.id)
            }
            Switch {
                anchors.verticalCenter: parent.verticalCenter
                checked: Settings.phoneLinkOn
                onToggled: {
                    Settings.setPhoneLinkOn(!Settings.phoneLinkOn)
                    page.say(Settings.phoneLinkOn ? "Phone link on" : "Phone link off", false)
                }
            }
        }
    }

    Repeater {
        model: PhoneLink.devices.filter(d => d !== PhoneLink.device)

        SettingsField {
            id: phoneRow
            required property var modelData
            readonly property string pairing: modelData.pairing
            label: modelData.name
            hint: pairing === "requested" ? "Accept on the phone…"
                : pairing === "incoming" ? "Wants to pair"
                : !modelData.paired ? "Not paired"
                : "Paired · out of reach"

            Row {
                anchors.right: parent.right
                spacing: Theme.spaceS

                FlyoutChip {
                    visible: !phoneRow.modelData.paired && phoneRow.pairing === ""
                    text: "Pair"
                    onClicked: PhoneLink.pair(phoneRow.modelData.id)
                }
                FlyoutChip {
                    visible: phoneRow.pairing === "incoming"
                    text: "Accept"
                    onClicked: PhoneLink.accept(phoneRow.modelData.id)
                }
                FlyoutChip {
                    visible: phoneRow.pairing === "incoming"
                    text: "Decline"
                    onClicked: PhoneLink.reject(phoneRow.modelData.id)
                }
                FlyoutChip {
                    visible: phoneRow.modelData.paired
                    text: "Unpair"
                    confirmText: "Unpair?"
                    onClicked: PhoneLink.unpair(phoneRow.modelData.id)
                }
            }
        }
    }

    SettingsNote {
        visible: !PhoneLink.connected
        text: "Needs KDE Connect on the phone, with notification access; a VPN there has to allow LAN"
    }

    // --- headset -------------------------------------------------------------

    Item { visible: Channels.headset !== ""; width: 1; height: Theme.spaceM }
    FlyoutHeading { visible: Channels.headset !== ""; text: "HEADSET" }

    HeadCard {
        visible: Channels.headset !== ""
        glyph: "󰋋"
        glyphColor: page.headsetOn ? Theme.textStrong : Theme.muted
        title: Channels.headsetName || "Headset"
        lines: [page.headsetOn
            ? (Channels.headsetLevel >= 0 ? Channels.headsetLevel + "%" + (Channels.headsetCharging ? " charging" : "") : "On")
            : "Off; what's picked here is sent when it turns on"]
    }

    SettingsNote {
        visible: Peripherals.headsetError !== ""
        text: Peripherals.headsetError
        alert: true
    }

    HeadsetLevel {
        key: "sidetone"
        label: "Sidetone"
        hint: "Your own voice in your ears"
    }
    HeadsetLevel {
        key: "micVolume"
        label: "Microphone level"
        hint: "The headset's own gain"
    }
    HeadsetChoice {
        key: "inactive"
        label: "Turn off when idle"
        hint: "After this long with no sound"
        choices: [{ value: 0, text: "Never" }, { value: 10, text: "10 min" }, { value: 30, text: "30 min" },
                  { value: 60, text: "1 h" }, { value: 90, text: "90 min" }]
    }
    HeadsetChoice {
        key: "muteLed"
        label: "Mute light"
        hint: "How bright it shows the mic is off"
        choices: [{ value: 0, text: "Off" }, { value: 1, text: "Low" }, { value: 2, text: "Mid" }, { value: 3, text: "High" }]
    }
    HeadsetSwitch {
        key: "limiter"
        label: "Volume limiter"
        hint: "Caps how loud it plays"
    }
    HeadsetSwitch {
        key: "btPower"
        label: "Bluetooth at power-on"
        hint: "Its Bluetooth comes on with it"
    }
    HeadsetSwitch {
        key: "lights"
        label: "Lights"
        hint: "The headset's own lights"
    }
    HeadsetSwitch {
        key: "prompts"
        label: "Voice prompts"
        hint: "Spoken power and pairing alerts"
    }

    FlyoutRow {
        visible: Channels.headset !== "" && Peripherals.headsetCaps.length > 0
            && !Object.keys(Peripherals.headsetFlags).some(k => Peripherals.headsetCan(k))
        label: "Nothing on it to set"
        enabled: false
    }

    // --- mouse ---------------------------------------------------------------

    // what each button can be set to: mouse buttons 1..5, or nothing
    readonly property var buttonActions: [
        { value: 1, text: "Left click" }, { value: 2, text: "Right click" }, { value: 3, text: "Middle click" },
        { value: 4, text: "Back" }, { value: 5, text: "Forward" }, { value: 0, text: "Nothing" },
    ]
    readonly property var buttonNames: ["Left button", "Right button", "Wheel click", "Back side button", "Front side button"]

    Item { visible: Mice.devices.length > 0; width: 1; height: Theme.spaceM }
    FlyoutHeading { visible: Mice.devices.length > 0; text: "MOUSE" }

    SettingsNote {
        visible: Mice.error !== ""
        text: Mice.error
        alert: true
    }

    Repeater {
        model: Mice.devices

        Column {
            id: mouse
            required property var modelData
            width: parent ? parent.width : 0

            // its battery from UPower, matched by name
            readonly property var battery: page.wireless.find(d => d.name === modelData.name) || null

            HeadCard {
                glyph: "󰍽"
                glyphColor: mouse.battery && mouse.battery.level < 0 ? Theme.muted : Theme.textStrong
                title: mouse.modelData.name
                lines: [[mouse.battery && mouse.battery.level >= 0
                            ? mouse.battery.level + "%" + (mouse.battery.charging ? " charging" : "") : "",
                         mouse.modelData.dpi + " DPI", mouse.modelData.rate + " Hz"].filter(t => t).join("  ·  ")]
            }

            // DPI steps through the ones the mouse has, sent when the drag ends
            SettingsField {
                id: dpiRow
                readonly property var dpis: mouse.modelData.dpis
                property int dragged: -1
                readonly property int at: dragged >= 0 ? dragged : Math.max(0, dpis.indexOf(mouse.modelData.dpi))
                visible: dpis.length > 1
                label: "DPI"
                hint: "Set on the mouse; pointer speed scales it"

                Row {
                    anchors.right: parent.right
                    spacing: Theme.sp(10)

                    Slider {
                        width: Theme.fit(220)
                        anchors.verticalCenter: parent.verticalCenter
                        value: dpiRow.at / (dpiRow.dpis.length - 1) * 100
                        onMoved: v => dpiRow.dragged = Math.round(v / 100 * (dpiRow.dpis.length - 1))
                        onReleased: {
                            const i = dpiRow.dragged
                            dpiRow.dragged = -1
                            if (i >= 0 && dpiRow.dpis[i] !== mouse.modelData.dpi) Mice.setDpi(mouse.modelData, dpiRow.dpis[i])
                        }
                    }
                    Text {
                        width: Theme.fs(52)
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        text: dpiRow.dpis[dpiRow.at] || "—"
                        color: Theme.textStrong
                        font.family: Theme.fontText
                        font.weight: Theme.weightBody
                        font.pixelSize: Theme.fontBody
                    }
                }
            }

            SettingsField {
                visible: mouse.modelData.rates.length > 1
                label: "Polling rate"
                hint: "How often it tells the computer where it is"

                FlyoutSegmented {
                    anchors.right: parent.right
                    fill: false
                    model: mouse.modelData.rates.map(r => ({ value: r, text: r + " Hz" }))
                    current: mouse.modelData.rate
                    onPicked: v => Mice.setRate(mouse.modelData, v)
                }
            }

            SettingsSubhead { visible: mouse.modelData.buttons.length > 1; caption: "BUTTONS" }

            // the left button stays a left click, so the mouse can't lose it
            Repeater {
                model: mouse.modelData.buttons.length

                SettingsField {
                    id: buttonRow
                    required property int index
                    readonly property var button: mouse.modelData.buttons[index]
                    // a key, macro or special action set elsewhere
                    readonly property bool other: button.type > 1
                    visible: index > 0
                    label: page.buttonNames[index] || "Button " + (index + 1)

                    SettingsDropdown {
                        anchors.right: parent.right
                        width: Theme.fit(150)
                        model: page.buttonActions.map(a => a.value)
                        labelFor: v => page.buttonActions.find(a => a.value === v).text
                        current: buttonRow.other ? undefined : buttonRow.button.type === 0 ? 0 : buttonRow.button.value
                        placeholder: "Something else"
                        onPicked: v => Mice.setButton(mouse.modelData, buttonRow.index, v)
                    }
                }
            }
        }
    }

    // --- wireless ------------------------------------------------------------

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "WIRELESS" }

    Repeater {
        model: page.wireless

        SettingsField {
            id: peri
            required property var modelData
            readonly property bool low: Peripherals.isLow(modelData)
            mark: modelData.glyph
            label: modelData.name
            hint: [modelData.kind, modelData.level < 0 ? "off" : modelData.charging ? "charging" : "",
                   low ? "low" : ""].filter(t => t).join(" · ")
            dimmed: modelData.level < 0

            Readout {
                text: peri.modelData.level < 0 ? "—" : (peri.modelData.charging ? "󱐋 " : "") + peri.modelData.level + "%"
                color: peri.low ? Theme.alert : Theme.textStrong
            }
        }
    }

    FlyoutRow {
        visible: page.wireless.length === 0
        label: "Nothing wireless with a battery"
        enabled: false
    }

    SettingsNote {
        text: "A notification when one is down to 15%, and again at 5%"
    }

    // --- drives --------------------------------------------------------------

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "DRIVES" }

    Repeater {
        model: Drives.drives

        Column {
            id: drive
            required property var modelData
            readonly property bool busy: Drives.busyPath === modelData.path
            width: parent ? parent.width : 0

            SettingsField {
                mark: "󱊟"
                label: drive.modelData.name
                hint: Format.bytes(drive.modelData.size) + " · "
                    + drive.modelData.parts.length + (drive.modelData.parts.length === 1 ? " filesystem" : " filesystems")

                FlyoutChip {
                    anchors.right: parent.right
                    icon: "󰕓"
                    text: drive.busy ? "Ejecting…" : "Eject"
                    enabled: !drive.busy
                    onClicked: Drives.eject(drive.modelData)
                }
            }

            SettingsIndent {
                visible: drive.modelData.parts.length > 0

                Repeater {
                    model: drive.modelData.parts

                    SettingsField {
                        id: part
                        required property var modelData
                        readonly property bool mounted: modelData.mountpoint !== ""
                        readonly property bool busy: Drives.busyPath === modelData.path
                        mark: "󰋊"
                        label: modelData.label !== "" ? modelData.label : modelData.fstype.toUpperCase()
                        hint: [modelData.fstype,
                               mounted && modelData.used > 0
                                   ? Format.bytes(modelData.used) + " of " + Format.bytes(modelData.size) + " used"
                                   : Format.bytes(modelData.size),
                               mounted ? modelData.mountpoint : "not mounted"].join(" · ")

                        Row {
                            anchors.right: parent.right
                            spacing: Theme.spaceS

                            FlyoutChip {
                                visible: part.mounted
                                text: "Open"
                                onClicked: Drives.open(part.modelData)
                            }
                            FlyoutChip {
                                text: part.busy ? "…" : part.mounted ? "Unmount" : "Mount"
                                enabled: !part.busy
                                onClicked: part.mounted ? Drives.unmount(part.modelData) : Drives.mount(part.modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    FlyoutRow {
        visible: Drives.count === 0
        label: "No removable drives"
        enabled: false
    }

    SettingsNote {
        visible: Drives.error !== ""
        text: Drives.error
        alert: true
    }

    // --- usb -----------------------------------------------------------------

    // each { path, id ("046d:c547"), name, kind, glyph, speed }, by name
    property var usb: []
    property bool usbAll: false
    readonly property int usbShown: 10

    // a device's interfaces ("0301" class and protocol, hex) to what it is
    function usbKind(ifs, name) {
        const has = c => ifs.some(i => i.indexOf(c) === 0)
        if (has("0e")) return ["Camera", "󰄀"]
        if (has("08")) return ["Storage", "󰋊"]
        if (has("e0")) return ["Bluetooth", "󰂯"]
        if (has("02") || has("0a")) return ["Network", "󰈀"]
        if (/receiver/i.test(name) && has("03")) return ["Wireless receiver", "󱇰"]
        if (has("01")) return ["Audio", "󰓃"]
        if (ifs.indexOf("0301") !== -1) return ["Keyboard", "󰌌"]
        if (ifs.indexOf("0302") !== -1) return ["Mouse", "󰍽"]
        if (has("03")) return ["Input", "󰍽"]
        if (has("07")) return ["Printer", "󰐪"]
        return ["Device", "󰗮"]
    }

    function usbSpeed(mbps) {
        if (mbps >= 20000) return "USB 3 · 20 Gb/s"
        if (mbps >= 10000) return "USB 3 · 10 Gb/s"
        if (mbps >= 5000) return "USB 3 · 5 Gb/s"
        if (mbps >= 480) return "USB 2"
        return mbps > 0 ? "USB 1" : ""
    }

    // every device but the hubs, one tab-separated line each: its path,
    // vendor:product, maker, product, speed, its interfaces
    Process {
        id: usbRead
        command: ["sh", "-c", 'for d in /sys/bus/usb/devices/*; do\n'
            + '  [ -f "$d/idVendor" ] || continue; [ "$(cat "$d/bDeviceClass")" = 09 ] && continue\n'
            + '  ifs=""; for i in "$d"/*:*; do [ -f "$i/bInterfaceClass" ] && ifs="$ifs$(cat "$i/bInterfaceClass")$(cat "$i/bInterfaceProtocol"),"; done\n'
            + '  printf "%s\\t%s:%s\\t%s\\t%s\\t%s\\t%s\\n" "${d##*/}" "$(cat "$d/idVendor")" "$(cat "$d/idProduct")" '
            + '"$(cat "$d/manufacturer" 2>/dev/null)" "$(cat "$d/product" 2>/dev/null)" "$(cat "$d/speed")" "$ifs"\n'
            + 'done']
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                for (const line of text.split("\n")) {
                    const f = line.split("\t")
                    if (f.length < 6) continue
                    const ifs = f[5].split(",").filter(i => i !== "")
                    // a hub's own controller, and makers that are a serial number
                    if (/hub/i.test(f[3]) || ifs.every(i => i.indexOf("09") === 0)) continue
                    let maker = f[2].replace(/([,.]?\s*\b(Inc|Corp|Co|Ltd|Tech)\b\.?)+$/i, "").trim()
                    let product = f[3].replace(/_/g, " ").trim()
                    if (/^[A-Z0-9]{12,}$/.test(maker) || /^generic$/i.test(maker)) maker = ""
                    const name = maker !== "" && product.toLowerCase().indexOf(maker.toLowerCase()) === -1
                        ? maker + " " + product : product || maker || f[1]
                    const k = page.usbKind(ifs, name)
                    out.push({ path: f[0], id: f[1], name: name, kind: k[0], glyph: k[1], speed: page.usbSpeed(Number(f[4])) })
                }
                page.usb = out.sort((a, b) => a.name.localeCompare(b.name))
            }
        }
    }

    // read again when one comes or goes; a burst (its interfaces) once
    Process {
        running: true
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=usb"]
        stdout: SplitParser {
            onRead: line => { if (/ (add|remove) /.test(line)) usbSettle.restart() }
        }
    }
    Timer {
        id: usbSettle
        interval: 600
        onTriggered: {
            if (!usbRead.running) usbRead.running = true
            Mice.refresh()
        }
    }

    Item { width: 1; height: Theme.spaceM }
    FlyoutHeading { text: "USB" }

    Repeater {
        model: page.usbAll ? page.usb : page.usb.slice(0, page.usbShown)

        SettingsValue {
            required property var modelData
            mark: modelData.glyph
            label: modelData.name
            hint: [modelData.kind, modelData.speed].filter(t => t).join(" · ")
            value: modelData.id
            copyable: true
        }
    }

    FlyoutRow {
        visible: page.usb.length > page.usbShown
        label: page.usbAll ? "Show fewer" : "Show all " + page.usb.length
        trailing: page.usbAll ? "󰅃" : "󰅀"
        onActivated: page.usbAll = !page.usbAll
    }

    FlyoutRow {
        visible: page.usb.length === 0
        label: "Nothing plugged in"
        enabled: false
    }
}
