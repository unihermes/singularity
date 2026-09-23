// Singularity - Quickshell
// ~/.config/quickshell/services/Calc.js
//
// The launcher's calculator mode: a small expression evaluator, used as
// `Calc.evaluate("2 + 2 * 3")`.
//
// Hand-written tokeniser and recursive-descent parser rather than a call to
// JavaScript's eval(). eval would run anything the box is given -- including
// property writes and function calls reachable from this scope -- and the
// launcher is a global hotkey away at all times. This understands numbers
// and the operators below, and nothing else: anything it doesn't recognise
// comes back as an error instead of running.
//
// Supported: + - * / and ^, parentheses, unary minus, `mod`, a trailing %
// (which is just /100), the constants pi/e/tau, and the functions listed in
// FUNCS. Numbers may be decimal, hex (0x1f) or binary (0b1011), and may use
// _ as a digit separator.
//
// `mod` is a word rather than the usual % because % is already the percent
// suffix; "10 % 3" is ambiguous in a box where "20% of" is the common case.

.pragma library

var CONSTS = {
    pi: Math.PI,
    e: Math.E,
    tau: Math.PI * 2,
}

var FUNCS = {
    sqrt: Math.sqrt, cbrt: Math.cbrt, abs: Math.abs,
    round: Math.round, floor: Math.floor, ceil: Math.ceil,
    ln: Math.log, log: function (x) { return Math.log(x) / Math.LN10 },
    log2: Math.log2, exp: Math.exp,
    sin: Math.sin, cos: Math.cos, tan: Math.tan,
    asin: Math.asin, acos: Math.acos, atan: Math.atan,
    min: Math.min, max: Math.max,
}

function tokenise(src) {
    var out = [], i = 0
    while (i < src.length) {
        var c = src[i]
        if (c === " " || c === "\t" || c === ",") { i++; continue }
        if ("+-*/^()%".indexOf(c) !== -1) { out.push({ t: c }); i++; continue }
        if (/[0-9.]/.test(c)) {
            var m = /^(0x[0-9a-fA-F_]+|0b[01_]+|[0-9_]*\.?[0-9_]+(e[+-]?[0-9]+)?)/.exec(src.slice(i))
            if (!m) throw "bad number"
            var raw = m[1].replace(/_/g, "")
            var v = raw.indexOf("0x") === 0 ? parseInt(raw.slice(2), 16)
                : raw.indexOf("0b") === 0 ? parseInt(raw.slice(2), 2)
                : parseFloat(raw)
            if (isNaN(v)) throw "bad number"
            out.push({ t: "num", v: v })
            i += m[1].length
            continue
        }
        if (/[a-zA-Z]/.test(c)) {
            var w = /^[a-zA-Z][a-zA-Z0-9]*/.exec(src.slice(i))[0]
            out.push({ t: "word", v: w.toLowerCase() })
            i += w.length
            continue
        }
        throw "unexpected " + c
    }
    return out
}

// expr := term (("+"|"-") term)*
// term := power (("*"|"/"|"mod") power)*
// power := unary ("^" power)?          -- right associative
// unary := ("-"|"+")* postfix
// postfix := atom "%"*
// atom := number | const | func "(" expr ("," expr)* ")" | "(" expr ")"
function parse(tokens) {
    var pos = 0

    function peek() { return tokens[pos] }
    function take() { return tokens[pos++] }
    function expect(t) {
        var tok = take()
        if (!tok || tok.t !== t) throw "expected " + t
        return tok
    }

    function expr() {
        var v = term()
        while (peek() && (peek().t === "+" || peek().t === "-")) {
            var op = take().t
            var r = term()
            v = op === "+" ? v + r : v - r
        }
        return v
    }

    function term() {
        var v = power()
        while (peek() && (peek().t === "*" || peek().t === "/"
                || (peek().t === "word" && peek().v === "mod"))) {
            var op = take()
            var r = power()
            if (op.t === "*") v = v * r
            else if (op.t === "/") v = v / r
            else v = v % r
        }
        return v
    }

    function power() {
        var v = unary()
        if (peek() && peek().t === "^") {
            take()
            return Math.pow(v, power())
        }
        return v
    }

    function unary() {
        if (peek() && (peek().t === "-" || peek().t === "+")) {
            var op = take().t
            var v = unary()
            return op === "-" ? -v : v
        }
        return postfix()
    }

    function postfix() {
        var v = atom()
        while (peek() && peek().t === "%") { take(); v = v / 100 }
        return v
    }

    function atom() {
        var tok = take()
        if (!tok) throw "unexpected end"
        if (tok.t === "num") return tok.v
        if (tok.t === "(") {
            var v = expr()
            expect(")")
            return v
        }
        if (tok.t === "word") {
            if (tok.v in CONSTS) return CONSTS[tok.v]
            if (tok.v in FUNCS) {
                expect("(")
                var args = [expr()]
                while (peek() && peek().t !== ")") args.push(expr())
                expect(")")
                return FUNCS[tok.v].apply(null, args)
            }
            throw "unknown " + tok.v
        }
        throw "unexpected token"
    }

    var value = expr()
    if (pos !== tokens.length) throw "trailing input"
    return value
}

