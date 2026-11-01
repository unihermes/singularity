#!/usr/bin/env python3
"""Show a sidebar artifact: its source on stdin becomes a page in
~/.cache/singularity/artifacts, opened in ArtifactViewer.qml or the browser.

artifact.py VIEWER TYPE TITLE BG FG ACCENT [browser]
TYPE: html | react | svg | mermaid | markdown (anything else shows as text).
"""
import hashlib
import html
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

REACT = '18.3.1'
IMPORTS = {
    'react': f'https://esm.sh/react@{REACT}',
    'react/': f'https://esm.sh/react@{REACT}/',
    'react-dom': f'https://esm.sh/react-dom@{REACT}?deps=react@{REACT}',
    'react-dom/client': f'https://esm.sh/react-dom@{REACT}/client?deps=react@{REACT}',
    'recharts': f'https://esm.sh/recharts@2?deps=react@{REACT},react-dom@{REACT}',
    'lucide-react': f'https://esm.sh/lucide-react@0.460.0?deps=react@{REACT}',
}

# errors shown on the page, since the viewer has no console
ERRORS = """<script>
addEventListener('error', e => show(e.message + (e.lineno ? ' (line ' + e.lineno + ')' : '')));
addEventListener('unhandledrejection', e => show(String(e.reason)));
function show(m) {
  const p = document.createElement('pre');
  p.style.cssText = 'position:fixed;left:0;right:0;bottom:0;margin:0;padding:8px 12px;'
    + 'background:#3b1219;color:#ffb4b4;font:12px monospace;white-space:pre-wrap;z-index:99999';
  p.textContent = m;
  document.body.appendChild(p);
}
</script>"""


def script_safe(code):
    return code.replace('</script', '<\\/script')


def page(kind, title, code, bg, fg, accent):
    head = (f'<!doctype html><html><head><meta charset="utf-8">'
            f'<meta name="viewport" content="width=device-width,initial-scale=1">'
            f'<title>{html.escape(title)}</title>{ERRORS}')
    themed = (f'<style>html,body{{margin:0;background:{bg};color:{fg};'
              f'font-family:system-ui,sans-serif}}a{{color:{accent}}}</style>')
    if kind == 'html':
        low = code.lstrip()[:200].lower()
        if low.startswith('<!doctype') or low.startswith('<html'):
            # the page's own head, with the error banner first
            i = code.lower().find('<head>')
            return code[:i + 6] + ERRORS + code[i + 6:] if i >= 0 else ERRORS + code
        return head + '</head><body>' + code + '</body></html>'
    if kind == 'svg':
        return (head + themed + '<style>body{display:grid;place-items:center;min-height:100vh}'
                'svg{max-width:100vw;max-height:100vh}</style></head><body>' + code + '</body></html>')
    if kind == 'mermaid':
        dark = 'dark' if sum(int(bg[i:i + 2], 16) for i in (1, 3, 5)) < 384 else 'default'
        return (head + themed + '<style>body{display:grid;place-items:center;min-height:100vh}</style>'
                '</head><body><pre class="mermaid">' + html.escape(code) + '</pre>'
                '<script type="module">import m from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";'
                f'm.initialize({{startOnLoad:true,theme:"{dark}"}});</script></body></html>')
    if kind in ('markdown', 'md'):
        return (head + themed + '<style>body{max-width:46rem;margin:0 auto;padding:2rem;line-height:1.6}'
                f'pre,code{{background:rgba(127,127,127,.15);border-radius:4px}}pre{{padding:.8rem;overflow:auto}}'
                'table{border-collapse:collapse}td,th{border:1px solid rgba(127,127,127,.4);padding:4px 8px}'
                'img{max-width:100%}</style>'
                '<script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script></head><body>'
                '<main id="md"></main><script>document.getElementById("md").innerHTML=marked.parse('
                + script_safe(json.dumps(code)) + ')</script></body></html>')
    if kind in ('react', 'jsx', 'tsx'):
        body = code.replace('export default function', 'const __Artifact__ = function', 1)
        if body == code:
            body = code.replace('export default', 'const __Artifact__ =', 1)
        return (head + '<script type="importmap">' + json.dumps({'imports': IMPORTS}) + '</script>'
                '<script src="https://cdn.tailwindcss.com"></script>'
                '<script src="https://unpkg.com/@babel/standalone@7/babel.min.js"></script>'
                '</head><body><div id="root"></div>'
                '<script type="text/babel" data-type="module" data-presets="react">'
                '/** @jsx __React.createElement */ /** @jsxFrag __React.Fragment */\n'
                'import * as __React from "react";\nimport { createRoot as __createRoot } from "react-dom/client";\n'
                + script_safe(body) +
                '\n__createRoot(document.getElementById("root")).render(__React.createElement(__Artifact__));'
                '</script></body></html>')
    return head + themed + '</head><body><pre style="padding:1rem;white-space:pre-wrap">' \
        + html.escape(code) + '</pre></body></html>'


def main():
    viewer, kind, title = sys.argv[1:4]
    # Qt's #aarrggbb as CSS's #rrggbb
    bg, fg, accent = ('#' + c.lstrip('#')[-6:] for c in sys.argv[4:7])
    browser = len(sys.argv) > 7 and sys.argv[7] == 'browser'
    code = sys.stdin.read()
    text = page(kind, title or 'Artifact', code, bg, fg, accent)
    cache = Path(os.environ.get('XDG_CACHE_HOME') or Path.home() / '.cache') / 'singularity' / 'artifacts'
    cache.mkdir(parents=True, exist_ok=True)
    path = cache / (hashlib.sha1(text.encode()).hexdigest()[:16] + '.html')
    path.write_text(text)
    qml = shutil.which('qml6') or shutil.which('qml') or '/usr/lib/qt6/bin/qml'
    command = (['xdg-open', path.as_uri()] if browser
               else [qml, viewer, '--', path.as_uri(), title or 'Artifact', bg])
    subprocess.Popen(command, start_new_session=True, stdin=subprocess.DEVNULL,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


if __name__ == '__main__':
    main()
