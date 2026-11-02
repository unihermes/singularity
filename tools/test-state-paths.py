#!/usr/bin/env python3
"""Exercise migrations with real files, conflicts, links and repeat launches."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'dotfiles/singularity/.config/singularity/state-paths.py'


class PathTests(unittest.TestCase):
    def test_migration_preserves_settings_notes_and_provider_identity(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            legacy = home / '.local/state/singularity'
            legacy.mkdir(parents=True)
            for name in ['appearance.json', 'notes.json', 'ai.json']:
                (legacy / name).write_text(name)
            (legacy / 'notes.json').chmod(0o600)
            cache = home / '.cache/singularity'
            (cache / 'ai/chat').mkdir(parents=True)
            (cache / 'ai/chat/file.txt').write_text('chat working files')
            (legacy / 'current-wallpaper').symlink_to('/images/wallpaper.jpg')
            env = dict(os.environ, HOME=tmp, XDG_STATE_HOME=str(home / 'state'), XDG_CACHE_HOME=str(home / 'cache'))
            dest = home / 'state/singularity'
            dest.mkdir(parents=True)
            (dest / 'appearance.json').write_text('new settings win')
            for _ in range(2):
                subprocess.run(['python3', str(SCRIPT)], env=env, check=True)
            self.assertTrue(legacy.is_symlink())
            self.assertEqual((dest / 'appearance.json').read_text(), 'new settings win')
            self.assertEqual((dest / 'notes.json').read_text(), 'notes.json')
            self.assertEqual((dest / 'notes.json').stat().st_mode & 0o777, 0o600)
            self.assertEqual(os.readlink(dest / 'current-wallpaper'), '/images/wallpaper.jpg')
            backups = list(legacy.parent.glob('singularity.before-xdg-*'))
            self.assertEqual(len(backups), 1)
            self.assertEqual((backups[0] / 'appearance.json').read_text(), 'appearance.json')
            self.assertEqual((cache / 'ai/chat/file.txt').read_text(), 'chat working files')
            # Changing XDG again retains both previous trees and the same cwd.
            env['XDG_STATE_HOME'] = str(home / 'other-state')
            subprocess.run(['python3', str(SCRIPT)], env=env, check=True)
            self.assertEqual((legacy / 'notes.json').read_text(), 'notes.json')
            self.assertEqual((dest / 'notes.json').read_text(), 'notes.json')

    def test_empty_xdg_and_default_paths_do_not_move_data(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = dict(os.environ, HOME=tmp, XDG_STATE_HOME='', XDG_CACHE_HOME='')
            subprocess.run(['python3', str(SCRIPT)], env=env, check=True)
            self.assertFalse((Path(tmp) / '.local/state/singularity').is_symlink())
            self.assertFalse(list(Path(tmp).rglob('*.before-xdg-*')))

    def test_nested_paths_are_rejected_before_copying(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = dict(os.environ, HOME=tmp, XDG_STATE_HOME=tmp + '/.local/state/singularity/nested', XDG_CACHE_HOME='')
            result = subprocess.run(['python3', str(SCRIPT)], env=env, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((Path(tmp) / '.local/state/singularity/nested').exists())


if __name__ == '__main__':
    unittest.main()
