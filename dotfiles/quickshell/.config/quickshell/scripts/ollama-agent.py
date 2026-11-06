#!/usr/bin/env python3
"""Run Codex against the local Ollama server, adapted for small local models.

Codex's tool set assumes a large hosted model. A loopback proxy between Codex
and Ollama trims the shell tool's schema and spells out what a still-running
command means, so a model polls it rather than starting it again. It also asks
again when a model ends its reply after planning, with nothing for Codex to do.
"""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import tempfile
import threading
import urllib.error
import urllib.request

OLLAMA = 'http://127.0.0.1:11434'
RUNNING = re.compile(r'Process running with session ID (\d+)')
# Tool parameters small models misuse; the escalation pair stays when approval can be asked.
UNUSED = {'login', 'shell', 'tty', 'prefix_rule', 'max_output_tokens'}
ESCALATION = {'justification', 'sandbox_permissions'}
# Answered by the sidebar with "not supported".
DROPPED_TOOLS = {'request_user_input'}
# Further tries after a reply with only reasoning in it.
EMPTY_RETRIES = 2


def input_text(request):
    parts = []
    for item in request.get('input', []):
        for part in item.get('content') or [] if isinstance(item.get('content'), list) else []:
            parts.append(part.get('text', ''))
    return '\n'.join(parts)


def running_hint(match):
    return (f'{match.group(0)}\n[STILL RUNNING. The output below is partial; the command has not failed '
            f'or stopped. Do not start it again. Next, call write_stdin with session_id {match.group(1)}, '
            'chars "" and yield_time_ms 300000, and repeat until it reports an exit code.]')


def adapt(request):
    never = 'Approval policy is currently never' in input_text(request)
    tools = []
    for tool in request.get('tools', []):
        if tool.get('name') in DROPPED_TOOLS:
            continue
        properties = (tool.get('parameters') or {}).get('properties')
        if tool.get('name') == 'exec_command' and properties:
            for name in UNUSED | (ESCALATION if never else set()):
                properties.pop(name, None)
        tools.append(tool)
    if 'tools' in request:
        request['tools'] = tools
    for item in request.get('input', []):
        if item.get('type') == 'function_call_output' and isinstance(item.get('output'), str):
            item['output'] = RUNNING.sub(running_hint, item['output'])
    return request


def empty_reply(event):
    """Whether an SSE event finishes a reply holding only reasoning."""
    for line in event.split(b'\n'):
        if line.startswith(b'data:') and b'response.completed' in line:
            try:
                data = json.loads(line[5:])
            except ValueError:
                return False
            if data.get('type') != 'response.completed':
                return False
            return all(item.get('type') == 'reasoning' for item in data['response'].get('output', []))
    return False


class Proxy(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, *args):
        pass

    def open_upstream(self, body):
        headers = {k: v for k, v in self.headers.items() if k.lower() not in ('host', 'content-length', 'connection')}
        upstream = urllib.request.Request(OLLAMA + self.path, data=body, headers=headers, method=self.command)
        try:
            return urllib.request.urlopen(upstream, timeout=3600)
        except urllib.error.HTTPError as error:
            return error

    def send_chunk(self, data):
        self.wfile.write(b'%x\r\n%s\r\n' % (len(data), data))
        self.wfile.flush()

    def relay(self, response, retry):
        """Stream a reply on. False when it came back empty and retry held its ending back."""
        pending = b''
        while chunk := response.read1(65536):
            if not retry:
                self.send_chunk(chunk)
                continue
            pending += chunk
            *events, pending = pending.split(b'\n\n')
            for event in events:
                if empty_reply(event):
                    return False
                self.send_chunk(event + b'\n\n')
        if pending:
            self.send_chunk(pending)
        return True

    def forward(self, body=None, retries=0):
        try:
            response = self.open_upstream(body)
        except OSError as error:
            message = json.dumps({'error': {'message': f'Ollama is not reachable: {error}'}}).encode()
            self.send_response(502)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(message)))
            self.send_header('Connection', 'close')
            self.end_headers()
            self.wfile.write(message)
            self.close_connection = True
            return
        self.send_response(response.status)
        for key, value in response.headers.items():
            if key.lower() not in ('transfer-encoding', 'content-length', 'connection'):
                self.send_header(key, value)
        self.send_header('Transfer-Encoding', 'chunked')
        self.send_header('Connection', 'close')
        self.end_headers()
        self.close_connection = True
        if self.command != 'HEAD':
            while True:
                with response:
                    finished = self.relay(response, retries > 0 and response.status == 200)
                if finished:
                    break
                retries -= 1
                try:
                    response = self.open_upstream(body)
                except OSError:
                    break
            self.wfile.write(b'0\r\n\r\n')

    def do_GET(self):
        self.forward()

    def do_HEAD(self):
        self.forward()

    def do_POST(self):
        body = self.rfile.read(int(self.headers.get('Content-Length') or 0))
        retries = 0
        if self.path.endswith('/responses'):
            try:
                body = json.dumps(adapt(json.loads(body))).encode()
                retries = EMPTY_RETRIES
            except ValueError:
                pass
        self.forward(body, retries)


def start_proxy():
    server = ThreadingHTTPServer(('127.0.0.1', 0), Proxy)
    server.daemon_threads = True
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server.server_address[1]


def catalog():
    template = json.loads(Path(__file__).with_name('ollama-model-template.json').read_text())
    with urllib.request.urlopen(OLLAMA + '/api/tags', timeout=5) as response:
        installed = json.load(response)['models']
    return {'models': [dict(template, slug=m['name'], display_name=m['name']) for m in installed]}


def codex_home():
    state = os.environ.get('XDG_STATE_HOME') or os.path.expanduser('~/.local/state')
    path = Path(state) / 'singularity' / 'ollama-codex'
    path.mkdir(parents=True, exist_ok=True)
    return str(path)


def main():
    with tempfile.TemporaryDirectory(prefix='singularity-ollama-') as directory:
        path = Path(directory) / 'models.json'
        path.write_text(json.dumps(catalog()))
        # App, agent, goal and skill catalogs overflow the local context and can
        # push the shell tools out of Ollama's prompt, so they stay off here.
        # Web search is turned off too: Ollama serves it from ollama.com and
        # answers 401 without an account.
        # A Codex home of its own: no ChatGPT login to bill or sync, so nothing
        # leaves the machine, and its threads stay apart from the Codex tab's.
        env = dict(os.environ, CODEX_HOME=codex_home(),
                   CODEX_OSS_BASE_URL=f'http://127.0.0.1:{start_proxy()}/v1')
        process = subprocess.Popen(['codex', 'app-server', '-c', 'notify=[]', '-c', 'model_provider="ollama"',
                                '-c', 'features.apps=false',
                                '-c', 'features.multi_agent=false',
                                '-c', 'features.goals=false',
                                '-c', 'skills.bundled.enabled=false',
                                '-c', 'skills.include_instructions=false',
                                '-c', 'web_search="disabled"',
                                '-c', 'model_catalog_json=' + json.dumps(str(path)),
                                '-c', 'model_context_window=32768', '-c', 'analytics.enabled=false'], env=env)
        signal.signal(signal.SIGTERM, lambda *_: process.terminate())
        signal.signal(signal.SIGINT, lambda *_: process.terminate())
        return process.wait()


if __name__ == '__main__':
    raise SystemExit(main())
