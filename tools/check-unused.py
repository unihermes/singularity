#!/usr/bin/env python3
# Finds what the shell declares and nothing reads: QML files nothing names,
# and functions, properties, signals and ids named only where declared. A plain
# text search (qmllint can't resolve the singletons). Run by the pre-commit
# hook; exits 1 on a find. Intended exceptions go in ALLOW, with the reason.
import collections, os, re, subprocess, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                    "..", "dotfiles", "quickshell", ".config", "quickshell")

# (file, name) pairs that are fine as they are, with the reason
ALLOW = {
    ("shell.qml", "saveDefault"): "IPC: qs ipc call look saveDefault",
    ("shell.qml", "resetToDefault"): "IPC: qs ipc call look resetToDefault",
    ("services/HyprBinds.js", "mergeDefaults"): "tools/merge-binds.mjs, run by link.sh",
}

def main():
    # tracked and new files alike, so a file not yet added still counts
    files = subprocess.check_output(["git", "ls-files", "--cached", "--others", "--exclude-standard",
                                     "*.qml", "*.js"], cwd=ROOT, text=True).split()
    files = [f for f in files if os.path.exists(os.path.join(ROOT, f))]
    src = {f: open(os.path.join(ROOT, f)).read() for f in files}
    words = collections.Counter(re.findall(r"\w+", re.sub(r"//[^\n]*", "", "\n".join(src.values()))))
    count = lambda n: words[n]

    found = []
    for f in files:
        if f.endswith(".qml") and f != "shell.qml":
            name = os.path.basename(f)[:-4]
            if words[name] == 0:
                found.append((f, name, "file nothing uses"))
        s = src[f]
        for n in re.findall(r"^\s*function\s+(\w+)\s*\(", s, re.M):
            if not (n.startswith("on") and n[2:3].isupper()) and count(n) <= 1:
                found.append((f, n, "function"))
        for n in re.findall(r"^\s*(?:readonly\s+)?property\s+[\w<>.]+\s+(\w+)", s, re.M):
            if count(n) <= 1:
                found.append((f, n, "property"))
        for n in re.findall(r"^\s*signal\s+(\w+)", s, re.M):
            if count(n) <= 1 and count("on" + n[0].upper() + n[1:]) == 0:
                found.append((f, n, "signal"))
        # ids only reach their own file; `root` is kept by habit
        bare = re.sub(r"//[^\n]*", "", s)
        for n in re.findall(r"^\s*id:\s*(\w+)", s, re.M):
            if n != "root" and len(re.findall(r"\b" + n + r"\b", bare)) <= 1:
                found.append((f, n, "id"))

    found = [x for x in found if (x[0], x[1]) not in ALLOW]
    for f, n, kind in found:
        print(f"{f}: {kind} {n} is never read")
    return 1 if found else 0

if __name__ == "__main__":
    sys.exit(main())
