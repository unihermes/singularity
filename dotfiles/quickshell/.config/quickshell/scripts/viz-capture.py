#!/usr/bin/env python3
# Singularity - Quickshell
# ~/.config/quickshell/scripts/viz-capture.py <app> [title]
#
# One app's sound for services/Visualizer.qml's cava: raw s16le 44.1 kHz
# stereo on stdout, from the app's running output stream (matched on its
# binary, application or node name). With a title, a stream named after
# it is the only one taken (a browser's stream per tab), so another tab
# playing doesn't count. Nothing while the app has none; it
# looks again every two seconds, and again when the stream goes away.
# Never falls back to another source, so a paused player stays silent.

import ctypes
import json
import select
import signal
import subprocess
import sys
import time

app = sys.argv[1].lower()
title = sys.argv[2].lower() if len(sys.argv) > 2 else ""


def die_with_parent():
    ctypes.CDLL(None).prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG


def reader_gone():
    p = select.poll()
    p.register(sys.stdout.fileno(), 0)
    return any(ev & (select.POLLERR | select.POLLHUP) for _, ev in p.poll(0))


def running_stream():
    try:
        nodes = json.loads(subprocess.run(["pw-dump"], capture_output=True, text=True, timeout=5).stdout)
    except (subprocess.SubprocessError, ValueError):
        return None
    ours = []
    for o in nodes:
        info = o.get("info") or {}
        p = info.get("props") or {}
        if p.get("media.class") != "Stream/Output/Audio":
            continue
        names = (p.get("application.process.binary"), p.get("application.name"), p.get("node.name"))
        if any(app in str(n).lower() for n in names if n):
            ours.append((info.get("state") == "running", str(p.get("media.name") or "").lower(), p.get("object.serial")))
    titled = [s for s in ours if title and title in s[1]]
    return next((serial for running, _, serial in titled or ours if running), None)


# this goes with the shell's sh, and pw-record with this
die_with_parent()
while not reader_gone():
    serial = running_stream()
    if serial is None:
        time.sleep(2)
        continue
    subprocess.run(["pw-record", "--target", str(serial), "--format", "s16", "--rate", "44100", "--channels", "2",
                    "-P", "{ node.dont-fallback = true node.dont-reconnect = true node.name = singularity-viz }",
                    "--raw", "-"], stdout=sys.stdout, stderr=subprocess.DEVNULL, preexec_fn=die_with_parent)
    time.sleep(1)
