"""Real local TLS/proxy smoke with synthetic inputs and a temporary private CA.

This checks the proxy/application boundary, NOT public DNS/certificates,
PostgreSQL persistence or SMTP delivery. No system trust store is modified.
"""
import argparse
import http.client
import json
import os
from pathlib import Path
import secrets
import shutil
import socket
import ssl
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent


def free_port():
    with socket.socket() as channel:
        channel.bind(('127.0.0.1', 0))
        return channel.getsockname()[1]


def run(caddy, output):
    ports = [free_port() for _ in range(3)]
    upstream, secure_port, plain_port = ports
    canaries = ['PRIVATE_RESET_CANARY', 'PRIVATE_AUTH_CANARY', 'private@example.test', '-16.328,-48.951']
    results = {'scope': 'local isolated TLS lab; temporary CA; unavailable database by design'}
    processes = []
    with tempfile.TemporaryDirectory(prefix='acessoja-proxy-lab-') as directory:
        folder = Path(directory)
        for name in ['logs', 'journal', 'data', 'config', 'web']:
            (folder / name).mkdir(mode=0o700)
        (folder / 'web/index.html').write_text('SYNTHETIC_SPA_FALLBACK')
        env = dict(os.environ, APP_ENV='staging', DEBUG='False',
                   DJANGO_SETTINGS_MODULE='acessoja.settings_staging', SECRET_KEY=secrets.token_urlsafe(64),
                   ALLOWED_HOSTS='127.0.0.1,localhost',
                   FRONTEND_PUBLIC_ORIGIN=f'https://localhost:{secure_port}',
                   CORS_ALLOWED_ORIGINS=f'https://localhost:{secure_port}',
                   CSRF_TRUSTED_ORIGINS=f'https://localhost:{secure_port}',
                   TRUSTED_PROXY_CIDRS='127.0.0.1/32',
                   DATABASE_URL='postgresql://synthetic:synthetic@127.0.0.1:1/acessoja_staging',
                   CACHE_URL='rediscache://127.0.0.1:1/1',
                   EMAIL_BACKEND='django.core.mail.backends.smtp.EmailBackend', EMAIL_HOST='smtp.example.test',
                   EMAIL_USE_TLS='True', DEFAULT_FROM_EMAIL='AcessoJa <no-reply@example.test>',
                   PRIVACY_CONTACT_EMAIL='privacy@example.test', SECURE_LOG_DIR=str(folder / 'logs'),
                   DELETION_JOURNAL_DIR=str(folder / 'journal'),
                   PUBLIC_HOST=f'https://localhost:{secure_port}', PILOT_CIDRS='127.0.0.0/8',
                   TLS_CONTACT_EMAIL='ops@example.test', PROXY_LOG_DIR=str(folder / 'logs'),
                   XDG_DATA_HOME=str(folder / 'data'), XDG_CONFIG_HOME=str(folder / 'config'))
        config = (ROOT / 'deploy/staging/Caddyfile').read_text()
        config = config.replace('{\n', '{\n\tskip_install_trust\n\tauto_https disable_redirects\n', 1)
        config = config.replace('{$PUBLIC_HOST} {', '{$PUBLIC_HOST} {\n\ttls internal')
        config = config.replace('app:8000', f'127.0.0.1:{upstream}')
        config = config.replace('/srv/web', str(folder / 'web'))
        config += f'\nhttp://127.0.0.1:{plain_port} {{\n redir https://localhost:{secure_port}{{uri}} 308\n}}\n'
        caddyfile = folder / 'Caddyfile'
        caddyfile.write_text(config)
        streams = [open(folder / name, 'wb') for name in ['gunicorn-start.log', 'caddy-start.log']]
        try:
            app = subprocess.Popen([sys.executable, '-m', 'gunicorn', 'acessoja.wsgi:application',
                                    '--config', 'deploy/staging/gunicorn.conf.py', '--workers', '1',
                                    '--bind', f'127.0.0.1:{upstream}'], cwd=ROOT, env=env,
                                   stdout=streams[0], stderr=subprocess.STDOUT)
            processes.append(app)
            proxy = subprocess.Popen([caddy, 'run', '--config', str(caddyfile), '--adapter', 'caddyfile'],
                                     env=env, stdout=streams[1], stderr=subprocess.STDOUT)
            processes.append(proxy)
            certificate = folder / 'data/caddy/pki/authorities/local/root.crt'
            deadline = time.monotonic() + 35
            while time.monotonic() < deadline:
                if app.poll() is not None or proxy.poll() is not None:
                    raise RuntimeError('The local server did not start. Inspect protected temporary configuration.')
                if certificate.is_file():
                    try:
                        with socket.create_connection(('127.0.0.1', upstream), timeout=.2):
                            break
                    except OSError:
                        pass
                time.sleep(.1)
            context = ssl.create_default_context(cafile=str(certificate))

            def request(path, secure=True, headers=None, source='127.0.0.2', port=None):
                kwargs = {'timeout': 5, 'source_address': (source, 0)}
                if secure:
                    client = http.client.HTTPSConnection('localhost', port or secure_port,
                                                         context=context, **kwargs)
                else:
                    client = http.client.HTTPConnection('127.0.0.1', port or plain_port, **kwargs)
                try:
                    client.request('GET', path, headers=headers or {})
                    response = client.getresponse()
                    return response.status, dict(response.getheaders()), response.read()
                finally:
                    client.close()

            deadline = time.monotonic() + 20
            while True:
                try:
                    assert request('/health/live/')[0] == 200
                    break
                except (OSError, http.client.HTTPException):
                    if time.monotonic() >= deadline:
                        raise
                    time.sleep(.1)
            results['tls_chain_verified'] = True
            assert request('/health/live/', secure=False)[0] == 308
            results['http_redirect'] = True
            status, headers, body = request('/auth/users/me/', headers={
                'X-Forwarded-Proto': 'http', 'X-Forwarded-For': 'PRIVATE_RESET_CANARY'})
            assert status == 401
            results['proxy_rewrites_forwarding'] = True
            assert request('/auth/users/me/', secure=False, port=upstream,
                           headers={'X-Forwarded-Proto': 'https'})[0] == 301
            results['direct_forged_https_refused'] = True
            status, headers, body = request('/admin/login/')
            assert status == 200 and 'Secure' in headers.get('Set-Cookie', '')
            results['admin_csrf_cookie_secure'] = True
            assert request('/api/schema/')[0] in {401, 403}
            results['schema_requires_staff'] = True
            assert request('/health/ready/')[0] == 503
            results['mandatory_dependency_failure_not_ready'] = True
            assert b'SYNTHETIC_SPA_FALLBACK' in request('/recuperar-senha/MQ/abc-def')[2]
            results['direct_spa_route_fallback'] = True
            request('/health/live/?token=PRIVATE_RESET_CANARY&email=private@example.test&coord=-16.328,-48.951',
                    headers={'Authorization': 'Token PRIVATE_AUTH_CANARY', 'Cookie': 'private=PRIVATE_AUTH_CANARY'})
            time.sleep(.2)
            contents = '\n'.join(path.read_text(errors='replace') for path in (folder / 'logs').glob('*.log'))
            assert contents and all(canary not in contents for canary in canaries)
            results['application_and_proxy_log_canaries_absent'] = True
        finally:
            for process in reversed(processes):
                process.terminate()
            for process in reversed(processes):
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
            for stream in streams:
                stream.close()
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(results, indent=2), encoding='utf-8')
    return results


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--caddy', default=shutil.which('caddy'))
    parser.add_argument('--report', required=True)
    options = parser.parse_args()
    if not options.caddy:
        parser.error('Supply the Caddy executable with --caddy.')
    print(json.dumps(run(options.caddy, options.report)))
