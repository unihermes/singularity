#!/usr/bin/env python3
"""Drive the running desktop to check where clicks leave the sidebar and the keyboard.

Live only, not in the pre-commit checks: it opens small test terminals on DP-2's
workspace, moves and clicks the real pointer (only ever on those windows or the
sidebar), and puts the pointer, focus, scratchpad and pin back afterwards.
A terminal's focus reporting is the witness: it sees the keyboard itself, while
Hyprland's active window stays put when a layer surface holds the keys.

    python3 tools/test-sidebar-focus.py [--rounds N] [--only SUBSTRING]
"""
import argparse
import json
import os
from pathlib import Path
import socket
import struct
import subprocess
import sys
import tempfile
import time

CONFIG = str(Path.home() / '.config/quickshell/AiHost.qml')
RUNTIME = Path(os.environ['XDG_RUNTIME_DIR'])
STATUS = RUNTIME / 'singularity-ai-status.json'
MAIN, OTHER = 'DP-2', 'DP-3'
LEFT, RIGHT = 0x110, 0x111

PROBE = r'''
import os, sys, termios, tty
log = sys.argv[1]
tty.setraw(0)
sys.stdout.write("\x1b[?1004h"); sys.stdout.flush()
while True:
    data = os.read(0, 64)
    if not data: break
    state = None
    for i, c in enumerate(data[:-2]):
        if data[i:i+3] == b"\x1b[I": state = "in"
        if data[i:i+3] == b"\x1b[O": state = "out"
    if state:
        with open(log + ".tmp", "w") as f: f.write(state)
        os.replace(log + ".tmp", log)
'''


