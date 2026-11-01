#!/usr/bin/env python3
# Singularity - Quickshell
# ~/.config/quickshell/scripts/viz-capture.py <app> [title]
#
# One app's sound for services/Visualizer.qml's cava: raw s16le 44.1 kHz
# stereo on stdout, from the app's running output streams (matched on
# their binary, application or node name). Each is recorded, and the one
# passed on is the stream named after the title (a browser's stream per
# tab) while it makes sound, else the one that made sound last, so
# switching to a muted or silent tab keeps the bars of the tab still
# playing. Streams are looked for again every two seconds. Never falls
# back to another app, so a paused player stays silent. The name of the
# stream passed on (a browser's tab title) goes to stderr as "tab <name>"
# each time it changes.

import ctypes
import json
import os
import select
import signal
import subprocess
import sys
import time
from array import array

app = sys.argv[1].lower()
title = sys.argv[2].lower() if len(sys.argv) > 2 else ""

CHUNK = 4096    # bytes read at a time: about 23 ms
LOUD = 64       # a sample past this (of 32767) is sound
HOLD = 1.0      # seconds a stream counts as sounding after its last sound
RESCAN = 2.0


def die_with_parent():
    ctypes.CDLL(None).prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG


def running_streams():
    """serial -> its name, for the app's running streams"""
    try:
        nodes = json.loads(subprocess.run(["pw-dump"], capture_output=True, text=True, timeout=5).stdout)
    except (subprocess.SubprocessError, ValueError):
        return {}
    found = {}
    for o in nodes:
        info = o.get("info") or {}
        p = info.get("props") or {}
        if p.get("media.class") != "Stream/Output/Audio" or info.get("state") != "running":
            continue
        names = (p.get("application.process.binary"), p.get("application.name"), p.get("node.name"))
        if any(app in str(n).lower() for n in names if n):
            found[p.get("object.serial")] = str(p.get("media.name") or "")
    return found


class Tap:
    def __init__(self, serial, name):
        self.name = name
        self.loud_at = 0.0
        self.rest = b""  # a frame cut short by the last read
        self.proc = subprocess.Popen(
            ["pw-record", "--target", str(serial), "--format", "s16", "--rate", "44100", "--channels", "2",
             "-P", "{ node.dont-fallback = true node.dont-reconnect = true node.name = singularity-viz }",
             "--raw", "-"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, preexec_fn=die_with_parent)
        self.fd = self.proc.stdout.fileno()

    @property
    def titled(self):
        return bool(title) and title in self.name.lower()

    def stop(self):
        self.proc.terminate()
        self.proc.wait()


def pick(taps, now):
    """the tap to pass on: the titled one while sounding, else the one that sounded last"""
    sounding = [t for t in taps if now - t.loud_at < HOLD]
    titled = [t for t in sounding if t.titled]
    if titled:
        return titled[0]
    if sounding:
        return max(sounding, key=lambda t: t.loud_at)
    return next((t for t in taps if t.titled), taps[0] if taps else None)


die_with_parent()
taps = {}
scanned = 0.0
told = None
try:
    while True:
        now = time.monotonic()
        if now - scanned >= RESCAN:
            scanned = now
            streams = running_streams()
            for serial in [s for s in taps if s not in streams]:
                taps.pop(serial).stop()
            for serial, name in streams.items():
                if serial in taps:
                    taps[serial].name = name
                else:
                    taps[serial] = Tap(serial, name)
        by_fd = {t.fd: (s, t) for s, t in taps.items()}
        if not by_fd:
            time.sleep(0.25)
            continue
        ready = select.select(list(by_fd), [], [], 0.25)[0]
        now = time.monotonic()
        chosen = pick(list(taps.values()), now)
        if chosen and chosen.name != told:
            told = chosen.name
            print("tab " + told, file=sys.stderr, flush=True)
        for fd in ready:
            serial, tap = by_fd[fd]
            data = os.read(fd, CHUNK)
            if not data:  # its stream went away
                taps.pop(serial).stop()
                continue
            data = tap.rest + data
            cut = len(data) // 4 * 4  # whole stereo frames, so a switch keeps them aligned
            data, tap.rest = data[:cut], data[cut:]
            samples = array("h", data)
            if samples and max(max(samples), -min(samples)) > LOUD:
                tap.loud_at = now
            if tap is chosen:
                sys.stdout.buffer.write(data)
                sys.stdout.buffer.flush()
except (BrokenPipeError, KeyboardInterrupt):
    pass
finally:
    for t in taps.values():
        t.stop()
