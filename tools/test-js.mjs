// Tests for the shell's plain-JS modules (services/*.js): the calculator,
// time windows, number formats, style resolution, the channel outline, and
// the readers/writers of hyprland.lua's tables and binds.
//
// The modules are QML JavaScript: `.pragma library` at the top, and
// `.import "X.js" as X` for another module. load() strips the pragma, loads
// imports first, and runs each file in its own context, the way the QML
// engine would. `Qt` is stubbed with only what a module reaches for.
//
// Run: node --test tools/test-js.mjs   (the pre-commit hook does, when a
// services/*.js file is staged)

import { test } from "node:test"
import assert from "node:assert/strict"
import fs from "node:fs"
import path from "node:path"
import vm from "node:vm"
import { fileURLToPath } from "node:url"

const repo = path.join(path.dirname(fileURLToPath(import.meta.url)), "..")
const services = path.join(repo, "dotfiles/quickshell/.config/quickshell/services")
const hyprland = fs.readFileSync(path.join(repo, "dotfiles/hypr/.config/hypr/hyprland.lua"), "utf8")

const Qt = { formatDateTime: (d) => d.toISOString() }
const loaded = {}

function load(name) {
    if (loaded[name]) return loaded[name]
    let src = fs.readFileSync(path.join(services, name), "utf8")
    const ctx = { Qt, Math, Number, String, JSON, Date, Array, Object, RegExp, isFinite, parseInt, parseFloat }
    src = src.replace(/^\.pragma library\s*$/m, "")
    src = src.replace(/^\.import "([^"]+)" as (\w+)\s*$/mg, (_, file, as) => {
        ctx[as] = load(file)
        return ""
    })
    vm.createContext(ctx)
    vm.runInContext(src, ctx, { filename: name })
    return (loaded[name] = ctx)
}

test("Calc evaluates arithmetic, functions and units", () => {
    const Calc = load("Calc.js")
    const v = (s) => Calc.evaluate(s)
    assert.equal(v("2 + 2 * 3").value, 8)
    assert.equal(v("(2 + 2) * 3").value, 12)
    assert.equal(v("2 ^ 10").value, 1024)
    assert.equal(v("-3 + 5").value, 2)
    assert.equal(v("10 mod 3").value, 1)
    assert.equal(v("50%").value, 0.5)
    assert.equal(v("0x1f").value, 31)
    assert.equal(v("0b1011").value, 11)
    assert.equal(v("1_000 + 1").value, 1001)
    assert.equal(v("sqrt(16)").value, 4)
    assert.ok(Math.abs(v("pi").value - Math.PI) < 1e-12)
    assert.equal(v("2 + 2 =").value, 4)
})

test("Calc refuses anything it doesn't understand", () => {
    const Calc = load("Calc.js")
    for (const s of ["alert(1)", "2 +", "this.x = 1", "Math.max(1,2)", "1 +* 2"])
        assert.equal(Calc.evaluate(s).ok, false, s)
    assert.equal(Calc.evaluate("").ok, false)
})

test("TimeWindow handles plain and overnight windows", () => {
    const TW = load("TimeWindow.js")
    const at = (h, m) => { const d = new Date(2026, 0, 1, h, m); return d }
    assert.equal(TW.contains(9 * 60, 17 * 60, at(12, 0)), true)
    assert.equal(TW.contains(9 * 60, 17 * 60, at(17, 0)), false)
    assert.equal(TW.contains(22 * 60, 7 * 60, at(23, 30)), true)
    assert.equal(TW.contains(22 * 60, 7 * 60, at(6, 59)), true)
    assert.equal(TW.contains(22 * 60, 7 * 60, at(12, 0)), false)
    assert.equal(TW.contains(600, 600, at(10, 0)), false)
})

test("Format picks units from the number", () => {
    const F = load("Format.js")
    assert.equal(F.bytes(250 * 1048576), "250M")
    assert.equal(F.bytes(1.5 * 1073741824), "1.5G")
    assert.equal(F.bytes(512 * 1073741824), "512G")
    assert.equal(F.bytes(-1), "--")
    assert.equal(F.rate(2048), "2 KB/s")
    assert.equal(F.duration(90061), "1d 1h")
    assert.equal(F.duration(3700), "1h 1m")
    assert.equal(F.pct(0.456), "46%")
})

test("Styles resolve every style, and Terminal is square", () => {
    const S = load("Styles.js")
    const base = { radius: 6, barStyle: "full", density: "normal", seeThrough: 100, shadows: true, heavyLines: false }
    for (const name of S.order) {
        const r = S.resolve(Object.assign({ style: name }, base))
        assert.ok(r.frameStyle && r.moduleStyle, name)
        assert.equal(r.barHeight, 32, name)
    }
    assert.equal(S.resolve(Object.assign({ style: "terminal" }, base)).radius, 0)
    assert.equal(S.resolve(Object.assign({ style: "channel" }, base)).radius, 6)
    assert.equal(S.resolve(Object.assign({ style: "lined" }, base)).flyoutAttach, "flush")
    assert.equal(S.resolve(Object.assign({ style: "lined" }, base, { barStyle: "floating" })).flyoutAttach, "floating")
    assert.equal(S.resolve(Object.assign({ style: "glass" }, base)).opacity, 70)
    assert.equal(S.resolve(Object.assign({ style: "nope" }, base)).frameStyle, "channel")
})

test("ChannelPath snaps near edges and closes its outline", () => {
    const C = load("ChannelPath.js")
    const g = { x0: 100, x1: 300, y0: 0, y1: 30, r: 8 }
    const s = C.snapTo({ x0: 102, x1: 290, y0: 30, y1: 200, r: 8 }, g, 3)
    assert.equal(s.x0, 100)
    assert.equal(s.x1, 290)
    const d = C.outline([g, { x0: 80, x1: 320, y0: 30, y1: 200, r: 10 }], 7, 0)
    assert.match(d, /^M/)
    assert.match(d.trim(), /Z$/)
    assert.doesNotMatch(d, /NaN/)
})

test("HyprTables reads hl.config fields", () => {
    const T = load("HyprTables.js")
    const deco = T.readConfig(hyprland, ["decoration"])
    assert.ok(deco && deco.dim_strength && deco.dim_strength.editable)
    assert.equal(T.readInput(hyprland).fields.kb_layout.value, "us")
    assert.equal(T.readConfig(hyprland, ["no_such_table"]), null)
})

test("HyprBinds parses the real config and round-trips an edit", () => {
    const B = load("HyprBinds.js")
    const model = B.parse(hyprland)
    assert.ok(model.rows.length > 20)
    assert.ok(model.rows.some((r) => r.editable))
    const row = model.rows.find((r) => r.editable && r.isExec)
    const removed = B.removeBind(model, row)
    assert.equal(B.parse(removed).rows.length, model.rows.length - 1)
})
