#!/usr/bin/env python3
"""Live scratchpad regression: click a bar module open and closed.

Supply the module centre in global logical coordinates, with no flyout open.
Requires an existing scratchpad terminal. Moves the real pointer, preserving
its position and the original focused monitor/window and scratchpad visibility.
Example: python3 tools/test-scratchpad-focus.py 2327 16 --monitor DP-2
"""
import argparse
import importlib.util
import json
from pathlib import Path
import time

spec = importlib.util.spec_from_file_location('sidebar_focus', Path(__file__).with_name('test-sidebar-focus.py'))
helpers = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helpers)


def shown():
    return next((m['name'] for m in helpers.hypr('monitors')
                 if m['specialWorkspace']['name'] == 'special:scratchpad'), None)


def flyout_up():
    return 'singularity-flyout' in helpers.run('hyprctl', 'layers')


def focus_monitor(name):
    helpers.lua('hl.dispatch(hl.dsp.focus({monitor=' + json.dumps(name) + '}))')


def toggle():
    # The existing terminal means this never launches a process.
    helpers.lua('toggleScratchpad("alacritty")')
    time.sleep(.3)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('x', type=int)
    parser.add_argument('y', type=int)
    parser.add_argument('--monitor', required=True)
    parser.add_argument('--rounds', type=int, default=3)
    args = parser.parse_args()
    assert not flyout_up(), 'Close open flyouts before running this test'
    assert any(w['class'] == 'singularity.scratch' for w in helpers.hypr('clients')), 'Open a scratchpad terminal first'
    monitors = helpers.hypr('monitors')
    original_monitor = next(m['name'] for m in monitors if m['focused'])
    original_window = helpers.hypr('activewindow').get('address')
    original_scratch = shown()
    original_cursor = helpers.hypr('cursorpos')
    pointer = helpers.Pointer(
        round(max(m['x'] + m['width'] / m['scale'] for m in monitors)),
        round(max(m['y'] + m['height'] / m['scale'] for m in monitors)))
    try:
        if original_scratch:
            focus_monitor(original_scratch)
            toggle()
        pointer.move(args.x, args.y)
        focus_monitor(args.monitor)
        for i in range(args.rounds):
            toggle()
            assert shown() == args.monitor, 'Explicit toggle failed to show scratchpad'
            assert helpers.hypr('activewindow').get('class') == 'singularity.scratch', 'Shown scratchpad did not receive focus'
            toggle()
            assert not shown(), 'Scratchpad did not hide'
            pointer.click(args.x, args.y)
            time.sleep(.4)
            assert flyout_up(), 'Coordinates did not open a module flyout'
            assert not shown(), 'Opening a module revealed scratchpad'
            pointer.click(args.x, args.y)
            time.sleep(.4)
            assert not flyout_up(), 'Reclick did not close the flyout'
            assert not shown(), 'Closing a module revealed scratchpad'
            print(f'Round {i + 1}: hidden after module open and reclick close')
    finally:
        if flyout_up():
            pointer.click(args.x, args.y)
            time.sleep(.4)
        if shown():
            focus_monitor(shown())
            toggle()
        if original_scratch:
            focus_monitor(original_scratch)
            toggle()
        focus_monitor(original_monitor)
        if original_window:
            helpers.lua('hl.dispatch(hl.dsp.focus({window=' + json.dumps('address:' + original_window) + '}))')
        pointer.move(original_cursor['x'], original_cursor['y'])
        pointer.sock.close()


if __name__ == '__main__':
    main()
