// The options page: the default mode and every site's rule.

const $ = (id) => document.getElementById(id);

function modeSelect(value, onChange) {
  const select = document.createElement("select");
  for (const [mode, label] of Object.entries(MODES)) select.add(new Option(label, mode, false, mode === value));
  if (onChange) select.addEventListener("change", () => onChange(select.value));
  return select;
}

async function render() {
  const settings = await loadSettings();
  $("warn").hidden = !(await browser.storage.local.get("widgetsIgnored")).widgetsIgnored;

  const def = $("default");
  def.replaceChildren();
  for (const [mode, label] of Object.entries(MODES)) {
    const row = document.createElement("label");
    const radio = document.createElement("input");
    radio.type = "radio";
    radio.name = "default";
    radio.value = mode;
    radio.checked = mode === settings.defaultMode;
    radio.addEventListener("change", () => browser.storage.local.set({ defaultMode: mode }));
    row.append(radio, document.createTextNode(label));
    def.append(row);
  }

  const rules = $("rules");
  rules.replaceChildren();
  const hosts = Object.keys(settings.sites).sort((a, b) => a.localeCompare(b));
  $("empty").hidden = hosts.length > 0;
  rules.parentElement.hidden = hosts.length === 0;
  for (const host of hosts) {
    const tr = document.createElement("tr");
    const site = document.createElement("td");
    site.className = "site";
    site.textContent = host === "file://" ? "Local files" : host;
    const mode = document.createElement("td");
    mode.append(modeSelect(settings.sites[host], (value) => update(host, value)));
    const act = document.createElement("td");
    act.className = "act";
    const remove = document.createElement("button");
    remove.textContent = "Remove";
    remove.setAttribute("aria-label", `Remove ${host}`);
    remove.addEventListener("click", () => update(host, null));
    act.append(remove);
    tr.append(site, mode, act);
    rules.append(tr);
  }
}

async function update(host, mode) {
  const { sites } = await loadSettings();
  if (mode) sites[host] = mode;
  else delete sites[host];
  await browser.storage.local.set({ sites });
}

$("add-mode").replaceWith(Object.assign(modeSelect("screen"), { id: "add-mode" }));
$("add").addEventListener("submit", async (e) => {
  e.preventDefault();
  const host = normalizeHost($("add-host").value);
  $("add-error").hidden = !!host;
  if (!host) return;
  await update(host, $("add-mode").value);
  $("add-host").value = "";
});

browser.storage.onChanged.addListener(render);
render();
