"""Operational contracts and real PostgreSQL restoration when the service exists."""
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import io
import json
import os
import shutil
import subprocess
import sys
import tarfile
import threading
from unittest.mock import patch
from urllib.parse import urlsplit, urlunsplit, quote
import uuid

from django.db import connection
import pytest

from scripts import staging_backup as backup
from scripts.probe_readiness import probe
from scripts.summarize_secure_logs import summarize


def bundle(tmp_path):
    root = tmp_path / 'bundle'
    root.mkdir()
    for name in ['database.dump', 'media.tar.gz']:
        (root / name).write_bytes(b'SYNTHETIC_TEST_BYTES')
    manifest = {'format': backup.FORMAT, 'privacy_restore_version': 1,
                'created_at': datetime.now(timezone.utc).isoformat(),
                'application_fingerprint': backup.fingerprint(),
                'sha256': {name: backup.digest(root / name) for name in ['database.dump', 'media.tar.gz']}}
    (root / 'manifest.json').write_text(json.dumps(manifest))
    return root, manifest


def test_backup_hash_age_version_and_fingerprint_are_required(tmp_path):
    root, manifest = bundle(tmp_path)
    assert backup.validate_bundle(root)[0] == root
    for field, invalid in [('format', 'old'), ('application_fingerprint', 'different'),
                           ('privacy_restore_version', 0),
                           ('created_at', (datetime.now(timezone.utc) - timedelta(days=15)).isoformat()),
                           ('created_at', (datetime.now(timezone.utc) + timedelta(days=2)).isoformat())]:
        (root / 'manifest.json').write_text(json.dumps({**manifest, field: invalid}))
        with pytest.raises(ValueError):
            backup.validate_bundle(root)
    (root / 'manifest.json').write_text(json.dumps(manifest))
    (root / 'database.dump').write_bytes(b'CORRUPTED')
    with pytest.raises(ValueError):
        backup.validate_bundle(root)


def test_postgres_secrets_use_environment_never_arguments():
    url = 'postgresql://synthetic:SYNTHETIC_SECRET@localhost:5432/acessoja_restore_test'
    with patch('scripts.staging_backup.subprocess.run') as run:
        run.return_value.returncode = 0
        backup.run_pg('pg_dump', ['--format=custom'], url)
    assert run.call_args.args[0] == ['pg_dump', '--format=custom']
    assert run.call_args.kwargs['env']['PGPASSWORD'] == 'SYNTHETIC_SECRET'
    with pytest.raises(ValueError):
        backup.pg_environment('sqlite:///local.db')


def test_media_roundtrip_and_rejects_links_and_traversal(tmp_path):
    source = tmp_path / 'source'
    source.mkdir()
    (source / 'nested').mkdir()
    (source / 'nested' / 'synthetic.bin').write_bytes(b'SYNTHETIC')
    archive = tmp_path / 'media.tar.gz'
    backup.pack_media(source, archive)
    destination = tmp_path / 'restored'
    backup.unpack_media(archive, destination)
    assert (destination / 'nested' / 'synthetic.bin').read_bytes() == b'SYNTHETIC'
    for name, kind in [('../escape', tarfile.REGTYPE), ('link', tarfile.SYMTYPE), ('/absolute', tarfile.REGTYPE)]:
        with tarfile.open(archive, 'w:gz') as tar:
            member = tarfile.TarInfo(name)
            member.type = kind
            member.linkname = '../outside'
            tar.addfile(member, io.BytesIO(b''))
        with pytest.raises(ValueError):
            backup.unpack_media(archive, tmp_path / 'unsafe')
    if os.name != 'nt':
        (source / 'link').symlink_to(source / 'nested' / 'synthetic.bin')
        with pytest.raises(ValueError):
            backup.pack_media(source, archive)


@pytest.mark.django_db
def test_restoration_rejects_live_name_missing_or_replaced_journal(tmp_path, settings):
    from usuarios.deletion_journal import journal_identity
    settings.DELETION_JOURNAL_DIR = tmp_path / 'journal'
    identity = journal_identity(initialize=True)
    root, manifest = bundle(tmp_path)
    with pytest.raises(ValueError, match='restore database'):
        backup.restore(root, 'postgresql://localhost/live', tmp_path / 'acessoja_restore_media')
    manifest['deletion_journal_id'] = identity
    (root / 'manifest.json').write_text(json.dumps(manifest))
    (settings.DELETION_JOURNAL_DIR / 'JOURNAL_ID').unlink()
    with pytest.raises(OSError):
        backup.restore(root, 'postgresql://localhost/acessoja_restore_test', tmp_path / 'acessoja_restore_media')
    journal_identity(initialize=True)
    with pytest.raises(ValueError, match='original current'):
        backup.restore(root, 'postgresql://localhost/acessoja_restore_test', tmp_path / 'acessoja_restore_media')


