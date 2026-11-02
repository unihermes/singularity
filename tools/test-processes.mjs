import { test } from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import vm from 'node:vm'
import { spawnSync } from 'node:child_process'
import { source, functions, handler } from './qml-harness.mjs'

function writer() {
    const files = new Map(), results = [], sent = []
    const reader = { path: '', reload() {}, waitForJob() {}, text() { return files.get(this.path) || '' } }
    const proc = { running: false, write: value => sent.push(value) }
    const s = functions(source('AtomicFileWrite.qml'), { queue: [], current: null, advancing: false,
        pendingText: '', reader, proc, script: 'script', console: { warn() {} } })
    s.root = s
    // The real signal handlers read implicit properties from their owning object.
    s.writeStdin = proc.write
    const startedSource = source('AtomicFileWrite.qml').split('    Process {')[1]
        .replace('            write(root.pendingText)', '            writeStdin(root.pendingText)')
    const started = handler(startedSource, 'onStarted', s)
    const collected = handler(startedSource, 'onStreamFinished', s)
    function job(name, transform, done) {
        return { path: name, transform, done: done || ((status, detail) => results.push([name, status, detail])) }
    }
    function output(status = 'ok', detail = '') {
        s.text = `${status}\n${detail}`
        collected()
    }
    function exit() { proc.running = false; s.next() }
    return { s, files, results, sent, proc, started, job, output, exit }
}

test('Queued config writes reread the latest file and wait for exit and output in either order', () => {
    for (const first of ['exit', 'output']) {
        const w = writer()
        w.files.set('config', 'old')
        w.s.write(w.job('config', text => text + ' first'))
        w.s.write(w.job('config', text => text + ' second'))
        w.started()
        assert.deepEqual(w.sent, ['old first'])
        w.files.set('config', 'hand edited')
        if (first === 'exit') {
            w.exit()
            assert.equal(w.s.current.path, 'config')
            assert.equal(w.s.pendingText, '')
            w.output()
        } else {
            w.output()
            assert.equal(w.s.current, null)
            assert.equal(w.s.queue.length, 1)
            w.exit()
        }
        assert.equal(w.s.pendingText, 'hand edited second')
        w.started()
        w.output('syntax', 'bad config')
        w.exit()
        assert.equal(w.s.current, null)
        assert.equal(w.s.queue.length, 0)
        assert.deepEqual(w.results.map(row => row[1]), ['ok', 'syntax'])
    }
})

test('Refused and unchanged writes, thrown transforms and dead callbacks cannot stall or overlap writes', () => {
    const w = writer()
    w.s.write(w.job('blocker', () => 'blocker'))
    w.s.write(w.job('refused', () => null, () => {
        w.s.write(w.job('nested', () => 'nested'))
    }))
    w.s.write(w.job('next', () => 'next'))
    w.s.write(w.job('last', () => 'last'))
    w.output(); w.exit()
    assert.equal(w.s.current.path, 'next')
    assert.equal(w.s.pendingText, 'next')
    assert.deepEqual(Array.from(w.s.queue, job => job.path), ['last', 'nested'])
    for (let i = 0; i < 3; i++) { w.output(); w.exit() }
    w.s.write(w.job('throw', () => { throw Error('transform') }))
    w.s.write(w.job('unchanged', text => text, () => { throw Error('closed page') }))
    w.s.write(w.job('after', () => 'still runs'))
    assert.equal(w.s.current.path, 'after')
    assert.ok(w.results.some(row => row[0] === 'throw' && row[1] === 'refused'))
})

test('Atomic writer script preserves symlinks, permissions and backups, and refuses invalid shell syntax', () => {
    const text = source('AtomicFileWrite.qml').match(/readonly property string script: (`[^]*?`)\n/)[1]
    const script = vm.runInNewContext(text)
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'singularity-write-'))
    try {
        const target = path.join(dir, 'target'), link = path.join(dir, 'link'), backup = path.join(dir, 'backup')
        fs.writeFileSync(target, 'old\n', { mode: 0o600 })
        fs.symlinkSync(target, link)
        const write = (input, check = '', after = '') => spawnSync('sh', ['-c', script, 'sh', link, check, backup, after], { input, encoding: 'utf8' })
        assert.equal(write('new\n', 'bash', 'printf after').stdout, 'ok\nafter')
        assert.equal(fs.readFileSync(backup, 'utf8'), 'old\n')
        assert.equal(fs.readFileSync(target, 'utf8'), 'new\n')
        assert.equal(fs.statSync(target).mode & 0o777, 0o600)
        assert.equal(fs.readlinkSync(link), target)
        assert.ok(write('if then\n', 'bash').stdout.startsWith('syntax\n'))
        assert.equal(fs.readFileSync(target, 'utf8'), 'new\n')
        assert.equal(fs.existsSync(target + '.new'), false)
    } finally { fs.rmSync(dir, { recursive: true, force: true }) }
})

