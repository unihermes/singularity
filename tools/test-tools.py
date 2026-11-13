#!/usr/bin/env python3
"""Regression checks for compact discovery and pre-commit check selection."""
import os
import importlib.util
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

    def test_largest_files(self):
        result = self.run_context("qs/services", "--largest", "--match", r"\.qml:", "--limit", "3")
        self.assertEqual(result.returncode, 0, result.stderr)
        rows = result.stdout.splitlines()[1:4]
        sizes = [int(row.rsplit(": ", 1)[1].split()[0]) for row in rows]
        self.assertEqual(len(sizes), 3)
        self.assertEqual(sizes, sorted(sizes, reverse=True))
        self.assertTrue(all(".qml:" in row for row in rows))

    def test_invalid_arguments(self):
        for args in [("/tmp",), ("--limit", "0"), ("--match", "["), ("missing-directory",),
                     ("missing-directory", "--largest")]:
            with self.subTest(args=args):
                result = self.run_context(*args)
                self.assertEqual(result.returncode, 2)
                self.assertNotIn("Traceback", result.stderr)


class UnusedTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location('check_unused', ROOT / 'tools/check-unused.py')
        cls.checker = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.checker)

    def test_duplicate_declarations_are_not_reads(self):
        body = 'Item {\n    function disarmNow() {}\n    property bool obsolete: false\n    signal forgotten()\n}'
        found = self.checker.find_unused({'shell.qml': 'A {}\nB {}', 'A.qml': body, 'B.qml': body})
        self.assertEqual({(f, n) for f, n, _ in found},
                         {(f, n) for f in ('A.qml', 'B.qml') for n in ('disarmNow', 'obsolete', 'forgotten')})

    def test_calls_bindings_handlers_and_inheritance_count(self):
        sources = {
            'shell.qml': 'Child {}',
            'Base.qml': 'Item {\n    function helper() {}\n    property bool ready: true\n    signal changed()\n}',
            'Child.qml': 'Base {\n    function onCompleted() { helper() }\n    visible: ready\n    onChanged: {}\n}',
        }
        self.assertEqual(self.checker.find_unused(sources), [])

    def test_external_entry_points_keep_their_allowance(self):
        self.assertEqual(self.checker.find_unused({'shell.qml': 'function saveDefault() {}'}), [])


class SyntaxTests(unittest.TestCase):
    def test_extensionless_helpers_and_python(self):
        with tempfile.TemporaryDirectory() as directory:
            for name, source in [('helper', '#!/bin/sh\nif then\n'),
                                 ('python-helper', '#!/usr/bin/env python3\ndef broken(\n'),
                                 ('module.py', 'def broken(\n')]:
                with self.subTest(name=name):
                    file = Path(directory) / name
                    file.write_text(source)
                    result = subprocess.run([sys.executable, str(ROOT / 'tools/check-syntax.py'), str(file)],
                                            capture_output=True, text=True)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(str(file), result.stdout + result.stderr)
                    file.write_text(source.splitlines()[0] + '\n' if source.startswith('#!') else 'x = 1\n')
                    subprocess.run([sys.executable, str(ROOT / 'tools/check-syntax.py'), str(file)], check=True)


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
                "tools/check-settings-index.py": {"check-settings-index.py", "check-syntax.py"},
                "tools/check-unused.py": {"check-unused.py", "test-tools.py", "check-syntax.py"},
                "dotfiles/hypr/.config/hypr/window-keys.lua": {"test-js.mjs", "check-syntax.py"},
                "scripts/lib.sh": {"check-hardware.sh", "check-syntax.py"},
                "scripts/hardware.sh": {"check-hardware.sh", "test-platform.py", "check-syntax.py"},
                "tools/context.py": {"test-tools.py", "check-syntax.py"},
                "tools/check-syntax.py": {"test-tools.py", "check-syntax.py"},
                "system/usr/local/lib/singularity/singularity-charge": {"check-syntax.py"},
                qs + "services/Ai.qml": {"check-unused.py", "test-processes.mjs", "test-ai-host.py", "test-notification-routing.mjs"},
                qs + "services/Files.qml": {"check-unused.py", "test-js.mjs", "test-processes.mjs"},
                qs + "services/Apps.qml": {"check-unused.py", "test-js.mjs"},
                qs + "AiHost.qml": {"check-unused.py", "test-processes.mjs", "test-ai-host.py", "test-notification-routing.mjs"},
                qs + "services/SystemStats.qml": {"check-unused.py", "test-js.mjs"},
                qs + "services/Settings.qml": {"check-unused.py", "test-settings.mjs"},
                qs + "services/SettingsValues.js": {"check-unused.py", "test-js.mjs", "test-settings.mjs"},
                qs + "sidebar/AiSidebar.qml": {"check-unused.py", "test-processes.mjs"},
                qs + "services/AtomicFileWrite.qml": {"check-unused.py", "test-processes.mjs"},
                qs + "services/ClaudeSession.qml": {"check-unused.py", "test-processes.mjs"},
                qs + "services/CodexSession.qml": {"check-unused.py", "test-processes.mjs"},
                "tools/qml-harness.mjs": {"test-settings.mjs", "test-processes.mjs"},
                qs + "scripts/ollama-agent.py": {"test-ollama-agent.py", "check-syntax.py"},
                "tools/test-ollama-agent.py": {"test-ollama-agent.py", "check-syntax.py"},
                "tools/ollama-status.py": {"test-ollama-status.py", "check-syntax.py"},
                "tools/test-ollama-status.py": {"test-ollama-status.py", "check-syntax.py"},
                "README.md": set(),
                "tools/git-hooks/pre-commit": {"check-settings-index.py", "check-unused.py",
                                               "test-js.mjs", "test-settings.mjs", "test-processes.mjs", "test-ai-host.py",
                                               "test-notification-routing.mjs", "test-state-paths.py", "check-hardware.sh",
                                               "test-tools.py", "test-platform.py", "test-ollama-agent.py",
                                               "test-ollama-status.py", "check-syntax.py"},
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

            (root / "staged").write_text(qs + "services/Settings.qml\n")
            (root / "calls").write_text("")
            (root / "bin/python3").write_text('#!/bin/sh\necho "failure detail" >&2\nexit 7\n')
            result = subprocess.run(["bash", str(ROOT / "tools/git-hooks/pre-commit")],
                                    env=env, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("failure detail", result.stdout)
            self.assertIn("FAIL python3 tools/check-unused.py", result.stderr)
            self.assertEqual((root / "calls").read_text(), "")


if __name__ == "__main__":
    unittest.main()
