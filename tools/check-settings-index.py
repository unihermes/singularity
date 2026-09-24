#!/usr/bin/env python3
# Checks services/SettingsIndex.js against the Settings pages, both ways:
#   - a field on a page with no index entry (search can't find it)
#   - an index entry whose label is nowhere on its page (the result opens the
#     page but highlights nothing, since scrollTo matches the label exactly)
#
# The index stays hand-written -- its keywords are the point of it -- so this
# is what keeps it honest. Run by the pre-commit hook (tools/pre-commit)
# whenever a Settings page or the index is staged; exits 1 on drift.
#
# Labels built at runtime ("Workspace " + key, the mixer's app names) can't be
# seen from here and are skipped. An entry may name a section instead of a
# field, as long as the page has that heading. Anything else that is fine as
# it is goes in ALLOW, with the reason.
import os, re, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                    "..", "dotfiles", "quickshell", ".config", "quickshell")

# (page, label) pairs that are fine as they are, with the reason
ALLOW = {
}

def main():
    idx = open(os.path.join(ROOT, "services", "SettingsIndex.js")).read()
    indexed = {}
    for page, label in re.findall(
            r'\{\s*page:\s*"([a-z]+)",\s*section:\s*"[^"]*",\s*label:\s*"([^"]*)"', idx):
        indexed.setdefault(page, set()).add(label)

    problems = []
    pages = set()
    for f in sorted(os.listdir(os.path.join(ROOT, "settings"))):
        m = re.match(r"SettingsPage([A-Z]\w+)\.qml$", f)
        if not m:
            continue
        page = m.group(1).lower()
        pages.add(page)
        src = open(os.path.join(ROOT, "settings", f)).read()

        # a field: a SettingsField block, or a one-line component use that
        # carries a label (Appearance's Stepper)
        fields = set()
        for blk in re.finditer(r"SettingsField\s*\{(.*?)\n\s{4}\}", src, re.S):
            # a label built at runtime ("Workspace " + key) can't be checked
            lm = re.search(r'^\s*label:\s*"([^"]+)"\s*(?:$|;|//)', blk.group(1), re.M)
            if lm:
                fields.add(lm.group(1))
        for lm in re.finditer(r'^\s*[A-Z]\w*\s*\{\s*label:\s*"([^"]+)"', src, re.M):
            fields.add(lm.group(1))

        have = indexed.get(page, set())
        for label in sorted(fields - have):
            if (page, label) not in ALLOW:
                problems.append(f"{page}: field \"{label}\" has no index entry")
        for label in sorted(have):
            # a field's label, or a section heading (FlyoutHeading, in capitals)
            if f'"{label}"' in src or f'"{label.upper()}"' in src:
                continue
            if (page, label) not in ALLOW:
                problems.append(f"{page}: index entry \"{label}\" is not on the page")

    for page in sorted(set(indexed) - pages):
        problems.append(f"{page}: index entries for a page that doesn't exist")

    for p in problems:
        print(p)
    return 1 if problems else 0

if __name__ == "__main__":
    sys.exit(main())
