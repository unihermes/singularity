#!/usr/bin/env python3
"""Own sidebar subprocesses independently of Quickshell.

Protocol: newline-delimited JSON over a private Unix socket. Clients issue
start, write, stop, status or watch requests. A watch receives retained events
with sequence numbers followed by new events. This broker is not yet wired to
the sidebar; its protocol is the first step towards reconnecting a session.
"""

import argparse
import asyncio
import json
import os
import signal
import stat
from pathlib import Path


class Broker:
    def __init__(self):
        self.sessions = {}
        self.watchers = set()
        self.events = []
        self.sequence = 0
        self.lock = asyncio.Lock()
        self.snapshots = {}

    def emit(self, event):
        self.sequence += 1
        event = {"seq": self.sequence, **event}
        self.events.append(event)
        data = (json.dumps(event) + "\n").encode()
        for writer in tuple(self.watchers):
            try:
                writer.write(data)
            except (ConnectionError, RuntimeError):
                self.watchers.discard(writer)

    async def read_stream(self, name, stream, kind):
        while line := await stream.readline():
            self.emit({"event": kind, "session": name, "line": line.decode(errors="replace").rstrip("\n")})

    async def reap(self, name, process):
        await asyncio.gather(self.read_stream(name, process.stdout, "stdout"),
                             self.read_stream(name, process.stderr, "stderr"))
        code = await process.wait()
        if self.sessions.get(name) is process:
            del self.sessions[name]
        self.emit({"event": "exit", "session": name, "code": code})

    async def request(self, req, writer):
        action = req.get("action")
        name = req.get("session")
        if action == "watch":
            since = req.get("since", 0)
            if not isinstance(since, int) or since < 0:
                raise ValueError("invalid sequence")
            for event in self.events:
                if event["seq"] > since:
                    writer.write((json.dumps(event) + "\n").encode())
            self.watchers.add(writer)
            return {"watching": True, "seq": self.sequence}
        if action == "status":
            return {"sessions": list(self.sessions), "seq": self.sequence}
        if not isinstance(name, str) or not name or len(name) > 128:
            raise ValueError("invalid session")
        if action == "checkpoint":
            state, seq = req.get("state"), req.get("seq")
            if not isinstance(state, dict) or not isinstance(seq, int) or not 0 <= seq <= self.sequence:
                raise ValueError("invalid checkpoint")
            previous = self.snapshots.get(name)
            if previous and seq < previous["seq"]:
                raise ValueError("checkpoint is older than the saved state")
            self.snapshots[name] = {"seq": seq, "state": state}
            return {}
        if action == "restore":
            checkpoint = self.snapshots.get(name)
            if not checkpoint:
                return {"checkpoint": None, "events": []}
            return {"checkpoint": checkpoint, "events": [event for event in self.events
                    if event["seq"] > checkpoint["seq"] and event.get("session") == name]}
        if action == "start":
            if name in self.sessions:
                raise ValueError("session already running")
            argv = req.get("argv")
            cwd = req.get("cwd")
            if not isinstance(argv, list) or not argv or not all(isinstance(x, str) for x in argv):
                raise ValueError("invalid argv")
            if not isinstance(cwd, str) or not os.path.isabs(cwd):
                raise ValueError("invalid working directory")
            process = await asyncio.create_subprocess_exec(*argv, cwd=cwd, stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE, start_new_session=True,
                limit=16 * 1024 * 1024)
            self.sessions[name] = process
            self.emit({"event": "start", "session": name, "pid": process.pid})
            asyncio.create_task(self.reap(name, process))
            return {"pid": process.pid}
        process = self.sessions.get(name)
        if not process or process.returncode is not None:
            raise ValueError("session not running")
        if action == "write":
            data = req.get("data")
            if not isinstance(data, str):
                raise ValueError("invalid data")
            process.stdin.write(data.encode())
            await process.stdin.drain()
            return {}
        if action == "stop":
            process.send_signal(signal.SIGTERM)
            return {}
        raise ValueError("unknown action")

    async def client(self, reader, writer):
        try:
            while line := await reader.readline():
                req = None
                try:
                    req = json.loads(line)
                    if not isinstance(req, dict):
                        raise ValueError("request must be an object")
                    async with self.lock:
                        result = await self.request(req, writer)
                    reply = {"id": req.get("id"), "result": result}
                except (ValueError, OSError, BrokenPipeError) as exc:
                    reply = {"id": req.get("id") if isinstance(req, dict) else None, "error": str(exc)}
                writer.write((json.dumps(reply) + "\n").encode())
                await writer.drain()
        except (ConnectionError, asyncio.LimitOverrunError):
            pass
        finally:
            self.watchers.discard(writer)
            writer.close()
            await writer.wait_closed()


async def serve(path):
    path = Path(path)
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    # Never unlink an active socket, or an unrelated file.
    if path.exists():
        if not stat.S_ISSOCK(path.stat().st_mode):
            raise RuntimeError("socket path is occupied")
        try:
            _, writer = await asyncio.open_unix_connection(path)
        except ConnectionRefusedError:
            path.unlink()
        else:
            writer.close()
            await writer.wait_closed()
            raise RuntimeError("broker already running")
    broker = Broker()
    server = await asyncio.start_unix_server(broker.client, path=str(path), limit=16 * 1024 * 1024)
    os.chmod(path, 0o600)
    try:
        async with server:
            await server.serve_forever()
    finally:
        path.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--socket", required=True)
    args = parser.parse_args()
    try:
        asyncio.run(serve(args.socket))
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
