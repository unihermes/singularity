// Singularity - Quickshell
// ~/.config/quickshell/services/HyprBinds.js
//
// Reads and rewrites the hl.bind() calls in Hyprland's Lua config, for the
// Keybinds window. Plain functions over the source text, no QML, so the
// parsing can be exercised outside the shell.
//
// This is not a Lua interpreter. It tokenizes (so strings and comments can't
// fool it), tracks block nesting, resolves top-level `local x = "literal"`
// strings, and expands numeric for-loops so loop-generated binds still show
// up. Only a bind in its simplest shape is offered for editing:
//
//   hl.bind("KEYS" | ident .. " + KEYS", hl.dsp.exec_cmd("cmd" | ident) [, { opts }])
//
// on lines of its own, outside any block. Everything else is listed read-only
// with the reason, because rewriting an expression it only half understands
// is how a config gets broken.
//
// Categories come from marker comments, `-- --- Window Management ---`; a
// section banner (`---- WINDOW RULES ----`) ends the current one.

var MARKER = /^--\s*---\s+(.+?)\s+---\s*$/
var BANNER = /^----\s+.+?\s+----\s*$/

var MOD_ALIASES = {
    SUPER: "SUPER", WIN: "SUPER", LOGO: "SUPER", MOD4: "SUPER", META: "SUPER",
    CTRL: "CTRL", CONTROL: "CTRL",
    ALT: "ALT", MOD1: "ALT",
    SHIFT: "SHIFT",
    MOD2: "MOD2", MOD3: "MOD3", MOD5: "MOD5", ALTGR: "MOD5",
}
var MOD_ORDER = ["SUPER", "CTRL", "ALT", "SHIFT", "MOD2", "MOD3", "MOD5"]

// --- tokenizer -----------------------------------------------------------

// level of a long bracket opening at p ("[[" is 0, "[==[" is 2), or -1
function longBracket(src, p) {
    if (src[p] !== "[") return -1
    var q = p + 1
    while (src[q] === "=") q++
    return src[q] === "[" ? q - p - 1 : -1
}

function countNewlines(src, from, to) {
    var n = 0
    for (var i = from; i < to; i++) if (src[i] === "\n") n++
    return n
}

var ESCAPES = { n: "\n", t: "\t", r: "\r", "\\": "\\", "\"": "\"", "'": "'", "\n": "\n" }

// [{ t: "comment"|"str"|"name"|"num"|"op", v, s, e, line }], where v for a
// string is its decoded value
function tokenize(src) {
    var toks = []
    var i = 0, line = 1, n = src.length
    while (i < n) {
        var c = src[i]
        if (c === "\n") { line++; i++; continue }
        if (c === " " || c === "\t" || c === "\r") { i++; continue }
        var s = i, startLine = line, lb, e

        if (c === "-" && src[i + 1] === "-") {
            lb = longBracket(src, i + 2)
            if (lb >= 0) {
                var close = "]" + "=".repeat(lb) + "]"
                e = src.indexOf(close, i + 4 + lb)
                e = e < 0 ? n : e + close.length
            } else {
                e = src.indexOf("\n", i)
                if (e < 0) e = n
            }
            line += countNewlines(src, i, e)
            toks.push({ t: "comment", v: src.slice(i, e).replace(/\r$/, ""), s: s, e: e, line: startLine })
            i = e
            continue
        }

        if (c === "\"" || c === "'") {
            var j = i + 1, out = ""
            while (j < n && src[j] !== c && src[j] !== "\n") {
                if (src[j] === "\\" && j + 1 < n) {
                    var x = src[j + 1]
                    if (x === "\n") line++
                    out += ESCAPES[x] !== undefined ? ESCAPES[x] : "\\" + x
                    j += 2
                } else {
                    out += src[j++]
                }
            }
            e = Math.min(n, j + 1)
            toks.push({ t: "str", v: out, s: s, e: e, line: startLine })
            i = e
            continue
        }

        lb = longBracket(src, i)
        if (lb >= 0) {
            var closeStr = "]" + "=".repeat(lb) + "]"
            var body = i + 2 + lb
            e = src.indexOf(closeStr, body)
            var end = e < 0 ? n : e
            e = e < 0 ? n : e + closeStr.length
            line += countNewlines(src, i, e)
            // a newline straight after the opening bracket isn't part of the string
            toks.push({ t: "str", v: src.slice(body, end).replace(/^\r?\n/, ""), s: s, e: e, line: startLine })
            i = e
            continue
        }

        if (/[A-Za-z_]/.test(c)) {
            e = i + 1
            while (e < n && /[A-Za-z0-9_]/.test(src[e])) e++
            toks.push({ t: "name", v: src.slice(i, e), s: s, e: e, line: startLine })
            i = e
            continue
        }

        if (/[0-9]/.test(c) || (c === "." && /[0-9]/.test(src[i + 1] || ""))) {
            e = i + 1
            while (e < n && (/[0-9A-Za-z_]/.test(src[e]) || (src[e] === "." && src[e + 1] !== "."))) e++
            toks.push({ t: "num", v: src.slice(i, e), s: s, e: e, line: startLine })
            i = e
            continue
        }

        var three = src.substr(i, 3), two = src.substr(i, 2)
        var op = three === "..." ? three
            : ["..", "==", "~=", "<=", ">=", "::", "//", "<<", ">>"].indexOf(two) >= 0 ? two
            : c
        toks.push({ t: "op", v: op, s: s, e: i + op.length, line: startLine })
        i += op.length
    }
    return toks
}

