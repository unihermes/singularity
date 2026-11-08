.pragma library

// ps supplies ancestry as well as memory; top supplies sampled CPU usage.
function memoryRows(text) {
    return text.trim().split("\n").map(function(line) {
        var m = line.trim().match(/^(\d+)\s+(\d+)\s+(\d+)\s+(.+)$/)
        return m ? { pid: Number(m[1]), ppid: Number(m[2]), memKb: Number(m[3]), name: m[4], cpu: 0 } : null
    }).filter(function(row) { return row !== null })
}

function group(rows, key, ancestry) {
    var browsers = { "floorp": "floorp", "floorp-bin": "floorp",
        "zen": "zen", "zen-bin": "zen", "zen-browser": "zen",
        "firefox": "firefox", "firefox-bin": "firefox", "firefox-esr": "firefox" }
    var helpers = /^(Isolated Web Co|Web Content|WebExtensions|RDD Process|Socket Process|Privileged Cont|Utility Process|Isolated Servic|GPU Process|forkserver)$/
    var parents = Object.create(null)
    ;(ancestry || rows).forEach(function(row) { parents[row.pid] = row })
    var by = Object.create(null), heavy = Object.create(null)
    rows.forEach(function(row) {
        var process = parents[row.pid] || row
        var name = browsers[process.name] || row.name
        if (helpers.test(process.name)) {
            var seen = Object.create(null)
            while (process && !seen[process.pid]) {
                seen[process.pid] = true
                if (browsers[process.name]) {
                    name = browsers[process.name]
                    break
                }
                process = parents[process.ppid]
            }
        }
        var bucket = by[name]
        if (!bucket) {
            bucket = by[name] = { pid: row.pid, user: row.user, name: name, cpu: 0, memKb: 0 }
            heavy[name] = -1
        }
        bucket.cpu += row.cpu
        bucket.memKb += row.memKb
        // Preserve the existing kill target: the group's heaviest member.
        if (row.memKb > heavy[name]) {
            heavy[name] = row.memKb
            bucket.pid = row.pid
            bucket.user = row.user
        }
    })
    return Object.keys(by).map(function(name) { return by[name] })
        .sort(function(a, b) { return b[key] - a[key] })
}
