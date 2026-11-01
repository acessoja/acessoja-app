#!/usr/bin/env python3
"""Compiled Flutter + real Django/SQLite; disposable synthetic panel/marker lab.

Build main.dart with --dart-define=API_BASE_URL=http://127.0.0.1:8001
--no-web-resources-cdn. Run --chrome PATH --report PATH.
Captures are requested deliverables and contain synthetic fixtures only.
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
from urllib.parse import urlparse
from wsgiref.simple_server import make_server


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--chrome", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[2]
    web = project / "frontend/build/web"
    report = {
        "started_at": datetime.now(timezone.utc).isoformat(),
        "status": "running",
        "scope": "Actual main.dart.js release + Django API + SQLite/private image storage; synthetic data",
        "input": "Playwright pointer and semantic actions, Escape/Tab; mobile viewport emulation",
        "excluded": [
            "Physical Android/TalkBack",
            "Human screen reader",
            "Real mobile browser",
            "External tiles and routing providers",
            "PostgreSQL/Redis",
        ],
        "steps": [],
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)

    def save():
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    def record(name, **details):
        report["steps"].append({"name": name, "status": "passed", **details})
        print(name, flush=True)
        save()

    with ExitStack() as stack:
        temporary = Path(stack.enter_context(tempfile.TemporaryDirectory(prefix="acessoja-panels-")))
        os.environ.update(
            {
                "DJANGO_SETTINGS_MODULE": "acessoja.settings",
                "DJANGO_ALLOW_ASYNC_UNSAFE": "true",
                "SECRET_KEY": "synthetic-local-panel-lab-only",
                "DEBUG": "True",
                "DATABASE_URL": f"sqlite:///{temporary}/db.sqlite3",
                "ALLOWED_HOSTS": "127.0.0.1,localhost",
                "CORS_ALLOWED_ORIGINS": "http://127.0.0.1:8002",
            }
        )
        sys.path.insert(0, str(project))
        import django

        django.setup()
        from django.core.management import call_command
        from django.core.wsgi import get_wsgi_application
        from django.contrib.staticfiles.handlers import StaticFilesHandler
        from django.core.servers.basehttp import WSGIServer, WSGIRequestHandler
        from django.db import connections
        from django.test import override_settings
        from locais.models import Local
        from modal_avaliacao.models import ModalAvaliacao
        from usuarios.models import Usuario
        from midia.models import ImageAsset, ReviewPhoto, PhotoRevision
        from PIL import Image, ImageDraw
        from playwright.sync_api import sync_playwright

        stack.enter_context(
            override_settings(
                PRIVATE_IMAGE_ROOT=temporary / "private",
                MEDIA_ROOT=temporary / "media",
                DELETION_JOURNAL_DIR=temporary / "journal",
                PASSWORD_HASHERS=["django.contrib.auth.hashers.MD5PasswordHasher"],
                OVERPASS_URL="http://127.0.0.1:9/unavailable",
            )
        )
        call_command("migrate", verbosity=0)
        viewer = Usuario.objects.create_user("painel-teste", "SyntheticOnly!52", email="panel@example.invalid")
        first = Local.objects.create(
            nome="Biblioteca do Painel",
            endereco="Rua Sintética, 52",
            distancia=0,
            latitude=-16.3267,
            longitude=-48.9528,
            categoria="educacao",
        )
        for i in range(3):
            Local.objects.create(
                nome=f"Grupo sintético {i + 1}",
                endereco="Coordenadas coincidentes",
                distancia=0,
                latitude=-16.328,
                longitude=-48.955,
                categoria=["saude", "parque", "banco"][i],
            )
        Local.objects.create(
            nome="Café sem avaliações",
            endereco="Praça de testes",
            distancia=0,
            latitude=-16.325,
            longitude=-48.95,
            categoria="cafeteria",
        )
        for n, answer in enumerate(["yes", "no"]):
            author = Usuario.objects.create_user(f"relato-{n}", "SyntheticOnly!52", email=f"relato-{n}@example.invalid")
            review = ModalAvaliacao.objects.create(
                user=author,
                local=first,
                estrelas=4 + n,
                comentario="Relato público sintético sobre a entrada.",
                verified_author=True,
                questionnaire_version=2,
                answers={"rampa_acesso": answer, "piso_tatil": "unknown"},
            )
            if n == 0:
                for state in ["approved", "pending", "rejected"]:
                    root = temporary / "private" / state
                    root.mkdir(parents=True)
                    image = Image.new("RGB", (360, 180), "#d5e8f0")
                    draw = ImageDraw.Draw(image)
                    draw.rectangle((50, 80, 310, 160), fill="#27627a")
                    draw.text((60, 30), "SYNTHETIC ACCESSIBILITY FIXTURE", fill="#172d3e")
                    for name in ["image.jpg", "thumb.jpg"]:
                        image.save(root / name)
                    asset = ImageAsset.objects.create(
                        owner=author,
                        purpose="photo",
                        state="ready",
                        image_key=f"{state}/image.jpg",
                        thumb_key=f"{state}/thumb.jpg",
                        width=360,
                        height=180,
                    )
                    photo = ReviewPhoto.objects.create(review=review, owner=author)
                    revision = PhotoRevision.objects.create(
                        photo=photo,
                        owner=author,
                        asset=asset,
                        state=state,
                        description=f"Foto sintética {state} da entrada, sem pessoas.",
                    )
                    photo.current_revision = revision
                    photo.save(update_fields=["current_revision"])

        class QuietWSGI(WSGIRequestHandler):
            def log_message(self, *args):
                pass

        class QuietFiles(SimpleHTTPRequestHandler):
            def __init__(self, *values, **kwargs):
                super().__init__(*values, directory=str(web), **kwargs)

            def log_message(self, *args):
                pass

        api = make_server(
            "127.0.0.1",
            8001,
            StaticFilesHandler(get_wsgi_application()),
            server_class=WSGIServer,
            handler_class=QuietWSGI,
        )
        static = ThreadingHTTPServer(("127.0.0.1", 8002), QuietFiles)
        for server in (api, static):
            Thread(target=server.serve_forever, daemon=True).start()
            stack.callback(server.server_close)
            stack.callback(server.shutdown)
        stack.callback(connections.close_all)
        playwright = stack.enter_context(sync_playwright())
        browser = playwright.chromium.launch(
            executable_path=str(args.chrome), headless=True, args=["--no-sandbox", "--disable-dev-shm-usage"]
        )
        stack.callback(browser.close)
        report["browser"] = browser.version
        report["platform"] = sys.platform
        page = None
        calls = []
        errors = []
        try:
            context = browser.new_context(locale="pt-BR", viewport={"width": 1280, "height": 900})
            stack.callback(context.close)
            context.set_default_timeout(15000)
            context.add_init_script("localStorage.setItem('flutter.onboarding_completed','true')")
            context.route(
                "**/*",
                lambda route: (
                    route.continue_()
                    if urlparse(route.request.url).hostname in {"127.0.0.1", "localhost"}
                    else route.abort()
                ),
            )
            page = context.new_page()
            page.on(
                "request",
                lambda request: (
                    calls.append({"method": request.method, "path": urlparse(request.url).path})
                    if "/api/" in request.url
                    else None
                ),
            )
            page.on("pageerror", lambda error: errors.append(str(error)))

            def click(name, role="button"):
                target = (
                    page.get_by_role("button", name=re.compile("^" + re.escape(name))).first
                    if role == "place"
                    else (
                        page.get_by_label(name, exact=True).first
                        if role == "section"
                        else page.get_by_role(role, name=name, exact=True).first
                    )
                )
                target.wait_for(state="attached")
                target.evaluate("(element) => element.click()")
                page.wait_for_timeout(350)

            def capture(name):
                path = args.report.parent / f"{name}.png"
                page.screenshot(path=str(path))
                return path.name

            page.goto("http://127.0.0.1:8002/")
            page.locator("flt-semantics-placeholder").wait_for(state="attached", timeout=30000)
            page.locator("flt-semantics-placeholder").evaluate("(element) => element.click()")
            for label, value in [("Usuário", viewer.nome), ("Senha", "SyntheticOnly!52")]:
                field = page.locator(f'input[aria-label="{label}"]:not([disabled])')
                field.click()
                page.wait_for_timeout(250)
                page.keyboard.press("ControlOrMeta+A")
                page.keyboard.type(value, delay=20)
            click("Entrar")
            page.get_by_role("tab", name="Avaliar", exact=True).wait_for(timeout=25000)
            page.wait_for_timeout(5000)
            record("Real login and map loaded", screenshot=capture("01_mapa_desktop"))
            click("Lista dos resultados do mapa")
            click("Biblioteca do Painel", "place")
            page.get_by_role("button", name="Expandir informações", exact=True).wait_for()
            record("CT-09 CT-17 selection opens one compact persistent panel", screenshot=capture("02_painel_compacto"))
            click("Expandir informações")
            record("CT-10 expanded accessibility surface", screenshot=capture("03_painel_expandido"))
            click("Rampa na entrada", "place")
            click("Ver fontes e histórico")
            record("CT-05 CT-06 genuine source details route", screenshot=capture("04_fontes"))
            page.keyboard.press("Escape")
            page.wait_for_timeout(300)
            # Flutter route back, then two panel Escape levels.
            if page.get_by_role("button", name="Back", exact=True).count():
                click("Back")
            elif page.get_by_role("button", name="Voltar", exact=True).count():
                click("Voltar")
            page.wait_for_timeout(300)
            click("Avaliações e fotos", "section")
            page.wait_for_timeout(1000)
            assert page.get_by_text("Foto sintética approved da entrada, sem pessoas.", exact=True).count() == 1
            assert page.get_by_text("Foto sintética pending da entrada, sem pessoas.", exact=True).count() == 0
            assert page.get_by_text("Foto sintética rejected da entrada, sem pessoas.", exact=True).count() == 0
            record("CT-22 real approved media only", screenshot=capture("05_avaliacoes_fotos_publicas"))
            page.set_viewport_size({"width": 390, "height": 844})
            page.wait_for_timeout(700)
            record(
                "CT-14 CT-44 real compiled panel at emulated mobile viewport", screenshot=capture("06_mobile_expandido")
            )
            click("Abrir ajustes de acessibilidade")
            for _ in range(4):
                click("Aumentar: Tamanho do texto")
            page.keyboard.press("Escape")
            page.wait_for_timeout(350)
            page.wait_for_timeout(600)
            for section, image_name in [
                ("Informações", "09_mobile_200_informacoes"),
                ("Acessibilidade", "10_mobile_200_recursos"),
                ("Avaliações e fotos", "11_mobile_200_fotos"),
            ]:
                page.mouse.move(200, 300)
                page.mouse.wheel(0, -2500)
                page.wait_for_timeout(400)
                click(section, "section")
                record("CT-52 200 percent " + section, screenshot=capture(image_name))
            page.set_viewport_size({"width": 1280, "height": 900})
            page.wait_for_timeout(600)
            record("CT-52 desktop 200 percent", screenshot=capture("12_desktop_200"))
            page.set_viewport_size({"width": 390, "height": 844})
            page.wait_for_timeout(400)
            page.keyboard.press("Escape")
            page.wait_for_timeout(400)
            record("CT-11 Escape collapses panel", screenshot=capture("07_mobile_compacto"))
            click("Fechar resumo")
            assert page.get_by_role("button", name="Fechar resumo", exact=True).count() == 0
            record("CT-11 close restores map", screenshot=capture("08_mobile_fechado"))
            click("5 locais. Abrir agrupamento.", "place")
            record("CT-35 CT-41 real cluster lists coincident members", screenshot=capture("13_agrupamento"))
            click("Grupo sintético 3", "place")
            page.get_by_text("Grupo sintético 3", exact=True).wait_for()
            record("CT-41 select a coincident member", screenshot=capture("14_membro_selecionado"))
            page.keyboard.press("Tab")
            assert page.evaluate("document.activeElement !== document.body")
            record("CT-51 keyboard focus traverses actual web semantics")
            assert not errors, errors
            assert not [r for r in calls if r["method"] == "POST" and r["path"] != "/api/login/"]
            report["api_requests"] = calls
            report["page_errors"] = errors
            report["status"] = "passed"
        except Exception as error:
            report["status"] = "failed"
            report["failure"] = f"{type(error).__name__}: {error}"
            if page is not None:
                page.screenshot(path=str(args.report.parent / "failure.png"))
                (args.report.parent / "failure_semantics.txt").write_text(
                    page.locator("body").aria_snapshot(), encoding="utf-8"
                )
            save()
            raise
        finally:
            save()


if __name__ == "__main__":
    main()
