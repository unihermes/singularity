#!/usr/bin/env python3
"""Exercise subprocess ownership and event replay without a Unix socket."""
import asyncio
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'dotfiles/quickshell/.config/quickshell/scripts/ai_broker.py'
spec = importlib.util.spec_from_file_location('ai_broker', SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class Writer:
    def __init__(self):
        self.lines = []

    def write(self, data):
        self.lines.append(json.loads(data))


class BrokerTest(unittest.IsolatedAsyncioTestCase):
    async def test_process_survives_disconnect_and_replays(self):
        broker = module.Broker()
        first = Writer()
        with tempfile.TemporaryDirectory() as directory:
            await broker.request({'action': 'start', 'session': 'chat', 'cwd': directory,
                                  'argv': [sys.executable, '-u', '-c',
                                           'import sys; print("ready"); print(sys.stdin.readline().strip())']}, first)
            await broker.request({'action': 'write', 'session': 'chat', 'data': 'hello\n'}, Writer())
            for _ in range(100):
                if any(event['event'] == 'exit' for event in broker.events):
                    break
                await asyncio.sleep(0.02)
            self.assertEqual([e['line'] for e in broker.events if e['event'] == 'stdout'], ['ready', 'hello'])
            self.assertNotIn('chat', broker.sessions)
            reconnect = Writer()
            await broker.request({'action': 'watch', 'since': 1}, reconnect)
            self.assertEqual([e['event'] for e in reconnect.lines], ['stdout', 'stdout', 'exit'])
            self.assertEqual([e['seq'] for e in reconnect.lines], [2, 3, 4])

    async def test_checkpoint_and_replay_are_per_session(self):
        broker = module.Broker()
        broker.emit({'event': 'stdout', 'session': 'chat', 'line': 'first'})
        await broker.request({'action': 'checkpoint', 'session': 'chat', 'seq': 1,
                              'state': {'asks': [{'id': 'approval'}]}}, Writer())
        broker.emit({'event': 'stdout', 'session': 'code', 'line': 'unrelated'})
        broker.emit({'event': 'stdout', 'session': 'chat', 'line': 'second'})
        result = await broker.request({'action': 'restore', 'session': 'chat'}, Writer())
        self.assertEqual(result['checkpoint']['state']['asks'][0]['id'], 'approval')
        self.assertEqual([e['line'] for e in result['events']], ['second'])
        with self.assertRaises(ValueError):
            await broker.request({'action': 'checkpoint', 'session': 'chat', 'seq': 0,
                                  'state': {}}, Writer())


if __name__ == '__main__':
    unittest.main()
