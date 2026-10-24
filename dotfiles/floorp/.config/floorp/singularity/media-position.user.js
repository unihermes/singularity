// ==UserScript==
// @name        Media position
// @namespace   singularity
// @description Tells the browser a video's length and position, so MPRIS (the shell's Music module) shows its time
// @match       *://*/*
// @grant       none
// @run-at      document-start
// @inject-into page
// ==/UserScript==

// Floorp/Firefox take a video's time from the page's media session, else
// guess it from the video on play, pause and seek only. YouTube starts a
// video before its length loads and keeps clearing the session's,
// leaving MPRIS with neither length nor position. This sets the session
// from whichever audible video or audio last changed, and again each
// second while one plays, and ignores the page's clears. Muted media
// (hover previews) is skipped and a live stream clears it. The session
// can't hold a stopped clock, so a paused one runs at a rate too slow to
// move. Needs `@inject-into page` to reach the page's own session.
(() => {
    const session = navigator.mediaSession
    if (!session || !session.setPositionState) return

    // the page's own clears are dropped
    const set = session.setPositionState.bind(session)
    session.setPositionState = state => { if (state && Object.keys(state).length) set(state) }

    let last = 0
    const report = e => {
        const m = e.target
        if (!(m instanceof HTMLMediaElement) || m.muted) return
        if (e.type === "timeupdate" && performance.now() - last < 1000) return
        last = performance.now()
        try {
            if (Number.isFinite(m.duration) && m.duration > 0)
                set({
                    duration: m.duration,
                    position: Math.min(m.currentTime, m.duration),
                    playbackRate: m.paused ? 1e-9 : m.playbackRate > 0 ? m.playbackRate : 1,
                })
            else set()
        } catch (_) {}
    }

    // media events don't bubble, so they're caught on the way down
    for (const type of ["loadedmetadata", "durationchange", "playing", "pause", "seeked", "ratechange", "volumechange", "timeupdate"])
        document.addEventListener(type, report, true)
})()
