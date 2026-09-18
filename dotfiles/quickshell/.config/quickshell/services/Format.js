// Singularity - Quickshell
// ~/.config/quickshell/services/Format.js
//
// Number formatting for readouts: percentages, sizes, rates, durations.
// Pulled out of the System window so anything else showing the same kind of
// number (a battery history graph, a disk flyout) says it the same way.

.pragma library

function pct(f) { return Math.round(f * 100) + "%" }

// binary units, labelled the way df -h and free -h label them
function gib(bytes) {
    var g = bytes / 1073741824
    return g >= 100 ? g.toFixed(0) + "G" : g.toFixed(1) + "G"
}

function kib(kb) {
    if (kb >= 1048576) return (kb / 1048576).toFixed(1) + "G"
    return Math.round(kb / 1024) + "M"
}

function rate(bps) {
    if (bps < 0) return "--"
    if (bps >= 1048576) return (bps / 1048576).toFixed(1) + " MB/s"
    if (bps >= 1024) return Math.round(bps / 1024) + " KB/s"
    return Math.round(bps) + " B/s"
}

function duration(s) {
    var d = Math.floor(s / 86400)
    var h = Math.floor((s % 86400) / 3600)
    var m = Math.floor((s % 3600) / 60)
    if (d > 0) return d + "d " + h + "h"
    if (h > 0) return h + "h " + m + "m"
    return m + "m"
}
