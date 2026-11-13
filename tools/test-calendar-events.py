#!/usr/bin/env python3
"""Calendar refreshes preserve usable offline data and report failed feeds."""
import datetime as dt
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('calendar_events', ROOT / 'dotfiles/quickshell/.config/quickshell/scripts/calendar-events.py')
calendar = importlib.util.module_from_spec(spec)
spec.loader.exec_module(calendar)


def feed(title='Meeting'):
    date = dt.date.today().strftime('%Y%m%d')
    return (f'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\nUID:one\r\n'
            f'DTSTART;VALUE=DATE:{date}\r\nSUMMARY:{title}\r\n'
            'END:VEVENT\r\nEND:VCALENDAR\r\n').encode()


class RefreshTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        for key, value in dict(CACHE=temp.name, CONF=str(self.root / 'calendars.conf'),
                               STATE=str(self.root / 'fetched.json'), OUT=str(self.root / 'events.json')).items():
            p = patch.object(calendar, key, value)
            p.start()
            self.addCleanup(p.stop)
        Path(calendar.CONF).write_text('Work = https://example.invalid/calendar\n')
        self.raw = Path(calendar.raw_path('https://example.invalid/calendar'))
        self.raw.write_bytes(feed())
        Path(calendar.STATE).write_text(json.dumps({self.raw.name: 123}))

    def run_refresh(self, data=None, offline=False):
        with patch.object(sys, 'argv', ['calendar-events.py'] + (['--offline'] if offline else [])), \
                patch.object(calendar, 'fetch', return_value=data):
            code = calendar.main()
        return code, json.loads(Path(calendar.OUT).read_text())

    def test_invalid_download_keeps_last_good_cache_and_timestamp(self):
        before = self.raw.read_bytes()
        code, out = self.run_refresh(b'BEGIN:VCALENDAR\r\nnot valid')
        self.assertEqual(code, 2)
        self.assertFalse(out['feeds'][0]['ok'])
        self.assertEqual(out['feeds'][0]['fetched'], 123)
        self.assertEqual(out['events'][0]['title'], 'Meeting')
        self.assertEqual(self.raw.read_bytes(), before)

    def test_success_replaces_cache(self):
        code, out = self.run_refresh(feed('Updated'))
        self.assertEqual(code, 0)
        self.assertTrue(out['feeds'][0]['ok'])
        self.assertEqual(out['events'][0]['title'], 'Updated')
        self.assertEqual(self.raw.read_bytes(), feed('Updated'))

    def test_offline_missing_or_invalid_cache_fails(self):
        for data in (None, b'broken'):
            if data is None:
                self.raw.unlink()
            else:
                self.raw.write_bytes(data)
            code, out = self.run_refresh(offline=True)
            self.assertEqual(code, 2)
            self.assertFalse(out['feeds'][0]['ok'])

    def test_invalid_state_shape_recovers(self):
        for value in ([], None, 42):
            Path(calendar.STATE).write_text(json.dumps(value))
            code, out = self.run_refresh(feed())
            self.assertEqual(code, 0)
            self.assertTrue(out['feeds'][0]['ok'])


if __name__ == '__main__':
    unittest.main()
