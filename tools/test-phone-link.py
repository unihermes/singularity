#!/usr/bin/env python3
"""Phone clipboard streaming handles the advertised clipboard size cap."""
import asyncio
import importlib.util
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import AsyncMock, Mock, patch

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('phone_link', ROOT / 'dotfiles/quickshell/.config/quickshell/scripts/phone-link.py')
phone = importlib.util.module_from_spec(spec)
spec.loader.exec_module(phone)


class ClipboardTests(unittest.IsolatedAsyncioTestCase):
    async def test_large_clipboard_does_not_stop_watcher(self):
        daemon = phone.Daemon.__new__(phone.Daemon)
        daemon.clip_last = ''
        daemon.clip_time = 0
        sent = []
        daemon.paired = {'phone': {}}
        daemon.links = {'phone': SimpleNamespace(send=lambda kind, body: sent.append(body['content']))}
        create = asyncio.create_subprocess_exec
        processes = []

        async def source(*args, **kwargs):
            proc = await create(sys.executable, '-c',
                'import base64\nfor text in (b"initial", b"x" * (1 << 20), b"after"):\n'
                ' print(base64.b64encode(text).decode(), flush=True)', **kwargs)
            processes.append(proc)
            return proc

        with patch.object(phone.asyncio, 'create_subprocess_exec', side_effect=source):
            try:
                await asyncio.wait_for(daemon.watch_clipboard(), 5)
            finally:
                for proc in processes:
                    await proc.wait()
        self.assertEqual(sent, ['x' * (1 << 20), 'after'])


class PayloadTests(unittest.IsolatedAsyncioTestCase):
    async def test_failed_payload_closes_connection_and_keeps_existing_file(self):
        daemon = phone.Daemon.__new__(phone.Daemon)
        daemon.me = SimpleNamespace(client_tls=lambda: None)
        link = SimpleNamespace(addr='127.0.0.1')
        packet = {'payloadTransferInfo': {'port': 1234}, 'payloadSize': 10}
        for failure in (OSError('read failed'), asyncio.TimeoutError()):
            reader = SimpleNamespace(read=AsyncMock(side_effect=[b'part', failure]))
            writer = Mock()
            with tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / 'download'
                path.write_bytes(b'existing')
                with patch.object(phone.asyncio, 'open_connection',
                                  AsyncMock(return_value=(reader, writer))):
                    self.assertFalse(await daemon.fetch(link, packet, str(path)))
                writer.close.assert_called_once()
                self.assertEqual(path.read_bytes(), b'existing')
                self.assertFalse(Path(str(path) + '.part').exists())


if __name__ == '__main__':
    unittest.main()
