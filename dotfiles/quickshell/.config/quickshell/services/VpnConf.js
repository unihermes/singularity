.pragma library

// Proton VPN's WireGuard files, read for what the shell shows (the server,
// its country, whether it forwards a port), and the INI edits that keep
// qBittorrent on the tunnel (services/Vpn.qml).

var countries = {
    AE: "UAE", AR: "Argentina", AT: "Austria", AU: "Australia", BE: "Belgium",
    BG: "Bulgaria", BR: "Brazil", CA: "Canada", CH: "Switzerland", CL: "Chile",
    CO: "Colombia", CY: "Cyprus", CZ: "Czechia", DE: "Germany", DK: "Denmark",
    EE: "Estonia", ES: "Spain", FI: "Finland", FR: "France", GR: "Greece",
    HK: "Hong Kong", HR: "Croatia", HU: "Hungary", IE: "Ireland", IL: "Israel",
    IN: "India", IS: "Iceland", IT: "Italy", JP: "Japan", KR: "South Korea",
    LT: "Lithuania", LU: "Luxembourg", LV: "Latvia", MD: "Moldova", MX: "Mexico",
    MY: "Malaysia", NL: "Netherlands", NO: "Norway", NZ: "New Zealand",
    PL: "Poland", PT: "Portugal", RO: "Romania", RS: "Serbia", SE: "Sweden",
    SG: "Singapore", SI: "Slovenia", SK: "Slovakia", TR: "Türkiye", TW: "Taiwan",
    UA: "Ukraine", UK: "United Kingdom", GB: "United Kingdom", US: "United States",
    ZA: "South Africa",
}

// The parts of a config the shell uses, or null for a file that isn't a
// WireGuard config. id is the file's name without .conf.
//   name     the server as Proton labels it ("NL#245", "US-NY#123"), else id
//   country  its country's name, "" when unknown
//   pf       true / false from Proton's "NAT-PMP (Port Forwarding)" line,
//            null when the file doesn't say
//   gateway  where NAT-PMP asks: the tunnel's DNS, else Proton's 10.2.0.1
function parse(id, text) {
    if (!/^\s*\[Peer\]/mi.test(text) || !/^\s*PrivateKey\s*=/mi.test(text)) return null
    var label = (text.match(/^\s*\[Peer\]\s*\n\s*#\s*([A-Z]{2}(?:-[A-Z]{2,3})?#\d+)/mi) || [])[1] || ""
    var code = label.split(/[-#]/)[0].toUpperCase()
    // Secure Core goes in through Switzerland, Iceland or Sweden: CH-US#1
    // comes out in the US
    var sc = label.match(/^(CH|IS|SE)-([A-Z]{2})#/i)
    if (sc && countries[sc[2].toUpperCase()]) code = sc[2].toUpperCase()
    var pfLine = text.match(/NAT-PMP[^=\n]*=\s*(on|off)/i)
    var dns = (text.match(/^\s*DNS\s*=\s*(.*)$/mi) || [])[1] || ""
    var gw = dns.split(/[\s,]+/).find(a => /^\d+\.\d+\.\d+\.\d+$/.test(a))
    return {
        id: id,
        name: label || id,
        country: countries[code] || "",
        pf: pfLine ? pfLine[1].toLowerCase() === "on" : null,
        gateway: gw || "10.2.0.1",
    }
}

// The INI text with section's key set to value (written as given, so
// qBittorrent's "Session\\Port"), or the key dropped when value is null.
// A missing section goes at the end.
function iniSet(text, section, key, value) {
    var lines = text === "" ? [] : text.replace(/\n$/, "").split("\n")
    var head = "[" + section + "]"
    var start = lines.findIndex(l => l.trim() === head)
    var line = value === null ? null : key + "=" + value
    if (start === -1) {
        if (line === null) return text
        if (lines.length > 0 && lines[lines.length - 1].trim() !== "") lines.push("")
        lines.push(head, line)
        return lines.join("\n") + "\n"
    }
    var end = start + 1
    while (end < lines.length && !/^\s*\[/.test(lines[end])) end++
    for (var i = start + 1; i < end; i++) {
        if (lines[i].split("=")[0].trim() !== key) continue
        if (line === null) lines.splice(i, 1)
        else lines[i] = line
        return lines.join("\n") + "\n"
    }
    if (line === null) return text
    // after the section's last key, before the blank line that ends it
    var at = end
    while (at > start + 1 && lines[at - 1].trim() === "") at--
    lines.splice(at, 0, line)
    return lines.join("\n") + "\n"
}
