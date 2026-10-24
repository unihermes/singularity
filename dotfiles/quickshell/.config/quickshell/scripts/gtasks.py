#!/usr/bin/env python3
# Singularity - Quickshell
# ~/.config/quickshell/scripts/gtasks.py
#
# Google Tasks for services/Tasks.qml, over the REST API with the standard
# library only. Each command prints one JSON value.
#
#   gtasks.py status              { connected, client } : whether there's a
#                                 sign-in, and an OAuth client to sign in with
#   gtasks.py auth                signs in: the browser opens Google's consent
#                                 page, which hands the code back to a server
#                                 on 127.0.0.1; prints { ok } or { error }
#   gtasks.py signout             forgets the sign-in
#   gtasks.py lists               every task list with its open and recently
#                                 done tasks: [{ id, title, tasks: [{ id,
#                                 title, notes, done, due }] }]
#   gtasks.py add LIST TITLE      a new task at the top of LIST
#   gtasks.py done LIST ID 1|0    ticks a task off, or back on
#   gtasks.py delete LIST ID      removes a task
#
# The OAuth client is a Google Cloud "Desktop app" client's JSON, kept as
# client.json in the state folder; auth takes the newest client_secret_*.json
# in ~/Downloads when there's none yet. The tokens sit beside it (mode 600).

import glob
import hashlib
import base64
import http.server
import json
import os
import secrets
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

HOME = os.path.expanduser("~")
STATE = os.path.join(HOME, ".local", "state", "singularity", "gtasks")
CLIENT = os.path.join(STATE, "client.json")
TOKEN = os.path.join(STATE, "token.json")
SCOPE = "https://www.googleapis.com/auth/tasks"
API = "https://tasks.googleapis.com/tasks/v1"
AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
TOKEN_URL = "https://oauth2.googleapis.com/token"


def out(v):
    print(json.dumps(v))


def fail(msg):
    out({"error": msg})
    sys.exit(1)


def write_private(path, data):
    os.makedirs(STATE, mode=0o700, exist_ok=True)
    tmp = path + ".tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(data, f)
    os.replace(tmp, path)


def client():
    if not os.path.exists(CLIENT):
        found = sorted(glob.glob(os.path.join(HOME, "Downloads", "client_secret_*.json")), key=os.path.getmtime)
        if not found:
            return None
        os.makedirs(STATE, mode=0o700, exist_ok=True)
        shutil.copyfile(found[-1], CLIENT)
        os.chmod(CLIENT, 0o600)
    try:
        with open(CLIENT) as f:
            c = json.load(f)
        c = c.get("installed") or c.get("web") or {}
        return c if c.get("client_id") and c.get("client_secret") else None
    except (OSError, ValueError):
        return None


def post_form(url, fields):
    data = urllib.parse.urlencode(fields).encode()
    with urllib.request.urlopen(urllib.request.Request(url, data=data), timeout=20) as r:
        return json.load(r)


