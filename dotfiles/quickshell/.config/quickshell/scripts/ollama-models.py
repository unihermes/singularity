#!/usr/bin/env python3
"""List models available on the local Ollama server."""
import json
import urllib.error
import urllib.request

try:
    with urllib.request.urlopen("http://127.0.0.1:11434/api/tags", timeout=3) as response:
        models = json.load(response).get("models", [])
    print(json.dumps([m["name"] for m in models if m.get("name")]))
except (urllib.error.URLError, OSError, ValueError):
    print("[]")
