// Answers the content scripts: which mode a tab's site uses, saving a choice
// made in the "Ask" prompt, and relaying in-window state between the frames
// of a tab so an iframe's fullscreen also fills its parent pages.

browser.runtime.onMessage.addListener((msg, sender) => {
  // Zen's first tab in a new profile isn't known to extensions; the frame's
  // own address stands in for the tab's there.
  const tab = sender.tab;
  const url = tab ? tab.url : sender.url;

  switch (msg.type) {
    case "decide":
      return (async () => {
        const settings = await loadSettings();
        const key = siteKey(url);
        return { mode: modeFor(settings, key), site: key };
      })();

    case "remember":
      return (async () => {
        const key = siteKey(url);
        if (!key || !MODES[msg.mode]) return false;
        const { sites } = await loadSettings();
        sites[key] = msg.mode;
        await browser.storage.local.set({ sites });
        return true;
      })();

    case "window-state":
      if (!tab) return Promise.resolve(null);
      return browser.windows.get(tab.windowId).then((w) => w.state);

    // A full screen request that left the window as it was: the browser
    // keeps page fullscreen inside the window (full-screen-api.ignore-widgets).
    case "screen-result":
      return browser.storage.local.set({ widgetsIgnored: !!msg.ignored });

    case "frame-state":
      if (tab) broadcast(tab.id, { type: "child-state", frameId: sender.frameId, on: msg.on });
      return undefined;

    case "exit-all":
      if (tab) broadcast(tab.id, { type: "exit" });
      return undefined;
  }
  return undefined;
});

function broadcast(tabId, msg) {
  browser.tabs.sendMessage(tabId, msg).catch(() => {});
}