def auth():
    c = client()
    if not c:
        fail("No OAuth client: put the Desktop app client's JSON in ~/Downloads")
    verifier = secrets.token_urlsafe(64)
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
    state = secrets.token_urlsafe(16)
    got = {}

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            if q.get("state", [""])[0] == state:
                got["code"] = q.get("code", [""])[0]
                got["error"] = q.get("error", [""])[0]
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            msg = "Signed in. You can close this tab." if got.get("code") else "Not signed in."
            self.wfile.write(("<p style='font:16px sans-serif'>" + msg + "</p>").encode())

        def log_message(self, *a):
            pass

    server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
    server.timeout = 1
    redirect = "http://127.0.0.1:%d" % server.server_port
    url = AUTH_URL + "?" + urllib.parse.urlencode({
        "client_id": c["client_id"], "redirect_uri": redirect, "response_type": "code",
        "scope": SCOPE, "access_type": "offline", "prompt": "consent", "state": state,
        "code_challenge": challenge, "code_challenge_method": "S256"})
    subprocess.Popen(["xdg-open", url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    deadline = time.time() + 300
    while "code" not in got and time.time() < deadline:
        server.handle_request()
    server.server_close()
    if not got.get("code"):
        fail(got.get("error") or "Sign-in timed out")
    try:
        tok = post_form(TOKEN_URL, {
            "code": got["code"], "client_id": c["client_id"], "client_secret": c["client_secret"],
            "redirect_uri": redirect, "grant_type": "authorization_code", "code_verifier": verifier})
    except urllib.error.HTTPError as e:
        fail("Google refused the sign-in (%d)" % e.code)
    if not tok.get("refresh_token"):
        fail("Google sent no refresh token")
    tok["expires_at"] = time.time() + tok.get("expires_in", 3600) - 60
    write_private(TOKEN, tok)
    out({"ok": True})


def access_token():
    try:
        with open(TOKEN) as f:
            tok = json.load(f)
    except (OSError, ValueError):
        fail("Not signed in")
    if tok.get("expires_at", 0) > time.time():
        return tok["access_token"]
    c = client()
    if not c:
        fail("No OAuth client")
    try:
        new = post_form(TOKEN_URL, {
            "client_id": c["client_id"], "client_secret": c["client_secret"],
            "refresh_token": tok["refresh_token"], "grant_type": "refresh_token"})
    except urllib.error.HTTPError as e:
        fail("Sign in again" if e.code in (400, 401) else "Google didn't answer (%d)" % e.code)
    except OSError:
        fail("Offline")
    tok["access_token"] = new["access_token"]
    tok["expires_at"] = time.time() + new.get("expires_in", 3600) - 60
    write_private(TOKEN, tok)
    return tok["access_token"]


def call(method, path, body=None, query=None):
    url = API + path + ("?" + urllib.parse.urlencode(query) if query else "")
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": "Bearer " + access_token(), "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            text = r.read()
            return json.loads(text) if text else {}
    except urllib.error.HTTPError as e:
        fail("Google Tasks said %d" % e.code)
    except OSError:
        fail("Offline")


def lists():
    rows = []
    for l in call("GET", "/users/@me/lists", query={"maxResults": 100}).get("items", []):
        items = call("GET", "/lists/%s/tasks" % l["id"], query={
            "maxResults": 100, "showCompleted": "true", "showHidden": "true"}).get("items", [])
        tasks = [{"id": t["id"], "title": t.get("title", ""), "notes": t.get("notes", ""),
                  "done": t.get("status") == "completed", "due": t.get("due", ""),
                  "position": t.get("position", ""), "parent": t.get("parent", "")}
                 for t in items if t.get("title")]
        # open ones in Google's order, then done ones
        tasks.sort(key=lambda t: (t["done"], t["position"]))
        rows.append({"id": l["id"], "title": l.get("title", ""), "tasks": tasks})
    return rows


def main():
    a = sys.argv[1:]
    cmd = a[0] if a else ""
    if cmd == "status":
        out({"connected": os.path.exists(TOKEN), "client": client() is not None})
    elif cmd == "auth":
        auth()
    elif cmd == "signout":
        if os.path.exists(TOKEN):
            os.remove(TOKEN)
        out({"ok": True})
    elif cmd == "lists":
        out(lists())
    elif cmd == "add" and len(a) >= 3:
        out(call("POST", "/lists/%s/tasks" % a[1], {"title": a[2]}))
    elif cmd == "done" and len(a) >= 4:
        body = {"status": "completed"} if a[3] == "1" else {"status": "needsAction", "completed": None}
        out(call("PATCH", "/lists/%s/tasks/%s" % (a[1], a[2]), body))
    elif cmd == "delete" and len(a) >= 3:
        out(call("DELETE", "/lists/%s/tasks/%s" % (a[1], a[2])))
    else:
        sys.exit("usage: gtasks.py status|auth|signout|lists|add|done|delete")


if __name__ == "__main__":
    main()