// 12 significant digits, then trailing zeros dropped: enough that 1/3 reads
// as 0.333333333333 and 0.1 + 0.2 doesn't read as 0.30000000000000004.
function format(n) {
    if (!isFinite(n)) return n > 0 ? "Infinity" : (n < 0 ? "-Infinity" : "NaN")
    if (Number.isInteger(n) && Math.abs(n) < 1e15) return String(n)
    var s = n.toPrecision(12)
    if (s.indexOf("e") === -1 && s.indexOf(".") !== -1)
        s = s.replace(/0+$/, "").replace(/\.$/, "")
    return s
}

// { ok, value, text } -- text is the formatted result, or the reason it
// isn't one. An empty box is not an error, just nothing to show.
function evaluate(src) {
    var s = String(src || "").trim().replace(/=+$/, "").trim()
    if (s === "") return { ok: false, value: 0, text: "" }
    try {
        var v = parse(tokenise(s))
        if (typeof v !== "number" || isNaN(v)) return { ok: false, value: 0, text: "Not a number" }
        return { ok: true, value: v, text: format(v) }
    } catch (err) {
        return { ok: false, value: 0, text: typeof err === "string" ? err : "Invalid expression" }
    }
}

// What the mode can do, listed in the launcher under the result so the
// syntax is discoverable without leaving the box. `insert` is what typing
// Enter on the row appends to the expression -- a function gets its opening
// bracket, an operator gets spaces around it.
var REFERENCE = [
    { name: "+  -  *  /", desc: "add, subtract, multiply, divide", insert: " + " },
    { name: "^", desc: "power, right associative: 2^3^2 = 512", insert: "^" },
    { name: "mod", desc: "remainder: 10 mod 3 = 1", insert: " mod " },
    { name: "%", desc: "percent, a trailing /100: 200 * 15% = 30", insert: "%" },
    { name: "( )", desc: "grouping: (1 + 2) * 3 = 9", insert: "(" },
    { name: "sqrt(x)", desc: "square root", insert: "sqrt(" },
    { name: "cbrt(x)", desc: "cube root", insert: "cbrt(" },
    { name: "abs(x)", desc: "absolute value", insert: "abs(" },
    { name: "round(x)", desc: "nearest whole number", insert: "round(" },
    { name: "floor(x)", desc: "round down", insert: "floor(" },
    { name: "ceil(x)", desc: "round up", insert: "ceil(" },
    { name: "min(a, b)", desc: "smaller of the two", insert: "min(" },
    { name: "max(a, b)", desc: "larger of the two", insert: "max(" },
    { name: "ln(x)", desc: "natural log", insert: "ln(" },
    { name: "log(x)", desc: "log base 10", insert: "log(" },
    { name: "log2(x)", desc: "log base 2", insert: "log2(" },
    { name: "exp(x)", desc: "e to the power of x", insert: "exp(" },
    { name: "sin(x)  cos(x)  tan(x)", desc: "trigonometry, in radians", insert: "sin(" },
    { name: "asin(x)  acos(x)  atan(x)", desc: "inverse trigonometry", insert: "asin(" },
    { name: "pi  e  tau", desc: "3.14159..., 2.71828..., 2 pi", insert: "pi" },
    { name: "0x1f  0b1011", desc: "hex and binary literals", insert: "0x" },
    { name: "1_000_000", desc: "_ as a digit separator", insert: "_" },
]

// The reference rows to show under the result. With something typed, only
// the ones matching the word being typed -- "sq" narrows to sqrt -- so the
// list doubles as completion; with nothing typed, all of them.
function reference(src) {
    var s = String(src || "").trim().toLowerCase()
    // only a part-typed name narrows the list; a trailing number would
    // match every description that happens to contain that digit
    var word = /[a-z][a-z0-9]*$/.exec(s)
    if (s === "" || !word) return REFERENCE
    var w = word[0]
    // name matches are what completion is for; descriptions are only
    // searched when the name turns nothing up, or typing "ne" would offer
    // round(x) for the "nearest" in its description
    var byName = REFERENCE.filter(function (r) {
        return r.name.toLowerCase().indexOf(w) !== -1
    })
    if (byName.length > 0) return byName
    return REFERENCE.filter(function (r) {
        return r.desc.toLowerCase().indexOf(w) !== -1
    })
}

// Whether a query looks like maths rather than an app name, for the hint
// the apps mode shows ("= 42  Enter to copy").
function looksNumeric(src) {
    var s = String(src || "").trim()
    if (s === "" || /^[a-zA-Z ]+$/.test(s)) return false
    return /^[-+(]?\s*(0x[0-9a-f_]+|0b[01_]+|[0-9._]+|pi|e|tau|sqrt|abs|sin|cos|tan|ln|log)/i.test(s)
        && /[-+*/^%()]|mod/i.test(s)
}
