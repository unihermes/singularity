#!/usr/bin/env python3
"""Exercise Ollama discovery against a local fake server."""

import importlib.util
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import threading
import unittest

spec = importlib.util.spec_from_file_location("ollama_status", Path(__file__).with_name("ollama-status.py"))
status = importlib.util.module_from_spec(spec)
spec.loader.exec_module(status)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def reply(self, body, code=200):
        self.send_response(code)
        self.end_headers()
        self.wfile.write(json.dumps(body).encode())

    def do_GET(self):
        if self.path == "/api/tags":
            self.reply({"models": [{"name": "vision"}, {"name": "unknown"}]})
        elif self.path == "/api/ps":
            self.reply({"models": [{"name": "vision", "size": 100, "size_vram": 75}]})
        else:
            self.reply({}, 404)

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        if self.path == "/api/show" and body["model"] == "vision":
            self.reply({"capabilities": ["completion", "vision"]})
        else:
            self.reply({}, 404)


class DiscoveryTest(unittest.TestCase):
    def test_models_capabilities_and_offload(self):
        with ThreadingHTTPServer(("127.0.0.1", 0), Handler) as server:
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                result = status.inspect(f"http://127.0.0.1:{server.server_port}")
            finally:
                server.shutdown()
                thread.join()
        self.assertEqual(result["models"], [
            {"name": "vision", "capabilities": ["completion", "vision"]},
            {"name": "unknown", "capabilities": None},
        ])
        self.assertEqual(result["running"], [{"name": "vision", "size": 100, "size_vram": 75}])


if __name__ == "__main__":
    unittest.main()
