#!/usr/bin/env python3
# Singularity - Quickshell
# ~/.config/quickshell/scripts/page-art.py <url>
#
# The picture a page names for sharing (og:image, else twitter:image), as
# an absolute URL on stdout; nothing when it has none or doesn't answer.
# For services/Media.qml: a browser's MPRIS art is often missing or stale,
# the page's own is the video's or track's.

import html
import re
import sys
import urllib.parse
import urllib.request

url = sys.argv[1]
req = urllib.request.Request(url, headers={
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0",
    "Accept-Language": "en",
})
try:
    with urllib.request.urlopen(req, timeout=6) as r:
        page = r.read(1 << 20).decode(r.headers.get_content_charset() or "utf-8", "replace")
        base = r.geturl()
except Exception:
    sys.exit(0)

metas = {}
for tag in re.findall(r"<meta\b[^>]*>", page, re.I):
    attrs = dict((k.lower(), html.unescape(v2 or v1)) for k, v1, v2 in
                 re.findall(r'([\w:-]+)\s*=\s*(?:"([^"]*)"|\'([^\']*)\')', tag))
    key = (attrs.get("property") or attrs.get("name") or "").lower()
    if key and "content" in attrs:
        metas.setdefault(key, attrs["content"].strip())

for key in ("og:image:secure_url", "og:image", "og:image:url", "twitter:image", "twitter:image:src"):
    if metas.get(key):
        # some pages escape it twice
        print(urllib.parse.urljoin(base, html.unescape(metas[key])))
        break
