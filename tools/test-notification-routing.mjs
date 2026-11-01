import { test } from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'

const source = fs.readFileSync(new URL('../dotfiles/quickshell/.config/quickshell/services/Notifications.qml', import.meta.url), 'utf8')
function context() {
    const opened = [], raised = [], hidden = []
    const ctx = vm.createContext({ shown: true,
        Ai: { openConversation: (...args) => opened.push(args) },
        hidePopup: entry => hidden.push(entry),
        raiser: { restart: () => raised.push(true) } })
    for (const name of ['openSidebar', 'activate', 'invoke']) {
        const body = source.match(new RegExp('    function ' + name + '\\([^]*?\\n    }'))[0]
        vm.runInContext(body, ctx)
    }
    return { ctx, opened, raised, hidden }
}

test('sidebar cards and actions open their saved tab and engine without raising a desktop app', () => {
    for (const tab of ['chat', 'code']) for (const engine of ['claude', 'codex']) {
        for (const action of [false, true]) {
            const { ctx, opened, raised } = context()
            const entry = { desktopEntry: `singularity-sidebar-${tab}-${engine}`, live: null }
            if (action) ctx.invoke(entry, { invoke: () => assert.fail('sidebar routing should handle action') })
            else ctx.activate(entry)
            assert.deepEqual(opened, [[tab, engine]])
            assert.equal(ctx.shown, false)
            assert.deepEqual(raised, [])
        }
    }
})

test('desktop and phone notifications keep their normal activation', () => {
    for (const entry of [{ desktopEntry: 'claude' }, { desktopEntry: 'singularity-sidebar-code-codex', phone: true }]) {
        const { ctx, opened, raised } = context()
        let invoked = false
        entry.live = { tracked: true, actions: [{ identifier: 'default', invoke: () => { invoked = true } }] }
        ctx.activate(entry)
        assert.equal(invoked, true)
        assert.deepEqual(opened, [])
        assert.equal(raised.length, 1)
    }
})

test('sidebar completion notifications use the source service and retain their routing marker', () => {
    const ai = fs.readFileSync(new URL('../dotfiles/quickshell/.config/quickshell/services/Ai.qml', import.meta.url), 'utf8')
    for (const engine of ['claude', 'codex']) {
        const note = {}
        const ctx = vm.createContext({ shown: false, chatNote: note, codeNote: note,
            tabNames: { chat: 'Chat', code: 'Code' },
            Quickshell: { shellPath: p => `/shell/${p}` } })
        vm.runInContext(ai.match(/    function notify\([^]*?\n    }/)[0], ctx)
        ctx.notify('code', engine, 'done', 'Finished')
        const args = Array.from(note.command)
        assert.equal(args[args.indexOf('-a') + 1], engine === 'codex' ? 'Codex' : 'Claude')
        assert.equal(args[args.indexOf('-i') + 1], `/shell/sidebar/icons/${engine}.svg`)
        assert.ok(args.includes(`string:desktop-entry:singularity-sidebar-code-${engine}`))
        assert.ok(args.includes('default=Open'))
        assert.equal(note.running, true)
    }
})

test('Claude and Codex sidebar logos occupy the app icon slot, never the body image', () => {
    const ctx = vm.createContext({ Quickshell: { shellPath: p => `/shell/${p}` },
        pictureFor: n => n.image, desktopFor: () => null, isClaude: () => false })
    for (const name of ['sidebarIcon', 'iconOf', 'pictureOf'])
        vm.runInContext(source.match(new RegExp('    function ' + name + '\\([^]*?\\n    }'))[0], ctx)
    for (const engine of ['claude', 'codex']) {
        for (const live of [null, { tracked: true, image: `file:///shell/sidebar/icons/${engine}.svg` }]) {
            const entry = { desktopEntry: `singularity-sidebar-code-${engine}`, icon: '',
                picture: `file:///shell/sidebar/icons/${engine}.svg`, live }
            assert.equal(ctx.iconOf(entry), `file:///shell/sidebar/icons/${engine}.svg`)
            assert.equal(ctx.pictureOf(entry), '')
        }
    }
    const other = { appName: 'Mail', icon: 'mail-icon', picture: 'file:///photo.png', live: null }
    assert.equal(ctx.iconOf(other), 'mail-icon')
    assert.equal(ctx.pictureOf(other), 'file:///photo.png')
})
