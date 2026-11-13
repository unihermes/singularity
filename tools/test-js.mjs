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
import { spawnSync } from "node:child_process"
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

test("Recorder groups Minecraft versions under Minecraft", () => {
    const source = fs.readFileSync(path.join(services, "Recorder.qml"), "utf8")
    const ctx = { Apps: { byClass: () => ({ entry: null }) } }
    vm.createContext(ctx)
    for (const name of ["isGame", "folderFor"]) {
        const match = source.match(new RegExp(`    function ${name}\\(t\\) \\{[\\s\\S]*?\\n    \\}`))
        assert.ok(match, `${name} exists`)
        vm.runInContext(match[0], ctx)
    }
    for (const cls of ["Minecraft* 26.1.2", "Minecraft 1.21.4", "minecraft 1.8.9"]) {
        const window = { title: cls, lastIpcObject: { class: cls } }
        assert.equal(ctx.isGame(window), true)
        assert.equal(ctx.folderFor(window), "Minecraft")
    }
    assert.equal(ctx.folderFor({ title: "Overwatch", lastIpcObject: { class: "steam_app_2357570" } }), "Overwatch")
})

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

test("Styles: leaving Flat or Pane puts the bar back at the top", () => {
    const S = load("Styles.js")
    assert.equal(S.finish("flat").barPosition, "bottom")
    assert.equal(S.finish("pane").barPosition, "bottom")
    for (const name of S.order.filter(n => n !== "flat" && n !== "pane")) {
        assert.equal(S.finish(name).barPosition, "top", name)
        assert.equal(S.finish(name).heavyLines, false, name)
    }
    assert.equal(S.finish("glass").shadows, true)
    // a style takes back every part drawn its own way
    for (const name of S.order) {
        assert.equal(S.finish(name).barChips, "auto", name)
        assert.equal(S.finish(name).flyoutAnim, "auto", name)
    }
})

test("KeybindGroups keeps sections, action clusters and search filters", () => {
    const B = load("HyprBinds.js"), G = load("KeybindGroups.js")
    const row = (keys, desc, category) => ({ keys, desc, category, command: "cmd", norm: B.normalizeKeys(keys) })
    const a = row("SUPER + A", "Launch", "Launchers")
    const b = row("SUPER + B", "Other", "Launchers")
    const c = row("SUPER + C", "Launch", "Launchers")
    const custom = row("SUPER + D", "Custom", "My section")
    const model = { rows: [a, b, c, custom], categories: [{ name: "Launchers" }, { name: "My section" }] }
    const groups = G.groups(model, "", "")
    assert.deepEqual(Array.from(groups, g => g.name), ["Apps", "My section"])
    assert.deepEqual(Array.from(groups[0].rows, r => r.keys), [a.keys, c.keys, b.keys])
    assert.equal(groups[0].section, "Launchers")
    assert.equal(G.groups(model, "apps", "")[0].rows.length, 3)
    assert.equal(G.groups(model, "", "WIN + A")[0].rows[0], a)
    assert.equal(G.groups(model, "no match", "").length, 0)
    assert.equal(G.groups(null, "", "").length, 0)
})

