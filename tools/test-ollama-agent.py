#!/usr/bin/env python3
"""The Ollama agent's proxy: request adaptation and empty-reply retries."""
from http.server import BaseHTTPRequestHandler, HTTPServer
import importlib.util
import json
from pathlib import Path
import threading
import unittest
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / 'dotfiles/quickshell/.config/quickshell/scripts/ollama-agent.py'
spec = importlib.util.spec_from_file_location('ollama_agent', SCRIPT)
agent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(agent)


def sse(output):
    done = {'type': 'response.completed', 'response': {'output': output}}
    return (b'event: response.created\ndata: {"type":"response.created"}\n\n'
            + b'event: response.completed\ndata: ' + json.dumps(done).encode() + b'\n\n')


REASONING = [{'type': 'reasoning', 'summary': []}]
CALL = REASONING + [{'type': 'function_call', 'name': 'exec_command', 'arguments': '{}'}]


class Upstream(BaseHTTPRequestHandler):
    replies = []
    calls = 0

    def log_message(self, *args):
        pass

    def do_POST(self):
        self.rfile.read(int(self.headers.get('Content-Length') or 0))
        cls = type(self)
        body = cls.replies[min(cls.calls, len(cls.replies) - 1)]
        cls.calls += 1
        self.send_response(200)
        self.send_header('Content-Type', 'text/event-stream')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)


class AdaptTest(unittest.TestCase):
    def request(self, instructions):
        return {'input': [
            {'type': 'message', 'content': [{'type': 'input_text', 'text': instructions}]},
            {'type': 'function_call_output', 'output': 'Process running with session ID 42\nOutput:\nstep 1'},
        ], 'tools': [
            {'name': 'exec_command', 'parameters': {'properties': {
                'cmd': {}, 'workdir': {}, 'yield_time_ms': {}, 'tty': {}, 'login': {}, 'shell': {},
                'prefix_rule': {}, 'max_output_tokens': {}, 'justification': {}, 'sandbox_permissions': {}}}},
            {'name': 'request_user_input', 'parameters': {'properties': {}}},
            {'name': 'write_stdin', 'parameters': {'properties': {'session_id': {}, 'chars': {}}}},
        ]}

    def test_never_drops_escalation(self):
        out = agent.adapt(self.request('Approval policy is currently never.'))
        self.assertEqual([t['name'] for t in out['tools']], ['exec_command', 'write_stdin'])
        self.assertEqual(set(out['tools'][0]['parameters']['properties']), {'cmd', 'workdir', 'yield_time_ms'})

    def test_asking_keeps_escalation(self):
        out = agent.adapt(self.request('Approval policy is currently on-request.'))
        self.assertIn('sandbox_permissions', out['tools'][0]['parameters']['properties'])
        self.assertIn('justification', out['tools'][0]['parameters']['properties'])

    def test_running_output_gets_hint(self):
        out = agent.adapt(self.request(''))['input'][1]['output']
        self.assertIn('STILL RUNNING', out)
        self.assertIn('session_id 42', out)
        self.assertIn('step 1', out)


class RetryTest(unittest.TestCase):
    def setUp(self):
        self.upstream = HTTPServer(('127.0.0.1', 0), Upstream)
        threading.Thread(target=self.upstream.serve_forever, daemon=True).start()
        self.saved = agent.OLLAMA
        agent.OLLAMA = f'http://127.0.0.1:{self.upstream.server_address[1]}'
        Upstream.calls = 0
        self.port = agent.start_proxy()

    def tearDown(self):
        agent.OLLAMA = self.saved
        self.upstream.shutdown()
        self.upstream.server_close()

    def post(self):
        request = urllib.request.Request(f'http://127.0.0.1:{self.port}/v1/responses',
                                         data=json.dumps({'input': [], 'tools': []}).encode())
        with urllib.request.urlopen(request, timeout=5) as response:
            return response.read()

    def test_empty_reply_is_asked_again(self):
        Upstream.replies = [sse(REASONING), sse(CALL)]
        body = self.post()
        self.assertEqual(Upstream.calls, 2)
        self.assertEqual(body.count(b'response.completed"'), 1)
        self.assertIn(b'function_call', body)

    def test_gives_up_with_the_empty_reply(self):
        Upstream.replies = [sse(REASONING)]
        body = self.post()
        self.assertEqual(Upstream.calls, agent.EMPTY_RETRIES + 1)
        self.assertEqual(body.count(b'response.completed"'), 1)

    def test_real_reply_is_not_retried(self):
        Upstream.replies = [sse(CALL)]
        self.post()
        self.assertEqual(Upstream.calls, 1)


if __name__ == '__main__':
    unittest.main()