// --- evaluation ----------------------------------------------------------

// A concatenation of strings, numbers and resolvable names; null otherwise.
function evalConcat(toks, env, locals) {
    if (toks.length === 0 || toks.length % 2 === 0) return null
    var out = ""
    for (var i = 0; i < toks.length; i++) {
        var t = toks[i]
        if (i % 2 === 1) {
            if (t.t !== "op" || t.v !== "..") return null
            continue
        }
        if (t.t === "str") out += t.v
        else if (t.t === "num") out += t.v
        else if (t.t === "name" && env[t.v] !== undefined) out += String(env[t.v])
        else if (t.t === "name" && locals[t.v] !== undefined) out += locals[t.v]
        else return null
    }
    return out
}

// Source text of a token run, with loop variables replaced by this
// iteration's value -- but not table keys (`workspace = i` keeps its key).
function substituted(src, toks, env) {
    if (toks.length === 0) return ""
    var out = "", pos = toks[0].s
    for (var i = 0; i < toks.length; i++) {
        var t = toks[i]
        out += src.slice(pos, t.s)
        var prev = toks[i - 1], next = toks[i + 1]
        var isVar = t.t === "name" && env[t.v] !== undefined
            && !(prev && prev.t === "op" && prev.v === ".")
            && !(next && next.t === "op" && next.v === "=")
        out += isVar ? String(env[t.v]) : src.slice(t.s, t.e)
        pos = t.e
    }
    return out
}

// "toggleMaximize" -> "Toggle maximize"
function humanize(ident) {
    var w = ident.replace(/([a-z0-9])([A-Z])/g, "$1 $2").replace(/[._-]+/g, " ").toLowerCase()
    return w.charAt(0).toUpperCase() + w.slice(1)
}