test("KeybindGroups filters bound presets and reports missing tools", () => {
    const B = load("HyprBinds.js"), P = load("HyprPresets.js"), G = load("KeybindGroups.js")
    const model = B.parse(binds)
    const visible = G.presetGroups(model, "", "", true, {})
    assert.ok(visible.length > 0)
    assert.ok(visible.every(g => g.items.every(i => i.state !== "bound")))
    const all = G.presetGroups(model, "", "", false, {})
    assert.equal(all.reduce((n, g) => n + g.items.length, 0), G.presetTotal())
    assert.equal(all.reduce((n, g) => n + g.bound, 0), G.presetBound(model))
    const item = all.flatMap(g => Array.from(g.items)).find(i => (i.preset.needs || []).length)
    assert.ok(item)
    assert.deepEqual(Array.from(item.missing), Array.from(item.preset.needs))
    const present = Object.fromEntries(P.neededBinaries().map(n => [n, true]))
    assert.ok(G.presetGroups(model, "", "", false, present).every(g => g.items.every(i => !i.missing.length)))
    assert.equal(G.presetGroups(null, "", "", true, {}).length, 0)
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

test("All styles default to window previews across workspaces", () => {
    const S = load("Styles.js"), V = load("SettingsValues.js")
    assert.equal(V.defaults.altTabStyle, "previews")
    assert.equal(V.defaults.altTabScope, "all")
    for (const name of S.order) {
        assert.equal(S.stockOf(name).altTabStyle, "previews", name)
        assert.equal(S.stockOf(name).altTabScope, "all", name)
    }
})

test("Styles: new defaults reset layout and retain their frame and control families", () => {
    const S = load("Styles.js")
    const expected = { rail: ["rail", "grouped"], notch: ["notch", "outline"],
        capsule: ["none", "filled"], bevel: ["bevel", "outline"] }
    for (const [name, [frame, modules]] of Object.entries(expected)) {
        assert.ok(S.order.includes(name), name)
        const stock = S.stockOf(name), resolved = S.resolve(stock)
        assert.equal(resolved.frameStyle, frame, name)
        assert.equal(resolved.moduleStyle, modules, name)
        assert.equal(resolved.controlStyle, name === "capsule" ? "solid" : name, name)
        assert.equal(stock.barStyle, name === "capsule" ? "islands" : "full", name)
        assert.equal(stock.edgeGap, name === "capsule" ? 10 : 0, name)
        assert.equal(stock.barPosition, "top", name)
        assert.equal(stock.styleOptions, "", name)
        const plain = S.resolve({ ...stock, plain: true })
        assert.equal(plain.shadow, "none", name)
        assert.equal(plain.moduleStyle, "bare", name)
        assert.equal(plain.flyoutAttach, "flush", name)
        const overridden = S.resolve({ ...stock, barChips: "outline", flyoutAnim: "fade", shadows: false })
        assert.equal(overridden.moduleStyle, "outline", name)
        assert.equal(overridden.flyoutAnim, "fade", name)
        assert.equal(overridden.shadow, "none", name)
    }
    assert.equal(S.resolve(S.stockOf("notch")).radius, 0)
    // Pane is the Windows 10 take: a square taskbar along the bottom
    const pane = S.stockOf("pane"), win10 = S.resolve(pane)
    assert.equal(win10.radius, 0)
    assert.equal(win10.moduleStyle, "taskbar")
    assert.equal(pane.barPosition, "bottom")
    assert.equal(pane.styleOptions, "taskbar")
    // Glass is the macOS take: a menu bar with a Dock
    const mac = S.stockOf("glass")
    assert.equal(S.resolve(mac).moduleStyle, "bare")
    assert.equal(mac.styleOptions.split(",").includes("dock"), true)
    assert.equal(mac.styleOptions.split(",").includes("menubar"), true)
    assert.equal(S.resolve(S.stockOf("bevel")).shadow, "hard")
    // Moving away from Capsule restores a full bar with no island gap.
    assert.equal(S.stockOf("channel").barStyle, "full")
    assert.equal(S.stockOf("channel").edgeGap, 0)
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

test("Markdown: fences split out, prose to rich text", () => {
    const M = load("Markdown.js")
    const ink = { text: "#t", strong: "#s", muted: "#m", accent: "#a", codeFill: "#f", codeInk: "#c", rule: "#r" }
    const parts = M.split("Hi\n\n```bash\nls -la\n```\nafter\n```py\nunclosed")
    assert.equal(parts.map(p => p.kind).join(","), "text,code,text,code")
    assert.equal(parts[1].lang, "bash")
    assert.equal(parts[1].code, "ls -la")
    assert.equal(parts[3].code, "unclosed")
    const art = M.split("Look:\n````artifact html My page\n```js\nx\n```\n````\n\n````artifact react Live")
    assert.equal(art.map(p => p.kind).join(","), "text,artifact,artifact")
    assert.deepEqual([art[1].type, art[1].title, art[1].code, art[1].done], ["html", "My page", "```js\nx\n```", true])
    assert.deepEqual([art[2].type, art[2].title, art[2].done], ["react", "Live", false])
    const h = M.html("# Title\n- **a** `x<y`\n  - nested\n1. one\n\n| a | b |\n|---|---|\n| 1 | 2 |", ink)
    assert.match(h, /<b style="color:#s">Title<\/b>/)
    assert.match(h, /<ul><li><b style="color:#s">a<\/b> <span[^>]*background-color:#f[^>]*>&nbsp;x&lt;y&nbsp;<\/span><\/li><ul><li>nested<\/li><\/ul><\/ul><ol><li>one<\/li><\/ol>/)
    assert.match(h, /<th align="left">a<\/th>/)
    assert.match(h, /<td>2<\/td>/)
    assert.match(M.html("see [docs](https://x.y) and *it*", ink), /<a href="https:\/\/x.y" style="color:#a">docs<\/a> and <i>it<\/i>/)
})

test("Settings search excludes lid controls without lid hardware", () => {
    const index = load("SettingsIndex.js")
    const pages = [{ id: "power", label: "Battery & Idle", icon: "", blurb: "Profile, idle and sleep" }]
    for (const capabilities of [undefined, { lid: false }]) {
        const desktop = index.build(pages, capabilities)
        assert.equal(desktop.filter(e => e.section === "Lid").length, 0)
        assert.equal(index.search(desktop, "lid").length, 0)
        assert.ok(index.search(desktop, "hibernate").length > 0)
    }
    const laptop = index.build(pages, { lid: true })
    assert.equal(laptop.filter(e => e.section === "Lid").length, 3)
    assert.ok(index.search(laptop, "lid closes").length > 0)
})

test("Settings search follows hardware capabilities independently of profile", () => {
    const index = load("SettingsIndex.js")
    const pages = ["power", "input", "lockscreen"].map(id => ({ id, label: id, icon: "" }))
    const absent = index.build(pages, {})
    for (const label of ["Charging", "Dim the screen", "Suspend on battery", "Tap to click", "Unlock with a fingerprint"])
        assert.ok(!absent.some(e => e.label === label), label)
    const attached = index.build(pages, { touchpad: true, fingerprint: true, backlight: true, battery: true, charging: true })
    for (const label of ["Charging", "Dim the screen", "Suspend on battery", "Tap to click", "Unlock with a fingerprint"])
        assert.ok(attached.some(e => e.label === label), label)
    assert.ok(!attached.some(e => e.section === "Lid"))
})

test("Mosaic packs tiles densely and walks them with the arrows", () => {
    const M = load("Mosaic.js")
    const r = M.pack([[2, 2], [2, 2], [2, 1], [2, 1], [1, 1], [1, 1], [1, 1]], 6)
    assert.deepEqual(JSON.parse(JSON.stringify(r)), [
        { x: 0, y: 0, w: 2, h: 2 }, { x: 2, y: 0, w: 2, h: 2 }, { x: 4, y: 0, w: 2, h: 1 },
        { x: 4, y: 1, w: 2, h: 1 }, { x: 0, y: 2, w: 1, h: 1 }, { x: 1, y: 2, w: 1, h: 1 }, { x: 2, y: 2, w: 1, h: 1 },
    ])
    // a tile wider than the grid is cut to fit
    assert.equal(M.pack([[9, 1]], 4)[0].w, 4)
    assert.equal(M.step(r, 0, 1, 0), 1)
    assert.equal(M.step(r, 1, 1, 0), 2)
    assert.equal(M.step(r, 2, 0, 1), 3)
    assert.equal(M.step(r, 0, 0, 1), 4)
    // nothing that way: stays put; a tile ok() refuses is passed over
    assert.equal(M.step(r, 0, -1, 0), 0)
    assert.equal(M.step(r, 0, 0, 1, (i) => i !== 4), 5)
})

test("Settings defaults, looks and styles obey their choices and bounds", () => {
    const V = load("SettingsValues.js"), L = load("Looks.js"), S = load("Styles.js")
    const validate = (values, label) => {
        for (const [key, value] of Object.entries(values)) {
            assert.equal(V.stored(key, value), value, `${label}.${key}: ${value}`)
        }
    }
    validate(V.defaults, 'defaults')
    for (const [name, look] of Object.entries(L.looks)) validate(look.settings, `look ${name}`)
    for (const name of S.order) validate(S.stockOf(name), `style ${name}`)
    for (const key of Object.keys(V.limits)) assert.equal(typeof V.defaults[key], 'number', key)
    for (const key of Object.keys(V.choices)) {
        if (key === 'density') continue // derived from three primitive dimensions
        assert.ok(key in V.defaults, key)
        assert.ok(V.choices[key].length > 0, key)
        assert.equal(new Set(V.choices[key]).size, V.choices[key].length, key)
    }
    const qml = fs.readFileSync(path.join(services, 'Settings.qml'), 'utf8')
    const declared = [...qml.matchAll(/property (?:string|int|bool) (\w+): Values\.defaults\.(\w+)/g)]
    for (const [, key, ref] of declared) {
        assert.equal(key, ref)
        assert.ok(key in V.defaults, key)
    }
    assert.equal(declared.length, Object.keys(V.defaults).length)
    // Installed choices must also accept the declared stock names.
    assert.ok(L.order.includes(V.defaults.look))
    assert.ok(S.order.includes(V.defaults.style))
    assert.ok(L.systemFonts.includes(V.defaults.systemFontFamily))
})

test("Settings reject invalid numeric edits and repair invalid stored values", () => {
    const V = load("SettingsValues.js")
    assert.equal(V.clamp('radius', -100), 0)
    assert.equal(V.clamp('radius', 999), 14)
    assert.equal(V.clamp('radius', 3.6), 4)
    for (const value of [NaN, Infinity, -Infinity, undefined, null, '5']) {
        assert.equal(V.clamp('radius', value), undefined)
        assert.equal(V.stored('radius', value), V.defaults.radius)
    }
    assert.equal(V.clamp('unknown', 5), undefined)
    assert.equal(V.stored('notifPositionX', 'typo'), 'right')
    assert.equal(V.stored('weekStart', 3), 1)
    assert.equal(V.stored('replaySeconds', 1000), 600)
    assert.equal(V.stored('fontFamily', 'A font currently uninstalled'), 'A font currently uninstalled')
    assert.equal(V.stored('cursorTheme', 'A theme currently uninstalled'), 'A theme currently uninstalled')
})


test("Window sizing keeps geometry, restore and directional commands consistent", () => {
    const result = spawnSync("lua", ["-"], { cwd: repo, encoding: "utf8", input: String.raw`
package.path = "dotfiles/hypr/.config/hypr/?.lua;" .. package.path
local G = require("window-geometry")
local function near(a, b) assert(math.abs(a - b) < 0.00001, tostring(a) .. " != " .. tostring(b)) end
local function same(a, b)
    for k, v in pairs(b) do near(a[k], v) end
end
local mon = { x = -1920, y = 100, width = 3840, height = 2160, scale = 2,
    reserved = { top = 32, bottom = 8 } }
local area = G.area(mon, { left = 10, right = 10, top = 10, bottom = 10 }, 24)
same(area, { x = -1910, y = 166, w = 1900, h = 996 })
local custom = { fx = 0.2, fy = 0.1, fw = 0.3, fh = 0.7 }
same(G.shape(G.rect(area, custom), area), custom)
local other = G.area({ x = 0, y = -200, width = 1440, height = 2560, scale = 1.25 })
same(G.shape(G.rect(other, custom), other), custom)
local bounded = G.rect(other, { fx = -1, fy = 3, fw = 2, fh = 0.5 })
near(bounded.x, other.x)
near(bounded.y + bounded.h, other.y + other.h)
near(bounded.w, other.w)
assert(G.area(mon, { left = 9000, bottom = 9000 }).w == 1)
local nextShape, changed = G.step(custom, 1)
assert(changed)
near(nextShape.fh, 0.85)
near(nextShape.fw / nextShape.fh, custom.fw / custom.fh)
near(nextShape.fx + nextShape.fw / 2, custom.fx + custom.fw / 2)
local filled, didFill = G.step(nextShape, 1)
assert(filled == nil and didFill)
local _, didGrow = G.step(nil, 1)
assert(not didGrow)
local smallest = G.centred(0.55)
local _, didShrink = G.step(smallest, -1)
assert(not didShrink)
near(G.step(nil, -1).fw, 0.85)
local edge = G.step({ fx = 0.7, fy = 0.3, fw = 0.3, fh = 0.7 }, 1)
near(edge.fx + edge.fw, 1)
near(edge.fy + edge.fh, 1)

-- Run the real sizing functions with a synchronous compositor double.
-- Other lifecycle hooks are excluded so this cannot move desktop windows.
local file = assert(io.open("dotfiles/hypr/.config/hypr/windows.lua"))
local source = file:read("a")
file:close()
local function section(first, last)
    local a = assert(source:find(first, 1, true))
    local b = assert(source:find(last, a + #first, true))
    return source:sub(a, b - 1)
end
local active, state, dispatched, borderChecks
local timers, hooks = {}, {}
local env = setmetatable({ G = G, S = { GROUPBAR_HEIGHT = 24 } }, { __index = _G })
env.popupOpts, env.sizes = { remember = true }, {}
env.screenKind = function() return "normal" end
env.num = function(n) return string.format("%.4f", n) end
env.saveSizes = function() end
env.edgeGaps = function() return { left = 10, right = 10, top = 10, bottom = 10 } end
env.stateOf = function() return state end
env.hasTag = function(w, tag) return w.tags[tag] end
env.syncFillBorder = function() borderChecks = borderChecks + 1 end
env.setShape = function(_, shape) state.shape = shape end
env.captureShape = function() end
env.unflagFloating = function(w) return w end
env.hl = {
    on = function(event, fn) hooks[event] = fn end,
    timer = function(fn) timers[#timers + 1] = fn end,
    get_active_window = function() return active end,
    get_active_monitor = function() return active.monitor end,
    get_window = function() return active end,
    dsp = { window = {} },
}
for _, name in ipairs({ "resize", "move", "fullscreen", "bring_to_top" }) do
    env.hl.dsp.window[name] = function(args) return { name = name, args = args } end
end
env.hl.dispatch = function(command)
    dispatched[#dispatched + 1] = command.name
    local args = command.args
    if command.name == "resize" then
        active.size = { x = args.x, y = args.y }
        -- Resizing may move the origin: applyRect must read it again.
        active.at.x = active.at.x + 7
    elseif command.name == "move" then active.at = { x = args.x, y = args.y }
    elseif command.name == "fullscreen" then active.fullscreen = active.fullscreen == 0 and 1 or 0 end
end
local code = section("local function usableArea(mon)", "local function isAlreadyFull")
    .. section("local function applyRect(win, r)", '-- also kept as a "shape_')
    .. section("local function placeMonocle(win, mon)", "-- Takes a monocle window's shape")
    .. section("local REFILL_TICK, REFILL_SETTLE", "-- REMEMBERED SIZES.")
    .. section("-- A window moved to another workspace takes on its layout", "-- Focuses the most recently used window")
    .. section("local function fillFloating(win)", "local function unflagFloating(win)")
    .. section("local function rememberPopout(win)", "-- Makes a popout a main window")
    .. "local function fillByHand(win) return fillFloating(win) end\n"
    .. section("local function toggleMaximizeWin(win)", "-- SUPER+C: hides a window")
    .. "return { toggle = toggleMaximizeWin, step = stepWindowSize, apply = applyRect, shape = shapeOf, remember = rememberPopout, refit = refitMoved }"
local commands = assert(load(code, "window-sizing", "t", env))()
local function reset(floating, monocle)
    state, dispatched, borderChecks = {}, {}, 0
    env.windowState = { test = state }
    timers = {}
    active = { address = "test", class = "test", floating = floating, fullscreen = 0,
        monitor = mon, tags = { monocle = monocle }, at = { x = -1500, y = 300 }, size = { x = 600, y = 500 } }
end
for _, monocle in ipairs({ false, true }) do
    reset(true, monocle)
    local initial = commands.shape(active, mon)
    commands.step(1)
    local stepped = commands.shape(active, mon)
    assert(math.abs(stepped.fw / stepped.fh - initial.fw / initial.fh) < 0.002)
    initial = stepped
    commands.toggle(active)
    same(state.lastShape, initial)
    assert(G.fitted({ x = active.at.x, y = active.at.y, w = active.size.x, h = active.size.y },
        G.area(mon, env.edgeGaps())))
    commands.toggle(active)
    local back = commands.shape(active, mon)
    for k, v in pairs(initial) do assert(math.abs(back[k] - v) < 0.002) end
    -- Fill, change monitor, restore: both types preserve fractional geometry.
    commands.toggle(active)
    active.monitor = { x = 0, y = 0, width = 2560, height = 1440, scale = 1 }
    local target = G.area(active.monitor, env.edgeGaps())
    commands.apply(active, target)
    commands.toggle(active)
    local restored = G.rect(target, initial)
    assert(math.abs(active.size.x - restored.w) <= 1)
    assert(math.abs(active.size.y - restored.h) <= 1)
end
-- The compositor keeps moving a dragged window after the workspace event.
-- Both filled types must re-fit again once that movement settles.
for _, monocle in ipairs({ false, true }) do
    reset(true, monocle)
    active.tags.filled = true
    active.monitor = { id = 2, x = 0, y = 0, width = 2560, height = 1440, scale = 1.25 }
    -- Floorp is natural + filled, and can land in an open scratchpad.
    hooks["window.move_to_workspace"](active, { special = true, monitor = active.monitor })
    assert(state.refilling)
    active.at = { x = 120, y = 200 }
    for _ = 1, 6 do
        local pending = timers
        timers = {}
        for _, fn in ipairs(pending) do fn() end
    end
    assert(not state.refilling)
    local area = G.area(active.monitor, env.edgeGaps())
    assert(G.fitted({ x = active.at.x, y = active.at.y, w = active.size.x, h = active.size.y }, area))
end
reset(true, false)
local target = { x = active.at.x, y = active.at.y, w = active.size.x, h = active.size.y }
commands.apply(active, target)
assert(#dispatched == 0 and borderChecks == 1)
target.w = target.w + 100
commands.apply(active, target)
assert(dispatched[1] == "resize" and dispatched[2] == "move")
near(active.at.x, target.x)
-- Near-full custom geometry stays custom instead of snapping at 94%.
local nearFull = G.rect(G.area(mon, env.edgeGaps()), G.centred(0.96))
commands.apply(active, nearFull)
assert(commands.shape(active, mon) ~= nil)
state.popoutKey, active.tags.popout = "test-popup", true
commands.remember(active)
assert(env.sizes["test-popup"].normal.fw > 0.95)
env.sizes = {}
commands.apply(active, G.area(mon, env.edgeGaps()))
commands.remember(active)
assert(next(env.sizes) == nil)
reset(false, false)
commands.step(1)
assert(active.fullscreen == 1)
commands.step(1)
assert(active.fullscreen == 1 and #dispatched == 1)
commands.step(-1)
assert(active.fullscreen == 0 and state.small)
commands.step(-1)
assert(active.fullscreen == 0 and #dispatched == 2)
active.fullscreen = 2
commands.step(1)
commands.step(-1)
assert(active.fullscreen == 2 and #dispatched == 2)
` });
    assert.equal(result.status, 0, result.error?.message || result.stderr || result.stdout);
});

test("autostart tray holds expire, recover refused closes, and leave existing windows alone", () => {
    const script = `
local windows, timers, rules, moves = {}, {}, {}, {}
local workspace = { id = 2 }
hl = {
    get_windows = function() return windows end,
    get_active_workspace = function() return workspace end,
    window_rule = function(spec)
        spec.enabled = true
        function spec:set_enabled(on) self.enabled = on end
        table.insert(rules, spec)
        return spec
    end,
    timer = function(fn, opts) table.insert(timers, { fn = fn, delay = opts.timeout }) end,
    dsp = { window = { move = function(opts) return opts end } },
    dispatch = function(opts) table.insert(moves, opts) end,
}
local function loadModule()
${hypr("autostart-tray.lua")}
end
local tray = loadModule()
tray.start("unknown")
assert(#rules == 0)
windows = {{ class = "Spotify" }}
tray.start("spotify")
assert(#rules == 0)
windows = {}
tray.start("spotify")
assert(#rules == 1 and rules[1].workspace == "special:autostart-spotify silent")
assert(rules[1].no_focus and timers[1].delay == 65000)
tray.start("spotify")
assert(#rules == 1)
windows = {
    { address = "0x1", workspace = { name = "special:autostart-spotify" } },
    { address = "0x2", workspace = { name = "2" } },
}
tray.finish("spotify")
assert(not rules[1].enabled and #moves == 0)
assert(timers[2].delay == 1000)
workspace = { id = 3 }
timers[2].fn()
assert(#moves == 1 and moves[1].workspace == 3 and moves[1].window == "address:0x1")
assert(moves[1].follow == false)
-- The old timeout cannot release a subsequent startup hold.
windows = {}
tray.start("spotify")
timers[1].fn()
assert(rules[2].enabled)
-- A launcher that dies still gets automatic recovery.
timers[3].fn()
assert(not rules[2].enabled)
windows = {{ address = "0x3", workspace = { name = "special:autostart-spotify" } }}
workspace = { special = true }
timers[4].fn()
assert(moves[2].workspace == 3)
-- A config reload recovers stale special workspaces, without touching others.
workspace = { id = 4 }
loadModule()
assert(#moves == 3 and moves[3].workspace == 4)
`
    const result = spawnSync("lua", ["-"], { input: script, encoding: "utf8" })
    assert.equal(result.status, 0, result.stderr || result.error?.message)
})

test("autostart releases holds after a tray close, native hidden startup, or timeout", () => {
    const source = fs.readFileSync(path.join(repo, "dotfiles/singularity/.config/singularity/autostart.sh"), "utf8")
        .split('case ${1:-run} in')[0]
    for (const mode of ["window", "hidden", "timeout"]) {
        const script = source + `
declare -A tray_keys=([10]=spotify)
sleep() { :; }
sid() { printf 10; }
busctl() {
    [[ '${mode}' == timeout ]] && return 1
    if [[ $* == *GetConnectionUnixProcessID* ]]; then printf 'u %s' "$$"
    else printf 'as 1 ":1.77/Item"'; fi
}
hyprctl() {
    if [[ $1 == clients ]]; then
        [[ '${mode}' != window ]] || printf 'Window abc -> test:\\n\\tpid: %s\\n' "$$"
    else printf '%s\\n' "$*" >> "$TEST_CALLS"; fi
}
to_tray 10
`
        const dir = fs.mkdtempSync("/tmp/singularity-autostart-test-")
        try {
            const calls = path.join(dir, "calls")
            const result = spawnSync("bash", ["-s"], {
                input: script, encoding: "utf8", env: { ...process.env, TEST_CALLS: calls },
            })
            assert.equal(result.status, 0, result.stderr)
            const output = fs.readFileSync(calls, "utf8")
            assert.match(output, /finish\("spotify"\)/)
            assert.equal(output.includes("window.close"), mode === "window")
        } finally {
            fs.rmSync(dir, { recursive: true, force: true })
        }
    }
})

test("process memory and CPU belong to the helper's actual browser", () => {
    const P = load("ProcessGroups.js")
    const rows = P.memoryRows(`10 1 100 zen-bin
11 10 20 forkserver
12 11 600 Isolated Web Co
20 1 200 floorp
21 20 300 WebExtensions
30 1 50 firefox
31 30 70 GPU Process
40 999 40 Isolated Web Co
50 51 5 Web Content
51 50 5 forkserver
12|user|50|600|Isolated Web Co`)
    assert.equal(rows.length, 10)
    const groups = P.group(rows, "memKb")
    const memory = Object.fromEntries(groups.map(r => [r.name, r.memKb]))
    assert.equal(memory.zen, 720)
    assert.equal(memory.floorp, 500)
    assert.equal(memory.firefox, 120)
    assert.equal(memory["Isolated Web Co"], 40)
    assert.equal(memory["Web Content"], 5)
    assert.equal(groups[0].pid, 12)
    // Closing Floorp must remove its group even while Zen keeps running.
    const zenOnly = rows.filter(r => r.pid !== 20 && r.pid !== 21)
    assert.equal(P.group(zenOnly, "memKb").some(r => r.name === "floorp"), false)
    const floorpOnly = rows.filter(r => r.pid === 20 || r.pid === 21)
    assert.equal(P.group(floorpOnly, "memKb")[0].memKb, 500)
    // top's CPU sample uses the separate ps ancestry, including forkservers.
    const sample = [{ pid: 12, user: "user", name: "Isolated Web Co", memKb: 650, cpu: 42 },
        { pid: 21, user: "user", name: "WebExtensions", memKb: 310, cpu: 7 }]
    const cpu = P.group(sample, "cpu", rows)
    assert.equal(cpu[0].name, "zen")
    assert.equal(cpu[0].cpu, 42)
    assert.equal(cpu[0].memKb, 650)
    assert.equal(cpu[1].name, "floorp")
    // A vanished parent must leave an honest helper label, not guess a browser.
    assert.equal(P.group(sample, "cpu", [rows[2]])[0].name, "Isolated Web Co")
})


test("Dwindle enables hover focus and preserves child popouts across layout changes", () => {
    const result = spawnSync("lua", ["-"], { cwd: repo, encoding: "utf8", input: String.raw`
local f = assert(io.open("dotfiles/hypr/.config/hypr/windows.lua"))
local source = f:read("a")
f:close()
local function section(first, last)
    local a = assert(source:find(first, 1, true))
    local b = assert(source:find(last, a + #first, true))
    return source:sub(a, b - 1)
end
local calls, config, on = {}, nil, false
local rule = { set_enabled = function() end }
local env = setmetatable({
    SCRATCH_CLASS = "scratch", BROWSER_CLASSES = { firefox = true }, knownWindows = {},
    hasTag = function(w, t) return w.tags[t] end,
    isPrompt = function(c) return c == "prompt" end,
    stateOf = function() return {} end,
    monocleOn = function() return on end,
    monocleRule = rule, naturalRule = rule, fullscreenRules = {},
    followOwner = function(w) return w end,
    isX11Popup = function() return false end,
    popoutOwnerOf = function() return { address = "owner" }, true end,
    hl = {
        get_active_workspace = function() return { id = 1 } end,
        config = function(c) config = c end,
        on = function() end,
        dispatch = function(c) calls[#calls + 1] = c end,
        dsp = { window = {} },
    },
}, { __index = _G })
for _, name in ipairs({ "float", "tag", "fullscreen" }) do
    env.hl.dsp.window[name] = function(args) return { name = name, args = args } end
end
assert(load(section("function setWindowMonocle(w, on, mon)", "-- In monocle right now:"), "layout", "t", env))()
for _, tag in ipairs({ "popout", "app-held", "modal" }) do
    for _, target in ipairs({ false, true }) do
        env.setWindowMonocle({ class = "app", address = "child", floating = true,
            tags = { [tag] = true, ["rule-float"] = true } }, target)
    end
end
env.setWindowMonocle({ class = "prompt", address = "child", floating = true, tags = {} }, false)
assert(#calls == 0, "dialogs must keep floating through layout switches")
env.setWindowMonocle({ class = "app", address = "main", floating = true,
    fullscreen = 0, tags = { ["rule-float"] = true }, at = { x = 0, y = 0 }, size = { x = 500, y = 400 } }, false)
assert(calls[1].name == "float" and calls[1].args.action == "disable")
assert(load(section("local rulesMonocle = nil", "-- The app rules' switch:"), "focus", "t", env))()
assert(config.input.follow_mouse == 1)
on = true
assert(load(section("local rulesMonocle = nil", "-- The app rules' switch:"), "focus", "t", env))()
assert(config.input.follow_mouse == 0)
-- Exercise the real popup gates without running placement or desktop hooks.
local gates = section("holdPopup = function(win)", "    local addr = \"address:\" .. win.address\n    -- the window strip lists it")
assert(load(gates .. " return true end", "popup-gates", "t", env))()
on = false
local function popup(class, floating, tags)
    env.knownWindows = {}
    return env.holdPopup({ address = "child", class = class, floating = floating, tags = tags or {} })
end
assert(popup("app", true))
assert(popup("app", false) == nil)
assert(popup("firefox", false) == nil)
assert(popup("firefox", true) == nil)
assert(popup("firefox", true, { modal = true, popout = true }))
assert(popup("app", true, { ["app-opened"] = true }) == nil)
` });
    assert.equal(result.status, 0, result.error?.message || result.stderr || result.stdout);
});
