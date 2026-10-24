#!/usr/bin/env python3
# Singularity - Quickshell
# ~/.config/quickshell/scripts/bongo.py
#
# Key presses from every keyboard, for the bar's Bongo Cat: a line "tap"
# per press, never which key. Prints "ready" once it can read a keyboard,
# or "noaccess" when the event devices are closed to it (the user isn't in
# the input group). Keyboards plugged in later are picked up within ten
# seconds. Exits when stdout closes.

import os
import re
import selectors
import struct
import sys
import time

EVENT = struct.Struct("llHHi")
EV_KEY = 1
EV_REP_BIT = 1 << 0x14


def keyboards():
    try:
        with open("/proc/bus/input/devices") as f:
            blocks = f.read().split("\n\n")
    except OSError:
        return []
    out = []
    for b in blocks:
        ev = re.search(r"^B: EV=([0-9a-f]+)", b, re.M)
        h = re.search(r"^H: Handlers=(.*)$", b, re.M)
        if not ev or not h or "kbd" not in h.group(1):
            continue
        # a keyboard repeats keys; a power button or a headset's media keys don't
        if not int(ev.group(1), 16) & EV_REP_BIT:
            continue
        node = re.search(r"\bevent\d+\b", h.group(1))
        if node:
            out.append("/dev/input/" + node.group(0))
    return out


def say(word):
    try:
        sys.stdout.write(word + "\n")
        sys.stdout.flush()
    except BrokenPipeError:
        sys.exit(0)


def main():
    sel = selectors.DefaultSelector()
    opened = {}
    state = ""
    last_scan = 0
    while True:
        if time.time() - last_scan > 10:
            last_scan = time.time()
            denied = False
            for path in keyboards():
                if path in opened:
                    continue
                try:
                    fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
                except PermissionError:
                    denied = True
                    continue
                except OSError:
                    continue
                opened[path] = fd
                sel.register(fd, selectors.EVENT_READ, path)
            now = "ready" if opened else "noaccess" if denied else ""
            if now and now != state:
                state = now
                say(now)
        for key, _ in sel.select(timeout=2):
            try:
                data = os.read(key.fd, EVENT.size * 64)
            except OSError:
                sel.unregister(key.fd)
                os.close(key.fd)
                opened.pop(key.data, None)
                continue
            for i in range(0, len(data) - EVENT.size + 1, EVENT.size):
                _, _, typ, _, value = EVENT.unpack_from(data, i)
                if typ == EV_KEY and value == 1:
                    say("tap")


if __name__ == "__main__":
    main()