function session(engine) {
    const data = [], writes = [], signals = [], events = []
    const rows = { get count() { return data.length }, append: row => data.push(row),
        clear: () => { data.length = 0 }, get: i => {
            assert.ok(i >= 0 && i < data.length, `invalid transcript row ${i}`)
            return data[i]
        }, setProperty: (i, key, value) => { rows.get(i)[key] = value } }
    const proc = { running: false, ready: false, write: line => writes.push(JSON.parse(line)), signal: n => signals.push(n) }
    const s = functions(source('AiSession.qml') + '\n' + source(`${engine}Session.qml`), {
        rows, transcript: rows, proc, errors: { text: '' }, console: { warn() {} },
        queue: [], killing: false, stopping: false, initialized: false, resuming: false, threadReady: false,
        pending: {}, waiting: [], itemRows: {}, toolRows: {}, streamed: {}, streamIndex: {}, streamMsg: '',
        sessionId: '', turnId: '', busy: false, activity: '', asks: [], attachments: [],
        cwd: '/project', modelPick: '', reasoningPick: '', mode: 'default',
        modelName: '', slashCommands: [], contextUsed: 0, contextWindow: 0, unseen: false,
        tools: null, appendPrompt: '', extraArgs: [], nextId: 0, nextRequest: 0, cliMode: '',
        commandRunning: false, commandRow: -1, commandOutput: '', commandStopped: false, shellContext: '', generation: 0,
        commandProc: { running: false },
        approval: 'never', sandbox: 'workspace-write', sandboxPolicy: {}, instructions: '',
        turnEnded: () => events.push('end'), rateLimit: () => events.push('limit'), asked: () => events.push('ask'),
    })
    s.root = s
    const process = source(`${engine}Session.qml`).split('        id: proc')[1]
    const read = handler(process, 'onRead', s)
    const exit = handler(process, 'onExited', s)
    // onStarted uses Process.ready through unqualified names in Claude.
    const started = handler(process, 'onStarted', s)
    return { s, data, writes, signals, events, proc, read: value => read(JSON.stringify(value)), exit, started }
}

test('Claude reset/resume ignores late output and old startup, then sends queued input to the resumed process', () => {
    const c = session('Claude')
    c.proc.running = true
    c.proc.ready = true
    c.s.sessionId = 'old'
    c.read({ type: 'stream_event', event: { type: 'message_start', message: { id: 'm' } } })
    c.read({ type: 'stream_event', event: { type: 'content_block_start', index: 0, content_block: { type: 'text' } } })
    c.s.resume('saved', [{ kind: 'assistant', text: 'saved answer' }])
    assert.equal(c.s.sessionId, 'saved')
    c.read({ type: 'system', session_id: 'old' })
    c.read({ type: 'assistant', message: { content: [{ type: 'text', text: 'late' }] } })
    assert.equal(c.s.sessionId, 'saved')
    assert.deepEqual(c.data.map(row => row.text), ['saved answer'])
    c.s.send('new question')
    c.started() // an old delayed start signal must not drain new input
    assert.equal(c.writes.length, 0)
    assert.equal(c.s.queue.length, 1)
    c.proc.running = false
    c.exit(0)
    assert.equal(c.proc.running, true)
    assert.ok(c.proc.command.includes('--resume'))
    c.started()
    assert.equal(c.writes.length, 1)
    assert.equal(c.writes[0].message.content[0].text, 'new question')
    assert.deepEqual(Object.keys(c.s.streamIndex), [])
    assert.equal(c.s.streamMsg, '')
    assert.deepEqual(c.events, [])
})

