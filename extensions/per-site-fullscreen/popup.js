// The toolbar button: the mode for the current tab's site.

const $ = (id) => document.getElementById(id);

async function render() {
  const [tab] = await browser.tabs.query({ active: true, currentWindow: true });
  const key = tab && siteKey(tab.url || "");
  const settings = await loadSettings();
  $("warn").hidden = !(await browser.storage.local.get("widgetsIgnored")).widgetsIgnored;

  if (!key) {
    $("site").textContent = "This page";
    $("none").hidden = false;
    $("pick").hidden = true;
    return;
  }
  $("site").textContent = key === "file://" ? "Local files" : key;

  const own = settings.sites[key];
  const inherited = !own && findRule(settings.sites, key);
  const rule = $("rule");
  rule.hidden = !inherited;
  if (inherited) rule.textContent = `Following the rule for ${inherited.host}.`;

  const current = own || (inherited ? inherited.mode : "default");
  const options = [["default", `Default (${MODES[settings.defaultMode]})`], ...Object.entries(MODES)];
  const pick = $("pick");
  pick.replaceChildren();
  for (const [value, label] of options) {
    const row = document.createElement("label");
    const radio = document.createElement("input");
    radio.type = "radio";
    radio.name = "mode";
    radio.value = value;
    radio.checked = value === current;
    radio.addEventListener("change", () => choose(key, value));
    row.append(radio, document.createTextNode(label));
    pick.append(row);
  }
}

async function choose(key, value) {
  const { sites } = await loadSettings();
  if (value === "default") delete sites[key];
  else sites[key] = value;
  await browser.storage.local.set({ sites });
  render();
}

$("options").addEventListener("click", () => {
  browser.runtime.openOptionsPage();
  window.close();
});

render();
