#!/usr/bin/env python3
"""Reject user home paths in shipped files; report filenames, never matched data."""
import re
import sys
from pathlib import Path

USER_PATH = re.compile(rb"/(?:Users|home)/[^/\x00\s]+/")


def check_bundle(bundle: Path) -> list[Path]:
    return [path.relative_to(bundle) for path in bundle.rglob('*')
            if path.is_file() and not path.is_symlink()
            and USER_PATH.search(path.read_bytes())]


if __name__ == '__main__':
    bundle = Path(sys.argv[1])
    if not bundle.is_dir():
        sys.exit('Expected an app bundle directory.')
    matches = check_bundle(bundle)
    for path in matches:
        print(f'User-home path detected in shipped file: {path}', file=sys.stderr)
    sys.exit(bool(matches))
