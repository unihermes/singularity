// Runs in the extension's isolated world. Decides how each fullscreen request
// held by page.js is carried out, shows the "Ask" prompt, and relays
// in-window state through the background so iframes and their parents agree.

(() => {
  "use strict";
  const REQ = "psf:request", CMD = "psf:command", NOTE = "psf:note";
  const isTop = window === window.top;

  const toPage = (data, target = window) =>
    target.dispatchEvent(new CustomEvent(CMD, { detail: JSON.stringify(data) }));
  const send = (msg) => browser.runtime.sendMessage(msg);
  const parse = (e) => {
    try {
      return typeof e.detail === "string" ? JSON.parse(e.detail) : null;
    } catch {
      return null;
    }
  };

  let emulated = false;
  let expectReal = 0; // real fullscreen requests we let through, not yet entered
  // In-window fullscreens this script started. Only those are passed on to
  // the parent frame, so a page can't fill the window by faking page.js's note.
  let granted = 0;
  const emulate = (data, target) => {
    granted++;
    toPage(data, target);
  };

  // Shift held on the click or key that asked for fullscreen shows the Ask
  // prompt, whatever the site's mode. Clicks on a <video>'s own controls
  // never reach the page, so pressing or releasing Shift itself counts too,
  // and the window is generous because those controls go fullscreen late.
  let lastInput = { shift: false, time: 0 };
  for (const type of ["pointerdown", "mousedown", "mouseup", "click", "dblclick", "keydown", "keyup", "touchend"]) {
    window.addEventListener(type, (e) => {
      if (e.isTrusted) lastInput = { shift: e.shiftKey || e.key === "Shift", time: Date.now() };
    }, true);
  }
  // Where the pointer last was, so the Ask prompt opens under it.
  let pointer = null;
  for (const type of ["pointermove", "pointerdown", "mousemove"]) {
    window.addEventListener(type, (e) => {
      if (e.isTrusted) pointer = { x: e.clientX, y: e.clientY };
    }, { capture: true, passive: true });
  }

  const shiftAsked = () => lastInput.shift && Date.now() - lastInput.time < 3000;

  window.addEventListener(REQ, (e) => {
    const msg = parse(e);
    if (!msg || typeof msg.id !== "number") return;
    toPage({ type: "ack", id: msg.id });
    // A new request replaces a prompt still waiting for an answer.
    if (open) open.cancel();
    // Checked here, where the page can't fake them: a request needs a user
    // gesture and a document allowed to go fullscreen, as it natively would.
    const active = !navigator.userActivation || navigator.userActivation.isActive;
    if (!active || !document.fullscreenEnabled) {
      toPage({ type: "reject", id: msg.id });
      return;
    }
    const forceAsk = shiftAsked();
    handleRequest(msg.id, forceAsk).catch(() => toPage({ type: "native", id: msg.id }));
  }, true);

  async function handleRequest(id, forceAsk) {
    const decided = await send({ type: "decide" });
    const site = decided.site;
    const mode = forceAsk ? "ask" : decided.mode;
    let choice = mode;
    if (mode === "ask") {
      const answer = await ask(forceAsk ? null : site, site);
      if (!answer) {
        toPage({ type: "reject", id });
        return;
      }
      choice = answer.mode;
      if (answer.remember) send({ type: "remember", mode: choice }).catch(() => {});
    }
    if (choice === "screen") {
      const before = await send({ type: "window-state" }).catch(() => null);
      expectReal++;
      pendingScreen.set(id, before);
      toPage({ type: "native", id });
    } else {
      emulate({ type: "emulate", id });
    }
  }

  const pendingScreen = new Map();

  window.addEventListener(NOTE, (e) => {
    const msg = parse(e);
    if (!msg) return;
    if (msg.type === "result") {
      if (!pendingScreen.has(msg.id)) return;
      const before = pendingScreen.get(msg.id);
      pendingScreen.delete(msg.id);
      if (!msg.ok) expectReal = Math.max(0, expectReal - 1);
      if (msg.ok && before && before !== "fullscreen") {
        send({ type: "window-state" }).then(
          (after) => send({ type: "screen-result", ignored: after !== "fullscreen" }),
          () => {},
        );
      }
    } else if (msg.type === "state") {
      emulated = msg.on;
      if (msg.on) {
        if (granted > 0) {
          granted = 0;
          if (!isTop) send({ type: "frame-state", on: true }).catch(() => {});
        }
      } else if (msg.cause !== "remote" && msg.cause !== "child") {
        send({ type: "exit-all" }).catch(() => {});
      }
    }
  }, true);

  // Fullscreen the page didn't ask for through the API, such as the button
  // on a <video>'s own controls: follow the site's mode after the fact.
  document.addEventListener("fullscreenchange", (e) => {
    if (!e.isTrusted) return;
    const el = document.fullscreenElement;
    if (expectReal > 0) {
      if (el) expectReal--;
      return;
    }
    if (!el || el.localName === "iframe" || el.localName === "frame") return;
    adoptReal(shiftAsked()).catch(() => {});
  }, true);

  async function adoptReal(forceAsk) {
    const decided = await send({ type: "decide" });
    const site = decided.site;
    const mode = forceAsk ? "ask" : decided.mode;
    if (mode === "screen" || !document.fullscreenElement) return;
    emulate({ type: "to-window" });
    if (mode !== "ask") return;
    // Asked after moving it into the window: the rest of a page is inert
    // while something is really fullscreen, so the prompt couldn't be used.
    const answer = await ask(forceAsk ? null : site, site);
    if (!answer) {
      toPage({ type: "exit", cause: "page" });
      return;
    }
    if (answer.remember) send({ type: "remember", mode: answer.mode }).catch(() => {});
    if (answer.mode === "screen") toPage({ type: "to-screen" });
  }

  browser.runtime.onMessage.addListener((msg) => {
    if (msg.type === "exit") {
      if (emulated) toPage({ type: "exit" });
    } else if (msg.type === "child-state") {
      for (const frame of frames()) {
        let id;
        try {
          id = browser.runtime.getFrameId(frame);
        } catch {
          continue;
        }
        if (id === msg.frameId) {
          if (msg.on) emulate({ type: "frame", on: true }, frame);
          else toPage({ type: "frame", on: false }, frame);
          break;
        }
      }
    }
  });

  function* frames(root = document) {
    for (const el of root.querySelectorAll("*")) {
      if (el.localName === "iframe" || el.localName === "frame") yield el;
      else if (el.shadowRoot) yield* frames(el.shadowRoot);
    }
  }

  // A frame leaving while in-window fullscreen takes its parents out too.
  window.addEventListener("pagehide", () => {
    if (emulated && !isTop) send({ type: "exit-all" }).catch(() => {});
  });

  // ---- The "Ask" prompt ----

  let open = null;

  // rememberFor is null for a Shift-asked fullscreen: that choice is for
  // this once and can't be saved.
  function ask(rememberFor, site) {
    if (open) open.cancel();
    return new Promise((resolve) => {
      const host = document.createElement("div");
      const shadow = host.attachShadow({ mode: "closed" });
      host.style.cssText = "all: initial !important; position: fixed !important; inset: 0 !important;" +
        "width: 100% !important; height: 100% !important; margin: 0 !important; padding: 0 !important;" +
        "border: none !important; background: transparent !important; overflow: visible !important;" +
        "display: flex !important; align-items: center !important; justify-content: center !important;" +
        "z-index: 2147483647 !important; pointer-events: none !important;";
      host.setAttribute("popover", "manual");

      const style = document.createElement("style");
      style.textContent = PROMPT_CSS;
      const box = document.createElement("div");
      box.className = "box";
      box.setAttribute("role", "dialog");
      box.setAttribute("aria-label", "Fullscreen");

      const title = document.createElement("div");
      title.className = "title";
      title.textContent = site && site !== "file://" ? `Fullscreen on ${site}` : "Fullscreen";

      const buttons = document.createElement("div");
      buttons.className = "buttons";
      const screenBtn = button("Full screen", "screen");
      const windowBtn = button("In window", "window");
      buttons.append(screenBtn, windowBtn);

      const remember = document.createElement("label");
      remember.className = "remember";
      const check = document.createElement("input");
      check.type = "checkbox";
      remember.append(check, document.createTextNode(" Remember for this site"));
      if (!rememberFor) remember.hidden = true;

      const close = document.createElement("button");
      close.className = "cancel";
      close.title = "Cancel";
      close.setAttribute("aria-label", "Cancel");
      const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
      svg.setAttribute("viewBox", "0 0 12 12");
      const cross = document.createElementNS("http://www.w3.org/2000/svg", "path");
      cross.setAttribute("d", "M2.5 2.5l7 7M9.5 2.5l-7 7");
      svg.append(cross);
      close.append(svg);

      box.append(close, title, buttons, remember);
      shadow.append(style, box);

      function button(label, mode) {
        const b = document.createElement("button");
        b.textContent = label;
        b.className = mode;
        b.addEventListener("click", (e) => {
          e.stopPropagation();
          finish({ mode, remember: !!rememberFor && check.checked });
        });
        return b;
      }

      const onKey = (e) => {
        if (e.key === "Escape") {
          e.stopPropagation();
          e.preventDefault();
          finish(null);
        }
      };
      const finish = (answer) => {
        if (!open || open.host !== host) return;
        open = null;
        window.removeEventListener("keydown", onKey, true);
        window.removeEventListener("pagehide", cancel);
        try {
          host.hidePopover();
        } catch {}
        host.remove();
        resolve(answer);
      };
      const cancel = () => finish(null);
      close.addEventListener("click", (e) => {
        e.stopPropagation();
        finish(null);
      });
      for (const type of ["mousedown", "pointerdown", "mouseup", "pointerup", "click", "dblclick", "keydown", "keyup", "wheel"]) {
        box.addEventListener(type, (e) => {
          if (type !== "keydown" || e.key !== "Escape") e.stopPropagation();
        });
      }
      window.addEventListener("keydown", onKey, true);
      window.addEventListener("pagehide", cancel);

      open = { host, cancel };
      document.documentElement.append(host);
      try {
        host.showPopover();
      } catch {
        host.removeAttribute("popover");
      }
      if (pointer) {
        const w = box.offsetWidth, h = box.offsetHeight;
        const vw = host.clientWidth || innerWidth, vh = host.clientHeight || innerHeight;
        const clamp = (v, lo, hi) => Math.max(lo, Math.min(v, hi));
        box.style.position = "absolute";
        box.style.left = `${clamp(pointer.x - w / 2, 8, vw - w - 8)}px`;
        box.style.top = `${clamp(pointer.y - h / 2, 8, vh - h - 8)}px`;
      }
      screenBtn.focus({ preventScroll: true });
    });
  }

  const PROMPT_CSS = `
:host { color-scheme: light dark; }
.box {
  pointer-events: auto; position: relative; box-sizing: border-box;
  max-width: calc(100% - 16px); min-width: 0; padding: 14px 16px 12px;
  border-radius: 10px; font: 13px/1.35 system-ui, sans-serif;
  background: #fbfbfe; color: #15141a; border: 1px solid rgba(0,0,0,.15);
  box-shadow: 0 8px 28px rgba(0,0,0,.35); text-align: left;
}
@media (prefers-color-scheme: dark) {
  .box { background: #2b2a33; color: #fbfbfe; border-color: rgba(255,255,255,.12); }
}
.title { font-weight: 600; margin: 0 22px 10px 0; overflow-wrap: anywhere; }
.buttons { display: flex; gap: 8px; flex-wrap: wrap; }
button {
  font: inherit; cursor: pointer; border-radius: 6px; padding: 6px 12px; margin: 0;
  border: 1px solid rgba(128,128,128,.4); background: rgba(128,128,128,.14); color: inherit;
}
button:hover { background: rgba(128,128,128,.26); }
button:focus-visible { outline: 2px solid #5b5bd6; outline-offset: 1px; }
.screen { background: #5b5bd6; border-color: #5b5bd6; color: #fff; }
.screen:hover { background: #4a4ac4; }
.cancel {
  position: absolute; top: 6px; right: 6px; width: 24px; height: 24px; padding: 0;
  border: none; background: transparent; font-size: 17px; line-height: 24px; opacity: .7;
}
.cancel:hover { opacity: 1; background: rgba(128,128,128,.2); }
.cancel svg { display: block; width: 12px; height: 12px; margin: auto; fill: none; stroke: currentColor; stroke-width: 1.6; stroke-linecap: round; }
.remember { display: flex; align-items: center; gap: 6px; margin-top: 10px; cursor: pointer; user-select: none; }
.remember[hidden] { display: none; }
input { margin: 0; }
`;
})();
