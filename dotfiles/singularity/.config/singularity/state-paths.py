#!/usr/bin/env python3
"""Migrate legacy Singularity directories before launching readers/writers.

Destination files win; sources survive in a sibling backup. Legacy paths become
compatibility links for generated app configs and provider cwd identities.
"""
import fcntl
import os
from pathlib import Path
import shutil
import tempfile
import uuid


def copy_missing(source, target):
    if source.is_symlink():
        try:
            target.symlink_to(os.readlink(source))
        except FileExistsError:
            pass
    elif source.is_dir():
        target.mkdir(mode=0o700, parents=True, exist_ok=True)
        for child in source.iterdir():
            dest = target / child.name
            # An existing file or link wins even against a legacy directory.
            if not os.path.lexists(dest) or (child.is_dir() and not child.is_symlink()
                                            and dest.is_dir() and not dest.is_symlink()):
                copy_missing(child, dest)
    elif source.is_file():
        fd, tmp = tempfile.mkstemp(prefix='.migrate-', dir=target.parent)
        os.close(fd)
        try:
            shutil.copy2(source, tmp)
            try:
                os.link(tmp, target)
            except FileExistsError:
                pass
        finally:
            os.unlink(tmp)


def migrate(legacy, target):
    source = legacy.resolve()
    target = target.resolve()
    if source == target:
        return
    if source in target.parents or target in source.parents:
        raise ValueError('Singularity XDG directory must not contain its legacy directory or be inside it')
    target.mkdir(mode=0o700, parents=True, exist_ok=True)
    if source.exists():
        copy_missing(source, target)
    legacy.parent.mkdir(parents=True, exist_ok=True)
    if os.path.lexists(legacy):
        # Keep the original tree (or old compatibility link) for recovery.
        legacy.rename(legacy.with_name(legacy.name + '.before-xdg-' + uuid.uuid4().hex))
    legacy.symlink_to(target, target_is_directory=True)


def main():
    home = Path.home()
    state = home / '.local/state'
    state.mkdir(parents=True, exist_ok=True)
    # The shell and independent AI host may start together.
    with (state / '.singularity-paths.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        for variable, fallback in [('XDG_STATE_HOME', state), ('XDG_CACHE_HOME', home / '.cache')]:
            base = Path(os.environ.get(variable) or fallback)
            if not base.is_absolute():
                raise ValueError(variable + ' must be an absolute path')
            migrate(Path(fallback) / 'singularity', base / 'singularity')


if __name__ == '__main__':
    main()
