#!/usr/bin/env python3
"""Profile selection and hardware gates, without changing the host."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent


class PlatformTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.state = Path(self.temp.name) / 'state'
        self.env = dict(os.environ, XDG_STATE_HOME=str(self.state))

    def shell(self, body, check=True):
        return subprocess.run(['bash', '-eu', '-c', 'source ./hardware.sh\n' + body],
                              cwd=ROOT, env=self.env, text=True, capture_output=True, check=check)

    def test_selection_persists_and_auto_redetects(self):
        result = self.shell('''
            detect_machine() { echo laptop; }
            select_machine; echo "$machine"
            select_machine desktop; save_machine
            select_machine; echo "$machine"
            select_machine auto; echo "$machine"
        ''')
        self.assertEqual(result.stdout.splitlines(), ['laptop', 'desktop', 'laptop'])
        self.assertEqual((self.state / 'singularity/machine').read_text(), 'desktop\n')

    def test_first_interactive_install_offers_a_choice(self):
        for answer, expected in [(b"\n", 'laptop'), (b"desktop\n", 'desktop'),
                                 (b"wrong\nlaptop\n", 'laptop')]:
            master, slave = os.openpty()
            try:
                process = subprocess.Popen(['bash', '-eu', '-c',
                    'source ./hardware.sh; detect_machine() { echo laptop; }; '
                    'select_machine "" true; echo "$machine"'], cwd=ROOT,
                    env=self.env, stdin=slave, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                os.write(master, answer)
                stdout, stderr = process.communicate(timeout=5)
                self.assertEqual(process.returncode, 0, stderr)
                self.assertEqual(stdout.decode().strip(), expected)
                self.assertIn(b'Machine profile', stderr)
            finally:
                os.close(master)
                os.close(slave)

    def test_invalid_profile_fails_closed(self):
        self.assertEqual(self.shell('select_machine toaster', check=False).returncode, 2)
        path = self.state / 'singularity/machine'
        path.parent.mkdir(parents=True)
        path.write_text('echo unsafe\n')
        self.assertEqual(self.shell('machine_type', check=False).returncode, 2)
        self.assertEqual(self.shell('select_machine laptop; echo "$machine"').stdout, 'laptop\n')

    def test_policy_and_hardware_matrix(self):
        for kind in ('laptop', 'desktop'):
            for caps in ('', 'lid battery touchpad backlight intel-gpu', 'nvidia ahci wifi bluetooth'):
                with self.subTest(kind=kind, caps=caps):
                    result = self.shell('''
                        has() { [[ " $CAPS " == *" $1 "* ]]; }
                        machine=$KIND; save_machine
                        platform_json
                        machine_lists "$machine"
                    '''.replace('$CAPS', caps).replace('$KIND', kind))
                    lines = result.stdout.splitlines()
                    inventory = json.loads(lines[0])
                    self.assertEqual(inventory['type'], kind)
                    self.assertEqual(inventory['features']['lid'], kind == 'laptop' and 'lid' in caps.split())
                    self.assertEqual(inventory['features']['cooling'], kind == 'desktop')
                    self.assertEqual(inventory['features']['hibernate-setup'], kind == 'laptop')
                    self.assertEqual(inventory['features']['early-nvidia'], kind == 'desktop' and 'nvidia' in caps.split())
                    self.assertEqual('packages/desktop.txt' in lines, kind == 'desktop')
                    self.assertEqual('packages/hardware/nvidia.txt' in lines, 'nvidia' in caps.split())
                    self.assertEqual('packages/hardware/backlight.txt' in lines, 'backlight' in caps.split())

    def test_preview_has_no_side_effects(self):
        for kind in ('laptop', 'desktop', 'auto'):
            result = subprocess.run(['bash', 'install.sh', '--plan', kind], cwd=ROOT,
                                    env=self.env, text=True, capture_output=True, check=True)
            self.assertIn('Profile:', result.stdout)
            self.assertIn('Idle defaults:', result.stdout)
            self.assertFalse(self.state.exists())

    def test_compositor_gates_defaults_and_overrides(self):
        script = '''
            local supported = arg[1] == 'yes'
            package.loaded.shared = {
                has = function() return supported end,
                allows = function() return supported end,
            }
            local configs, binds, gestures = {}, {}, 0
            hl = {
                config = function(c) table.insert(configs, c) end,
                bind = function(k) table.insert(binds, k) end,
                gesture = function() gestures = gestures + 1 end,
            }
            dofile('dotfiles/hypr/.config/hypr/platform.lua')
            hl.config({input = {kb_layout = 'us', touchpad = {tap_to_click = true}}, gestures = {workspace_swipe_invert = false}})
            hl.config({input = {touchpad = {natural_scroll = true}}})
            hl.bind('switch:on:Lid Switch')
            hl.bind('XF86MonBrightnessUp')
            hl.bind('SUPER + E')
            hl.gesture({fingers = 3})
            assert(configs[1].input.kb_layout == 'us')
            assert((configs[1].input.touchpad ~= nil) == supported)
            assert((configs[2].input.touchpad ~= nil) == supported)
            assert((configs[1].gestures ~= nil) == supported)
            assert(#binds == (supported and 3 or 1))
            assert(gestures == (supported and 1 or 0))
        '''
        path = Path(self.temp.name) / 'gates.lua'
        path.write_text(script)
        for supported in ('yes', 'no'):
            subprocess.run(['lua', str(path), supported], cwd=ROOT, check=True)


if __name__ == '__main__':
    unittest.main()
