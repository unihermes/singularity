// Singularity - Quickshell
// ~/.config/quickshell/services/Markdown.js
//
// Claude's replies for the sidebar (AiTranscript): markdown split into
// prose and fenced code blocks, the prose turned into the rich text a Text
// renders. Covers what replies use: headings, paragraphs, lists (nested by
// indent), quotes, rules, small tables, and inline code, bold, italics,
// strikethrough and links. Colours come in as `ink`:
//   { text, strong, muted, accent, codeFill, codeInk, rule }
// An unclosed fence (a reply still streaming) runs to the end.

.pragma library

// [{ kind: "text", text } | { kind: "code", lang, code }]
function split(md) {
    var out = [], prose = [], lines = String(md || "").split("\n")
    var i = 0
    function flush() {
        var t = prose.join("\n").replace(/^\n+|\n+$/g, "")
        if (t !== "") out.push({ kind: "text", text: t })
        prose = []
    }
    while (i < lines.length) {
        var m = lines[i].match(/^\s*(```+|~~~+)\s*([\w+#.-]*)/)
        if (!m) { prose.push(lines[i++]); continue }
        flush()
        var fence = m[1], lang = m[2] || "", code = []
        i++
        while (i < lines.length && lines[i].trim().indexOf(fence) !== 0) code.push(lines[i++])
        i++
        out.push({ kind: "code", lang: lang, code: code.join("\n") })
    }
    flush()
    return out
}

function esc(s) {
    return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}

// one line's inline marks; code spans first, so nothing inside them counts
function inline(s, ink) {
    var codes = []
    s = s.replace(/`([^`]+)`/g, (_, c) => {
        codes.push(c)
        return "\u0000" + (codes.length - 1) + "\u0000"
    })
    s = esc(s)
    s = s.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, (_, t, u) =>
        "<a href=\"" + u.replace(/"/g, "%22") + "\" style=\"color:" + ink.accent + "\">" + t + "</a>")
    s = s.replace(/(^|[\s(])(https?:\/\/[^\s<)]+)/g, (_, p, u) =>
        p + "<a href=\"" + u + "\" style=\"color:" + ink.accent + "\">" + u + "</a>")
    s = s.replace(/\*\*([^*]+)\*\*|__([^_]+)__/g, (_, a, b) =>
        "<b style=\"color:" + ink.strong + "\">" + (a || b) + "</b>")
    s = s.replace(/(^|[^*\w])\*([^*\s][^*]*)\*(?!\w)/g, (_, p, t) => p + "<i>" + t + "</i>")
    s = s.replace(/(^|[^\w])_([^_\s][^_]*)_(?!\w)/g, (_, p, t) => p + "<i>" + t + "</i>")
    s = s.replace(/~~([^~]+)~~/g, "<s>$1</s>")
    return s.replace(/\u0000(\d+)\u0000/g, (_, n) =>
        "<span style=\"background-color:" + ink.codeFill + ";color:" + ink.codeInk + "\">&nbsp;"
        + esc(codes[Number(n)]) + "&nbsp;</span>")
}

function cells(line) {
    return line.trim().replace(/^\||\|$/g, "").split("|").map(c => c.trim())
}

// a prose block as rich text
function html(md, ink) {
    var lines = String(md || "").split("\n"), out = [], para = []
    // open lists, innermost last: { tag, indent }
    var lists = []
    function endPara() {
        if (para.length > 0) out.push("<p>" + para.map(l => inline(l, ink)).join("<br>") + "</p>")
        para = []
    }
    function closeLists(indent) {
        while (lists.length > 0 && lists[lists.length - 1].indent >= indent)
            out.push("</" + lists.pop().tag + ">")
    }
    for (var i = 0; i < lines.length; i++) {
        var l = lines[i]
        if (l.trim() === "") { endPara(); continue }
        var h = l.match(/^(#{1,6})\s+(.*)$/)
        var item = l.match(/^(\s*)([-*+]|\d+[.)])\s+(.*)$/)
        var row = /^\s*\|.*\|\s*$/.test(l)
        if (h) {
            endPara(); closeLists(0)
            var size = h[1].length <= 1 ? "large" : h[1].length === 2 ? "medium" : "normal"
            out.push("<p style=\"font-size:" + size + "\"><b style=\"color:" + ink.strong + "\">"
                + inline(h[2], ink) + "</b></p>")
        } else if (item) {
            endPara()
            var indent = item[1].replace(/\t/g, "    ").length
            var tag = /\d/.test(item[2]) ? "ol" : "ul"
            closeLists(indent + 1)
            var top = lists.length > 0 ? lists[lists.length - 1] : null
            if (!top || top.indent < indent) {
                out.push("<" + tag + ">")
                lists.push({ tag: tag, indent: indent })
            } else if (top.tag !== tag) {
                out.push("</" + lists.pop().tag + "><" + tag + ">")
                lists.push({ tag: tag, indent: indent })
            }
            out.push("<li>" + inline(item[3], ink) + "</li>")
        } else if (/^\s*>/.test(l)) {
            endPara(); closeLists(0)
            var q = []
            while (i < lines.length && /^\s*>/.test(lines[i])) q.push(lines[i++].replace(/^\s*>\s?/, ""))
            i--
            out.push("<table width=\"100%\" cellpadding=\"6\"><tr><td style=\"color:" + ink.muted + "\">"
                + q.map(x => inline(x, ink)).join("<br>") + "</td></tr></table>")
        } else if (/^\s*([-*_])(\s*\1){2,}\s*$/.test(l)) {
            endPara(); closeLists(0)
            out.push("<hr>")
        } else if (row && i + 1 < lines.length && /^\s*\|?[\s:|-]+\|?\s*$/.test(lines[i + 1])) {
            endPara(); closeLists(0)
            var head = cells(l)
            i += 2
            var t = "<table cellspacing=\"0\" cellpadding=\"4\" border=\"1\" style=\"border-color:" + ink.rule
                + ";border-style:solid\"><tr>" + head.map(c => "<th align=\"left\">" + inline(c, ink) + "</th>").join("") + "</tr>"
            while (i < lines.length && /^\s*\|.*\|\s*$/.test(lines[i]))
                t += "<tr>" + cells(lines[i++]).map(c => "<td>" + inline(c, ink) + "</td>").join("") + "</tr>"
            i--
            out.push(t + "</table>")
        } else if (lists.length > 0 && /^\s+\S/.test(l)) {
            // a wrapped list item's next line
            out[out.length - 1] = out[out.length - 1].replace(/<\/li>$/, " " + inline(l.trim(), ink) + "</li>")
        } else {
            closeLists(0)
            para.push(l)
        }
    }
    endPara()
    closeLists(0)
    return out.join("")
}
