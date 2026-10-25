#!/usr/bin/env python3
# Singularity - Quickshell
# ~/.config/quickshell/scripts/phone-link.py
#
# A small KDE Connect daemon for services/PhoneLink.qml, talking to the
# stock KDE Connect app on the phone: discovery, pairing, battery, the
# phone's notifications (popups here, with reply, dismiss and their
# actions), ringing it, pings, files and text both ways, and the clipboard
# both ways. Only the standard library, openssl (the key, made once) and
# wl-clipboard.
#
# Commands come in on stdin and the state goes out on stdout, a JSON object
# a line:
#
#   in:  {"cmd": "pair" | "unpair" | "accept" | "reject" | "ring" | "share"
#                | "reply" | "dismiss" | "action" | "refresh", "id": ..., ...}
#   out: {"event": "ready", "name": ...}
#        {"event": "state", "devices": [...]}      after every change
#        {"event": "error", "text": ...}
#
# The phone always connects to us: it answers our UDP identity (broadcast,
# or sent back to its own broadcast) over TCP, and we take the TLS client's
# side, so its certificate can be read without the standard library having
# to vouch for it. That certificate is pinned at pairing. The key, the id
# and paired phones (with their last address, asked directly while they're
# away) are kept in ~/.local/state/singularity/phone-link/. Each paired
# phone's battery and notifications are kept in the runtime dir too, taken
# back when the shell reloads and starts this again: the phone keeps its
# old connection's plugins then and doesn't send them anew.
# Exits when stdin closes.

import asyncio
import base64
import ctypes
import json
import os
import re
import signal
import socket
import ssl
import subprocess
import sys
import time
import uuid

UDP_PORT = 1716
TCP_PORTS = range(1716, 1765)
PAYLOAD_PORTS = range(1739, 1765)
PROTOCOL = 8
PAIR_TIMEOUT = 30
MAX_NOTIFICATIONS = 50
CARRY_FOR = 300
# how often a paired phone that's away is asked, by its last address, and
# everyone is, by broadcast
ASK_EVERY = 10
BROADCAST_EVERY = 30

STATE = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"),
                     "singularity", "phone-link")
ICONS = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"),
                     "singularity", "phone-link")
CARRIED = os.path.join(os.environ.get("XDG_RUNTIME_DIR") or "/tmp", "singularity-phone-link.json")

INCOMING = ["kdeconnect.battery", "kdeconnect.notification", "kdeconnect.ping",
            "kdeconnect.share.request", "kdeconnect.clipboard", "kdeconnect.clipboard.connect"]
OUTGOING = ["kdeconnect.notification.request", "kdeconnect.notification.reply",
            "kdeconnect.notification.action", "kdeconnect.findmyphone.request", "kdeconnect.ping",
            "kdeconnect.share.request", "kdeconnect.clipboard", "kdeconnect.clipboard.connect"]

VALID_ID = re.compile(r"^[A-Za-z0-9_-]{16,64}$")


def packet(kind, body):
    return {"id": int(time.time() * 1000), "type": kind, "body": body}


def encode(p):
    return (json.dumps(p) + "\n").encode()


