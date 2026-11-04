#!/usr/bin/env python3
"""Supply local model tool metadata to the Codex app server."""
import json
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


def main():
    with tempfile.TemporaryDirectory(prefix='singularity-ollama-') as directory:
        path = Path(directory) / 'models.json'
        path.write_text(json.dumps(catalog()))
        process = subprocess.Popen(['codex', 'app-server', '-c', 'notify=[]', '-c', 'model_provider="ollama"',
                                '-c', 'model_catalog_json=' + json.dumps(str(path)),
                                '-c', 'model_context_window=16384'])
        signal.signal(signal.SIGTERM, lambda *_: process.terminate())
        signal.signal(signal.SIGINT, lambda *_: process.terminate())
        return process.wait()


if __name__ == '__main__':
    raise SystemExit(main())
