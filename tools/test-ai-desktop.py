#!/usr/bin/env python3
"""Exercise desktop staging against disposable repositories and user directories."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / 'dotfiles/quickshell/.config/quickshell/scripts/ai-desktop.sh'


class DesktopTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.repo = self.root / 'repo'
        self.repo.mkdir()
        self.home = self.root / 'home'
        config = self.home / '.config/quickshell'
        config.mkdir(parents=True)
        (self.repo / 'shell.qml').write_text('original\n')
        (config / 'shell.qml').symlink_to(self.repo / 'shell.qml')
        self.settings = self.home / 'appearance.json'
        self.settings.write_text(json.dumps({'radius': 6, 'fontSize': 16}))
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.stub('notify-send', 'exit 0')
        self.env = dict(os.environ, HOME=str(self.home), XDG_CACHE_HOME=str(self.root / 'custom cache'),
                        SINGULARITY_SETTINGS=str(self.settings), GIT_CONFIG_NOSYSTEM='1',
                        GIT_CONFIG_GLOBAL=os.devnull, PATH=str(self.bin) + ':' + os.environ['PATH'])
        self.git = shutil.which('git')
        # Hooks export index/worktree variables that must not reach fixture repos.
        for key in subprocess.check_output([self.git, 'rev-parse', '--local-env-vars'], text=True).splitlines():
            self.env.pop(key, None)
        subprocess.run([self.git, 'init', '-q', str(self.repo)], env=self.env, check=True)
        subprocess.run([self.git, '-C', str(self.repo), 'add', '.'], env=self.env, check=True)

    def stub(self, name, body):
        p = self.bin / name
        p.write_text('#!/bin/sh\n' + body + '\n')
        p.chmod(0o755)

    def run_script(self, command, ok=True):
        r = subprocess.run(['bash', str(SCRIPT), command], env=self.env, capture_output=True, text=True)
        if ok:
            self.assertEqual(r.returncode, 0, r.stderr)
        else:
            self.assertNotEqual(r.returncode, 0, r.stdout)
        return r

    def start(self):
        work = Path(self.run_script('start').stdout.strip())
        cache = self.env.get('XDG_CACHE_HOME') or str(self.home / '.cache')
        self.assertEqual(work, Path(cache) / 'singularity/ai-desktop/work')
        self.assertEqual((work / 'shell.qml').read_text(), 'original\n')
        self.assertFalse((work / '.git').exists())
        return work

    def test_custom_cache_apply_merges_only_changed_settings(self):
        work = self.start()
        (work / 'shell.qml').write_text('edited\n')
        (work / '.live/appearance.json').write_text(json.dumps({'radius': 9, 'fontSize': 16}))
        self.settings.write_text(json.dumps({'radius': 6, 'fontSize': 20}))
        self.assertIn('+edited', self.run_script('diff').stdout)
        self.run_script('apply')
        self.assertEqual((self.repo / 'shell.qml').read_text(), 'edited\n')
        self.assertEqual(json.loads(self.settings.read_text()), {'radius': 9, 'fontSize': 20})
        self.assertFalse(work.exists())

    def test_empty_and_unset_cache_fall_back_and_discard(self):
        for value in ('', None):
            with self.subTest(value=value):
                if value is None:
                    self.env.pop('XDG_CACHE_HOME', None)
                else:
                    self.env['XDG_CACHE_HOME'] = value
                work = self.start()
                self.run_script('discard')
                self.assertFalse(work.exists())
                self.assertEqual(self.run_script('diff', ok=False).returncode, 3)

    def test_conflicting_repo_edit_preserves_live_settings_and_staging(self):
        work = self.start()
        (work / 'shell.qml').write_text('staged edit\n')
        (self.repo / 'shell.qml').write_text('live edit\n')
        (work / '.live/appearance.json').write_text('{"radius": 9}')
        self.run_script('apply', ok=False)
        self.assertEqual((self.repo / 'shell.qml').read_text(), 'live edit\n')
        self.assertEqual(json.loads(self.settings.read_text())['radius'], 6)
        self.assertTrue(work.exists())

    def test_failed_snapshot_does_not_report_success(self):
        # Fail after repository discovery, when the staging repository is initialized.
        self.stub('git', 'for arg do [ "$arg" = init ] && exit 1; done\nexec "' + self.git + '" "$@"')
        self.run_script('start', ok=False)

    def test_failed_apply_keeps_staging(self):
        work = self.start()
        (work / 'shell.qml').write_text('edited\n')
        self.stub('git', 'case " $* " in *" apply "*)\n'
                  '  case " $* " in *" --check "*) ;; *) exit 1;; esac;; esac\n'
                  'exec "' + self.git + '" "$@"')
        self.run_script('apply', ok=False)
        self.assertTrue(work.exists())
        self.assertEqual((self.repo / 'shell.qml').read_text(), 'original\n')

    def test_failed_settings_write_keeps_staging(self):
        work = self.start()
        (work / '.live/appearance.json').write_text('{"radius": 9}')
        self.stub('cp', 'exit 1')
        self.run_script('apply', ok=False)
        self.assertTrue(work.exists())
        self.assertEqual(json.loads(self.settings.read_text())['radius'], 6)


if __name__ == '__main__':
    unittest.main()