test('Codex reset/resume drops old responses, clears canceled resume state and waits for history before send', () => {
    const c = session('Codex')
    c.proc.running = true
    c.s.initialized = true
    c.s.sessionId = 'old'
    let staleCalled = false
    c.s.call('old/request', {}, () => { staleCalled = true })
    const old = c.writes[0].id
    c.s.resume('saved')
    c.read({ id: old, result: {} })
    c.read({ method: 'item/completed', params: { threadId: 'old', item: { type: 'agentMessage', id: 'old', text: 'late' } } })
    assert.equal(staleCalled, false)
    assert.equal(c.data.length, 0)
    assert.equal(c.s.send('too early'), false)
    const count = c.writes.length
    c.started()
    assert.equal(c.writes.length, count)
    c.proc.running = false
    c.exit(0)
    c.started()
    const init = c.writes.at(-1)
    assert.equal(init.method, 'initialize')
    c.read({ id: init.id, result: {} })
    const resume = c.writes.at(-1)
    assert.equal(resume.method, 'thread/resume')
    assert.equal(resume.params.threadId, 'saved')
    c.read({ id: resume.id, result: { thread: { turns: [{ items: [{ type: 'agentMessage', id: 'saved-message', text: 'history' }] }] } } })
    assert.equal(c.s.resuming, false)
    assert.deepEqual(c.data.map(row => row.text), ['history'])
    assert.equal(c.s.send('follow-up'), true)
    assert.equal(c.writes.at(-1).method, 'turn/start')
    c.s.resuming = true
    c.s.reset()
    assert.equal(c.s.resuming, false)
    assert.equal(c.s.initialized, false)
})

test('Claude queued history keeps its target through either event order and discards canceled requests', () => {
    for (const order of ['output-first', 'exit-first']) {
        const historyProc = { job: null, running: false, collected: false, exited: false }
        const s = functions(source('Ai.qml'), { resumeQueue: [], historyProc, py: 'ai.py' })
        s.root = s
        const history = source('Ai.qml').split('        id: historyProc')[1].split('    Process {')[0]
        const output = handler(history, 'onStreamFinished', s)
        // Model unqualified Process properties in the real exit handler.
        Object.defineProperty(s, 'exited', { get: () => historyProc.exited, set: v => { historyProc.exited = v } })
        const exited = handler(history, 'onExited', s)
        const a = session('Claude'), b = session('Claude')
        s.resumeIn(a.s, 'a')
        s.resumeIn(b.s, 'b')
        assert.equal(a.s.busy, true)
        assert.equal(a.s.send('during history load'), false)
        if (order === 'exit-first') {
            historyProc.running = false
            exited()
            assert.equal(historyProc.job.id, 'a')
        }
        s.text = JSON.stringify([{ kind: 'assistant', text: 'a history' }])
        output()
        assert.deepEqual(a.data.map(row => row.text), ['a history'])
        assert.equal(b.data.length, 0)
        if (order === 'output-first') {
            assert.equal(historyProc.job.id, 'a')
            historyProc.running = false
            exited()
        }
        assert.equal(historyProc.job.id, 'b')
        b.s.reset()
        s.text = JSON.stringify([{ kind: 'assistant', text: 'obsolete' }])
        output()
        historyProc.running = false
        exited()
        assert.equal(historyProc.job, null)
        assert.equal(b.data.length, 0)
        assert.equal(b.s.sessionId, '')
    }
})

test('Session reset excludes late shell-command output from the next conversation', () => {
    for (const engine of ['Claude', 'Codex']) {
        const c = session(engine)
        c.s.commandRow = c.s.add({ kind: 'tool', name: 'Bash', phase: 'running' })
        c.s.shellContext = 'old context'
        c.s.reset()
        c.s.commandLine('late command output')
        const command = source('AiSession.qml').split('        id: commandProc')[1]
        handler(command, 'onExited', c.s)(0, 0)
        assert.equal(c.data.length, 0)
        assert.equal(c.s.shellContext, '')
        assert.equal(c.s.busy, false)
        assert.deepEqual(c.events, [])
    }
})

test('Writer launch failures report write errors and leave the queue usable', () => {
    const w = writer()
    w.s.write(w.job('first', () => 'new'))
    w.s.write(w.job('second', () => 'next'))
    w.output('shell failed before status')
    w.exit()
    assert.equal(w.results[0][1], 'write')
    assert.match(w.results[0][2], /shell failed/)
    assert.equal(w.s.current.path, 'second')
})

test('Codex failed resume exits release pending requests; the next send restores the saved thread', () => {
    const c = session('Codex')
    c.s.resume('saved')
    c.started()
    const init = c.writes.at(-1)
    c.read({ id: init.id, result: {} })
    const resume = c.writes.at(-1)
    assert.equal(resume.method, 'thread/resume')
    c.proc.running = false
    c.exit(1)
    assert.equal(c.s.resuming, false)
    assert.equal(c.s.busy, false)
    assert.deepEqual(Object.keys(c.s.pending), [])
    c.s.send('retry')
    c.started()
    c.read({ id: c.writes.at(-1).id, result: {} })
    assert.equal(c.writes.at(-1).method, 'thread/resume')
    c.read({ id: c.writes.at(-1).id, result: { thread: { id: 'saved' } } })
    assert.equal(c.writes.at(-1).method, 'turn/start')
    assert.equal(c.writes.at(-1).params.threadId, 'saved')
})

