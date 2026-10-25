// Adds the keybinds new in the repo's defaults to this machine's binds.lua
// (HyprBinds.mergeDefaults), leaving its own edits alone. link.sh runs it.
//
// Run: node tools/merge-binds.mjs DEFAULTS BINDS SEEN
//   DEFAULTS  the repo's binds.defaults.lua
//   BINDS     ~/.config/hypr/binds.lua
//   SEEN      the copy of the defaults last merged; written after each run,
//             so a bind removed from BINDS isn't added back

import fs from "node:fs"
import path from "node:path"
import vm from "node:vm"
import { fileURLToPath } from "node:url"

const repo = path.join(path.dirname(fileURLToPath(import.meta.url)), "..")
const lib = path.join(repo, "dotfiles/quickshell/.config/quickshell/services/HyprBinds.js")

const [defaults, binds, seen] = process.argv.slice(2)
const ctx = { Math, Number, String, JSON, Array, Object, RegExp }
vm.createContext(ctx)
vm.runInContext(fs.readFileSync(lib, "utf8").replace(/^\.pragma library\s*$/m, ""), ctx)

const read = (f) => (fs.existsSync(f) ? fs.readFileSync(f, "utf8") : "")
const fresh = read(defaults)
const r = ctx.mergeDefaults(read(binds), fresh, read(seen))
if (r.added.length > 0) fs.writeFileSync(binds, r.src)
for (const row of r.added) console.log(`added ${row.keys}: ${row.desc}`)
for (const row of r.skipped) console.log(`not added ${row.keys} (${row.desc}): its keys or action are bound to something else`)
fs.mkdirSync(path.dirname(seen), { recursive: true })
fs.writeFileSync(seen, fresh)
