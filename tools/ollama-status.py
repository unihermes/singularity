#!/usr/bin/env python3
"""Inspect a local Ollama server without downloading or loading models."""

import argparse
import json
import sys
import urllib.error
import urllib.request


def request(base, path, data=None):
    body = None if data is None else json.dumps(data).encode()
    headers = {} if body is None else {"Content-Type": "application/json"}
    req = urllib.request.Request(base.rstrip("/") + path, data=body, headers=headers)
    with urllib.request.urlopen(req, timeout=5) as response:
        return json.load(response)


def inspect(base):
    installed = request(base, "/api/tags").get("models", [])
    running = request(base, "/api/ps").get("models", [])
    models = []
    for model in installed:
        name = model.get("name") or model.get("model")
        if not name:
            continue
        try:
            info = request(base, "/api/show", {"model": name})
            capabilities = info.get("capabilities")
        except urllib.error.HTTPError as error:
            error.close()
            capabilities = None
        except (urllib.error.URLError, TimeoutError, ValueError):
            capabilities = None
        models.append({"name": name, "capabilities": capabilities})
    return {"models": models, "running": [
        {"name": model.get("name") or model.get("model"),
         "size": model.get("size"), "size_vram": model.get("size_vram")}
        for model in running
    ]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default="http://127.0.0.1:11434", help="Ollama server URL")
    args = parser.parse_args()
    try:
        result = inspect(args.url)
    except (urllib.error.URLError, TimeoutError, ValueError, OSError) as error:
        print(f"Cannot inspect Ollama at {args.url}: {error}", file=sys.stderr)
        return 1
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
