import { test } from 'node:test'
import assert from 'node:assert/strict'
import vm from 'node:vm'
import { source, functions } from './qml-harness.mjs'

function settings() {
    const V = vm.createContext({})
    vm.runInContext(source('SettingsValues.js').replace('.pragma library', ''), V)
    const adapter = { ...V.defaults }
    const ctx = functions(source('Settings.qml'), { adapter, Values: V, limits: V.limits,
        choices: V.choices, hexKeys: [], headingShapes: [], isFinite,
        Looks: { densities: { compact: { spacing: 85, rowScale: 90, barHeight: 28 } } } })
    return { ctx, adapter }
}

test('Settings public setters keep density, schedules, bounds and refusal behavior', () => {
    const { ctx: s, adapter: a } = settings()
    s.set('density', 'compact')
    assert.equal(a.spacing, 85)
    s.setReplaySeconds(900)
    assert.equal(a.replaySeconds, 600)
    s.setUpdateInterval(-2)
    assert.equal(a.updateInterval, 0)
    s.setNotifTimeout('notifTimeoutCritical', 70)
    assert.equal(a.notifTimeoutCritical, 60)
    s.setScheduleTime('nightLightFrom', -30)
    assert.equal(a.nightLightFrom, 1410)
    s.setScheduleTime('nightLightFrom', Infinity)
    assert.equal(a.nightLightFrom, 1410)
    s.set('radius', NaN)
    assert.equal(a.radius, 6)
    s.set('radius', 99)
    assert.equal(a.radius, 14)
    s.set('missing', 1)
    assert.equal(a.missing, undefined)
    s.cycle('missing', 1)
})

test('Hand edits and imported defaults are normalized before use', () => {
    const { ctx: s, adapter: a } = settings()
    a.radius = 999
    a.notifPositionX = 'invalid'
    a.weekStart = 5
    s.normalizeStored()
    assert.equal(a.radius, 14)
    assert.equal(a.notifPositionX, 'right')
    assert.equal(a.weekStart, 1)
    s.applyValues({ radius: -1, windowScope: 'typo', unknown: true })
    assert.equal(a.radius, 0)
    assert.equal(a.windowScope, 'workspace')
    assert.equal(a.unknown, undefined)
    a.colourMode = 'wallpaper'
    s.applyValues({ seeThrough: 100 })
    assert.equal(a.seeThrough, 100)
    a.seeThrough = 85
    s.applyValues({ seeThrough: 100 })
    assert.equal(a.seeThrough, 85)
})
