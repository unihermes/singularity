// Shared transcript and conversation state for the CLI adapters.
import Quickshell
import QtQuick

Scope {
    property string cwd: ""
    property string modelPick: ""
    property string mode: "default"
    property bool busy: false
    property string sessionId: ""
    property string activity: ""
    property string modelName: ""
    property var slashCommands: []
    property int contextUsed: 0
    property int contextWindow: 0
    property bool unseen: false
    // [{ id, tool, input, title, detail, suggestions }]
    property var asks: []
    // [{ kind: "image" | "text", label, path, media, data, text }]
    property var attachments: []

    readonly property alias entries: rows
    readonly property alias transcript: rows
    readonly property bool empty: rows.count === 0
    signal edited()
    signal rateLimit(var info)
    signal turnEnded()
    signal asked(string title)

    ListModel { id: rows }

    function attach(a) { if (a) attachments = attachments.concat([a]) }
    function unattach(i) {
        var a = attachments.slice()
        a.splice(i, 1)
        attachments = a
    }

    function lastReply() {
        for (var i = rows.count - 1; i >= 0; i--) {
            var r = rows.get(i)
            if (r.kind === "user") return ""
            if (r.kind === "assistant" || r.kind === "error") return r.text
        }
        return ""
    }

    // Rows retain every role and their index for the lifetime of a conversation.
    function add(o) {
        rows.append({
            kind: o.kind, text: o.text || "", note: o.note || "", images: o.images || "",
            name: o.name || "", detail: o.detail || "", body: o.body || "", result: o.result || "",
            toolId: o.toolId || "", phase: o.phase || "", streaming: !!o.streaming, open: false
        })
        return rows.count - 1
    }
    function setRow(i, o) { for (var k in o) rows.setProperty(i, k, o[k]) }
    function clip(t) { return t.length > 4000 ? t.slice(0, 4000) + "\n…" : t }
    function rel(p) {
        p = String(p || "")
        return cwd !== "" && p.indexOf(cwd + "/") === 0 ? p.slice(cwd.length + 1) : p
    }
}
