.pragma library

function index(entries, hidden) {
    var excluded = new Set(hidden)
    return entries.filter(e => !e.noDisplay && !excluded.has(e.id)).map(e => ({
        entry: e, name: e.name.toLowerCase(),
        terms: [e.genericName || "", e.startupClass || ""].concat(Array.from(e.keywords || []))
            .map(s => s.toLowerCase()),
    }))
}

function order(rows, counts) {
    return rows.slice().sort((a, b) => (counts ? (counts[b.entry.id] || 0) - (counts[a.entry.id] || 0) : 0)
        || a.name.localeCompare(b.name))
}

function search(rows, query) {
    var q = (query || "").trim().toLowerCase()
    var starts = [], rest = []
    for (var row of rows) {
        if (q && row.name.startsWith(q)) starts.push(row.entry)
        else if (!q || row.name.includes(q) || row.terms.some(s => s.includes(q))) rest.push(row.entry)
    }
    return starts.concat(rest)
}
