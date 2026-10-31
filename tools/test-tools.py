#!/usr/bin/env python3
"""Regression checks for compact discovery and pre-commit check selection."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent


class ContextTests(unittest.TestCase):
    def run_context(self, *args):
        return subprocess.run([sys.executable, str(ROOT / "tools/context.py"), *args],
                              cwd="/tmp", capture_output=True, text=True)

    def test_filtered_outline(self):
        result = self.run_context("qs/services/Settings.qml", "--match", "function", "--limit", "2")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("function setDensity", result.stdout)
        self.assertNotIn("property alias", result.stdout)
        self.assertIn("more;", result.stdout)

    def test_markdown_headings(self):
        result = self.run_context("qs/DESIGN.md", "--match", "controls")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("## Controls", result.stdout)
        self.assertNotIn("## Styles", result.stdout)

    def test_inventory_filter(self):
        result = self.run_context("qs", "--match", "SERVICES")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("services/:", result.stdout)
        self.assertNotIn("settings/:", result.stdout)

    def test_invalid_arguments(self):
        for args in [("/tmp",), ("--limit", "0"), ("--match", "["), ("missing-directory",)]:
            with self.subTest(args=args):
                result = self.run_context(*args)
                self.assertEqual(result.returncode, 2)
                self.assertNotIn("Traceback", result.stderr)


class HookTests(unittest.TestCase):
    def test_check_selection(self):
        # Stub command execution: no checks or user configuration are changed.
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "bin").mkdir()
            (root / "tools").mkdir()
            commands = {
                "bin/git": 'case "$1" in rev-parse) echo "$TEST_ROOT";; diff) cat "$TEST_ROOT/staged";; esac',
                "bin/python3": 'echo "$1" >> "$TEST_ROOT/calls"',
                "bin/node": 'echo "$2" >> "$TEST_ROOT/calls"',
                "tools/check-hardware.sh": 'echo tools/check-hardware.sh >> "$TEST_ROOT/calls"',
            }
            for name, body in commands.items():
                file = root / name
                file.write_text("#!/bin/sh\n" + body + "\n")
                file.chmod(0o755)
            env = dict(os.environ, TEST_ROOT=directory, PATH=str(root / "bin") + ":" + os.environ["PATH"])
            qs = "dotfiles/quickshell/.config/quickshell/"
            cases = {
                qs + "settings/appearance/ShapeTab.qml": {"check-settings-index.py", "check-unused.py"},
                "tools/check-settings-index.py": {"check-settings-index.py"},
                "tools/check-unused.py": {"check-unused.py"},
                "dotfiles/hypr/.config/hypr/window-keys.lua": {"test-js.mjs"},
                "lib.sh": {"check-hardware.sh"},
                "tools/context.py": {"test-tools.py"},
                "README.md": set(),
                "tools/git-hooks/pre-commit": {"check-settings-index.py", "check-unused.py",
                                               "test-js.mjs", "check-hardware.sh", "test-tools.py"},
            }
            for staged, expected in cases.items():
                with self.subTest(staged=staged):
                    (root / "staged").write_text(staged + "\n")
                    (root / "calls").write_text("")
                    result = subprocess.run(["bash", str(ROOT / "tools/git-hooks/pre-commit")],
                                            env=env, capture_output=True, text=True)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    actual = {Path(p).name for p in (root / "calls").read_text().splitlines()}
                    self.assertEqual(actual, expected)


if __name__ == "__main__":
    unittest.main()
