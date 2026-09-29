#!/usr/bin/env bash
# Packs the extension into per-site-fullscreen-<version>.xpi beside this folder.
set -euo pipefail
cd "$(dirname "$0")"
version=$(python3 -c 'import json; print(json.load(open("manifest.json"))["version"])')
out="../per-site-fullscreen-$version.xpi"
rm -f "$out"
python3 -m zipfile -c "$out" manifest.json *.js *.html *.css icons/
echo "$(cd .. && pwd)/per-site-fullscreen-$version.xpi"