test('Normal completion notifies once and interruption completes without notifying in both adapters', () => {
    for (const engine of ['Claude', 'Codex']) for (const stop of [false, true]) {
        const c = session(engine)
        c.s.busy = true
        c.s.stopping = stop
        c.s.sessionId = 'thread'
        c.s.add({ kind: 'tool', phase: 'running', name: 'Bash' })
        if (engine === 'Claude') c.read({ type: 'result', subtype: 'success' })
        else c.read({ method: 'turn/completed', params: { threadId: 'thread', turn: { status: stop ? 'interrupted' : 'completed' } } })
        assert.equal(c.s.busy, false)
        assert.equal(c.s.stopping, false)
        assert.equal(c.s.unseen, true)
        assert.equal(c.data[0].phase, 'stopped')
        assert.equal(c.events.length, stop ? 0 : 1)
    }
})

test('Native Quickshell loads the adapters and completes chained atomic writes', {
    skip: spawnSync('qs', ['--version'], { encoding: 'utf8' }).error?.code === 'ENOENT'
}, () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'singularity-qml-'))
    try {
        for (const name of ['AiSession.qml', 'ClaudeSession.qml', 'CodexSession.qml', 'AtomicFileWrite.qml']) {
            fs.writeFileSync(path.join(dir, name), source(name))
        }
        fs.writeFileSync(path.join(dir, 'qmldir'), [
            'singleton AtomicFileWrite 1.0 AtomicFileWrite.qml',
            'AiSession 1.0 AiSession.qml', 'ClaudeSession 1.0 ClaudeSession.qml',
            'CodexSession 1.0 CodexSession.qml', ''
        ].join('\n'))
        const target = JSON.stringify(path.join(dir, 'config'))
        fs.writeFileSync(path.join(dir, 'shell.qml'), `import Quickshell
import QtQuick
import "."
ShellRoot {
    ClaudeSession { id: claude }
    CodexSession { id: codex }
    Component.onCompleted: {
        claude.resume("saved", [{kind: "assistant", text: "history"}])
        if (claude.transcript.count !== 1) throw Error("resume failed")
        codex.reset()
        AtomicFileWrite.write({path: ${target}, transform: t => "one", done: (status, detail) => {
            if (status !== "ok") throw Error(status + detail)
            AtomicFileWrite.write({path: ${target}, transform: t => t + " two", done: status => {
                if (status !== "ok") throw Error(status)
                console.log("NATIVE_PROCESS_CHECK_PASSED")
                Qt.quit()
            }})
        }})
    }
}`)
        fs.mkdirSync(path.join(dir, 'runtime'), { mode: 0o700 })
        const env = { ...process.env, QT_QPA_PLATFORM: 'offscreen', XDG_CACHE_HOME: path.join(dir, 'cache'),
            XDG_RUNTIME_DIR: path.join(dir, 'runtime') }
        delete env.WAYLAND_DISPLAY
        const run = spawnSync('qs', ['-p', dir, '--no-color'], { env, encoding: 'utf8', timeout: 5000 })
        assert.equal(run.status, 0, run.stdout + run.stderr)
        assert.match(run.stdout + run.stderr, /NATIVE_PROCESS_CHECK_PASSED/)
        assert.equal(fs.readFileSync(path.join(dir, 'config'), 'utf8'), 'one two')
    } finally { fs.rmSync(dir, { recursive: true, force: true }) }
})

test('Codex initialization failure clears old work and restarts for the next send', () => {
    const c = session('Codex')
    c.s.resume('saved')
    c.started()
    c.read({ id: c.writes.at(-1).id, error: { message: 'initialization failed' } })
    assert.equal(c.s.killing, true)
    assert.equal(c.s.resuming, false)
    assert.equal(c.s.waiting.length, 0)
    assert.deepEqual(Object.keys(c.s.pending), [])
    c.s.send('retry')
    c.proc.running = false
    c.exit(0)
    assert.equal(c.proc.running, true)
    c.started()
    c.read({ id: c.writes.at(-1).id, result: {} })
    assert.equal(c.writes.at(-1).method, 'thread/resume')
})
