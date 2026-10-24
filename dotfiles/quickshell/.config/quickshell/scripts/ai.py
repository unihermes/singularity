#!/usr/bin/env python3
# Singularity - Quickshell
# ~/.config/quickshell/scripts/ai.py
#
# The Claude sidebar's helpers (services/Ai.qml). Each prints one JSON value.
#
#   ai.py shot area|window|screen [OUTPUT]   a screenshot to send, scaled to
#                                            what the model reads (1568px)
#   ai.py paste clipboard|selection          the clipboard or the primary
#                                            selection: text, or an image
#   ai.py sessions DIR                       Claude Code's past sessions there
#   ai.py history DIR ID                     one session as transcript rows
#   ai.py projects                           the folders Claude Code has run in
#
# An image comes back as { kind: "image", label, path, media, data } (data in
# base64), text as { kind: "text", label, text }; null when there's nothing.

import base64
import json
import os
import re
import subprocess
import sys
import time

HOME = os.path.expanduser("~")
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.join(HOME, ".cache")),
                     "singularity", "ai")
PROJECTS = os.path.join(HOME, ".claude", "projects")
# the long edge the model downscales to anyway
LONG_EDGE = 1568
# pasted text past this is cut, so one paste can't fill the context
TEXT_MAX = 20000
# a tool's output in a loaded session; the sidebar shows less still
RESULT_MAX = 4000


def out(v):
    print(json.dumps(v))


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, **kw)


def hypr(what):
    r = run(["hyprctl", what, "-j"], text=True)
    return json.loads(r.stdout) if r.returncode == 0 else None


def image(path, media, label):
    with open(path, "rb") as f:
        data = base64.b64encode(f.read()).decode()
    return {"kind": "image", "label": label, "path": path, "media": media, "data": data}


def shot_file():
    d = os.path.join(CACHE, "shots")
    os.makedirs(d, exist_ok=True)
    # the last few only; the session keeps what it was sent
    for old in sorted(os.listdir(d))[:-20]:
        os.remove(os.path.join(d, old))
    return os.path.join(d, time.strftime("%Y%m%d-%H%M%S") + ".jpg")


def shot(kind, output):
    args = []
    if kind == "area":
        r = run(["slurp"], text=True)
        if r.returncode != 0 or not r.stdout.strip():
            return None
        geo = r.stdout.strip()
        w, h = (int(n) for n in geo.split(" ")[1].split("x"))
        args = ["-g", geo]
    elif kind == "window":
        win = hypr("activewindow")
        if not win or not win.get("size"):
            return None
        (x, y), (w, h) = win["at"], win["size"]
        args = ["-g", f"{x},{y} {w}x{h}"]
    else:
        mons = hypr("monitors") or []
        mon = next((m for m in mons if m["name"] == output), None) \
            or next((m for m in mons if m.get("focused")), None)
        if not mon:
            return None
        w, h = mon["width"] / mon["scale"], mon["height"] / mon["scale"]
        args = ["-o", mon["name"]]
    # grim's scale is pixels per logical pixel: the shot comes out at most
    # LONG_EDGE wide or tall, however dense the screen
    scale = min(2.0, LONG_EDGE / max(w, h, 1))
    path = shot_file()
    r = run(["grim", "-t", "jpeg", "-q", "85", "-s", f"{scale:.4f}"] + args + [path])
    if r.returncode != 0:
        return None
    label = {"area": "Screenshot", "window": "Window", "screen": "Screen"}[kind]
    return image(path, "image/jpeg", label)


def paste(which):
    flag = ["-p"] if which == "selection" else []
    label = "Selection" if which == "selection" else "Clipboard"
    types = run(["wl-paste", "-l"] + flag, text=True).stdout.split()
    img = next((t for t in ("image/png", "image/jpeg") if t in types), None)
    if img:
        path = shot_file()[:-4] + "." + img.split("/")[1]
        data = run(["wl-paste", "-t", img] + flag).stdout
        if data:
            with open(path, "wb") as f:
                f.write(data)
            return image(path, img, label)
    r = run(["wl-paste", "-n"] + flag)
    text = r.stdout.decode("utf-8", "replace") if r.returncode == 0 else ""
    if not text.strip():
        return None
    if len(text) > TEXT_MAX:
        text = text[:TEXT_MAX] + "\n…"
    return {"kind": "text", "label": label, "text": text}


def project_dir(path):
    # how Claude Code names a folder's sessions directory
    return os.path.join(PROJECTS, re.sub(r"[^A-Za-z0-9]", "-", path))


