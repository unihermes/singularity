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
