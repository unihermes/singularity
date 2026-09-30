// Singularity - Quickshell
// ~/.config/quickshell/services/TimeWindow.js
//
// Daily windows given as minutes after midnight, for the Night Light and
// Do Not Disturb schedules. A window whose end is before its start runs
// overnight (22:00 to 07:00).

.pragma library

function minuteOf(d) { return d.getHours() * 60 + d.getMinutes() }

function contains(from, to, d) {
    var m = minuteOf(d)
    if (from === to) return false
    return from < to ? m >= from && m < to : m >= from || m < to
}

// minutes after midnight as a clock time, in the given Qt format
function format(minutes, fmt) {
    var d = new Date()
    d.setHours(Math.floor(minutes / 60), minutes % 60, 0, 0)
    return Qt.formatDateTime(d, fmt)
}
