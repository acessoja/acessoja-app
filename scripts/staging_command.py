"""Explicit private env-file entry point, also usable from PowerShell."""
import argparse
import os
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--env-file', required=True)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    path = Path(args.env_file)
    if not path.is_absolute() or not path.is_file() or path.is_symlink():
        parser.error('Use an absolute private environment file.')
    if os.name != 'nt' and path.stat().st_mode & 0o077:
        parser.error('The environment file must have mode 0600 or stricter.')
    if not args.command:
        parser.error('Supply the command to run after --env-file.')
    import environ
    environ.Env.read_env(path, overwrite=True)
    os.environ['APP_ENV'] = 'staging'
    os.environ['DJANGO_SETTINGS_MODULE'] = 'acessoja.settings_staging'
    os.environ['DEBUG'] = 'False'
    return subprocess.run(args.command, cwd=Path(__file__).resolve().parent.parent).returncode


if __name__ == '__main__':
    sys.exit(main())
