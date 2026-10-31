#!/usr/bin/env python3
"""Compact repository inventory or file outline. Read-only; uses git's file list."""
import argparse
import collections
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
ALIASES = {"qs": "dotfiles/quickshell/.config/quickshell",
           "hypr": "dotfiles/hypr/.config/hypr"}
SYMBOL = re.compile(
    r"^\s*(?:import |\.import |(?:async )?function |(?:readonly |required )?property "
    r"|signal |component |(?:async )?def |class |(?:local )?function "
    r"|[A-Za-z_]\w*\(\)\s*\{)")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", nargs="?", default=".", help="repo path; aliases: qs, hypr")
    parser.add_argument("--limit", type=int, default=40, help="maximum output rows (default 40)")
    args = parser.parse_args()
    if args.limit < 1:
        parser.error("--limit must be positive")
    head, sep, tail = args.path.partition("/")
    target = (ROOT / (ALIASES.get(head, head) + sep + tail)).resolve()
    if not target.is_relative_to(ROOT):
        parser.error("path must be inside the repository")
    paths = subprocess.check_output(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"], cwd=ROOT
    ).decode().split("\0")
    files = sorted({ROOT / p for p in paths if p and (ROOT / p).is_file()})
    if target.is_file():
        if target not in files:
            parser.error("file is ignored or not part of the repository")
        text = target.read_bytes()
        if b"\0" in text:
            parser.error("binary file has no source outline")
        lines = text.decode("utf-8", errors="replace").splitlines()
        rows = [f"{n}: {line.strip()}" for n, line in enumerate(lines, 1) if SYMBOL.match(line)]
        print(f"{target.relative_to(ROOT)}: {len(lines)} lines, {len(text)} bytes")
    else:
        groups = collections.defaultdict(list)
        for path in files:
            if path.is_relative_to(target):
                rel = path.relative_to(target)
                groups[rel.parts[0] + ("/" if len(rel.parts) > 1 else "")].append(path)
        if not groups:
            parser.error("no repository files at this path")
        rows = [f"{name}: {len(paths)} files, {sum(p.stat().st_size for p in paths)} bytes"
                for name, paths in sorted(groups.items())]
        print(f"{target.relative_to(ROOT)}: {sum(map(len, groups.values()))} files")
    print("\n".join(rows[:args.limit]))
    if len(rows) > args.limit:
        print(f"… {len(rows) - args.limit} more; narrow the path or increase --limit")


if __name__ == "__main__":
    main()
