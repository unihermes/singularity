// Runs in the page's own world. Page fullscreen requests are held here until
// content.js says how to carry them out: with the browser's real fullscreen,
// or by filling the window ("in window"), where the page is told it is
// fullscreen while the element is laid over the page in the top layer.
// Messages to content.js are events on window carrying JSON strings.

(() => {
  "use strict";
  if (window.__perSiteFullscreen) return;
  Object.defineProperty(window, "__perSiteFullscreen", { value: true });

  const REQ = "psf:request", CMD = "psf:command", NOTE = "psf:note";
  const EP = Element.prototype, DP = Document.prototype;
  const SRP = typeof ShadowRoot === "function" ? ShadowRoot.prototype : null;

  const getter = (proto, name) => {
    const d = proto && Object.getOwnPropertyDescriptor(proto, name);
    return d && d.get;
  };
  const nativeElement = getter(DP, "fullscreenElement");
  const nativeRequests = {};
  for (const name of ["requestFullscreen", "mozRequestFullScreen", "webkitRequestFullscreen", "webkitRequestFullScreen"]) {
    if (typeof EP[name] === "function") nativeRequests[name] = EP[name];
  }
  const nativeExits = {};
  for (const name of ["exitFullscreen", "mozCancelFullScreen", "webkitExitFullscreen", "webkitCancelFullScreen"]) {
    if (typeof DP[name] === "function") nativeExits[name] = DP[name];
  }
  const realElement = () => nativeElement.call(document);
  const nativeRequest = nativeRequests.requestFullscreen;
  const nativeExit = nativeExits.exitFullscreen;
  if (!nativeElement || !nativeRequest || !nativeExit) return;

  const note = (data) => window.dispatchEvent(new CustomEvent(NOTE, { detail: JSON.stringify(data) }));

  // ---- In-window fullscreen ----

  const CSS = `
[data-psf-fullscreen]:not(:root) {
  position: fixed !important; inset: 0 !important; margin: 0 !important;
  box-sizing: border-box !important; min-width: 0 !important; max-width: none !important;
  min-height: 0 !important; max-height: none !important;
  width: 100% !important; height: 100% !important;
  transform: none !important; translate: none !important; scale: none !important; rotate: none !important;
  z-index: 2147483647 !important; object-fit: contain;
}
:where([data-psf-fullscreen][popover]) {
  padding: 0; border: none; overflow: visible; color: inherit; background-color: transparent;
}
:where(iframe[data-psf-fullscreen], frame[data-psf-fullscreen]) { border: none !important; padding: 0 !important; }
[data-psf-fullscreen]::backdrop { background: black !important; }
:where([data-psf-fullscreen]:not([popover]):not(:root)) { background-color: black; }
:root[data-psf-lock] { overflow: hidden !important; }
`;
  let sheet = null;
  const adopt = (root) => {
    try {
      if (!sheet) {
        sheet = new CSSStyleSheet();
        sheet.replaceSync(CSS);
      }
      if (!root.adoptedStyleSheets.includes(sheet)) {
        root.adoptedStyleSheets = [...root.adoptedStyleSheets, sheet];
      }
      return true;
    } catch {
      return false;
    }
  };
  // Fallback when a constructed sheet can't be adopted: inline !important styles.
  const INLINE = {
    position: "fixed", inset: "0px", margin: "0px", "box-sizing": "border-box",
    "min-width": "0px", "max-width": "none", "min-height": "0px", "max-height": "none",
    width: "100%", height: "100%", transform: "none", "z-index": "2147483647",
  };

  let emu = null; // { el, popover, inlined, inline, observer }

  // The element a document or shadow root reports as fullscreen: the
  // emulated element, or its shadow host as seen from outside the shadow.
  const retarget = (el, root) => {
    for (let node = el; node; ) {
      const r = node.getRootNode();
      if (r === root) return node;
      if (SRP && r instanceof ShadowRoot) node = r.host;
      else return null;
    }
    return null;
  };

  const fire = (el) => {
    const target = el && el.isConnected ? el : document;
    target.dispatchEvent(new Event("fullscreenchange", { bubbles: true, composed: true }));
  };

  function emulate(el, cause) {
    if (emu && emu.el === el) return;
    if (emu) unemulate("switch");
    const isRoot = el === document.documentElement;
    const state = { el, popover: false, inlined: false, inline: null, observer: null };
    el.setAttribute("data-psf-fullscreen", "");
    if (!isRoot) {
      const root = el.getRootNode();
      let styled = adopt(document);
      if (root !== document) styled = adopt(root) && styled;
      if (!styled) {
        state.inlined = true;
        state.inline = el.getAttribute("style");
        for (const [k, v] of Object.entries(INLINE)) el.style.setProperty(k, v, "important");
      }
      document.documentElement.setAttribute("data-psf-lock", "");
      if (!el.hasAttribute("popover") && typeof el.showPopover === "function" &&
          !(typeof HTMLDialogElement === "function" && el instanceof HTMLDialogElement)) {
        el.setAttribute("popover", "manual");
        try {
          el.showPopover();
          state.popover = true;
        } catch {
          el.removeAttribute("popover");
        }
      }
    }
    // The page removing the element ends fullscreen, as it would natively.
    state.observer = new MutationObserver(() => {
      if (emu === state && !el.isConnected) unemulate("removed");
    });
    state.observer.observe(document, { childList: true, subtree: true });
    emu = state;
    fire(el);
    window.dispatchEvent(new Event("resize"));
    note({ type: "state", on: true, cause });
  }

  function unemulate(cause) {
    if (!emu) return;
    const { el, popover, inlined, inline, observer } = emu;
    emu = null;
    observer.disconnect();
    if (popover) {
      try {
        el.hidePopover();
      } catch {}
      el.removeAttribute("popover");
    }
    if (inlined) {
      if (inline === null) el.removeAttribute("style");
      else el.setAttribute("style", inline);
    }
    el.removeAttribute("data-psf-fullscreen");
    document.documentElement.removeAttribute("data-psf-lock");
    if (cause === "switch") return;
    fire(el);
    window.dispatchEvent(new Event("resize"));
    note({ type: "state", on: false, cause });
  }

  // Escape leaves in-window fullscreen, as it leaves the real one.
  window.addEventListener("keydown", (e) => {
    if (emu && e.key === "Escape" && !e.repeat) unemulate("escape");
  }, true);

  // Real fullscreen events the page shouldn't see: the exit when a real
  // fullscreen is turned into an in-window one.
  let swallow = 0;
  const swallowChange = (e) => {
    if (swallow > 0 && e.isTrusted) {
      swallow--;
      e.stopImmediatePropagation();
    }
  };
  window.addEventListener("fullscreenchange", swallowChange, true);

  // Turn the element that is really fullscreen into an in-window one.
  function toWindow(cause) {
    const el = realElement();
    if (!el) return;
    let inner = el;
    while (inner.shadowRoot) {
      const deeper = nativeElement.call(inner.shadowRoot);
      if (!deeper || deeper === inner) break;
      inner = deeper;
    }
    swallow++;
    nativeExit.call(document).catch(() => { swallow = Math.max(0, swallow - 1); });
    emulate(inner, cause);
  }

  // Turn an in-window fullscreen into the real one; needs a user gesture.
  function toScreen() {
    if (!emu) return;
    const el = emu.el;
    unemulate("switch");
    swallow++;
    nativeRequest.call(el).catch(() => {
      swallow = Math.max(0, swallow - 1);
      emulate(el, "page");
    });
  }

  // ---- Requests from the page ----

  let seq = 0;
  const pending = new Map();

  function makeRequest(name) {
    const nat = nativeRequests[name];
    const returnsPromise = name === "requestFullscreen";
    return {
      [name](options) {
        const el = this;
        if (!(el instanceof Element) || !el.isConnected) return nat.apply(this, arguments);
        let result;
        // Already fullscreen in the window: move it to the new element.
        if (emu) {
          emulate(el, "page");
          result = Promise.resolve();
        } else if (realElement()) {
          result = nativeRequest.call(el, options);
        } else {
          const id = ++seq;
          result = new Promise((resolve, reject) => {
            pending.set(id, { el, options, resolve, reject, acked: false });
          });
          window.dispatchEvent(new CustomEvent(REQ, { detail: JSON.stringify({ id }) }));
          const p = pending.get(id);
          // content.js isn't there (extension updating): behave natively.
          if (p && !p.acked) {
            pending.delete(id);
            nativeRequest.call(el, options).then(p.resolve, p.reject);
          }
        }
        if (returnsPromise) return result;
        result.catch(() => {});
        return undefined;
      },
    }[name];
  }

  function makeExit(name) {
    const nat = nativeExits[name];
    const returnsPromise = name === "exitFullscreen";
    return {
      [name]() {
        if (emu && this === document) {
          unemulate("page");
          return returnsPromise ? Promise.resolve() : undefined;
        }
        return nat.apply(this, arguments);
      },
    }[name];
  }

  const deny = () => new TypeError("Fullscreen request denied");

  window.addEventListener(CMD, (e) => {
    let msg;
    try {
      msg = JSON.parse(e.detail);
    } catch {
      return;
    }
    const p = msg.id !== undefined ? pending.get(msg.id) : null;
    switch (msg.type) {
      case "ack":
        if (p) p.acked = true;
        break;
      case "native":
        if (!p) break;
        pending.delete(msg.id);
        nativeRequest.call(p.el, p.options).then(
          () => { p.resolve(); note({ type: "result", id: msg.id, ok: true }); },
          (err) => { p.reject(err); note({ type: "result", id: msg.id, ok: false }); },
        );
        break;
      case "emulate":
        if (!p) break;
        pending.delete(msg.id);
        if (!p.el.isConnected) {
          p.reject(deny());
          break;
        }
        emulate(p.el, "page");
        p.resolve();
        break;
      case "reject":
        if (!p) break;
        pending.delete(msg.id);
        document.dispatchEvent(new Event("fullscreenerror", { bubbles: true, composed: true }));
        p.reject(deny());
        break;
      case "to-window":
        toWindow(msg.cause || "adopt");
        break;
      case "to-screen":
        toScreen();
        break;
      case "frame":
        // Sent on an <iframe> whose page went fullscreen in its window.
        if (msg.on && e.target instanceof Element) emulate(e.target, "child");
        else if (!msg.on && emu && emu.el === e.target) unemulate("child");
        break;
      case "exit":
        unemulate(msg.cause || "remote");
        break;
    }
  }, true);

  // ---- Replace the page-facing API ----

  const define = (proto, name, desc) => {
    const old = Object.getOwnPropertyDescriptor(proto, name);
    if (!old) return;
    Object.defineProperty(proto, name, { ...desc, enumerable: old.enumerable, configurable: true });
  };
  const method = (proto, name, fn) => define(proto, name, { value: fn, writable: true });
  const getterFor = (proto, name, fn) => {
    const get = { get [name]() { return fn.call(this); } };
    define(proto, name, { get: Object.getOwnPropertyDescriptor(get, name).get });
  };

  for (const name of Object.keys(nativeRequests)) method(EP, name, makeRequest(name));
  for (const name of Object.keys(nativeExits)) method(DP, name, makeExit(name));

  const docElement = function () {
    if (emu) return this === document ? retarget(emu.el, document) : null;
    return nativeElement.call(this);
  };
  for (const name of ["fullscreenElement", "mozFullScreenElement", "webkitFullscreenElement", "webkitCurrentFullScreenElement"]) {
    getterFor(DP, name, docElement);
  }
  for (const name of ["fullscreen", "mozFullScreen", "webkitIsFullScreen"]) {
    getterFor(DP, name, function () { return !!docElement.call(this); });
  }
  const nativeShadowElement = getter(SRP, "fullscreenElement");
  if (nativeShadowElement) {
    getterFor(SRP, "fullscreenElement", function () {
      if (emu) return retarget(emu.el, this);
      return nativeShadowElement.call(this);
    });
  }
})();