class Pointer:
    """zwlr_virtual_pointer_v1 over a bare Wayland socket."""

    def __init__(self, width, height):
        self.width, self.height = width, height
        self.sock = socket.socket(socket.AF_UNIX)
        self.sock.connect(str(RUNTIME / os.environ.get('WAYLAND_DISPLAY', 'wayland-1')))
        self.send(1, 1, struct.pack('<I', 2))  # wl_display.get_registry -> 2
        self.send(1, 0, struct.pack('<I', 3))  # wl_display.sync -> 3
        name = version = None
        buf = b''
        done = False
        while not done:
            buf += self.sock.recv(65536)
            while len(buf) >= 8:
                obj, word = struct.unpack('<II', buf[:8])
                size = word >> 16
                if len(buf) < size:
                    break
                body, buf = buf[8:size], buf[size:]
                if obj == 3:
                    done = True
                elif obj == 2 and (word & 0xffff) == 0:
                    n, slen = struct.unpack('<II', body[:8])
                    iface = body[8:8 + slen - 1].decode()
                    if iface == 'zwlr_virtual_pointer_manager_v1':
                        name, version = n, struct.unpack('<I', body[8 + (slen + 3) // 4 * 4:][:4])[0]
        if name is None:
            raise SystemExit('The compositor has no virtual pointer')
        iface = b'zwlr_virtual_pointer_manager_v1\0'
        pad = iface + b'\0' * (-len(iface) % 4)
        self.send(2, 0, struct.pack('<II', name, len(iface)) + pad + struct.pack('<II', version, 4))
        self.send(4, 0, struct.pack('<II', 0, 5))  # create_virtual_pointer(seat=null) -> 5

    def send(self, obj, op, body=b''):
        self.sock.sendall(struct.pack('<II', obj, (8 + len(body)) << 16 | op) + body)

    @staticmethod
    def now():
        return int(time.monotonic() * 1000) & 0xffffffff

    def move(self, x, y):
        self.send(5, 1, struct.pack('<IIIII', self.now(), int(x), int(y), self.width, self.height))
        self.send(5, 4)

    def click(self, x, y, button=LEFT):
        self.move(x, y)
        time.sleep(0.08)
        self.send(5, 2, struct.pack('<III', self.now(), button, 1))
        self.send(5, 4)
        time.sleep(0.04)
        self.send(5, 2, struct.pack('<III', self.now(), button, 0))
        self.send(5, 4)


def run(*cmd):
    return subprocess.run(cmd, capture_output=True, text=True).stdout


def hypr(what):
    return json.loads(run('hyprctl', '-j', what))


def lua(code):
    out = run('hyprctl', 'eval', code)
    if out.strip() != 'ok':
        raise SystemExit(f'hyprctl eval failed: {code}\n{out}')


def status():
    try:
        return json.loads(STATUS.read_text())
    except (OSError, ValueError):
        return {}


def host(*args):
    subprocess.run(['qs', 'ipc', '-p', CONFIG, 'call', 'chat', *args], check=True, capture_output=True)


def wait(test, timeout=2.0):
    end = time.time() + timeout
    while time.time() < end:
        if test():
            return True
        time.sleep(0.03)
    return test()


def monitor(name):
    return next(m for m in hypr('monitors') if m['name'] == name)


def scratch_up():
    return monitor(MAIN)['specialWorkspace']['name'] == 'special:scratchpad'


class Desk:
    def __init__(self, directory):
        self.dir = Path(directory)
        self.script = self.dir / 'probe.py'
        self.script.write_text(PROBE)
        self.saved = {
            'scratch': scratch_up(),
            'window': hypr('activewindow').get('address'),
            'monitor': next(m['name'] for m in hypr('monitors') if m['focused']),
            'cursor': hypr('cursorpos'),
            'shown': status().get('shown'),
            'screen': status().get('screen'),
        }
        boxes = hypr('monitors')
        width = max(m['x'] + round(m['width'] / m['scale']) for m in boxes)
        height = max(m['y'] + round(m['height'] / m['scale']) for m in boxes)
        self.pointer = Pointer(width, height)
        self.workspace = monitor(MAIN)['activeWorkspace']['id']
        self.probes = {}
        self.spawn('S', 40, 100)
        self.spawn('A', 40, 390)
        self.spawn('B', 40, 680)
        self.spawn('T', 40, 970)
        if not wait(lambda: len(self.windows()) == 4 and all(c['mapped'] for c in self.windows().values()), 5):
            raise SystemExit('The test terminals did not open')
        for name in 'ST':
            address = self.windows()[name]['address']
            lua('hl.dispatch(hl.dsp.window.move({ workspace = "special:scratchpad", '
                f'window = "address:{address}", follow = false }}))')

    def spawn(self, name, x, y, activate=False):
        cls = f'singularity.focus-test-{name}'
        workspace = str(self.workspace) + ("" if activate else " silent")
        lua(f'hl.window_rule({{ name = "focus-test-{name}", tag = "-monocle", match = {{ class = "^({cls})$" }}, '
            f'workspace = "{workspace}", float = true, size = "400 280", move = "{x} {y}" }})')
        log = self.dir / name
        self.probes[name] = log
        subprocess.Popen(['alacritty', '--class', cls, '-e', 'python3', '-I', str(self.script), str(log)],
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)

    def windows(self):
        return {c['class'][-1]: c for c in hypr('clients') if c['class'].startswith('singularity.focus-test-')}

    def holder(self):
        """The test terminal with the keyboard, or None."""
        held = [n for n, log in self.probes.items() if log.exists() and log.read_text() == 'in']
        return held[0] if len(held) == 1 else (None if not held else ','.join(held))

    def centre(self, name):
        c = self.windows()[name]
        if not c['mapped'] or c['monitor'] != monitor(MAIN)['id']:
            raise SystemExit(f'Test terminal {name} is not on {MAIN}')
        return c['at'][0] + c['size'][0] // 2, c['at'][1] + c['size'][1] // 2

    def click_window(self, name, button=LEFT):
        self.pointer.click(*self.centre(name), button)

    def sidebar_box(self):
        for levels in hypr('layers').values():
            for layer in levels['levels'].values():
                for s in layer:
                    if s['namespace'] == 'singularity-sidebar':
                        return s
        return None

    def click_sidebar(self):
        box = self.sidebar_box()
        self.pointer.click(box['x'] + box['w'] // 2, box['y'] + box['h'] // 2)

    def set_scratch(self, up):
        if scratch_up() != up:
            if not monitor(MAIN)['focused']:
                lua(f'hl.dispatch(hl.dsp.focus({{ monitor = "{MAIN}" }}))')
            lua('hl.dispatch(hl.dsp.workspace.toggle_special("scratchpad"))')
            wait(lambda: scratch_up() == up)

    def close_sidebar(self):
        host('pin', 'false')
        host('close')
        wait(lambda: not status().get('shown') and self.sidebar_box() is None)

    def open_sidebar(self, screen):
        host('toggle', screen)
        return wait(lambda: status().get('shown') and status().get('screen') == screen
                    and self.sidebar_box() is not None)

    def restore(self):
        self.close_sidebar()
        self.set_scratch(self.saved['scratch'])
        for c in self.windows().values():
            lua(f'hl.dispatch(hl.dsp.window.close({{ window = "address:{c["address"]}" }}))')
        wait(lambda: not self.windows(), 3)
        lua(f'hl.dispatch(hl.dsp.focus({{ monitor = "{self.saved["monitor"]}" }}))')
        if self.saved['window']:
            lua(f'hl.dispatch(hl.dsp.focus({{ window = "address:{self.saved["window"]}" }}))')
        self.pointer.move(self.saved['cursor']['x'], self.saved['cursor']['y'])
        if self.saved['shown']:
            host('toggle', self.saved['screen'])


# name, scratchpad up, pinned (before opening, or 'after'), sidebar's screen,
# window focused first, actions, stays open, keyboard after. Hyprland doesn't
# focus through a shown special workspace, so a click behind it lands on the scratchpad.
CASES = [
    ('closes: click the focused window', False, False, MAIN, 'A', 'A', False, 'A'),
    ('closes: click another window', False, False, MAIN, 'A', 'B', False, 'B'),
    ('closes: right-click another window', False, False, MAIN, 'A', 'B:right', False, 'B'),
    ('closes: click the scratchpad', True, False, MAIN, 'S', 'S', False, 'S'),
    ('closes: click another scratchpad window', True, False, MAIN, 'S', 'T', False, 'T'),
    ('closes: click behind the scratchpad', True, False, MAIN, 'S', 'A', False, 'S'),
    ("closes: the press on the way to a toggle doesn't reopen it", False, False, MAIN, 'A', 'A,toggle', False, 'A'),
    ('closes: click the focused window, sidebar on the other screen', False, False, OTHER, 'A', 'A', False, 'A'),
    ('closes: click another window, sidebar on the other screen', False, False, OTHER, 'A', 'B', False, 'B'),
    ('closes: click the scratchpad, sidebar on the other screen', True, False, OTHER, 'S', 'S', False, 'S'),
    ('pinned: opens with the keyboard', False, True, MAIN, 'A', '', True, None),
    ('pinned: pinning keeps the keyboard', False, 'after', MAIN, 'A', '', True, None),
    ('pinned: click the focused window', False, True, MAIN, 'A', 'A', True, 'A'),
    ('pinned: click another window', False, True, MAIN, 'A', 'B', True, 'B'),
    ('pinned: click the scratchpad', True, True, MAIN, 'S', 'S', True, 'S'),
    ('pinned: click another scratchpad window', True, True, MAIN, 'S', 'T', True, 'T'),
    ('pinned: click behind the scratchpad', True, True, MAIN, 'S', 'A', True, 'S'),
    ('pinned: hovering leaves the keyboard alone', False, True, MAIN, 'A', 'A,hover', True, 'A'),
    ('pinned: hovering over the scratchpad too', True, True, MAIN, 'S', 'S,hover', True, 'S'),
    ('pinned: back inside takes the keyboard', False, True, MAIN, 'A', 'A,inside', True, None),
    ('pinned: other screen, click then back inside', False, True, OTHER, 'A', 'B,inside', True, None),
    ('stays: click inside', False, False, MAIN, 'A', 'inside', True, None),
    ('stays: click inside with the scratchpad up', True, False, MAIN, 'S', 'inside', True, None),
    ('stays: the scratchpad comes up by key', False, False, MAIN, 'A', 'scratch', True, 'S'),
    ('pinned: the scratchpad comes up by key', False, True, MAIN, 'A', 'scratch', True, 'S'),
    ('stays: another window activates by key', False, False, MAIN, 'A', 'focus:B', True, 'B'),
    ('pinned: another window activates by key', False, True, MAIN, 'A', 'focus:B', True, 'B'),
    ('stays: a new window opens', False, False, MAIN, 'A', 'spawn', True, 'N'),
    ('pinned: a new window opens', False, True, MAIN, 'A', 'spawn', True, 'N'),
]


def steady(desk, want, shown):
    """The expected result arrives and is still true half a second later."""
    good = lambda: desk.holder() == want and bool(status().get('shown')) == shown
    return wait(good) and (time.sleep(0.5) or good())


def run_case(desk, case):
    name, scratch, pinned, screen, first, action, stays, keys = case
    desk.close_sidebar()
    if 'N' in desk.windows():
        lua(f'hl.dispatch(hl.dsp.window.close({{ window = "address:{desk.windows()["N"]["address"]}" }}))')
        wait(lambda: 'N' not in desk.windows())
        desk.probes.pop('N', None)
    if 'scratch' in action.split(','):
        desk.set_scratch(True)
        desk.click_window('S')
        if not wait(lambda: desk.holder() == 'S'):
            return 'setup: scratchpad probe never took the keyboard'
    desk.set_scratch(scratch)
    desk.click_window(first)
    if not wait(lambda: desk.holder() == first):
        return f'setup: {first} never took the keyboard (holder {desk.holder()})'
    if pinned is True:
        host('pin', 'true')
    if not desk.open_sidebar(screen):
        return 'setup: the sidebar did not open'
    if pinned == 'after':
        time.sleep(0.25)
        host('pin', 'true')
    if not wait(lambda: desk.holder() is None):
        return f'opening left the keyboard with {desk.holder()}'
    time.sleep(0.25)
    for step in filter(None, action.split(',')):
        if step == 'inside':
            desk.click_sidebar()
        elif step == 'hover':
            box = desk.sidebar_box()
            desk.pointer.move(box['x'] + box['w'] // 2, box['y'] + box['h'] // 2)
        elif step == 'scratch':
            desk.set_scratch(True)
        elif step.startswith('focus:'):
            address = desk.windows()[step.split(':')[1]]['address']
            lua(f'hl.dispatch(hl.dsp.focus({{ window = "address:{address}" }}))')
        elif step == 'spawn':
            desk.spawn('N', 480, 390, activate=True)
            wait(lambda: 'N' in desk.windows())
        elif step == 'toggle':
            subprocess.run(['qs', 'ipc', 'call', 'claude', 'toggle'], check=True, capture_output=True)
        else:
            target, _, button = step.partition(':')
            desk.click_window(target, RIGHT if button == 'right' else LEFT)
        time.sleep(0.15)
    if not steady(desk, keys, stays):
        return (f'expected shown={stays} keyboard={keys}, '
                f'got shown={status().get("shown")} keyboard={desk.holder()}')
    return None


def shell_toggle(desk):
    """SUPER+I's path, through the shell rather than the host."""
    desk.close_sidebar()
    desk.set_scratch(False)
    desk.click_window('A')
    wait(lambda: desk.holder() == 'A')
    subprocess.run(['qs', 'ipc', 'call', 'claude', 'toggle'], check=True, capture_output=True)
    if not wait(lambda: status().get('shown') and desk.sidebar_box()):
        return 'the shell did not open the sidebar'
    if not wait(lambda: desk.holder() is None):
        return f'opening left the keyboard with {desk.holder()}'
    subprocess.run(['qs', 'ipc', 'call', 'claude', 'toggle'], check=True, capture_output=True)
    if not wait(lambda: not status().get('shown') and desk.sidebar_box() is None):
        return 'the shell did not close the sidebar'
    if not wait(lambda: desk.holder() == 'A'):
        return f'closing left the keyboard with {desk.holder()}'
    return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--rounds', type=int, default=3)
    parser.add_argument('--only', default='')
    args = parser.parse_args()
    cases = [c for c in CASES if args.only in c[0]]
    failures = 0
    with tempfile.TemporaryDirectory() as directory:
        desk = Desk(directory)
        try:
            time.sleep(0.5)
            for n in range(args.rounds):
                for case in cases:
                    problem = run_case(desk, case)
                    failures += bool(problem)
                    print(f'{"FAIL" if problem else "ok  "} [{n + 1}] {case[0]}' + (f': {problem}' if problem else ''),
                          flush=True)
                if args.only in 'shell toggle':
                    problem = shell_toggle(desk)
                    failures += bool(problem)
                    print(f'{"FAIL" if problem else "ok  "} [{n + 1}] shell toggle' + (f': {problem}' if problem else ''),
                          flush=True)
        finally:
            desk.restore()
    print(f'{failures} failed')
    sys.exit(1 if failures else 0)


if __name__ == '__main__':
    main()
