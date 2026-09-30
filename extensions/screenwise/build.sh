#!/usr/bin/env bash
# Packs the extension into screenwise-<version>.xpi beside this folder.
set -euo pipefail
cd "$(dirname "$0")"
version=$(python3 -c 'import json; print(json.load(open("manifest.json"))["version"])')
out="../screenwise-$version.xpi"
rm -f "$out"
python3 -m zipfile -c "$out" manifest.json *.js *.html *.css icons/
echo "$(cd .. && pwd)/screenwise-$version.xpi"