def notify(title, body="", app="Phone", icon="phone", package=None):
    # package: the phone notification's Android app, for the shell to open
    # it with on a click (services/Notifications.qml)
    hint = ["-h", f"string:x-singularity-phone:{package}"] if package is not None else []
    subprocess.Popen(["notify-send", "-a", app, "-i", icon] + hint + [title, body],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def die_with_parent():
    # PR_SET_PDEATHSIG, so wl-paste goes when this does, however it goes
    ctypes.CDLL("libc.so.6").prctl(1, signal.SIGTERM)


async def start_tls(writer, ctx, server_side):
    # StreamWriter.start_tls takes the server's side on a connection a server
    # accepted, and here that side is the phone's
    protocol = writer._protocol
    await writer.drain()
    transport = await asyncio.get_running_loop().start_tls(
        writer.transport, protocol, ctx, server_side=server_side)
    writer._transport = transport
    protocol._replace_transport(transport)


def downloads():
    try:
        d = subprocess.run(["xdg-user-dir", "DOWNLOAD"], capture_output=True, text=True).stdout.strip()
    except OSError:
        d = ""
    d = d if d and d != os.path.expanduser("~") else os.path.expanduser("~/Downloads")
    os.makedirs(d, exist_ok=True)
    return d


def free_name(folder, name):
    name = os.path.basename(name).strip() or "file"
    stem, ext = os.path.splitext(name)
    path, n = os.path.join(folder, name), 1
    while os.path.exists(path):
        path = os.path.join(folder, f"{stem} ({n}){ext}")
        n += 1
    return path


class Me:
    def __init__(self):
        os.makedirs(STATE, mode=0o700, exist_ok=True)
        id_file = os.path.join(STATE, "id")
        if not os.path.exists(id_file):
            with open(id_file, "w") as f:
                f.write(uuid.uuid4().hex)
        with open(id_file) as f:
            self.id = f.read().strip()
        self.cert = os.path.join(STATE, "cert.pem")
        self.key = os.path.join(STATE, "key.pem")
        if not (os.path.exists(self.cert) and os.path.exists(self.key)):
            # dated a year back, as KDE Connect does, for a phone whose clock is behind
            start = time.strftime("%Y%m%d%H%M%SZ", time.gmtime(time.time() - 365 * 86400))
            subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
                            "-keyout", self.key, "-out", self.cert, "-not_before", start, "-days", "3650",
                            "-subj", f"/O=KDE/OU=Kde connect/CN={self.id}"],
                           check=True, capture_output=True)
            os.chmod(self.key, 0o600)
        self.name = socket.gethostname()
        try:
            with open("/sys/class/dmi/id/chassis_type") as f:
                laptop = f.read().strip() in ("8", "9", "10", "13", "14", "31", "32")
        except OSError:
            laptop = False
        self.type = "laptop" if laptop else "desktop"
        self.tcp_port = 0

    def identity(self):
        return packet("kdeconnect.identity", {
            "deviceId": self.id, "deviceName": self.name, "deviceType": self.type,
            "protocolVersion": PROTOCOL, "tcpPort": self.tcp_port,
            "incomingCapabilities": INCOMING, "outgoingCapabilities": OUTGOING})

    def client_tls(self):
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        ctx.load_cert_chain(self.cert, self.key)
        return ctx

    def server_tls(self):
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ctx.load_cert_chain(self.cert, self.key)
        return ctx


class Link:
    """One phone's open connection."""

    def __init__(self, ident, cert, addr, reader, writer):
        self.id = ident["deviceId"]
        self.name = ident.get("deviceName") or "Phone"
        self.type = ident.get("deviceType") or "phone"
        self.cert = cert
        self.addr = addr
        self.reader = reader
        self.writer = writer
        self.battery = -1
        self.charging = False
        self.notifications = []

    def send(self, kind, body, extra=None):
        p = packet(kind, body)
        if extra:
            p.update(extra)
        try:
            self.writer.write(encode(p))
        except (OSError, RuntimeError):
            pass

    def close(self):
        try:
            self.writer.close()
        except (OSError, RuntimeError):
            pass


