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

test('older notifications use durable routing even when a stale action is present', () => {
    const { ctx, opened, raised } = context()
    let invoked = false
    ctx.activate({ appName: 'Claude', desktopEntry: '', summary: 'Claude · Code: done',
        live: { tracked: true, actions: [{ identifier: 'open', invoke: () => { invoked = true } }] } })
    assert.equal(invoked, false)
    assert.deepEqual(opened, [['code', 'claude']])
    assert.deepEqual(raised, [])
    assert.equal(ctx.shown, false)
})

test('older sidebar history still routes to the host when its action has expired', () => {
    const { ctx, opened, raised } = context()
    ctx.activate({ appName: 'Claude', desktopEntry: '', summary: 'Claude · Chat: replied', live: null })
    assert.deepEqual(opened, [['chat', 'claude']])
    assert.deepEqual(raised, [])
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

test('old duplicate pairs become one Codex card with a durable route', () => {
    const body = 'The finished task has a detailed result that is shared by both notifications.'
    const old = { key: 'a', id: 1, time: 1000, appName: 'Claude', summary: 'Claude · Code: done', body, live: { tracked: true } }
    const hook = { key: 'b', id: 2, time: 1100, appName: 'Codex', summary: 'Codex', body, live: { tracked: true } }
    const unrelated = { key: 'c', id: 3, time: 1200, appName: 'Codex', summary: 'Codex', body: 'A separate terminal task', live: null }
    const ctx = vm.createContext({ history: [hook, old, unrelated], popups: [hook, old],
        Quickshell: { shellPath: p => `/shell/${p}` }, saveTimer: { restart() {} } })
    vm.runInContext(source.match(/    function repairSidebarHistory\([^]*?\n    }/)[0], ctx)
    ctx.repairSidebarHistory()
    assert.equal(ctx.history.length, 2)
    assert.equal(ctx.history[0].desktopEntry, 'singularity-sidebar-code-codex')
    assert.equal(ctx.history[0].appName, 'Codex')
    assert.equal(ctx.popups.length, 1)
    assert.equal(hook.live.tracked, false)
    assert.equal(old.live.tracked, false)
    assert.equal(ctx.history[1], unrelated)
    ctx.repairSidebarHistory()
    assert.equal(ctx.history.length, 2)
})
