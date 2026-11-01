#!/usr/bin/env python3
"""Start the independent chat host once and forward sidebar commands."""
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import time


def upgrade(config, runtime, probe):
    """Stop an obsolete, idle, hidden host so startup can load the current code."""
    try:
        status = json.loads((runtime / 'singularity-ai-status.json').read_text())
    except (OSError, ValueError):
        return False
    if status.get('notificationVersion') == 1 or status.get('busy') is not False or status.get('shown') is not False:
        return False
    subprocess.run(['qs', 'kill', '-p', config], check=True)
    for _ in range(100):
        if subprocess.run(probe, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode:
            return True
        time.sleep(0.05)
    raise SystemExit('Chat host did not stop for the update')


def main():
    config = sys.argv[1]
    runtime = Path(os.environ['XDG_RUNTIME_DIR'])
    with (runtime / 'singularity-ai-host.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        probe = ['qs', 'ipc', '-p', config, 'show']
        if len(sys.argv) > 2 and sys.argv[2] == 'upgrade' and not upgrade(config, runtime, probe):
            return
        if subprocess.run(probe, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode:
            env = dict(os.environ, SINGULARITY_AI_HOST='1')
            with (runtime / 'singularity-ai-host.log').open('a') as log:
                subprocess.Popen(['qs', '-n', '-p', config], env=env, start_new_session=True,
                                 stdin=subprocess.DEVNULL, stdout=log, stderr=log)
            for _ in range(100):
                if subprocess.run(probe, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
                    break
                time.sleep(0.05)
            else:
                raise SystemExit('Chat host failed to start; see ' + str(runtime / 'singularity-ai-host.log'))
        if len(sys.argv) > 2 and sys.argv[2] == 'close':
            subprocess.run(['qs', 'ipc', '-p', config, 'call', 'chat', 'close'], check=True)
        elif len(sys.argv) > 4 and sys.argv[2] == 'open':
            methods = subprocess.run(probe, capture_output=True, text=True, check=True).stdout
            if 'function open(' in methods:
                subprocess.run(['qs', 'ipc', '-p', config, 'call', 'chat', 'open',
                                sys.argv[3], sys.argv[4]], check=True)
            else:
                # Older hosts can stay alive until their active conversation finishes.
                try:
                    status = json.loads((runtime / 'singularity-ai-status.json').read_text())
                except (OSError, ValueError):
                    status = {}
                if not status.get('shown'):
                    subprocess.run(['qs', 'ipc', '-p', config, 'call', 'chat', 'toggle',
                                    status.get('screen', '')], check=True)
        elif len(sys.argv) > 2 and sys.argv[2] == 'toggle':
            subprocess.run(['qs', 'ipc', '-p', config, 'call', 'chat', 'toggle',
                            sys.argv[3] if len(sys.argv) > 3 else ''], check=True)


if __name__ == '__main__':
    main()