class Daemon:
    def __init__(self):
        self.me = Me()
        self.store_path = os.path.join(STATE, "devices.json")
        try:
            with open(self.store_path) as f:
                self.paired = json.load(f)
        except (OSError, ValueError):
            self.paired = {}
        self.links = {}
        self.pairing = {}        # id -> "requested" | "incoming"
        self.pending_emit = False
        self.clip_last = None
        self.clip_time = int(time.time() * 1000)
        self.clip_proc = None
        self.udp = None
        self.heard = {}          # address -> when its broadcast was last answered
        # id -> battery, charging and notifications from before a restart
        try:
            with open(CARRIED) as f:
                carried = json.load(f)
            self.carried = {did: c for did, c in carried.items() if time.time() - c["time"] < CARRY_FOR}
        except (OSError, ValueError, KeyError, TypeError, AttributeError):
            self.carried = {}
        self.kept = dict(self.carried)

    # --- the shell ---

    def out(self, obj):
        sys.stdout.write(json.dumps(obj) + "\n")
        sys.stdout.flush()

    def emit(self):
        if not self.pending_emit:
            self.pending_emit = True
            asyncio.get_running_loop().call_soon(self.flush)

    def flush(self):
        self.pending_emit = False
        devices = []
        for did in sorted(set(self.paired) | set(self.links)):
            link = self.links.get(did)
            saved = self.paired.get(did, {})
            devices.append({
                "id": did,
                "name": link.name if link else saved.get("name", "Phone"),
                "type": link.type if link else saved.get("type", "phone"),
                "paired": did in self.paired,
                "reachable": link is not None,
                "pairing": self.pairing.get(did, ""),
                "battery": link.battery if link else -1,
                "charging": link.charging if link else False,
                "notifications": link.notifications if link and did in self.paired else [],
            })
        self.out({"event": "state", "devices": devices})
        for d in devices:
            if d["paired"] and d["reachable"]:
                self.kept[d["id"]] = {"battery": d["battery"], "charging": d["charging"],
                                      "notifications": d["notifications"], "time": time.time()}
        try:
            with open(CARRIED + ".tmp", "w") as f:
                json.dump(self.kept, f)
            os.replace(CARRIED + ".tmp", CARRIED)
        except OSError:
            pass

    def save(self):
        tmp = self.store_path + ".tmp"
        with open(tmp, "w") as f:
            json.dump(self.paired, f, indent=1)
        os.replace(tmp, self.store_path)

    async def read_commands(self):
        loop = asyncio.get_running_loop()
        reader = asyncio.StreamReader(limit=1 << 20)
        await loop.connect_read_pipe(lambda: asyncio.StreamReaderProtocol(reader), sys.stdin)
        while line := await reader.readline():
            try:
                self.command(json.loads(line))
            except (ValueError, KeyError, TypeError, AttributeError) as e:
                self.out({"event": "error", "text": f"bad command: {e}"})

    def command(self, c):
        cmd, did = c.get("cmd"), c.get("id", "")
        link = self.links.get(did)
        if cmd == "refresh":
            self.broadcast()
        elif cmd == "pair" and link and did not in self.paired:
            self.pairing[did] = "requested"
            link.send("kdeconnect.pair", {"pair": True, "timestamp": int(time.time())})
            asyncio.get_running_loop().call_later(PAIR_TIMEOUT, self.expire_pairing, did, "requested")
        elif cmd == "accept" and link and self.pairing.get(did) == "incoming":
            link.send("kdeconnect.pair", {"pair": True, "timestamp": int(time.time())})
            self.set_paired(link)
        elif cmd == "reject" and self.pairing.get(did) == "incoming":
            self.pairing.pop(did, None)
            if link:
                link.send("kdeconnect.pair", {"pair": False})
        elif cmd == "unpair":
            self.pairing.pop(did, None)
            if link:
                link.send("kdeconnect.pair", {"pair": False})
                link.notifications = []
            self.paired.pop(did, None)
            self.save()
            self.clipboard_watch()
        elif did not in self.paired or not link:
            pass
        elif cmd == "ring":
            link.send("kdeconnect.findmyphone.request", {})
        elif cmd == "share":
            for path in c.get("paths", []):
                path = path[7:] if path.startswith("file://") else path
                if os.path.isfile(path):
                    asyncio.create_task(self.send_file(link, path))
            if c.get("text"):
                link.send("kdeconnect.share.request", {"text": c["text"]})
        elif cmd == "reply":
            link.send("kdeconnect.notification.reply", {"requestReplyId": c["replyId"], "message": c["text"]})
        elif cmd == "dismiss":
            link.send("kdeconnect.notification.request", {"cancel": c["nid"]})
            link.notifications = [n for n in link.notifications if n["id"] != c["nid"]]
        elif cmd == "action":
            link.send("kdeconnect.notification.action", {"key": c["nid"], "action": c["action"]})
        self.emit()

    # --- finding phones ---

    def broadcast(self):
        if self.udp:
            try:
                self.udp.sendto(encode(self.me.identity()), ("255.255.255.255", UDP_PORT))
            except OSError:
                pass

    def heard_identity(self, data, addr):
        try:
            body = json.loads(data)["body"]
            did = body["deviceId"]
        except (ValueError, KeyError, TypeError):
            return
        if did == self.me.id or did in self.links:
            return
        now = time.monotonic()
        if now - self.heard.get(addr[0], 0) < 2:
            return
        self.heard[addr[0]] = now
        # answered straight back, so the phone connects to us over TCP
        try:
            self.udp.sendto(encode(self.me.identity()), (addr[0], UDP_PORT))
        except OSError:
            pass

    async def keep_looking(self):
        n = 0
        while True:
            away = [did for did in self.paired if did not in self.links]
            for did in away:
                if self.paired[did].get("addr"):
                    try:
                        self.udp.sendto(encode(self.me.identity()), (self.paired[did]["addr"], UDP_PORT))
                    except OSError:
                        pass
            if (away or not self.paired) and n % (BROADCAST_EVERY // ASK_EVERY) == 0:
                self.broadcast()
            n += 1
            await asyncio.sleep(ASK_EVERY)

    # --- a phone's connection ---

    async def connected(self, reader, writer):
        sock = writer.get_extra_info("socket")
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)
        sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_KEEPIDLE, 10)
        sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_KEEPINTVL, 5)
        sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_KEEPCNT, 3)
        addr = writer.get_extra_info("peername")[0]
        try:
            first = json.loads(await asyncio.wait_for(reader.readline(), 10))
            ident = first["body"]
            if first.get("type") != "kdeconnect.identity" or not VALID_ID.match(ident.get("deviceId", "")) \
                    or ident["deviceId"] == self.me.id:
                raise ValueError("not an identity")
            await asyncio.wait_for(start_tls(writer, self.me.client_tls(), False), 10)
            cert = writer.get_extra_info("ssl_object").getpeercert(binary_form=True)
            if ident.get("protocolVersion", 0) >= 8:
                # identities again, now that both ends are on TLS
                writer.write(encode(self.me.identity()))
                again = json.loads(await asyncio.wait_for(reader.readline(), 10))
                if again.get("type") != "kdeconnect.identity" or again["body"].get("deviceId") != ident["deviceId"]:
                    raise ValueError("identity changed")
                ident = again["body"]
        except (OSError, ValueError, KeyError, TypeError, AttributeError, asyncio.TimeoutError, ssl.SSLError):
            writer.close()
            return

        did = ident["deviceId"]
        saved = self.paired.get(did)
        if saved and saved["cert"] != base64.b64encode(cert).decode():
            self.out({"event": "error", "text": f"{ident.get('deviceName', did)} came back with another key; unpair it and pair again"})
            writer.close()
            return
        old = self.links.get(did)
        if old:
            old.close()
        link = Link(ident, cert, addr, reader, writer)
        carried = self.carried.pop(did, None)
        if saved and carried:
            link.battery = carried.get("battery", -1)
            link.charging = carried.get("charging", False)
            link.notifications = carried.get("notifications", [])
        self.links[did] = link
        if saved and (saved.get("name") != link.name or saved.get("addr") != addr):
            saved["name"] = link.name
            saved["addr"] = addr
            self.save()
        if saved:
            self.linked(link)
        self.emit()
        try:
            while line := await reader.readline():
                try:
                    p = json.loads(line)
                except ValueError:
                    continue
                if isinstance(p, dict) and isinstance(p.get("body"), dict):
                    self.received(link, p)
        except (OSError, ValueError, ssl.SSLError):
            pass
        finally:
            link.close()
            if self.links.get(did) is link:
                del self.links[did]
                self.pairing.pop(did, None)
                self.clipboard_watch()
                self.emit()

    def linked(self, link):
        """A paired phone's link is up: catch up on what it has."""
        link.send("kdeconnect.notification.request", {"request": True})
        self.clipboard_watch()

    def set_paired(self, link):
        self.pairing.pop(link.id, None)
        self.paired[link.id] = {"name": link.name, "type": link.type, "addr": link.addr,
                                "cert": base64.b64encode(link.cert).decode()}
        self.save()
        self.linked(link)
        notify(f"Paired with {link.name}")

    def expire_pairing(self, did, state):
        if self.pairing.get(did) == state:
            del self.pairing[did]
            self.emit()

    # --- what a phone sends ---

    def received(self, link, p):
        kind, body = p.get("type"), p["body"]
        if kind == "kdeconnect.pair":
            self.pair_packet(link, body)
            return
        if link.id not in self.paired:
            return
        if kind == "kdeconnect.battery":
            link.battery = int(body.get("currentCharge", -1))
            link.charging = bool(body.get("isCharging"))
        elif kind == "kdeconnect.notification":
            asyncio.create_task(self.notification(link, p))
        elif kind == "kdeconnect.ping":
            notify(body.get("message") or "Ping", f"From {link.name}")
        elif kind == "kdeconnect.share.request":
            asyncio.create_task(self.shared(link, p))
        elif kind in ("kdeconnect.clipboard", "kdeconnect.clipboard.connect"):
            content = body.get("content")
            stamp = int(body.get("timestamp", 0) or 0)
            if isinstance(content, str) and content and content != self.clip_last \
                    and (kind == "kdeconnect.clipboard" or stamp > self.clip_time):
                self.clip_last = content
                self.clip_time = int(time.time() * 1000)
                subprocess.Popen(["wl-copy", "--", content], stdout=subprocess.DEVNULL,
                                 stderr=subprocess.DEVNULL)
        self.emit()

    def pair_packet(self, link, body):
        did = link.id
        if body.get("pair"):
            if self.pairing.get(did) == "requested":
                self.set_paired(link)
            elif did in self.paired:
                link.send("kdeconnect.pair", {"pair": True, "timestamp": int(time.time())})
            else:
                self.pairing[did] = "incoming"
                asyncio.get_running_loop().call_later(PAIR_TIMEOUT, self.expire_pairing, did, "incoming")
                notify(f"{link.name} wants to pair", "Accept it from the phone module or Settings › Phone")
        else:
            self.pairing.pop(did, None)
            if did in self.paired:
                del self.paired[did]
                link.notifications = []
                self.save()
                self.clipboard_watch()
                notify(f"{link.name} unpaired")
        self.emit()

    async def notification(self, link, p):
        b = p["body"]
        nid = b.get("id")
        if nid is None:
            return
        if b.get("isCancel"):
            link.notifications = [n for n in link.notifications if n["id"] != nid]
            self.emit()
            return
        icon = ""
        if b.get("payloadHash") and p.get("payloadTransferInfo"):
            icon = os.path.join(ICONS, re.sub(r"[^A-Za-z0-9]", "", str(b["payloadHash"])) + ".png")
            if not os.path.exists(icon) and not await self.fetch(link, p, icon):
                icon = ""
        # an update to one sent before may come without its icon
        old = next((n for n in link.notifications if n["id"] == nid), None)
        if not icon and old:
            icon = old["icon"]
        # Android's notification key: "user|package|id|tag|uid"
        parts = str(nid).split("|")
        entry = {"id": nid, "app": b.get("appName", ""), "package": parts[1] if len(parts) > 2 else "", "title": b.get("title", ""),
                 "text": b.get("text", ""), "time": int(b.get("time", 0) or 0), "icon": icon,
                 "replyId": b.get("requestReplyId", ""), "clearable": bool(b.get("isClearable")),
                 "actions": [a for a in b.get("actions", []) if isinstance(a, str)]}
        link.notifications = ([entry] + [n for n in link.notifications if n["id"] != nid])[:MAX_NOTIFICATIONS]
        link.notifications.sort(key=lambda n: -n["time"])
        if not (b.get("silent") or b.get("requestAnswer")):
            title = entry["title"] or entry["app"]
            notify(title, entry["text"] if entry["text"] != title else "", app=entry["app"] or link.name,
                   icon=icon or "phone", package=entry["package"])
        self.emit()

    async def shared(self, link, p):
        b = p["body"]
        if b.get("filename") and p.get("payloadTransferInfo"):
            path = free_name(downloads(), b["filename"])
            if await self.fetch(link, p, path):
                notify(f"{os.path.basename(path)} from {link.name}", "Saved in " + os.path.dirname(path),
                       icon=path if re.search(r"\.(png|jpe?g|webp|gif)$", path, re.I) else "document-save")
            else:
                notify(f"Couldn't receive {b['filename']}", f"From {link.name}")
        elif isinstance(b.get("text"), str):
            self.clip_last = b["text"]
            subprocess.Popen(["wl-copy", "--", b["text"]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            notify(f"Text from {link.name}", "Copied to the clipboard")
        elif isinstance(b.get("url"), str) and re.match(r"^(https?|mailto|tel|geo):", b["url"]):
            subprocess.Popen(["xdg-open", b["url"]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    # --- payloads (icons, files) ---

    async def fetch(self, link, p, path):
        """A packet's payload, from the port the phone opened for it, into path."""
        try:
            port = int(p["payloadTransferInfo"]["port"])
            size = int(p.get("payloadSize", -1))
        except (KeyError, ValueError, TypeError):
            return False
        os.makedirs(os.path.dirname(path), exist_ok=True)
        part = path + ".part"
        try:
            reader, writer = await asyncio.wait_for(
                asyncio.open_connection(link.addr, port, ssl=self.me.client_tls(), server_hostname=""), 10)
            got = 0
            with open(part, "wb") as f:
                while size < 0 or got < size:
                    chunk = await asyncio.wait_for(reader.read(1 << 16), 30)
                    if not chunk:
                        break
                    f.write(chunk)
                    got += len(chunk)
            writer.close()
            if size >= 0 and got != size:
                raise OSError("short")
            os.replace(part, path)
            return True
        except (OSError, asyncio.TimeoutError, ssl.SSLError):
            try:
                os.unlink(part)
            except OSError:
                pass
            return False

    async def send_file(self, link, path):
        """A file to the phone: a port opened for it, named in the packet, and served once."""
        size = os.path.getsize(path)
        done = asyncio.get_running_loop().create_future()

        async def serve(reader, writer):
            if writer.get_extra_info("peername")[0] != link.addr or done.done():
                writer.close()
                return
            try:
                with open(path, "rb") as f:
                    while chunk := f.read(1 << 16):
                        writer.write(chunk)
                        await writer.drain()
                writer.close()
                done.set_result(True)
            except (OSError, ssl.SSLError):
                done.set_result(False)

        server = None
        for port in PAYLOAD_PORTS:
            try:
                server = await asyncio.start_server(serve, "0.0.0.0", port, ssl=self.me.server_tls())
                break
            except OSError:
                continue
        if not server:
            notify(f"Couldn't send {os.path.basename(path)}", "No free port")
            return
        link.send("kdeconnect.share.request", {"filename": os.path.basename(path)},
                  {"payloadSize": size, "payloadTransferInfo": {"port": port}})
        try:
            ok = await asyncio.wait_for(done, 120)
        except asyncio.TimeoutError:
            ok = False
        server.close()
        if not ok:
            notify(f"Couldn't send {os.path.basename(path)}", f"{link.name} didn't take it")

    # --- the clipboard, while a paired phone is linked ---

    def clipboard_watch(self):
        want = any(did in self.paired for did in self.links)
        if want and not self.clip_proc:
            self.clip_proc = asyncio.create_task(self.watch_clipboard())
        elif not want and self.clip_proc:
            self.clip_proc.cancel()
            self.clip_proc = None

    async def watch_clipboard(self):
        proc = None
        try:
            # a line per change: the text as base64 (empty for a picture)
            proc = await asyncio.create_subprocess_exec(
                "wl-paste", "--no-newline", "--type", "text", "--watch", "sh", "-c", "head -c 1048576 | base64 -w0; echo",
                stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL, preexec_fn=die_with_parent)
            first = True
            while line := await proc.stdout.readline():
                try:
                    text = base64.b64decode(line.strip()).decode()
                except (ValueError, UnicodeDecodeError):
                    continue
                # the first is what was already there when the phone came
                if first:
                    first = False
                    self.clip_last = self.clip_last or text
                    continue
                if not text or text == self.clip_last:
                    continue
                self.clip_last = text
                self.clip_time = int(time.time() * 1000)
                for did, link in self.links.items():
                    if did in self.paired:
                        link.send("kdeconnect.clipboard", {"content": text})
        except asyncio.CancelledError:
            pass
        except OSError:
            self.out({"event": "error", "text": "wl-paste isn't installed; the clipboard isn't shared"})
        finally:
            if proc and proc.returncode is None:
                proc.terminate()

    # --- running ---

    async def run(self):
        loop = asyncio.get_running_loop()
        server = None
        for port in TCP_PORTS:
            try:
                server = await asyncio.start_server(self.connected, "0.0.0.0", port, limit=1 << 22)
                self.me.tcp_port = port
                break
            except OSError:
                continue
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
            sock.bind(("0.0.0.0", UDP_PORT))
        except OSError:
            sock = None
        if not server or not sock:
            self.out({"event": "error", "text": "KDE Connect's ports are taken; is KDE Connect or GSConnect running?"})
            return

        daemon = self

        class Udp(asyncio.DatagramProtocol):
            def datagram_received(self, data, addr):
                daemon.heard_identity(data, addr)

        self.udp, _ = await loop.create_datagram_endpoint(Udp, sock=sock)
        for sig in (signal.SIGTERM, signal.SIGINT):
            loop.add_signal_handler(sig, lambda: [t.cancel() for t in asyncio.all_tasks()])
        self.out({"event": "ready", "name": self.me.name})
        self.emit()
        looking = asyncio.create_task(self.keep_looking())
        try:
            await self.read_commands()
        except asyncio.CancelledError:
            pass
        looking.cancel()
        if self.clip_proc:
            self.clip_proc.cancel()
            await asyncio.gather(self.clip_proc, return_exceptions=True)
        for link in list(self.links.values()):
            link.close()
        server.close()


if __name__ == "__main__":
    try:
        asyncio.run(Daemon().run())
    except (KeyboardInterrupt, asyncio.CancelledError):
        pass
