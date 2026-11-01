#!/usr/bin/env python3
"""Start the independent chat host once and forward sidebar commands."""
import fcntl
import os
from pathlib import Path
import subprocess
import sys
import time


def main():
    config = sys.argv[1]
    runtime = Path(os.environ['XDG_RUNTIME_DIR'])
    with (runtime / 'singularity-ai-host.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        probe = ['qs', 'ipc', '-p', config, 'show']
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
            subprocess.run(['qs', 'ipc', '-p', config, 'call', 'chat', 'open',
                            sys.argv[3], sys.argv[4]], check=True)
        elif len(sys.argv) > 2 and sys.argv[2] == 'toggle':
            subprocess.run(['qs', 'ipc', '-p', config, 'call', 'chat', 'toggle',
                            sys.argv[3] if len(sys.argv) > 3 else ''], check=True)


if __name__ == '__main__':
    main()
