#!/usr/bin/env python3
"""Check independent sidebar startup and command forwarding without a desktop."""
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

SCRIPT = Path(__file__).resolve().parents[1] / 'dotfiles/quickshell/.config/quickshell/scripts/ai_host.py'
spec = importlib.util.spec_from_file_location('ai_host', SCRIPT)
host = importlib.util.module_from_spec(spec)
spec.loader.exec_module(host)


class HostTests(unittest.TestCase):
    def invoke(self, args, results):
        with tempfile.TemporaryDirectory() as runtime, \
                patch.dict(os.environ, {'XDG_RUNTIME_DIR': runtime}), \
                patch.object(host.sys, 'argv', ['ai_host.py', '/config/AiHost.qml', *args]), \
                patch.object(host.subprocess, 'run', side_effect=[Mock(returncode=r) for r in results]) as run, \
                patch.object(host.subprocess, 'Popen') as launch, \
                patch.object(host.time, 'sleep'):
            host.main()
            return run.call_args_list, launch.call_args_list

    def test_existing_host_is_reused(self):
        calls, launches = self.invoke(['toggle', 'DP-1'], [0, 0])
        self.assertFalse(launches)
        self.assertEqual(calls[-1].args[0][-4:], ['call', 'chat', 'toggle', 'DP-1'])

    def test_start_waits_for_ipc_before_forwarding(self):
        calls, launches = self.invoke(['close'], [1, 1, 0, 0])
        self.assertEqual(len(launches), 1)
        self.assertEqual(launches[0].kwargs['env']['SINGULARITY_AI_HOST'], '1')
        self.assertTrue(launches[0].kwargs['start_new_session'])
        self.assertEqual(calls[-1].args[0][-3:], ['call', 'chat', 'close'])
        self.assertTrue(calls[-1].kwargs['check'])

    def test_open_forwards_tab_and_engine(self):
        calls, launches = self.invoke(['open', 'code', 'codex'], [0, 0])
        self.assertFalse(launches)
        self.assertEqual(calls[-1].args[0][-5:], ['call', 'chat', 'open', 'code', 'codex'])
        self.assertTrue(calls[-1].kwargs['check'])

    def test_start_without_command(self):
        calls, launches = self.invoke([], [1, 0])
        self.assertEqual(len(launches), 1)
        self.assertEqual(len(calls), 2)

    def test_failed_start_does_not_forward(self):
        with self.assertRaisesRegex(SystemExit, 'Chat host failed to start'):
            self.invoke(['toggle'], [1] * 101)


if __name__ == '__main__':
    unittest.main()