def text_of(content):
    if isinstance(content, str):
        return content
    return "\n".join(b.get("text", "") for b in content or [] if isinstance(b, dict) and b.get("type") == "text")


def is_noise(text):
    # the CLI's own wrappers: slash commands, caveats, reminders
    return text.lstrip().startswith("<")


def sessions(path):
    d = project_dir(path)
    if not os.path.isdir(d):
        return []
    files = sorted((f for f in os.listdir(d) if f.endswith(".jsonl")),
                   key=lambda f: os.path.getmtime(os.path.join(d, f)), reverse=True)
    rows = []
    for f in files[:30]:
        p = os.path.join(d, f)
        title = first = last = ""
        turns = 0
        try:
            with open(p) as fh:
                for line in fh:
                    try:
                        e = json.loads(line)
                    except ValueError:
                        continue
                    t = e.get("type")
                    if t == "ai-title":
                        title = e.get("aiTitle") or title
                    elif t == "custom-title":
                        title = e.get("customTitle") or title
                    elif t == "last-prompt":
                        last = e.get("lastPrompt") or last
                    elif t == "user" and not e.get("isMeta") and not e.get("isSidechain"):
                        txt = text_of((e.get("message") or {}).get("content"))
                        if txt.strip() and not is_noise(txt):
                            turns += 1
                            first = first or txt
        except OSError:
            continue
        if turns == 0:
            continue
        rows.append({"id": f[:-6], "title": (title or first).strip().split("\n")[0][:120],
                     "last": last.strip().split("\n")[0][:120], "turns": turns,
                     "mtime": int(os.path.getmtime(p))})
    return rows


def history(path, sid):
    p = os.path.join(project_dir(path), sid + ".jsonl")
    rows = []
    try:
        fh = open(p)
    except OSError:
        return rows
    with fh:
        for line in fh:
            try:
                e = json.loads(line)
            except ValueError:
                continue
            if e.get("isSidechain") or e.get("isMeta") or e.get("type") not in ("user", "assistant"):
                continue
            content = (e.get("message") or {}).get("content")
            if e["type"] == "user":
                if isinstance(content, str):
                    if content.strip() and not is_noise(content):
                        rows.append({"kind": "user", "text": content})
                    continue
                for b in content or []:
                    if b.get("type") == "tool_result":
                        rows.append({"kind": "result", "toolId": b.get("tool_use_id", ""),
                                     "content": text_of(b.get("content"))[:RESULT_MAX],
                                     "isError": bool(b.get("is_error"))})
                    elif b.get("type") == "text" and b.get("text", "").strip() and not is_noise(b["text"]):
                        rows.append({"kind": "user", "text": b["text"]})
                    elif b.get("type") == "image":
                        rows.append({"kind": "user", "text": "", "note": "Image"})
            else:
                for b in content or []:
                    if b.get("type") == "text" and b.get("text", "").strip():
                        rows.append({"kind": "assistant", "text": b["text"]})
                    elif b.get("type") == "tool_use":
                        rows.append({"kind": "tool", "toolId": b.get("id", ""), "name": b.get("name", ""),
                                     "input": b.get("input") or {}})
    return rows


def projects():
    try:
        with open(os.path.join(HOME, ".claude.json")) as f:
            known = list((json.load(f).get("projects") or {}).keys())
    except (OSError, ValueError):
        known = []
    rows = []
    for p in known:
        # the sidebar's own folders and throwaway ones aren't projects
        if not os.path.isdir(p) or p.startswith(CACHE) or p.startswith("/tmp") or "/scratch" in p:
            continue
        d = project_dir(p)
        rows.append({"path": p, "name": os.path.basename(p) or p,
                     "used": int(os.path.getmtime(d)) if os.path.isdir(d) else 0})
    rows.sort(key=lambda r: r["used"], reverse=True)
    return rows


def main():
    a = sys.argv[1:]
    if not a:
        sys.exit(__doc__ or "usage: ai.py shot|paste|sessions|history|projects")
    cmd = a[0]
    if cmd == "shot" and len(a) >= 2:
        out(shot(a[1], a[2] if len(a) > 2 else ""))
    elif cmd == "paste" and len(a) >= 2:
        out(paste(a[1]))
    elif cmd == "sessions" and len(a) >= 2:
        out(sessions(a[1]))
    elif cmd == "history" and len(a) >= 3:
        out(history(a[1], a[2]))
    elif cmd == "projects":
        out(projects())
    else:
        sys.exit("ai.py: unknown command")


if __name__ == "__main__":
    main()
