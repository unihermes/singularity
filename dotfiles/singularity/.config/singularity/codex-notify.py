#!/usr/bin/env python3
"""Codex's notify hook: completion notifications with the ChatGPT icon."""
import html
import json
import subprocess
import sys


def main():
    event = json.loads(sys.argv[1])
    if event.get("type") != "agent-turn-complete":
        return
    message = event.get("last-assistant-message") or "Finished working."
    subprocess.run([
        "notify-send", "--app-name=Codex", "--icon=chatgpt",
        "--", "Codex", html.escape(message[:4000]),
    ], check=True)


if __name__ == "__main__":
    main()
