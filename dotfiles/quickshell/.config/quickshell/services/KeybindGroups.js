// Filtering and grouping for the keybind editor. No QML or file writes.
.import "HyprBinds.js" as HyprBinds
.import "HyprPresets.js" as HyprPresets

// --- grouping: the config's own binds --------------------------------

// The file's sections gathered into the list's groups, in this order;
// a section not named here keeps its own heading after them.
var displayGroups = [
    { name: "Apps",       sections: ["Launchers"] },
    { name: "Shell",      sections: ["Shell windows", "Clipboard", "Calculator and file search",
                                     "Notes", "Claude"] },
    { name: "Windows",    sections: ["Window Management", "Mouse", "Scratchpad"] },
    { name: "Focus",      sections: ["Focus"] },
    { name: "Workspaces", sections: ["Workspaces"] },
    { name: "Session",    sections: ["Session", "Screenshot"] },
    { name: "Hardware keys", sections: ["Function Keys", "Media Keys", "Lock Keys", "Lid"] },
]

// Within a section, a bind that does the same as an earlier one (two
// keys for maximize) is listed right under it rather than lines later.
function clusterSame(rows) {
    var out = []
    rows.forEach(r => {
        var at = -1
        for (var i = out.length - 1; i >= 0; i--)
            if (r.desc !== "" && out[i].desc === r.desc) { at = i; break }
        if (at < 0) out.push(r)
        else out.splice(at + 1, 0, r)
    })
    return out
}

function groups(model, query, findKeys) {
    if (!model) return []
    var q = query.trim().toLowerCase()
    var f = findKeys !== "" ? HyprBinds.normalizeKeys(findKeys) : ""
    var groupOf = {}
    displayGroups.forEach(g => g.sections.forEach(sec => groupOf[sec] = g.name))
    var bySection = {}
    for (var i = 0; i < model.rows.length; i++) {
        var r = model.rows[i]
        var sec = r.category !== "" ? r.category : "Other"
        var shown = groupOf[sec] || sec
        if (q !== "" && (r.keys + "\n" + r.desc + "\n" + r.command + "\n" + sec + "\n" + shown)
                .toLowerCase().indexOf(q) < 0)
            continue
        if (f !== "" && r.norm !== f) continue
        if (!bySection[sec]) bySection[sec] = []
        bySection[sec].push(r)
    }
    var out = []
    // `section` is where Add a bind… writes: the group's last section
    // that has binds
    var take = (name, sections) => {
        var rows = [], last = ""
        sections.forEach(sec => {
            if (bySection[sec]) { rows = rows.concat(clusterSame(bySection[sec])); last = sec }
        })
        if (rows.length > 0) out.push({ name: name, rows: rows, section: last })
    }
    displayGroups.forEach(g => take(g.name, g.sections))
    model.categories.map(c => c.name).concat(["Other"])
        .filter(sec => !groupOf[sec])
        .forEach(sec => take(sec, [sec]))
    return out
}
// --- grouping: the catalogue -----------------------------------------

// Every preset, wrapped with what the config says about it and whether
// the tools it needs are installed.
function presetGroups(model, query, findKeys, hideBound, present) {
    if (!model) return []
    var q = query.trim().toLowerCase()
    var f = findKeys !== "" ? HyprBinds.normalizeKeys(findKeys) : ""
    var out = []
    var packs = HyprPresets.PACKS
    for (var i = 0; i < packs.length; i++) {
        var pack = packs[i]
        var items = [], bound = 0
        for (var j = 0; j < pack.binds.length; j++) {
            var b = pack.binds[j]
            var st = HyprPresets.status(model, b)
            if (st.state === "bound") bound++
            if (hideBound && st.state === "bound") continue
            if (f !== "" && HyprBinds.normalizeKeys(b.keys) !== f) continue
            var action = b.lua ? b.lua : b.cmd
            if (q !== "" && (b.keys + "\n" + b.desc + "\n" + action + "\n" + pack.name)
                    .toLowerCase().indexOf(q) < 0)
                continue
            var missing = (b.needs || []).filter(n => !present[n])
            items.push({
                preset: b, id: HyprPresets.id(b), keys: b.keys, desc: b.desc,
                action: action, section: b.section,
                state: st.state, other: st.row, missing: missing,
            })
        }
        if (items.length) out.push({ name: pack.name, note: pack.note, items: items, total: pack.binds.length, bound: bound })
    }
    return out
}

function presetTotal() {
    var n = 0
    HyprPresets.PACKS.forEach(p => n += p.binds.length)
    return n
}

function presetBound(model) {
    if (!model) return 0
    var n = 0
    HyprPresets.PACKS.forEach(p => p.binds.forEach(b => {
        if (HyprPresets.status(model, b).state === "bound") n++
    }))
    return n
}
