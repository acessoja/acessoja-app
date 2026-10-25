"""Private PostgreSQL/media backups and fail-closed ISOLATED restoration.

Credentials are read from environment; subprocess arguments never contain a DSN
or password. A backup is not evidence that restoration succeeded.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
from urllib.parse import urlsplit, unquote
import uuid

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
FORMAT = 'acessoja.backup.v1'


def digest(path):
    result = hashlib.sha256()
    with Path(path).open('rb') as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b''):
            result.update(block)
    return result.hexdigest()


def fingerprint():
    result = hashlib.sha256()
    folders = ['acessoja', 'usuarios', 'locais', 'contribuicoes',
               'favoritos', 'modal_avaliacao', 'avaliacao', 'backend']
    for folder in folders:
        for path in sorted((ROOT / folder).rglob('*')):
            if path.is_file() and path.suffix in {'.py', '.txt'} and '__pycache__' not in path.parts:
                result.update(str(path.relative_to(ROOT)).encode())
                result.update(path.read_bytes())
    return result.hexdigest()


def pg_environment(url):
    parsed = urlsplit(url)
    if parsed.scheme not in {'postgres', 'postgresql'} or not parsed.hostname or not parsed.path.strip('/'):
        raise ValueError('A valid PostgreSQL URL is required in the environment.')
    # Never inherit password-bearing service URLs into a process command line.
    result = dict(os.environ)
    result.update(PGHOST=parsed.hostname, PGPORT=str(parsed.port or 5432),
                  PGDATABASE=unquote(parsed.path.lstrip('/')), PGUSER=unquote(parsed.username or ''),
                  PGPASSWORD=unquote(parsed.password or ''), PGCONNECT_TIMEOUT='5')
    return result


def run_pg(binary, args, url):
    result = subprocess.run([binary, *args], env=pg_environment(url), capture_output=True, timeout=300)
    if result.returncode:
        # Raw libpq output can include hostnames or data; keep it out of logs.
        raise RuntimeError(f'{Path(binary).name} failed; inspect the protected database state.')


def row_counts():
    from django.db import connection
    result = {}
    with connection.cursor() as cursor:
        for table in sorted(connection.introspection.table_names(cursor)):
            cursor.execute(f'SELECT COUNT(*) FROM {connection.ops.quote_name(table)}')
            result[table] = cursor.fetchone()[0]
    return result


def pack_media(source, destination):
    root = Path(source)
    with tarfile.open(destination, 'w:gz') as archive:
        if not root.exists():
            return
        for path in sorted(root.rglob('*')):
            if path.is_symlink() or not (path.is_file() or path.is_dir()):
                raise ValueError('Media backups reject symlinks and special files.')
            archive.add(path, arcname=str(path.relative_to(root)), recursive=False)


def unpack_media(source, destination):
    root = Path(destination)
    with tarfile.open(source) as archive:
        for member in archive:
            parts = PurePosixPath(member.name)
            if parts.is_absolute() or '..' in parts.parts or not (member.isfile() or member.isdir()):
                raise ValueError('Unsafe media archive entry.')
            path = root.joinpath(*parts.parts)
            if member.isdir():
                path.mkdir(parents=True, exist_ok=True, mode=0o700)
            else:
                path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
                content = archive.extractfile(member)
                if content is None:
                    raise ValueError('Invalid media archive.')
                with content, path.open('xb') as output:
                    shutil.copyfileobj(content, output)
                path.chmod(0o600)


def backup(destination, source_url, pg_dump='pg_dump'):
    from django.conf import settings
    from django.db import transaction
    from usuarios.deletion_journal import journal_identity, read_receipts
    from usuarios.models import AccountDeletionReceipt
    root = Path(destination).resolve()
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    if os.name != 'nt' and root.stat().st_mode & 0o077:
        raise ValueError('Backup destination must have mode 0700.')
    records = read_receipts()
    pending = AccountDeletionReceipt.objects.filter(published=False).exists()
    if any(record['state'] == 'pending' for record in records) or pending:
        raise ValueError('Reconcile deletion receipts before taking a backup.')
    folder = Path(tempfile.mkdtemp(prefix='.incomplete-', dir=root))
    try:
        # Counts and pg_dump share one exported PostgreSQL snapshot.
        from django.db import connection
        if connection.vendor != 'postgresql':
            raise ValueError('Backups require PostgreSQL.')
        with transaction.atomic():
            with connection.cursor() as cursor:
                cursor.execute('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY')
                cursor.execute('SELECT pg_export_snapshot()')
                snapshot = cursor.fetchone()[0]
            counts = row_counts()
            run_pg(pg_dump, ['--format=custom', '--no-owner', '--no-privileges', f'--snapshot={snapshot}',
                             '--file', str(folder / 'database.dump')], source_url)
        pack_media(settings.MEDIA_ROOT, folder / 'media.tar.gz')
        manifest = {'format': FORMAT, 'created_at': datetime.now(timezone.utc).isoformat(),
                    'deletion_journal_id': journal_identity(),
                    'privacy_restore_version': 1, 'application_fingerprint': fingerprint(),
                    'row_counts': counts, 'sha256': {name: digest(folder / name)
                                                     for name in ['database.dump', 'media.tar.gz']}}
        (folder / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
        for path in folder.iterdir():
            path.chmod(0o600)
            with path.open('rb') as handle:
                os.fsync(handle.fileno())
        final = root / (datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex[:8])
        folder.rename(final)
        return final
    except Exception:
        shutil.rmtree(folder)
        raise


def validate_bundle(bundle):
    root = Path(bundle).resolve()
    manifest_path = root / 'manifest.json'
    if manifest_path.is_symlink() or manifest_path.stat().st_size > 1024 * 1024:
        raise ValueError('Invalid backup manifest.')
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    if manifest.get('format') != FORMAT or manifest.get('privacy_restore_version') != 1:
        raise ValueError('Unsupported backup format; pre-privacy backups need controller review.')
    if manifest.get('application_fingerprint') != fingerprint():
        raise ValueError('Application differs from the backup; validate compatibility before restoring.')
    for name in ['database.dump', 'media.tar.gz']:
        path = root / name
        if path.is_symlink() or not path.is_file() or digest(path) != manifest.get('sha256', {}).get(name):
            raise ValueError('Backup integrity validation failed.')
    created = datetime.fromisoformat(manifest['created_at'])
    age = (datetime.now(timezone.utc) - created).total_seconds() if created.tzinfo else None
    if age is None or age < -300 or age > 14 * 86400:
        raise ValueError('Backup is outside the 14-day restorable retention window.')
    return root, manifest


def restore(bundle, target_url, media_target, pg_restore='pg_restore'):
    from django.conf import settings
    from django.core.management import call_command
    from django.db import connection
    from usuarios.deletion_journal import journal_identity, read_receipts
    pg = pg_environment(target_url)
    if not pg['PGDATABASE'].startswith('acessoja_restore_'):
        raise ValueError('The restore database name must start with acessoja_restore_.')
    root, manifest = validate_bundle(bundle)
    if manifest.get('deletion_journal_id') != journal_identity():
        raise ValueError('The original current independent deletion journal is required.')
    receipts = read_receipts()
    if any(record['state'] == 'pending' for record in receipts):
        raise ValueError('Pending independent deletion receipts block restoration.')
    with connection.cursor() as cursor:
        if connection.introspection.table_names(cursor):
            raise ValueError('Restore requires an empty isolated database. No overwrite is allowed.')
    target = Path(media_target).resolve()
    source = Path(settings.MEDIA_ROOT).resolve()
    if target == source or source in target.parents or not target.name.startswith('acessoja_restore_'):
        raise ValueError('Use a separate media directory named acessoja_restore_*.')
    target.mkdir(parents=True, exist_ok=False, mode=0o700)
    started = time.monotonic()
    run_pg(pg_restore, ['--exit-on-error', '--no-owner', '--no-privileges', '--dbname', pg['PGDATABASE'],
                        str(root / 'database.dump')], target_url)
    unpack_media(root / 'media.tar.gz', target)
    before = row_counts()
    if before != manifest['row_counts']:
        raise ValueError('Restored row counts do not match the exported snapshot.')
    call_command('migrate', check=True, verbosity=0)
    call_command('check', verbosity=0)
    call_command('apply_privacy_deletions', isolated_restore=True, verbosity=0)
    after = row_counts()
    result = {'event': 'isolated_restore', 'integrity': 'verified', 'privacy_suppression': 'applied',
              'duration_seconds': round(time.monotonic() - started, 3), 'before_counts': before, 'after_counts': after,
              'authentication_smoke': 'pending: use synthetic accounts; run the documented smoke after restore'}
    # No credentials, original filenames, hostnames or personal rows in the report.
    report = target.parent / f'{target.name}-report.json'
    report.write_text(json.dumps(result, indent=2), encoding='utf-8')
    report.chmod(0o600)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='operation', required=True)
    create = sub.add_parser('backup')
    create.add_argument('--destination', required=True)
    recover = sub.add_parser('restore')
    recover.add_argument('--bundle', required=True)
    recover.add_argument('--media-target', required=True)
    args = parser.parse_args()
    source_url = os.environ.get('DATABASE_URL', '')
    if args.operation == 'restore':
        target_url = os.environ.get('RESTORE_DATABASE_URL', '')
        original, target = pg_environment(source_url), pg_environment(target_url)
        if (original['PGHOST'], original['PGPORT'], original['PGDATABASE']) == (
                target['PGHOST'], target['PGPORT'], target['PGDATABASE']):
            raise ValueError('The restore target cannot be the source database.')
        os.environ['DATABASE_URL'] = target_url
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'acessoja.settings')
    import django
    django.setup()
    os.umask(0o077)
    if args.operation == 'backup':
        output = backup(args.destination, source_url)
    else:
        output = restore(args.bundle, target_url, args.media_target)
    print(f'{args.operation}: verified output at {output}')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired):
        print('Operation failed; no completion confirmed. Review protected configuration and integrity checks.',
              file=sys.stderr)
        raise SystemExit(1)
