#!/usr/bin/env python3
# Singularity - Quickshell
# ~/.config/quickshell/scripts/calendar-events.py [--offline]
#
# The events in the iCalendar feeds listed in calendars.conf, for
# services/Calendar.qml. Each feed is downloaded and its raw .ics kept, then
# every feed's events in a window around today are expanded (recurrences
# included) into one JSON file the shell watches:
#
#   ~/.cache/singularity/calendar/events.json
#     { generated, feeds: [{ name, ok, fetched }],
#       events: [{ cal, title, location, start, end, allDay }] }
#
# A feed that can't be fetched (offline, just woken from sleep) falls back to
# its last good download, so a failure never blanks the calendar. --offline
# skips the downloads and only re-expands what's cached. Exits 2 when any
# feed failed to download, so the shell knows to try again soon.
#
# The feed URLs are secret addresses: they're never printed, and the cache
# is private to the user.

import datetime as dt
import hashlib
import json
import os
import sys
import tempfile
import urllib.request

import icalendar
import recurring_ical_events

HOME = os.path.expanduser("~")
CONF = os.path.join(HOME, ".local/state/singularity/calendars.conf")
CACHE = os.path.join(HOME, ".cache/singularity/calendar")
OUT = os.path.join(CACHE, "events.json")
STATE = os.path.join(CACHE, "fetched.json")

# how far back and ahead of today events are expanded
PAST_DAYS = 62
FUTURE_DAYS = 190


def read_feeds():
    feeds = []
    try:
        with open(CONF) as f:
            lines = f.read().splitlines()
    except OSError:
        return feeds
    for line in lines:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        name, url = "", line
        if " = " in line:
            name, url = (p.strip() for p in line.split(" = ", 1))
        if url.startswith("webcal://"):
            url = "https://" + url[len("webcal://"):]
        if not url.startswith(("http://", "https://")):
            continue
        feeds.append({"name": name or "Calendar", "url": url})
    return feeds


def raw_path(url):
    return os.path.join(CACHE, hashlib.sha256(url.encode()).hexdigest()[:24] + ".ics")


def write_private(path, data):
    fd, tmp = tempfile.mkstemp(dir=CACHE, prefix=".tmp-")
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(data)
        os.chmod(tmp, 0o600)
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "singularity-calendar"})
    with urllib.request.urlopen(req, timeout=20) as r:
        data = r.read(32 * 1024 * 1024)
    if b"BEGIN:VCALENDAR" not in data[:4096]:
        raise ValueError("not an iCalendar feed")
    return data


def local(value):
    """A DTSTART/DTEND value as (local naive datetime or date, all-day)."""
    if isinstance(value, dt.datetime):
        if value.tzinfo is not None:
            value = value.astimezone().replace(tzinfo=None)
        return value, False
    return value, True


def expand(name, data, start, end):
    cal = icalendar.Calendar.from_ical(data)
    out = []
    for ev in recurring_ical_events.of(cal).between(start, end):
        if str(ev.get("STATUS", "")).upper() == "CANCELLED":
            continue
        s = ev.get("DTSTART")
        if s is None:
            continue
        s, all_day = local(s.dt)
        e = ev.get("DTEND")
        if e is not None:
            e, _ = local(e.dt)
        elif ev.get("DURATION") is not None:
            e = s + ev.get("DURATION").dt
        else:
            e = s + dt.timedelta(days=1) if all_day else s
        fmt = "%Y-%m-%d" if all_day else "%Y-%m-%dT%H:%M"
        out.append({
            "cal": name,
            "title": str(ev.get("SUMMARY", "")).strip() or "(No title)",
            "location": str(ev.get("LOCATION", "")).strip(),
            "start": s.strftime(fmt),
            "end": e.strftime(fmt),
            "allDay": all_day,
        })
    return out


def main():
    offline = "--offline" in sys.argv[1:]
    os.makedirs(CACHE, mode=0o700, exist_ok=True)
    os.chmod(CACHE, 0o700)

    try:
        with open(STATE) as f:
            fetched = json.load(f)
    except (OSError, ValueError):
        fetched = {}

    today = dt.date.today()
    start = today - dt.timedelta(days=PAST_DAYS)
    end = today + dt.timedelta(days=FUTURE_DAYS)

    failed = False
    feeds, events = [], []
    for feed in read_feeds():
        path = raw_path(feed["url"])
        key = os.path.basename(path)
        ok = True
        if not offline:
            try:
                write_private(path, fetch(feed["url"]))
                fetched[key] = int(dt.datetime.now().timestamp() * 1000)
            except Exception:
                ok = False
                failed = True
        try:
            with open(path, "rb") as f:
                events += expand(feed["name"], f.read(), start, end)
        except OSError:
            ok = False
        except Exception as e:
            ok = False
            print(f"{feed['name']}: couldn't read the feed ({type(e).__name__})", file=sys.stderr)
        feeds.append({"name": feed["name"], "ok": ok, "fetched": fetched.get(key, 0)})

    # the same meeting from two invitations shows once, with a location if
    # either copy has one
    seen = {}
    for e in events:
        key = (e["title"], e["start"], e["end"])
        if key not in seen or (e["location"] and not seen[key]["location"]):
            seen[key] = e
    events = sorted(seen.values(), key=lambda e: (e["start"], not e["allDay"], e["title"]))
    write_private(STATE, json.dumps(fetched).encode())
    write_private(OUT, json.dumps({
        "generated": int(dt.datetime.now().timestamp() * 1000),
        "feeds": feeds,
        "events": events,
    }).encode())
    return 2 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