function describeRaw(path, inner) {
    var p = path.replace(/^hl\.dsp\./, "")
    function kv(key) {
        var m = inner.match(new RegExp(key + "\\s*=\\s*\"?([\\w.-]+)\"?"))
        return m ? m[1] : null
    }
    var where = { left: "to the left", right: "to the right", up: "above", down: "below",
                  l: "to the left", r: "to the right", u: "above", d: "below" }
    switch (p) {
    case "window.close":      return "Close window"
    case "window.fullscreen": return kv("mode") === "maximized" ? "Maximize or restore window" : "Fullscreen window"
    case "window.float":      return "Float or tile window"
    case "window.pseudo":     return "Keep window's own size in its tile"
    case "window.drag":       return "Move window by dragging"
    case "window.resize":     return "Resize window by dragging"
    case "exit":              return "Log out"
    case "window.move":
        if (kv("workspace")) return "Move window to workspace " + kv("workspace")
        if (kv("direction")) return "Move window " + (where[kv("direction")] || kv("direction"))
        break
    case "focus":
        if (kv("workspace")) return "Go to workspace " + kv("workspace")
        if (kv("direction")) return "Focus window " + (where[kv("direction")] || kv("direction"))
        break
    case "layout":
        var m = inner.match(/"([^"]+)"/)
        if (m && m[1] === "togglesplit") return "Split side by side or stacked"
        if (m) return humanize(m[1])
        break
    case "function":
        // an inline closure: name it after the function it calls
        var f = inner.match(/([A-Za-z_]\w*)\s*\(/g)
        if (f) return humanize(f[f.length - 1].replace(/\s*\($/, ""))
        return "Custom action"
    }
    return humanize(p.replace(/^window\./, ""))
}

function describeExec(cmd, ident) {
    if (ident) return "Open " + humanize(ident).toLowerCase()
    var c = cmd.trim(), m
    if ((m = c.match(/wpctl set-volume .*@DEFAULT_AUDIO_(SINK|SOURCE)@ [\d.]+%?([+-])/)))
        return (m[1] === "SOURCE" ? "Microphone " : "Volume ") + (m[2] === "+" ? "up" : "down")
    if ((m = c.match(/wpctl set-mute @DEFAULT_AUDIO_(SINK|SOURCE)@/)))
        return m[1] === "SOURCE" ? "Mute or unmute microphone" : "Mute or unmute sound"
    if ((m = c.match(/brightnessctl .*set [\d.]+%?([+-])/)))
        return "Brightness " + (m[1] === "+" ? "up" : "down")
    if ((m = c.match(/^qs ipc call (\S+)(?: (\S+))?/)))
        return humanize(((m[2] || "") + " " + m[1]).trim())
    var w = c.split(/\s+/)
    var first = (w[0] || "").replace(/^.*\//, "").replace(/\.(sh|py)$/, "")
    if (/\//.test(w[0] || "")) return "Run " + first.replace(/[-_]/g, " ") + " script"
    return "Open " + first
}

// --- keys ----------------------------------------------------------------

// { mods: canonical names in MOD_ORDER, rest: the non-modifier parts as typed }
function splitKeys(keys) {
    var parts = String(keys).split("+").map(function(s) { return s.trim() }).filter(function(s) { return s !== "" })
    var mods = [], rest = []
    for (var i = 0; i < parts.length; i++) {
        var m = MOD_ALIASES[parts[i].toUpperCase()]
        if (m) { if (mods.indexOf(m) < 0) mods.push(m) }
        else rest.push(parts[i])
    }
    mods.sort(function(a, b) { return MOD_ORDER.indexOf(a) - MOD_ORDER.indexOf(b) })
    return { mods: mods, rest: rest }
}

// For comparison only: canonical modifiers, then the key uppercased
// (Hyprland matches keysym names case-insensitively).
function normalizeKeys(keys) {
    var k = splitKeys(keys)
    return k.mods.concat(k.rest.length ? [k.rest[k.rest.length - 1].toUpperCase()] : []).join(" + ")
}

// For writing: modifiers canonical and first, the key as typed.
function tidyKeys(keys) {
    var k = splitKeys(keys)
    return { text: k.mods.concat(k.rest).join(" + "), keyCount: k.rest.length }
}

// --- parse ---------------------------------------------------------------

function parse(src) {
    var toks = tokenize(src)
    var code = []
    for (var k = 0; k < toks.length; k++) {
        toks[k].k = k
        if (toks[k].t !== "comment") { toks[k].ci = code.length; code.push(toks[k]) }
    }
    function isOp(t, v) { return t && t.t === "op" && t.v === v }
    function isName(t, v) { return t && t.t === "name" && (v === undefined || t.v === v) }

    var lineStarts = [0]
    for (var p = 0; p < src.length; p++) if (src[p] === "\n") lineStarts.push(p + 1)

    var locals = {}
    var stack = []
    var expectDo = false
    var category = ""
    var categories = []
    var calls = []

    for (k = 0; k < toks.length; k++) {
        var tk = toks[k]
        if (tk.t === "comment") {
            var m = tk.v.match(MARKER)
            if (m) {
                category = m[1]
                if (!categories.some(function(c) { return c.name === category }))
                    categories.push({ name: category, insertLine: tk.line })
            } else if (BANNER.test(tk.v)) {
                category = ""
            }
            continue
        }
        if (tk.t !== "name") continue
        var ci = tk.ci
        if (isOp(code[ci - 1], ".") || isOp(code[ci - 1], ":")) continue

        switch (tk.v) {
        case "function": case "if": case "repeat":
            stack.push({ kind: "block" })
            break
        case "while":
            stack.push({ kind: "block" })
            expectDo = true
            break
        case "for":
            var frame = { kind: "for" }
            var c = code
            // a loop bound is a number literal or a top-level numeric local
            // (`for i = 1, MAX_WORKSPACES do`)
            var num = function(t) {
                if (t && t.t === "num") return Number(t.v)
                if (isName(t) && typeof locals[t.v] === "number") return locals[t.v]
                return NaN
            }
            if (isName(c[ci + 1]) && isOp(c[ci + 2], "=") && !isNaN(num(c[ci + 3]))
                    && isOp(c[ci + 4], ",") && !isNaN(num(c[ci + 5]))) {
                var step = 1, doAt = ci + 6
                if (isOp(c[ci + 6], ",") && !isNaN(num(c[ci + 7]))) { step = num(c[ci + 7]); doAt = ci + 8 }
                if (isName(c[doAt], "do") && step !== 0) {
                    frame.var = c[ci + 1].v
                    frame.from = num(c[ci + 3])
                    frame.to = num(c[ci + 5])
                    frame.step = step
                }
            }
            stack.push(frame)
            expectDo = true
            break
        case "do":
            if (expectDo) expectDo = false
            else stack.push({ kind: "block" })
            break
        case "end": case "until":
            var popped = stack.pop()
            if (popped) popped.endLine = tk.line
            break
        case "local":
            if (stack.length === 0 && isName(code[ci + 1]) && isOp(code[ci + 2], "=")
                    && code[ci + 3] && !isOp(code[ci + 4], "..")) {
                if (code[ci + 3].t === "str") locals[code[ci + 1].v] = code[ci + 3].v
                else if (code[ci + 3].t === "num" && !isOp(code[ci + 4], "+") && !isOp(code[ci + 4], "-")
                        && !isOp(code[ci + 4], "*") && !isOp(code[ci + 4], "/"))
                    locals[code[ci + 1].v] = Number(code[ci + 3].v)
            }
            break
        case "hl":
            if (!(isOp(code[ci + 1], ".") && isName(code[ci + 2], "bind") && isOp(code[ci + 3], "("))) break
            var depth = 0, args = [], cur = [], closeTok = null
            for (var j = ci + 4; j < code.length; j++) {
                var t = code[j]
                if (t.t === "op" && (t.v === "(" || t.v === "{" || t.v === "[")) depth++
                else if (t.t === "op" && (t.v === ")" || t.v === "}" || t.v === "]")) {
                    if (depth === 0) { closeTok = t; break }
                    depth--
                } else if (isOp(t, ",") && depth === 0) {
                    args.push(cur); cur = []
                    continue
                }
                cur.push(t)
            }
            if (!closeTok) break
            if (cur.length) args.push(cur)
            var after = toks[closeTok.k + 1]
            calls.push({
                args: args,
                s: tk.s, e: closeTok.e,
                line: tk.line, endLine: closeTok.line,
                comment: after && after.t === "comment" && after.line === closeTok.line ? after : null,
                category: category,
                frames: stack.slice(),
            })
            k = closeTok.k
            break
        }
    }

    // `mod` in `mod .. " + Q"`: the prefix new SUPER binds are written with
    var prefixCounts = {}

    var rows = []
    for (var n = 0; n < calls.length; n++) {
        var call = calls[n]
        var a = call.args
        if (a.length < 2) continue

        // own lines: nothing but whitespace before the call, and nothing but
        // whitespace or its comment after
        var ls = lineStarts[call.line - 1]
        var le = call.endLine < lineStarts.length ? lineStarts[call.endLine] - 1 : src.length
        var tailEnd = call.comment ? call.comment.s : le
        var ownLines = /^[ \t]*$/.test(src.slice(ls, call.s)) && /^[ \t\r]*$/.test(src.slice(call.e, tailEnd))

        var k0 = a[0]
        var keysForm = k0.length === 1 && k0[0].t === "str" ? "literal"
            : k0.length === 3 && isName(k0[0]) && typeof locals[k0[0].v] === "string" && isOp(k0[1], "..") && k0[2].t === "str" ? "prefixed"
            : "expr"
        if (keysForm === "prefixed") prefixCounts[k0[0].v] = (prefixCounts[k0[0].v] || 0) + 1

        var d = a[1]
        var isExec = d.length >= 7 && isName(d[0], "hl") && isOp(d[1], ".") && isName(d[2], "dsp")
            && isOp(d[3], ".") && isName(d[4], "exec_cmd") && isOp(d[5], "(") && isOp(d[d.length - 1], ")")
        var inner = isExec ? d.slice(6, d.length - 1) : []
        var cmdForm = !isExec ? "raw"
            : inner.length === 1 && inner[0].t === "str" ? "literal"
            : inner.length === 1 && isName(inner[0]) && typeof locals[inner[0].v] === "string" ? "ident"
            : "expr"

        var path = ""
        for (var q = 0; q < d.length && !isOp(d[q], "("); q++) path += d[q].v
        var parenAt = q

        var opts = a.length >= 3 ? src.slice(a[2][0].s, a[2][a[2].length - 1].e) : ""
        var flags = []
        var fm, flagRe = /([A-Za-z_]\w*)\s*=\s*true/g
        while ((fm = flagRe.exec(opts)) !== null) flags.push(fm[1])

        // one env per loop iteration; a loop it can't count gives one
        // unresolved row
        var loops = call.frames.filter(function(f) { return f.kind === "for" })
        var envs = [{}]
        if (loops.some(function(f) { return f.var === undefined })) {
            envs = [{}]
        } else {
            for (var li = 0; li < loops.length; li++) {
                var L = loops[li], next = []
                for (var ei = 0; ei < envs.length && next.length < 500; ei++) {
                    for (var v = L.from; L.step > 0 ? v <= L.to : v >= L.to; v += L.step) {
                        var env = Object.assign({}, envs[ei])
                        env[L.var] = v
                        next.push(env)
                        if (next.length >= 500) break
                    }
                }
                envs = next
            }
        }

        var reason = ""
        if (loops.length) reason = "Made by a loop"
        else if (call.frames.length) reason = "Inside other code"
        else if (!isExec) reason = "Runs a Hyprland action rather than a command"
        else if (keysForm === "expr") reason = "Its keys are worked out in code"
        else if (cmdForm === "expr") reason = "Its command is worked out in code"
        else if (!ownLines) reason = "Shares its line with other code"

        var outer = call.frames.length ? call.frames[0] : null

        for (var en = 0; en < envs.length; en++) {
            var envN = envs[en]
            var keys = evalConcat(k0, envN, locals)
            var keysText = keys !== null ? keys : substituted(src, k0, envN)
            var command, desc
            if (isExec) {
                var cv = evalConcat(inner, envN, locals)
                command = cv !== null ? cv : substituted(src, inner, envN)
                desc = describeExec(command, cmdForm === "ident" ? inner[0].v : "")
            } else {
                command = substituted(src, d, envN).replace(/^hl\.dsp\./, "")
                desc = describeRaw(path, substituted(src, d.slice(parenAt), envN))
            }
            var commentText = call.comment ? call.comment.v.replace(/^--\s*/, "").trim() : ""
            rows.push({
                id: call.s + ":" + en,
                callStart: call.s,
                line: call.line,
                endLine: call.endLine,
                category: call.category,
                keys: keysText,
                norm: normalizeKeys(keysText),
                command: command,
                isExec: isExec,
                comment: commentText,
                desc: commentText !== "" ? commentText : desc,
                autoDesc: desc,
                flags: flags,
                editable: reason === "" && keys !== null,
                reason: reason,
                keysForm: keysForm,
                keysIdent: keysForm === "prefixed" ? k0[0].v : "",
                keysSpan: [k0[0].s, k0[k0.length - 1].e],
                keysSrc: src.slice(k0[0].s, k0[k0.length - 1].e),
                cmdSpan: [d[0].s, d[d.length - 1].e],
                cmdSrc: src.slice(d[0].s, d[d.length - 1].e),
                optsSrc: opts,
                optsSpan: a.length >= 3 ? [a[2][0].s, a[2][a[2].length - 1].e] : null,
                callEnd: call.e,
                commentSpan: call.comment ? [call.comment.s, call.comment.e] : null,
                insertLine: outer && outer.endLine ? outer.endLine : call.endLine,
            })
        }
    }

    // a category's new binds go after its last one
    for (var r = 0; r < rows.length; r++) {
        for (var cc = 0; cc < categories.length; cc++)
            if (categories[cc].name === rows[r].category)
                categories[cc].insertLine = Math.max(categories[cc].insertLine, rows[r].insertLine)
    }

    // duplicates already in the file get flagged too
    var byNorm = {}
    rows.forEach(function(row) { (byNorm[row.norm] = byNorm[row.norm] || []).push(row) })
    rows.forEach(function(row) {
        row.conflict = byNorm[row.norm].some(function(o) { return o.callStart !== row.callStart })
    })

    var prefixIdent = ""
    for (var id in prefixCounts)
        if (prefixIdent === "" || prefixCounts[id] > prefixCounts[prefixIdent]) prefixIdent = id

    return {
        src: src,
        rows: rows,
        categories: categories,
        locals: locals,
        prefixIdent: prefixIdent,
        lineStarts: lineStarts,
    }
}

// Other binds on the same combo, leaving out the call being edited.
function conflictsFor(model, keys, exceptCallStart) {
    var norm = normalizeKeys(keys)
    if (norm === "") return []
    return model.rows.filter(function(r) { return r.norm === norm && r.callStart !== exceptCallStart })
}

// --- rewrite -------------------------------------------------------------

function luaString(s) {
    return "\"" + String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"")
        .replace(/\n/g, "\\n").replace(/\r/g, "\\r").replace(/\t/g, "\\t") + "\""
}

function oneLine(s) {
    return String(s || "").replace(/\s*[\r\n]+\s*/g, " ").trim()
}

// keeps the file's `mod .. " + Q"` style when the combo starts with mod's value
function keysSource(keys, ident, locals) {
    if (ident && typeof locals[ident] === "string") {
        var p = locals[ident] + " + "
        if (keys.indexOf(p) === 0 && keys.length > p.length)
            return ident + " .. " + luaString(" + " + keys.slice(p.length))
    }
    return luaString(keys)
}

function lineRange(model, first, last) {
    var s = model.lineStarts[first - 1]
    var e = last < model.lineStarts.length ? model.lineStarts[last] : model.src.length
    return [s, e]
}

function callSource(keysSrc, cmdSrc, optsSrc) {
    return "hl.bind(" + [keysSrc, cmdSrc].concat(optsSrc ? [optsSrc] : []).join(", ") + ")"
}

// A section the config doesn't have yet gets one, rather than the bind
// landing under whatever section happens to be last: presets come with the
// section they belong in, and "Groups" or "Session" may be new here.
function insertCall(model, category, text) {
    var cat = null
    for (var i = 0; i < model.categories.length; i++)
        if (model.categories[i].name === category) cat = model.categories[i]
    var newSection = !cat && category !== "" && model.rows.length > 0
    var line = cat ? cat.insertLine
        : model.rows.length ? model.rows[model.rows.length - 1].insertLine
        : model.lineStarts.length
    var r = lineRange(model, line, line)
    var src = model.src
    var at = r[1]
    var indent = (src.slice(r[0], r[1]).match(/^[ \t]*/) || [""])[0]
    if (at === src.length && src.length > 0 && src[src.length - 1] !== "\n") { src += "\n"; at++ }
    var head = newSection ? "\n" + indent + "-- --- " + category + " ---\n" : ""
    return src.slice(0, at) + head + indent + text + "\n" + src.slice(at)
}

// The second argument to hl.bind(): a command wrapped in exec_cmd, or a
// dispatcher expression written out as given (presets, and the editor's Lua
// mode). Never guessed at -- whatever it is, luac sees it before the file does.
function actionSource(fields) {
    if (fields.kind === "lua") return oneLine(fields.src)
    return "hl.dsp.exec_cmd(" + luaString(fields.command) + ")"
}

// hl.bind's options table from a set of boolean flags, or "" for none
var FLAG_ORDER = ["locked", "repeating", "mouse", "release", "long_press", "non_consuming"]

function optsSource(flags) {
    var parts = []
    for (var i = 0; i < FLAG_ORDER.length; i++)
        if (flags && flags[FLAG_ORDER[i]]) parts.push(FLAG_ORDER[i] + " = true")
    return parts.length ? "{ " + parts.join(", ") + " }" : ""
}

// The reverse, for prefilling the editor: { simple, flags }. simple is false
// for an options table holding anything but `name = true`, which the editor
// then leaves alone rather than rewriting into something shorter.
function readOpts(optsSrc) {
    var s = String(optsSrc || "").trim()
    if (s === "") return { simple: true, flags: {} }
    var m = s.match(/^\{([^{}]*)\}$/)
    if (!m) return { simple: false, flags: {} }
    var body = m[1].trim()
    var flags = {}
    if (body !== "") {
        var parts = body.split(",")
        for (var i = 0; i < parts.length; i++) {
            var p = parts[i].trim()
            if (p === "") continue
            var kv = p.match(/^([A-Za-z_]\w*)\s*=\s*true$/)
            if (!kv) return { simple: false, flags: {} }
            flags[kv[1]] = true
        }
    }
    return { simple: true, flags: flags }
}

// fields: { keys, command, desc, category, kind, src, opts }
function addBind(model, fields) {
    var keys = tidyKeys(fields.keys).text
    var desc = oneLine(fields.desc)
    var text = callSource(keysSource(keys, model.prefixIdent, model.locals),
        actionSource(fields), oneLine(fields.opts))
    return insertCall(model, fields.category, text + (desc ? " -- " + desc : ""))
}

// Several at once (a preset pack), as one new file: each insert moves every
// offset after it, so the text is re-read between them.
function addBinds(model, list) {
    var m = model, src = model.src
    for (var i = 0; i < list.length; i++) {
        src = addBind(m, list[i])
        if (i < list.length - 1) m = parse(src)
    }
    return src
}

function removeBind(model, row) {
    var r = lineRange(model, row.line, row.endLine)
    return model.src.slice(0, r[0]) + model.src.slice(r[1])
}

function editBind(model, row, fields) {
    var keys = tidyKeys(fields.keys).text
    var desc = oneLine(fields.desc)
    var kind = fields.kind === "lua" ? "lua" : "exec"
    var keysChanged = keys !== row.keys
    // for a command, compare the command rather than the source: unchanged
    // text keeps `exec_cmd(terminal)` as the ident it was written as
    var cmdChanged = kind === "lua" ? oneLine(fields.src) !== row.cmdSrc
        : !row.isExec || fields.command !== row.command
    var newKeys = keysChanged ? keysSource(keys, row.keysIdent || model.prefixIdent, model.locals) : row.keysSrc
    var newCmd = cmdChanged ? actionSource(fields) : row.cmdSrc
    var newOpts = fields.opts === undefined ? row.optsSrc : oneLine(fields.opts)

    if (fields.category !== row.category) {
        var moved = parse(removeBind(model, row))
        return insertCall(moved, fields.category,
            callSource(newKeys, newCmd, newOpts) + (desc ? " -- " + desc : ""))
    }

    // in place, span by span, so the file's column alignment survives
    var reps = []
    if (keysChanged) reps.push([row.keysSpan[0], row.keysSpan[1], newKeys])
    if (cmdChanged) reps.push([row.cmdSpan[0], row.cmdSpan[1], newCmd])
    if (newOpts !== row.optsSrc) {
        // the options table, the comma before it, or neither
        if (row.optsSpan && newOpts === "") reps.push([row.cmdSpan[1], row.optsSpan[1], ""])
        else if (row.optsSpan) reps.push([row.optsSpan[0], row.optsSpan[1], newOpts])
        else reps.push([row.callEnd - 1, row.callEnd - 1, ", " + newOpts])
    }
    if (desc !== row.comment) {
        if (row.commentSpan && desc === "") reps.push([row.callEnd, row.commentSpan[1], ""])
        else if (row.commentSpan) reps.push([row.commentSpan[0], row.commentSpan[1], "-- " + desc])
        else reps.push([row.callEnd, row.callEnd, " -- " + desc])
    }
    reps.sort(function(x, y) { return y[0] - x[0] })
    var src = model.src
    for (var i = 0; i < reps.length; i++)
        src = src.slice(0, reps[i][0]) + reps[i][2] + src.slice(reps[i][1])
    return src
}
