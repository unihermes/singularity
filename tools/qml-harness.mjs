// Run production QML JavaScript in a VM with explicit Qt/process stand-ins.
// Parse complete functions with V8 so nested braces and strings stay intact.
import fs from 'node:fs'
import vm from 'node:vm'

export function source(name) {
    return fs.readFileSync(new URL(`../dotfiles/quickshell/.config/quickshell/services/${name}`, import.meta.url), 'utf8')
}

function complete(lines, start, prefix = '') {
    for (let end = start; end < lines.length; end++) {
        const text = lines.slice(start, end + 1).join('\n')
        try { new vm.Script(prefix ? `(${text})` : text) } catch { continue }
        return text
    }
    throw new Error(`Incomplete JavaScript at ${lines[start]}`)
}

export function functions(text, bindings) {
    const ctx = vm.createContext(bindings)
    const lines = text.split('\n')
    for (let i = 0; i < lines.length; i++) {
        if (/^    function \w+\(/.test(lines[i])) vm.runInContext(complete(lines, i), ctx)
    }
    return ctx
}

export function handler(text, name, ctx) {
    const lines = text.split('\n')
    const start = lines.findIndex(line => new RegExp(`^\\s*${name}:`).test(line))
    if (start < 0) throw new Error(`Missing handler ${name}`)
    lines[start] = lines[start].replace(new RegExp(`^\\s*${name}:\\s*`), '')
    // Block-only handlers use the signal's implicit context, no arguments.
    if (lines[start].startsWith('{')) lines[start] = '() => ' + lines[start]
    return vm.runInContext(`(${complete(lines, start, 'expression')})`, ctx)
}
