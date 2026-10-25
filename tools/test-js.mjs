// Tests for the shell's plain-JS modules (services/*.js): the calculator,
// time windows, number formats, style resolution, the channel outline, and
// the readers/writers of the Hyprland config's tables and binds.
//
// load() runs each QML JS module as the engine would: pragma stripped,
// imports first, own context, a minimal `Qt` stub.
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
const hypr = (name) => fs.readFileSync(path.join(repo, "dotfiles/hypr/.config/hypr", name), "utf8")
const looks = hypr("looks.lua"), input = hypr("input.lua")
const binds = fs.readFileSync(path.join(repo, "dotfiles/singularity/.config/singularity/binds.defaults.lua"), "utf8")

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

test("Styles: leaving Flat puts the bar back at the top", () => {
    const S = load("Styles.js")
    assert.equal(S.finish("flat").barPosition, "bottom")
    for (const name of S.order.filter(n => n !== "flat")) {
        assert.equal(S.finish(name).barPosition, "top", name)
        assert.equal(S.finish(name).heavyLines, false, name)
    }
    assert.equal(S.finish("glass").shadows, true)
})

test("Styles resolve every style, and Flat is square", () => {
    const S = load("Styles.js")
    const base = { radius: 6, barStyle: "full", barHeight: 32, spacing: 100, seeThrough: 100, shadows: true, heavyLines: false }
    for (const name of S.order) {
        const r = S.resolve(Object.assign({ style: name }, base))
        assert.ok(r.frameStyle && r.moduleStyle, name)
        assert.equal(r.barHeight, 32, name)
    }
    assert.equal(S.resolve(Object.assign({ style: "flat" }, base)).radius, 0)
    assert.equal(S.resolve(Object.assign({ style: "channel" }, base)).radius, 6)
    assert.equal(S.resolve(Object.assign({ style: "double" }, base)).flyoutAttach, "flush")
    assert.equal(S.resolve(Object.assign({ style: "double" }, base, { barStyle: "floating" })).flyoutAttach, "floating")
    assert.equal(S.resolve(Object.assign({ style: "glass" }, base)).opacity, 70)
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
    const deco = T.readConfig(looks, ["decoration"])
    assert.ok(deco && deco.dim_strength && deco.dim_strength.editable)
    assert.equal(T.readInput(input).fields.kb_layout.value, "us")
    assert.equal(T.readConfig(looks, ["no_such_table"]), null)
})

test("HyprBinds parses the real config and round-trips an edit", () => {
    const B = load("HyprBinds.js")
    const model = B.parse(binds)
    assert.ok(model.rows.length > 20)
    assert.ok(model.rows.some((r) => r.editable))
    const row = model.rows.find((r) => r.editable && r.isExec)
    const removed = B.removeBind(model, row)
    assert.equal(B.parse(removed).rows.length, model.rows.length - 1)
})

test("HyprBinds.mergeDefaults adds only the binds new in the defaults", () => {
    const B = load("HyprBinds.js")
    const head = 'local mod = "SUPER"\n-- --- Apps ---\nhl.bind(mod .. " + Q", hl.dsp.exec_cmd("kitty"))  -- Terminal\n'
    const seen = head + 'hl.bind(mod .. " + E", hl.dsp.exec_cmd("files"))  -- Files\n'
    const fresh = seen + 'hl.bind(mod .. " + B", hl.dsp.exec_cmd("browser"))  -- Browser\n'
        + 'hl.bind(mod .. " + M", hl.dsp.exec_cmd("mail"))  -- Mail\n'
        + 'hl.bind(mod .. " + V", hl.dsp.exec_cmd("volume"))  -- Volume\n'
        + '\n-- --- Claude ---\n-- the sidebar\nhl.bind(mod .. " + I", hl.dsp.exec_cmd("qs ipc call claude toggle"))  -- Claude\n'
    // E removed on purpose, M's key taken, V's action moved to a combo of its own
    const mine = head + 'hl.bind(mod .. " + M", hl.dsp.exec_cmd("music"))  -- Music\n'
        + 'hl.bind(mod .. " + F12", hl.dsp.exec_cmd("volume"))  -- Volume\n'
    const r = B.mergeDefaults(mine, fresh, seen)
    assert.deepEqual(Array.from(r.added, (x) => x.keys), ["SUPER + B", "SUPER + I"])
    assert.deepEqual(Array.from(r.skipped, (x) => x.keys), ["SUPER + M", "SUPER + V"])
    assert.match(r.src, /"volume"\)\)  -- Volume\nhl\.bind\(mod \.\. " \+ B"/)
    assert.match(r.src, /\n\n-- --- Claude ---\n-- the sidebar\nhl\.bind\(mod \.\. " \+ I"/)
    assert.doesNotMatch(r.src, /files/)
    // the file's own lines all stay, unchanged and in order; only whole lines are added
    const own = mine.split("\n").filter((l) => l !== "")
    const kept = r.src.split("\n").filter((l) => own.includes(l))
    assert.deepEqual(kept, own)
    // a first run, with nothing seen, brings back every default the file lacks
    assert.equal(B.mergeDefaults(mine, fresh, "").added.length, 3)
})