def test_probe_observes_actual_http_failure_and_recovery_without_data(tmp_path):
    class Handler(BaseHTTPRequestHandler):
        status = 503

        def do_GET(self):
            self.send_response(type(self).status)
            self.end_headers()
            self.wfile.write(b'{"status":"ok"}')

        def log_message(self, *args):
            pass

    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        url = f'http://127.0.0.1:{server.server_port}/health/ready/'
        failure = probe(url)
        Handler.status = 200
        recovery = probe(url)
        assert not failure['healthy'] and failure['status'] == 503 and recovery['healthy']
        with pytest.raises(ValueError):
            probe(url + '?token=SYNTHETIC_SECRET')
        log = tmp_path / 'probes.json.log'
        log.write_text('\n'.join(json.dumps(row) for row in [failure, recovery]) + '\n[]\ninvalid\n')
        assert summarize([log])['unavailable_probes'] == 1
        assert summarize([log])['availability_sla'] == 'not established'
    finally:
        server.shutdown()
        server.server_close()
        thread.join(5)


@pytest.mark.django_db(transaction=True)
def test_i05_postgresql_restore_checks_counts_media_suppression_and_synthetic_smoke(tmp_path, settings):
    if connection.vendor != 'postgresql':
        pytest.skip('Requires actual PostgreSQL plus matching pg_dump/pg_restore; CI job provided.')
    if not shutil.which('pg_dump') or not shutil.which('pg_restore'):
        pytest.fail('The PostgreSQL CI job must install matching pg_dump/pg_restore.')
    from django.test import override_settings
    import psycopg2
    from psycopg2 import sql
    from usuarios.deletion_journal import journal_identity
    from usuarios.models import Usuario
    from usuarios.privacy_services import delete_account
    from rest_framework.authtoken.models import Token

    settings.DELETION_JOURNAL_DIR = tmp_path / 'journal'
    settings.MEDIA_ROOT = tmp_path / 'media'
    settings.MEDIA_ROOT.mkdir()
    (settings.MEDIA_ROOT / 'synthetic.bin').write_bytes(b'SYNTHETIC_MEDIA')
    journal_identity(initialize=True)
    password = 'Synthetic-backup!73952'
    erased = Usuario.objects.create_user('synthetic-erased', email='erased@example.test', password=password)
    kept = Usuario.objects.create_user('synthetic-kept', email='kept@example.test', password=password)
    Token.objects.create(user=kept)
    parsed = urlsplit(os.environ['DATABASE_URL'])
    source_url = urlunsplit(parsed._replace(path='/' + quote(str(connection.settings_dict['NAME']))))
    target_name = 'acessoja_restore_' + uuid.uuid4().hex
    target_url = urlunsplit(parsed._replace(path='/' + target_name))
    admin = connection.settings_dict
    operator = psycopg2.connect(host=admin['HOST'], port=admin['PORT'], dbname='postgres',
                                user=admin['USER'], password=admin['PASSWORD'])
    operator.autocommit = True
    with operator.cursor() as cursor:
        cursor.execute(sql.SQL('CREATE DATABASE {}').format(sql.Identifier(target_name)))
    try:
        destination = tmp_path / 'backups'
        saved = backup.backup(destination, source_url)
        erased_id = erased.pk
        with override_settings(APP_ENV='local'):
            assert delete_account(erased.pk, password)
        env = dict(os.environ, DATABASE_URL=source_url, RESTORE_DATABASE_URL=target_url,
                   DJANGO_SETTINGS_MODULE='acessoja.settings', APP_ENV='local',
                   DELETION_JOURNAL_DIR=str(settings.DELETION_JOURNAL_DIR), MEDIA_ROOT=str(settings.MEDIA_ROOT))
        recovered = tmp_path / 'acessoja_restore_media'
        command = [sys.executable, 'scripts/staging_backup.py', 'restore', '--bundle', str(saved),
                   '--media-target', str(recovered)]
        result = subprocess.run(command, cwd=backup.ROOT, env=env, capture_output=True, timeout=120)
        assert result.returncode == 0, 'Isolated restore failed; inspect protected test output.'
        assert (recovered / 'synthetic.bin').read_bytes() == b'SYNTHETIC_MEDIA'
        restored = psycopg2.connect(target_url)
        try:
            with restored.cursor() as cursor:
                cursor.execute('SELECT id_usuario FROM usuarios ORDER BY id_usuario')
                assert [row[0] for row in cursor.fetchall()] == [kept.pk] and erased_id != kept.pk
                cursor.execute('SELECT COUNT(*) FROM authtoken_token')
                assert cursor.fetchone()[0] == 0
        finally:
            restored.close()
        env.update(DATABASE_URL=target_url, SYNTHETIC_SMOKE_PASSWORD=password)
        smoke = subprocess.run([sys.executable, 'manage.py', 'smoke_account_security',
                                '--synthetic-isolated', '--user', kept.nome],
                               cwd=backup.ROOT, env=env, capture_output=True, timeout=120)
        assert smoke.returncode == 0, 'Synthetic restored-account smoke failed.'
        report = json.loads((tmp_path / 'acessoja_restore_media-report.json').read_text())
        assert report['integrity'] == 'verified' and report['privacy_suppression'] == 'applied'
    finally:
        with operator.cursor() as cursor:
            cursor.execute(sql.SQL('DROP DATABASE {} WITH (FORCE)').format(sql.Identifier(target_name)))
        operator.close()
