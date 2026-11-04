#!/usr/bin/env python3
"""Supply local model tool metadata to the Codex app server."""
import json
import os
from pathlib import Path
import subprocess
import signal
import tempfile
import urllib.request


def catalog():
    template = json.loads(Path(__file__).with_name('ollama-model-template.json').read_text())
    with urllib.request.urlopen('http://127.0.0.1:11434/api/tags', timeout=5) as response:
        installed = json.load(response)['models']
    return {'models': [dict(template, slug=m['name'], display_name=m['name']) for m in installed]}


def codex_home():
    state = os.environ.get('XDG_STATE_HOME') or os.path.expanduser('~/.local/state')
    path = Path(state) / 'singularity' / 'ollama-codex'
    path.mkdir(parents=True, exist_ok=True)
    return str(path)


def main():
    with tempfile.TemporaryDirectory(prefix='singularity-ollama-') as directory:
        path = Path(directory) / 'models.json'
        path.write_text(json.dumps(catalog()))
        # App tool catalogs overflow the local context and can push the shell
        # tools out of Ollama's prompt, so they stay off for this provider.
        # Web search is turned off too: Ollama serves it from ollama.com and
        # answers 401 without an account.
        # A Codex home of its own: no ChatGPT login to bill or sync, so nothing
        # leaves the machine, and its threads stay apart from the Codex tab's.
        env = dict(os.environ, CODEX_HOME=codex_home())
        process = subprocess.Popen(['codex', 'app-server', '-c', 'notify=[]', '-c', 'model_provider="ollama"',
                                '-c', 'features.apps=false',
                                '-c', 'web_search="disabled"',
                                '-c', 'model_catalog_json=' + json.dumps(str(path)),
                                '-c', 'model_context_window=16384', '-c', 'analytics.enabled=false'], env=env)
        signal.signal(signal.SIGTERM, lambda *_: process.terminate())
        signal.signal(signal.SIGINT, lambda *_: process.terminate())
        return process.wait()


if __name__ == '__main__':
    raise SystemExit(main())