test("VpnConf reads a Proton WireGuard file", () => {
    const V = load("VpnConf.js")
    const conf = "[Interface]\n# NAT-PMP (Port Forwarding) = on\nPrivateKey = k=\nAddress = 10.2.0.2/32\nDNS = 10.2.0.1\n\n"
        + "[Peer]\n# NL#245\nPublicKey = p=\nAllowedIPs = 0.0.0.0/0\nEndpoint = 1.2.3.4:51820\n"
    const s = V.parse("wg-NL-245", conf)
    assert.equal(s.name, "NL#245")
    assert.equal(s.country, "Netherlands")
    assert.equal(s.pf, true)
    assert.equal(s.gateway, "10.2.0.1")
    assert.equal(V.parse("x", conf.replace("# NAT-PMP (Port Forwarding) = on\n", "").replace("# NL#245\n", "")).pf, null)
    assert.equal(V.parse("sc", conf.replace("NL#245", "CH-US#1")).country, "United States")
    assert.equal(V.parse("x", "[Interface]\nPrivateKey = k\n"), null)
})

test("VpnConf.iniSet sets, adds and drops keys", () => {
    const V = load("VpnConf.js")
    const ini = "[BitTorrent]\nSession\\Port=6881\n\n[Preferences]\nGeneral\\Locale=en\n"
    let t = V.iniSet(ini, "BitTorrent", "Session\\Port", "51234")
    assert.match(t, /^Session\\Port=51234$/m)
    t = V.iniSet(t, "BitTorrent", "Session\\Interface", "proton")
    assert.match(t, /\[BitTorrent\]\nSession\\Port=51234\nSession\\Interface=proton\n\n\[Preferences\]/)
    t = V.iniSet(t, "LegalNotice", "Accepted", "true")
    assert.match(t, /\n\n\[LegalNotice\]\nAccepted=true\n$/)
    t = V.iniSet(t, "BitTorrent", "Session\\Interface", null)
    assert.doesNotMatch(t, /Interface/)
    assert.equal(V.iniSet("", "A", "k", "v"), "[A]\nk=v\n")
    assert.equal(V.iniSet(ini, "BitTorrent", "Session\\Port", "6881"), ini)
})

test("WidgetPlacement places, stores and snaps the desktop widgets", () => {
    const P = load("WidgetPlacement.js")
    const a = P.area(2560, 1440, 44, false)
    assert.deepEqual({ ...a }, { x: 0, y: 44, w: 2560, h: 1396 })
    assert.equal(P.area(2560, 1440, 44, true).y, 0)
    const sizes = { clock: { w: 300, h: 150 }, weather: { w: 300, h: 200 }, stats: { w: 300, h: 250 }, music: { w: 300, h: 180 } }
    const none = { fx: -1, fy: -1 }
    // where they start out
    const clock = P.rectOf("clock", none, sizes, a, 48, 16)
    assert.equal(clock.x, 48)
    assert.equal(clock.y + clock.h, 1440 - 48)
    const weather = P.rectOf("weather", none, sizes, a, 48, 16)
    assert.equal(weather.x, 48 + 300 + 16)
    assert.equal(weather.y + weather.h, 1440 - 48)
    const stats = P.rectOf("stats", none, sizes, a, 48, 16)
    assert.equal(stats.x + stats.w, 2560 - 48)
    assert.equal(stats.y, 44 + 48)
    // the note a gap under the stats
    const note = P.rectOf("note", none, { ...sizes, note: { w: 300, h: 150 } }, a, 48, 16)
    assert.equal(note.y, 44 + 48 + 250 + 16)
    assert.equal(note.x + note.w, 2560 - 48)
    // stored as fractions, and back
    const r = { x: 1130, y: 600, w: 300, h: 150 }
    const f = P.fractionsOf(r, a)
    const back = P.rectOf("clock", f, sizes, a, 48, 16)
    assert.equal(back.x, 1130)
    assert.equal(back.y, 600)
    // the far edge stays on the far edge on a smaller screen
    const edge = P.fractionsOf({ x: 2260, y: 1290, w: 300, h: 150 }, a)
    const small = P.rectOf("clock", edge, sizes, P.area(1920, 1080, 44, false), 48, 16)
    assert.equal(small.x + small.w, 1920)
    assert.equal(small.y + small.h, 1080)
    // the middle snaps to the middle line, within reach only
    const s = P.snap({ x: 1135, y: 700, w: 300, h: 150 }, a, 48, 10)
    assert.equal(s.x, 1130)
    assert.deepEqual(JSON.parse(JSON.stringify(s.guides)), [{ dir: "v", at: 1280 }])
    assert.equal(P.snap({ x: 1100, y: 500, w: 300, h: 150 }, a, 48, 10).x, 1100)
    // the margin in from an edge, and never out of the area
    assert.equal(P.snap({ x: 2215, y: 500, w: 300, h: 150 }, a, 48, 10).x, 2212)
    const out = P.snap({ x: -50, y: 10, w: 300, h: 150 }, a, 48, 10)
    assert.equal(out.x, 0)
    assert.equal(out.y, 44)
    // a gap beside another widget, and in line with its top
    const other = [{ x: 400, y: 600, w: 300, h: 150 }]
    const by = P.snap({ x: 712, y: 603, w: 300, h: 150 }, a, 48, 10, other, 16)
    assert.equal(by.x, 716)
    assert.equal(by.y, 600)
})
