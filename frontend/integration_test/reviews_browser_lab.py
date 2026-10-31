#!/usr/bin/env python3
"""Real compiled Flutter + Django/storage browser lab with disposable synthetic data.

Install backend requirements and playwright; build Flutter web with
--dart-define=API_BASE_URL=http://127.0.0.1:8001 --no-web-resources-cdn.
Run with --chrome /path/to/chrome-headless-shell --report /path/to/report.json.
No production database, accounts, network services or persistent media are used.
"""
import argparse
from contextlib import ExitStack
from datetime import datetime, timezone
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import os
import re
from pathlib import Path
import sys
import tempfile
from threading import Thread
from unittest.mock import patch
from urllib.parse import urlparse
from wsgiref.simple_server import make_server


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--chrome', required=True, type=Path)
    parser.add_argument('--report', required=True, type=Path)
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[2]
    web = project / 'frontend/build/web'
    if not (web / 'main.dart.js').exists():
        parser.error('Build Flutter web first with the loopback API URL.')
    report = {
        'started_at': datetime.now(timezone.utc).isoformat(),
        'scope': 'Compiled main.dart.js, real Django API, SQLite, private filesystem storage, synthetic accounts',
        'fault_injection': 'Only the third derivative storage call fails once; no fabricated API success responses',
        'excluded': ['Android hardware/camera', 'PostgreSQL/Redis concurrency', 'Assistive technology',
                     'External map tiles/providers', 'Cross-platform synchronization'],
        'steps': [], 'status': 'running',
    }

    def record(name, **evidence):
        report['steps'].append({'name': name, 'status': 'passed', **evidence})
        print(name, flush=True)
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')

    with ExitStack() as stack:
        temporary = Path(stack.enter_context(tempfile.TemporaryDirectory(prefix='acessoja-browser-')))
        os.environ.update({
            'DJANGO_SETTINGS_MODULE': 'acessoja.settings',
            # Playwright sync owns an event loop; this disposable lab uses synchronous ORM assertions only.
            'DJANGO_ALLOW_ASYNC_UNSAFE': 'true',
            'SECRET_KEY': 'synthetic-local-browser-lab-only',
            'DATABASE_URL': f'sqlite:///{temporary}/db.sqlite3',
            'DEBUG': 'True', 'ALLOWED_HOSTS': '127.0.0.1,localhost',
            'CORS_ALLOWED_ORIGINS': 'http://127.0.0.1:8002',
        })
        sys.path.insert(0, str(project))
        import django
        django.setup()
        from django.contrib.auth.models import Permission
        from django.core.management import call_command
        from django.core.wsgi import get_wsgi_application
        from django.contrib.staticfiles.handlers import StaticFilesHandler
        from django.core.servers.basehttp import WSGIServer, WSGIRequestHandler
        from django.db import connections
        from django.db.models import Sum
        from django.test import override_settings
        from contribuicoes.models import ContributionPointEvent, PointActivity
        from evidencias.models import ResourceEvidence
        from locais.models import Local
        from midia.models import ReviewPhoto
        from midia.services import store_derivatives
        from modal_avaliacao.models import ModalAvaliacao
        from usuarios.models import Usuario
        from playwright.sync_api import sync_playwright
        stack.enter_context(override_settings(
            PRIVATE_IMAGE_ROOT=temporary / 'private', MEDIA_ROOT=temporary / 'media',
            DELETION_JOURNAL_DIR=temporary / 'journal',
            PASSWORD_HASHERS=['django.contrib.auth.hashers.MD5PasswordHasher'],
            OVERPASS_URL='http://127.0.0.1:9/unavailable',
        ))
        call_command('migrate', verbosity=0)
        owner = Usuario.objects.create_user(
            'cards47-owner', 'SyntheticOnly!47', email='owner@example.invalid')
        reader_user = Usuario.objects.create_user(
            'cards47-reader', 'SyntheticOnly!47', email='reader@example.invalid')
        Usuario.objects.create_user('cards47-stars', 'SyntheticOnly!47', email='stars@example.invalid')
        moderator = Usuario.objects.create_user(
            'cards47-mod', 'SyntheticOnly!47', email='moderator@example.invalid', is_staff=True)
        moderator.user_permissions.add(Permission.objects.get(
            codename='moderate_content', content_type__app_label='evidencias'))
        Local.objects.create(
            nome='Biblioteca Cards 47', endereco='Rua Sintética', distancia=0,
            latitude=-16.3267, longitude=-48.9528, categoria='outros')
        calls = {'storage': 0, 'review_post': 0, 'photo_post': 0}

        def storage_once(*values, **kwargs):
            calls['storage'] += 1
            if calls['storage'] == 3:
                raise OSError('Synthetic one-shot storage interruption')
            return store_derivatives(*values, **kwargs)

        stack.enter_context(patch('midia.services.store_derivatives', storage_once))

        class QuietWSGI(WSGIRequestHandler):
            def log_message(self, *args):
                pass

        class QuietFiles(SimpleHTTPRequestHandler):
            def __init__(self, *args, **kwargs):
                super().__init__(*args, directory=str(web), **kwargs)

            def log_message(self, *args):
                pass

        api = make_server('127.0.0.1', 8001, StaticFilesHandler(get_wsgi_application()),
                          server_class=WSGIServer, handler_class=QuietWSGI)
        static = ThreadingHTTPServer(('127.0.0.1', 8002), QuietFiles)
        for server in (api, static):
            Thread(target=server.serve_forever, daemon=True).start()
            stack.callback(server.server_close)
            stack.callback(server.shutdown)
        stack.callback(connections.close_all)
        playwright = stack.enter_context(sync_playwright())
        browser = playwright.chromium.launch(
            executable_path=str(args.chrome), headless=True,
            args=['--no-sandbox', '--disable-dev-shm-usage'])
        stack.callback(browser.close)
        report['browser'] = browser.version

        def context():
            result = browser.new_context(locale='pt-BR', viewport={'width': 1280, 'height': 900})
            result.set_default_timeout(12000)
            result.add_init_script("localStorage.setItem('flutter.onboarding_completed','true')")

            def route(request):
                if urlparse(request.request.url).hostname in {'127.0.0.1', 'localhost'}:
                    request.continue_()
                else:
                    request.abort()
            result.route('**/*', route)
            return result

        active_page = [None]

        def click(page, name, role='button'):
            active_page[0] = page
            locator = page.get_by_role(role, name=name, exact=True).first
            page.wait_for_timeout(300)
            for _ in range(12):
                if locator.count():
                    break
                page.mouse.move(640, 600)
                page.mouse.wheel(0, 550)
                page.wait_for_timeout(300)
            locator.wait_for(state='attached', timeout=5000)
            locator.evaluate('(element) => element.click()')
            page.wait_for_timeout(250)

        def login(page, username):
            page.goto('http://127.0.0.1:8002/')
            page.locator('flt-semantics-placeholder').wait_for(state='attached', timeout=20000)
            page.locator('flt-semantics-placeholder').evaluate('(element) => element.click()')
            for label, value in [('Usuário', username), ('Senha', 'SyntheticOnly!47')]:
                field = page.locator(f'input[aria-label="{label}"]:not([disabled])')
                field.click()
                page.wait_for_timeout(250)
                page.keyboard.press('ControlOrMeta+A')
                page.keyboard.type(value, delay=25)
                page.wait_for_timeout(200)
                assert field.input_value() == value, f'Input synchronization failed: {label}'
            click(page, 'Entrar')
            page.get_by_role('tab', name='Avaliar', exact=True).wait_for(timeout=20000)
            click(page, 'Avaliar', 'tab')
            page.get_by_role('button', name='Avaliar', exact=True).wait_for(state='attached', timeout=20000)

        def fill(page, label, value):
            field = page.get_by_role('textbox', name=label, exact=True)
            field.last.click()
            page.wait_for_timeout(250)
            page.keyboard.press('ControlOrMeta+A')
            page.keyboard.type(value, delay=15)
            page.wait_for_timeout(250)

        def answer(page, label, value):
            locator = page.get_by_role('checkbox', name=label, exact=True)
            if locator.count() == 0:
                locator = page.get_by_role('checkbox', name=label)
            locator.first.evaluate('(element) => element.click()')
            page.wait_for_timeout(150)
            page.get_by_role('button', name=value, exact=True).last.evaluate('(element) => element.click()')
            page.wait_for_timeout(150)

        def total():
            return PointActivity.objects.filter(event__user=owner).aggregate(n=Sum('delta'))['n'] or 0

        def active_bonus():
            return ContributionPointEvent.objects.filter(user=owner, action='photo_evidence', active=True).count()

        page = context().new_page()
        page.set_default_timeout(12000)

        def observe(request):
            path = urlparse(request.url).path
            if request.method == 'POST' and path == '/api/login/':
                data = request.post_data_json
                assert data['nome'] == owner.nome and data['password'] == 'SyntheticOnly!47', (
                    'Synthetic login input mismatch')
            if request.method == 'POST' and path == '/api/avaliacoes/modal-avaliacoes/':
                calls['review_post'] += 1
            if request.method == 'POST' and path == '/api/midia/fotos/enviar/':
                calls['photo_post'] += 1
        page.on('request', observe)
        try:
            login(page, owner.nome)
            click(page, 'Avaliar')
            click(page, '4 estrelas')
            fill(page, 'Comentário (opcional)', 'Visita sintética para testar recursos e fotografias.')
            click(page, 'Informar recursos de acessibilidade (opcional)')
            answer(page, 'Rampa na entrada', 'Sim')
            answer(page, 'Banheiro com recursos de adaptação', 'Não sei')
            answer(page, 'Piso tátil', 'Não')
            answer(page, 'Sinalização visual legível', 'Sim')
            assert ModalAvaliacao.objects.count() == 0
            record('Partial draft has two v2 and two independent answers, no review persisted')
            click(page, 'Continuar para fotos (opcional)')
            from PIL import Image
            for number in range(3):
                photo = temporary / f'synthetic-{number}.png'
                Image.new('RGB', (200, 120), (40 + number * 50, 110, 160)).save(photo)
                click(page, 'Selecionar foto')
                with page.expect_file_chooser() as chooser:
                    click(page, 'Galeria ou arquivo')
                chooser.value.set_files(str(photo))
                page.get_by_role('textbox', name='Descrição da foto (10 a 500 caracteres)', exact=True).nth(
                    number).wait_for(state='attached')
                fill(page, 'Descrição da foto (10 a 500 caracteres)',
                     f'Foto sintética {number + 1} da entrada utilizada.')
            assert ReviewPhoto.objects.count() == 0 and ModalAvaliacao.objects.count() == 0
            record('Three local photos selected before review creation or upload')
            click(page, 'Revisar e publicar')
            click(page, 'Confirmar publicação')
            page.get_by_text(
                'Avaliação salva. Fotos recebidas neste envio: 2; pendentes: 1.', exact=True).last.wait_for()
            assert ModalAvaliacao.objects.count() == 1 and ReviewPhoto.objects.count() == 2
            review = ModalAvaliacao.objects.get()
            assert len(review.answers) == 2 and review.answers['rampa_acesso'] == 'yes'
            assert ResourceEvidence.objects.filter(kind='observation').count() == 2
            assert total() == 10 and active_bonus() == 0
            record('Real one-shot storage failure preserves review, two receipts, partial evidence and 10 points')
            click(page, 'Tentar somente pendências')
            page.get_by_role('button', name='Avaliar', exact=True).wait_for(state='attached')
            assert ReviewPhoto.objects.count() == 3 and ModalAvaliacao.objects.count() == 1
            assert calls['review_post'] == 1 and calls['photo_post'] == 4
            assert total() == 10
            record('Retry uploads only remaining photo', review_posts=1, photo_posts=4, photos=3, points=10)

            from rest_framework.authtoken.models import Token
            token = Token.objects.get(user=owner).key
            photos = list(ReviewPhoto.objects.select_related('current_revision').order_by('-created_at', 'pk'))
            asset_url = f'http://127.0.0.1:8001/api/midia/arquivos/{photos[0].current_revision.asset_id}/image/'
            anonymous = playwright.request.new_context()
            assert anonymous.get(asset_url).status == 404
            authorized = playwright.request.new_context(extra_http_headers={'Authorization': f'Token {token}'})
            assert authorized.get(asset_url).status == 200
            assert authorized.head(asset_url).status == 200
            record('Pending image is private for GET and available to its authenticated owner for GET/HEAD')

            admin = browser.new_context().new_page()
            admin.goto('http://127.0.0.1:8001/admin/login/')
            admin.locator('[name=username]').fill(moderator.nome)
            admin.locator('[name=password]').fill('SyntheticOnly!47')
            admin.locator('input[type=submit]').click()

            def decide(photo, action='approve'):
                admin.goto(f'http://127.0.0.1:8001/admin/midia/reviewphoto/{photo.pk}/decidir/')
                admin.locator('[name=action]').select_option(action)
                admin.locator('[name=reason]').fill(
                    'INTERNAL_SYNTHETIC_CANARY Decision based on synthetic test content.')
                admin.locator('[name=author_reason]').select_option('privacy' if action == 'reject' else 'context')
                admin.get_by_role('button', name='Confirmar decisão', exact=True).click()
                photo.refresh_from_db()
                assert photo.current_revision.state == ('approved' if action == 'approve' else 'rejected')

            decide(photos[0])
            event = ContributionPointEvent.objects.get(user=owner, action='photo_evidence')
            assert total() == 13 and active_bonus() == 1
            decide(photos[1])
            assert total() == 13 and active_bonus() == 1
            assert anonymous.get(asset_url).status == 200
            record('Real CSRF-protected Admin approvals publish bytes and grant exactly one +3 event', points=13)

            page.context.close()
            reader = context().new_page()
            login(reader, 'cards47-reader')
            click(reader, 'Ver avaliações')
            click(reader, 'Fotos desta avaliação')
            reader.get_by_text('Disponível após análise', exact=True).first.wait_for()
            click(reader, 'Ampliar foto')
            reader.keyboard.press('Escape')
            reader.get_by_text('Disponível após análise', exact=True).first.wait_for()
            record('Reader opens actual public gallery and closes enlarged photo with Escape')
            reader.context.close()

            def owner_gallery():
                # New page reloads server state rather than importing private in-memory drafts.
                fresh = context().new_page()
                login(fresh, owner.nome)
                click(fresh, 'Avaliar')
                click(fresh, 'Adicionar fotos (opcional)')
                click(fresh, 'Gerenciar fotos e corrigir rejeições')
                return fresh

            def edit_description(target, index, description):
                target.get_by_role('button', name='Ações da foto', exact=True).nth(index).evaluate('(e)=>e.click()')
                click(target, 'Editar descrição e reenviar', 'menuitem')
                fill(target, 'Descrição (10 a 500 caracteres)', description)
                click(target, 'Enviar nova revisão pendente')

            gallery = owner_gallery()
            edit_description(gallery, 0, 'Primeira fotografia com contexto sintético corrigido.')
            assert total() == 13 and active_bonus() == 1
            assert anonymous.get(asset_url).status == 404
            edit_description(gallery, 1, 'Segunda fotografia com contexto sintético corrigido.')
            assert total() == 10 and active_bonus() == 0
            record('Description revisions hide old bytes; another approved photo preserves bonus, last one revokes it')

            decide(photos[0], 'reject')
            gallery.context.close()
            gallery = owner_gallery()
            assert 'INTERNAL_SYNTHETIC_CANARY' not in gallery.locator('body').inner_text()
            assert 'privacy' in authorized.get(
                f'http://127.0.0.1:8001/api/midia/fotos/{photos[0].pk}/').text()
            assert 'INTERNAL_SYNTHETIC_CANARY' not in authorized.get(
                f'http://127.0.0.1:8001/api/midia/fotos/{photos[0].pk}/').text()
            edit_description(gallery, 0, 'Imagem sintética corrigida sem dados de terceiros.')
            decide(photos[0])
            assert total() == 13
            assert ContributionPointEvent.objects.get(user=owner, action='photo_evidence').pk == event.pk
            record('Safe rejection reason, private moderator notes and correction restore the same +3 event')

            gallery.context.close()
            gallery = owner_gallery()
            gallery.get_by_role('button', name='Ações da foto', exact=True).first.evaluate('(e)=>e.click()')
            click(gallery, 'Remover minha foto', 'menuitem')
            click(gallery, 'Remover')
            assert total() == 10 and active_bonus() == 0
            assert anonymous.get(asset_url).status == 404
            record('Removing last approved photograph revokes +3 and blocks the known URL')
            gallery.context.close()
            standalone = context().new_page()
            login(standalone, reader_user.nome)
            click(standalone, 'Avaliar')
            click(standalone, 'Apenas informar acessibilidade, sem estrelas')
            answer(standalone, 'Atendimento em Libras', 'Não sei')
            click(standalone, 'Revisar')
            with standalone.expect_response(
                    lambda r: '/api/evidencias/relatos/' in r.url and r.request.method == 'POST') as saved:
                click(standalone, 'Confirmar publicação')
            assert saved.value.status in (200, 201)
            assert ModalAvaliacao.objects.filter(user=reader_user).count() == 0
            assert ResourceEvidence.objects.filter(
                owner=reader_user, resource='atendimento_libras', kind='observation').count() == 1
            record('Independent report is saved from the real editor without stars, review or prior evidence')

            standalone.context.close()
            stars = context().new_page()
            login(stars, 'cards47-stars')
            click(stars, 'Avaliar')
            click(stars, '3 estrelas')
            click(stars, 'Revisar e publicar')
            with stars.expect_response(
                    lambda r: '/api/avaliacoes/modal-avaliacoes/' in r.url and r.request.method == 'POST') as saved:
                click(stars, 'Confirmar publicação')
            assert saved.value.status == 201
            simple = ModalAvaliacao.objects.get(user__nome='cards47-stars')
            assert simple.answers == {} and not simple.photos.exists() and simple.comentario == ''
            record('Stars-only review publishes without requiring resources, comment or photographs')
            before = PointActivity.objects.count()
            call_command('reconcile_contributions', apply=True, verbosity=0)
            call_command('reconcile_contributions', apply=True, verbosity=0)
            assert total() == 10 and PointActivity.objects.count() == before
            record('Two real contribution reconciliations keep the ledger and point total unchanged')
            report['points_final'] = total()
            report['status'] = 'passed'
        except Exception as error:
            report['status'] = 'failed'
            report['failure'] = re.sub(r'Token [a-fA-F0-9]+', 'Token [REDACTED]',
                                       f'{type(error).__name__}: {error}')[:3000]
            # Synthetic semantic tree only; never screenshots, real credentials or response bodies.
            current = active_page[0] or page
            if not current.is_closed():
                report['last_semantics'] = current.locator('body').inner_text()[-18000:]

            raise
        finally:
            report['calls'] = calls
            report['finished_at'] = datetime.now(timezone.utc).isoformat()
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')


if __name__ == '__main__':
    main()
