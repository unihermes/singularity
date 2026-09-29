// Settings and site matching, shared by the background, popup and options pages.

const MODES = {
  window: "In window",
  screen: "Full screen",
  ask: "Ask",
};

const DEFAULT_SETTINGS = { defaultMode: "window", sites: {} };

async function loadSettings() {
  const s = await browser.storage.local.get(DEFAULT_SETTINGS);
  if (!MODES[s.defaultMode]) s.defaultMode = DEFAULT_SETTINGS.defaultMode;
  if (typeof s.sites !== "object" || !s.sites) s.sites = {};
  return s;
}

// The key a site's rule is saved under: its host without "www.", or null for
// pages no rule can apply to (about:, moz-extension: and the like).
function siteKey(url) {
  let u;
  try {
    u = new URL(url);
  } catch {
    return null;
  }
  if (u.protocol === "file:") return "file://";
  if (u.protocol !== "http:" && u.protocol !== "https:") return null;
  return normalizeHost(u.hostname);
}

// Accepts a bare domain or a pasted URL, as typed on the options page.
function normalizeHost(text) {
  let h = String(text).trim().toLowerCase();
  if (h === "file://" || h === "file") return "file://";
  if (/^[a-z][a-z0-9+.-]*:\/\//.test(h)) {
    try {
      h = new URL(h).hostname;
    } catch {
      return null;
    }
  }
  h = h.replace(/[/?#].*$/, "").replace(/:\d+$/, "").replace(/\.$/, "").replace(/^\*\./, "");
  h = h.replace(/^www\./, "");
  if (!h || !/^(\[[0-9a-f:.]+\]|[a-z0-9.-]+)$/.test(h)) return null;
  return h;
}

// A rule for example.com also covers its subdomains; the most specific wins.
function findRule(sites, key) {
  if (!key) return null;
  if (key.startsWith("[") || /^\d+(\.\d+){3}$/.test(key) || key === "file://") {
    return sites[key] ? { host: key, mode: sites[key] } : null;
  }
  for (let h = key; h; ) {
    if (MODES[sites[h]]) return { host: h, mode: sites[h] };
    const dot = h.indexOf(".");
    if (dot < 0) break;
    h = h.slice(dot + 1);
  }
  return null;
}

function modeFor(settings, key) {
  const rule = findRule(settings.sites, key);
  return rule ? rule.mode : settings.defaultMode;
}
