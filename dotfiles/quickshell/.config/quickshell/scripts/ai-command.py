#!/usr/bin/env python3
"""Run a sidebar ! command and forward cancellation to its process group."""

import os
import signal
import subprocess
import sys


def main():
    # Block cancellation until the child exists so Stop cannot orphan it.
    signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGTERM})
    child = subprocess.Popen(["bash", "-lc", sys.argv[1]], start_new_session=True)

    def stop(_signum, _frame):
        try:
            os.killpg(child.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass

    signal.signal(signal.SIGTERM, stop)
    signal.pthread_sigmask(signal.SIG_UNBLOCK, {signal.SIGTERM})
    code = child.wait()
    return code if code >= 0 else 128 - code


if __name__ == "__main__":
    sys.exit(main())
