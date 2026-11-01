#!/usr/bin/env python3
"""Cards 59–61: actual compiled main.dart.js + disposable Django/SQLite.

Build with API_BASE_URL=http://127.0.0.1:8001 --no-web-resources-cdn.
OSRM and GPS are controlled fixtures. Google Search uses a trusted pointer,
native window.open and a real HTTPS attempt; provider loading is reported apart.
"""

import argparse
from contextlib import ExitStack
from datetime import datetime, timezone
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import sys
import tempfile
from threading import Thread
from urllib.parse import urlparse, urlsplit, parse_qs
from wsgiref.simple_server import make_server


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--chrome", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[2]
    args.report.parent.mkdir(parents=True, exist_ok=True)
    report = {
        "started_at": datetime.now(timezone.utc).isoformat(),
        "status": "running",
        "scope": "Compiled Flutter release + real Django/SQLite + synthetic user/places",
        "controlled": ["Browser geolocation", "OSRM response", "External map tiles disabled"],
        "pending": [
            "Physical Android and predictive Back",
            "Real mobile Chrome",
            "Installed Google Maps/Waze",
            "Human screen reader",
            "PostgreSQL/Redis CI",
        ],
        "steps": [],
    }

    def save():
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    def record(name, **details):
        report["steps"].append({"name": name, "status": "passed", **details})
        print(name, flush=True)
        save()

    with ExitStack() as stack:
        temporary = Path(stack.enter_context(tempfile.TemporaryDirectory(prefix="acessoja-routes-")))
        os.environ.update(
            DJANGO_SETTINGS_MODULE="acessoja.settings",
            DJANGO_ALLOW_ASYNC_UNSAFE="true",
            SECRET_KEY="synthetic-route-browser-lab-only",
            DEBUG="True",
            DATABASE_URL=f"sqlite:///{temporary}/db.sqlite3",
            ALLOWED_HOSTS="127.0.0.1,localhost",
            CORS_ALLOWED_ORIGINS="http://127.0.0.1:8002",
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
        from locais.models import Local, RouteHistorySession, VisitaRecente
        from usuarios.models import Usuario
        from favoritos.models import Favorito
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
        viewer = Usuario.objects.create_user("rotas-teste", "SyntheticOnly!59", email="routes@example.invalid")
        place = Local.objects.create(
            nome="Biblioteca das Rotas",
            endereco="Rua Sintética, 59",
            distancia=0,
            latitude=-16.327,
            longitude=-48.9531,
            categoria="educacao",
        )
        Favorito.objects.create(user=viewer, local=place)

        class QuietWSGI(WSGIRequestHandler):
            def log_message(self, *args):
                pass

        class QuietFiles(SimpleHTTPRequestHandler):
            def __init__(self, *values, **kwargs):
                super().__init__(*values, directory=str(project / "frontend/build/web"), **kwargs)

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
        context = browser.new_context(
            locale="pt-BR",
            viewport={"width": 1280, "height": 900},
            geolocation={"latitude": -16.3267, "longitude": -48.9528, "accuracy": 5},
            permissions=["geolocation"],
        )
        stack.callback(context.close)
        context.set_default_timeout(15000)
        context.add_init_script("""localStorage.setItem('flutter.onboarding_completed','true');
          window.__launches=[]; const originalOpen=window.open;
          window.open=function(url,target,features){
            const row={url:String(url),active:navigator.userActivation.isActive,features:String(features)};
            window.__launches.push(row); const result=originalOpen.call(this,url,target,features);
            row.returnedWindow=!!result; return result;
          };""")

        def network(route):
            host = urlparse(route.request.url).hostname
            if host in {"127.0.0.1", "localhost", "www.google.com"}:
                route.continue_()
            elif host == "router.project-osrm.org":
                pairs = urlsplit(route.request.url).path.split("/")[-1].split(";")
                start, end = [[float(n) for n in pair.split(",")] for pair in pairs]
                steps = [
                    {
                        "distance": 1100,
                        "duration": 120,
                        "name": "Rua Sintética",
                        "maneuver": {"type": "depart", "modifier": "straight", "location": start},
                    },
                    {"distance": 0, "duration": 0, "name": "", "maneuver": {"type": "arrive", "location": end}},
                ]
                route.fulfill(
                    json={
                        "code": "Ok",
                        "routes": [
                            {
                                "distance": 1100,
                                "duration": 120,
                                "geometry": {"type": "LineString", "coordinates": [start, end]},
                                "legs": [{"steps": steps}],
                            }
                        ],
                    }
                )
            else:
                route.abort()

        context.route("**/*", network)
        page = context.new_page()
        errors, calls = [], []
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.on(
            "request",
            lambda request: (
                calls.append({"method": request.method, "path": urlparse(request.url).path})
                if "/api/" in request.url
                else None
            ),
        )

        def click(name, role="button"):
            target = page.get_by_role(role, name=name, exact=True).first
            target.wait_for(state="attached")
            target.evaluate("(element) => element.click()")
            page.wait_for_timeout(350)

        def capture(name):
            path = args.report.parent / f"{name}.png"
            page.screenshot(path=str(path))
            return path.name

        def input_text(label, text):
            field = page.locator(f'input[aria-label="{label}"]:not([disabled])')
            field.click()
            page.wait_for_timeout(200)
            page.keyboard.press("ControlOrMeta+A")
            page.keyboard.type(text, delay=15)
            page.wait_for_timeout(450)

        try:
            page.goto("http://127.0.0.1:8002/")
            page.locator("flt-semantics-placeholder").wait_for(state="attached", timeout=30000)
            page.locator("flt-semantics-placeholder").evaluate("(element) => element.click()")
            input_text("Usuário", viewer.nome)
            input_text("Senha", "SyntheticOnly!59")
            click("Entrar")
            page.get_by_role("tab", name="Avaliar", exact=True).wait_for(timeout=25000)
            page.wait_for_timeout(5000)
            record("Login real e mapa disponível")
            click("Lista dos resultados do mapa")
            target = page.get_by_role("button", name=re.compile("^Biblioteca das Rotas")).first
            target.evaluate("(element) => element.click()")
            page.wait_for_timeout(500)
            click("Expandir informações")
            record(
                "CT001 CT075 consulta junto ao endereço no painel expandido", screenshot=capture("01_endereco_consulta")
            )
            target = page.get_by_role("button", name="Ver local no Google Maps", exact=True).first
            box = target.bounding_box()
            assert box and box["height"] >= 48, box
            with context.expect_page() as pending:
                page.mouse.click(box["x"] + box["width"] / 2, box["y"] + box["height"] / 2)
            popup = pending.value
            popup.wait_for_timeout(1200)
            launches = page.evaluate("window.__launches")
            assert launches and launches[-1]["active"], launches
            assert "noopener" in launches[-1]["features"], launches
            uri = urlparse(launches[-1]["url"])
            assert uri.hostname == "www.google.com" and uri.path == "/maps/search/"
            assert parse_qs(uri.query) == {"api": ["1"], "query": ["Biblioteca das Rotas, Rua Sintética, 59"]}
            report["external_launch"] = {
                "uri": launches[-1]["url"],
                "trusted_activation": True,
                "native_window_returned": launches[-1]["returnedWindow"],
                "popup_observed": True,
                "popup_url": popup.url,
                "noopener": True,
                "provider_page_loaded": False if popup.url.startswith("chrome-error:") else None,
                "provider_load_observation": "Provider rendering is not certified; inspect popup_url separately.",
                "note": (
                    "Trusted popup is observed. noopener can return null despite success. "
                    "Provider rendering, installed apps and business identity are not certified."
                ),
            }
            popup.close()
            page.bring_to_front()
            assert RouteHistorySession.objects.count() == 0 and VisitaRecente.objects.count() == 0
            record("CT059 CT071 CT072 gesto de ponteiro abriu Search nativo, sem histórico ou visita")
            click("Rota")
            page.get_by_text("Escolha um ponto ou atualize sua localização", exact=True).wait_for()
            record("CT017 planejamento antes de iniciar", screenshot=capture("02_planejamento"))
            click("Cancelar rota")
            page.get_by_role("button", name="Ver local no Google Maps", exact=True).wait_for()
            record("CT002 retorno ao mesmo painel expandido", screenshot=capture("03_retorno_painel"))
            page.keyboard.press("Escape")
            page.wait_for_timeout(350)
            page.keyboard.press("Escape")
            page.wait_for_timeout(350)
            click("Locais Salvos", "tab")
            input_text("Buscar nos favoritos", "Biblioteca")
            # Existing LocalCard exposes the detail action as reviews-of semantics.
            target = page.get_by_role("button", name=re.compile("^Abrir avaliações de Biblioteca")).first
            target.wait_for(state="attached")
            target.get_by_role("button").last.evaluate("(element) => element.click()")
            page.wait_for_timeout(500)
            for index in range(2):
                target = page.get_by_role("button", name=re.compile("^Planejar rota para Biblioteca")).first
                target.get_by_role("button").last.evaluate("(element) => element.click()")
                page.wait_for_timeout(500)
                if index == 0:
                    click("Cancelar rota")
                else:
                    click("Atualizar localização")
                    click("Calcular rota")
                    click("Iniciar navegação")
                    page.get_by_text("Navegação ativa", exact=True).wait_for()
                    record(
                        "CT084 acompanhamento Web com GPS emulado e histórico desligado",
                        screenshot=capture("07_navegacao_web"),
                    )
                    page.keyboard.press("Escape")
                    page.wait_for_timeout(350)
                    page.get_by_role("alertdialog").wait_for()
                    record("CT021 CT091 Escape abre confirmação de saída", screenshot=capture("08_confirmacao"))
                    click("Continuar navegando")
                    page.get_by_text("Navegação ativa", exact=True).wait_for()
                    page.keyboard.press("Escape")
                    page.wait_for_timeout(350)
                    click("Encerrar e voltar")
                page.get_by_role("button", name=re.compile("^Planejar rota para Biblioteca")).first.wait_for()
                record(f"CT004 CT016 detalhes preservados após rota {index+1}")
            record("Detalhe preservado e consulta única no endereço", screenshot=capture("04_detalhe_retorno"))
            click("Voltar")
            field = page.locator('input[aria-label="Buscar nos favoritos"]')
            field.click()
            page.wait_for_timeout(250)
            assert field.input_value() == "Biblioteca"
            record("CT004 busca original de Salvos preservada", screenshot=capture("05_salvos_busca"))
            page.set_viewport_size({"width": 390, "height": 844})
            page.wait_for_timeout(500)
            record("Viewport móvel emulado: Salvos preservado", screenshot=capture("06_mobile_salvos"))
            page.reload()
            page.wait_for_timeout(1800)
            assert not page.get_by_text("Em navegação", exact=True).count()
            assert RouteHistorySession.objects.count() == 0 and VisitaRecente.objects.count() == 0
            record("CT099 reload não ressuscita navegação ou histórico")
            assert not errors, errors
            report.update(
                status="passed",
                page_errors=errors,
                api_requests=calls,
                history_rows=0,
                visit_rows=0,
                persisted_source_places=Local.objects.count(),
            )
        except Exception as error:
            report.update(status="failed", failure=f"{type(error).__name__}: {error}", page_errors=errors)
            page.screenshot(path=str(args.report.parent / "failure.png"))
            (args.report.parent / "failure_semantics.txt").write_text(
                page.locator("body").aria_snapshot(), encoding="utf-8"
            )
            raise
        finally:
            save()


if __name__ == "__main__":
    main()
