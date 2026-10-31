#!/usr/bin/env python3
"""Parse shell, Python and Lua sources without running them or writing bytecode."""
import argparse
import ast
from pathlib import Path
import shlex
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent


def check(path):
    with path.open('rb') as stream:
        first = stream.readline(256).decode('utf-8', errors='replace').strip()
    interpreter = ''
    if first.startswith('#!'):
        words = shlex.split(first[2:])
        if words:
            interpreter = Path(words[0]).name
            if interpreter == 'env':
                interpreter = next((w for w in words[1:] if not w.startswith('-')), '')
    if path.suffix == '.py' or interpreter.startswith('python'):
        try:
            ast.parse(path.read_bytes(), filename=str(path))
        except (SyntaxError, ValueError) as e:
            print(f'{path}: {e}')
            return False
        return True
    if interpreter in ('sh', 'bash') or path.suffix == '.sh':
        command = [interpreter if interpreter in ('sh', 'bash') else 'bash', '-n']
    elif path.suffix == '.lua':
        command = [shutil.which('luac') or shutil.which('luac5.4') or 'luac', '-p']
    else:
        return True
    try:
        return subprocess.run([*command, str(path)]).returncode == 0
    except OSError as e:
        print(f'{path}: {e}')
        return False


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('paths', nargs='*', help='files to check; default: repository sources')
    args = parser.parse_args()
    if args.paths:
        paths = [Path(p) for p in args.paths]
    else:
        names = subprocess.check_output(
            ['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'], cwd=ROOT
        ).decode().split('\0')
        paths = sorted({ROOT / p for p in names if p and (ROOT / p).is_file()})
    return 0 if all([check(p) for p in paths]) else 1


if __name__ == '__main__':
    raise SystemExit(main())
