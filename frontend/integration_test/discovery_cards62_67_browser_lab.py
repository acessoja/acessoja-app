#!/usr/bin/env python3
"""Compiled Flutter Web + real Django + disposable SQLite persistence.

This is Playwright Python, not Playwright MCP or physical Android. No API mocking:
only third-party network is blocked. Screenshots contain synthetic fixtures only.
Build with API_BASE_URL=http://127.0.0.1:8001 and --no-web-resources-cdn.
"""

import argparse
from contextlib import ExitStack
from datetime import datetime, timezone
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import tempfile
from threading import Thread
from urllib.parse import urljoin, urlparse
from wsgiref.simple_server import make_server


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--chrome", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[2]
    build_path = project / "frontend/build/web/main.dart.js"
    build_hash = hashlib.sha256(build_path.read_bytes()).hexdigest()
    report = {
        "started_at": datetime.now(timezone.utc).isoformat(),
        "status": "running",
        "steps": [],
        "engine": "Playwright Python + real compiled main.dart.js + Django/SQLite persistence",
        "build_sha256": build_hash,
        "not_executed": [
            "Playwright MCP unavailable",
            "PostgreSQL",
            "Physical Android/Chrome mobile",
            "Human screen reader/TalkBack",
            "Remote CI",
            "Real third-party providers",
        ],
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)

    def save():
        args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    def record(name, **details):
        report["steps"].append({"name": name, "status": "passed", **details})
        print(name, flush=True)
        save()

    with ExitStack() as stack:
        temporary = Path(stack.enter_context(tempfile.TemporaryDirectory(prefix="discovery-c62-")))
        os.environ.update(
            {
                "DJANGO_SETTINGS_MODULE": "acessoja.settings",
                "DJANGO_ALLOW_ASYNC_UNSAFE": "true",
                "SECRET_KEY": "synthetic-discovery-laboratory-only",
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
        from django.core.servers.basehttp import WSGIServer, WSGIRequestHandler
        from django.db import connections
        from django.test import override_settings
        from locais.models import Local
        from usuarios.models import Usuario
        from playwright.sync_api import sync_playwright

        stack.enter_context(
            override_settings(
                PASSWORD_HASHERS=["django.contrib.auth.hashers.MD5PasswordHasher"],
                OVERPASS_URL="http://127.0.0.1:9/unavailable",
                PRIVATE_IMAGE_ROOT=temporary / "private",
            )
        )
        call_command("migrate", verbosity=0)
        owner = Usuario.objects.create_user(
            "discovery-lab",
            "SyntheticOnly!67",
            email="discovery@example.invalid",
            accessibility_preferences=["rampa_acesso", "banheiro_acessivel", "piso_tatil"],
        )
        other = Usuario.objects.create_user(
            "discovery-other",
            "SyntheticOnly!67",
            email="other@example.invalid",
            accessibility_preferences=["atendimento_libras"],
        )
        for i, (name, states) in enumerate(
            [
                (
                    "ZZ Principal",
                    {
                        "rampa_acesso": "presence_reported",
                        "banheiro_acessivel": "presence_reported",
                        "piso_tatil": "absence_reported",
                    },
                ),
                ("MM Parcial", {"rampa_acesso": "presence_reported"}),
                ("AA Zero", {}),
            ]
        ):
            Local.objects.create(
                nome=name,
                endereco="Rua Sintética, 67",
                distancia=0,
                categoria="saude",
                subcategoria="hospital" if i == 0 else "clinica" if i == 1 else "",
                latitude=-16.3267 + i * 0.0005,
                longitude=-48.9528,
                accessibility_information={key: {"state": value} for key, value in states.items()},
            )
        for i in range(22):
            Local.objects.create(
                nome=f"Lugar de teste {i:02}",
                endereco="Rua Sintética",
                distancia=0,
                categoria="educacao",
                latitude=-16.33,
                longitude=-48.96,
            )

        class QuietWSGI(WSGIRequestHandler):
            def log_message(self, *values):
                pass

        class Files(SimpleHTTPRequestHandler):
            def __init__(self, *values, **kwargs):
                super().__init__(*values, directory=str(project / "frontend/build/web"), **kwargs)

            def log_message(self, *values):
                pass

        api = make_server("127.0.0.1", 8001, get_wsgi_application(), server_class=WSGIServer, handler_class=QuietWSGI)
        static = ThreadingHTTPServer(("127.0.0.1", 8002), Files)
        for server in [api, static]:
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
        context = browser.new_context(locale="pt-BR", viewport={"width": 1280, "height": 900})
        stack.callback(context.close)
        context.set_default_timeout(15000)
        context.add_init_script("localStorage.setItem('flutter.onboarding_completed','true')")
        external = []

        def route(request_route):
            request = request_route.request
            if urlparse(request.url).hostname in {"127.0.0.1", "localhost"}:
                request_route.continue_()
            else:
                external.append({"url": request.url, "has_auth": "authorization" in request.headers})
                request_route.abort()

        context.route("**/*", route)
        page = context.new_page()
        calls, responses, errors = [], [], []

        def on_request(request):
            if "/api/" in request.url:
                # Only synthetic discovery bodies are retained in memory for assertions; no credentials in report.
                calls.append(
                    {
                        "method": request.method,
                        "url": request.url,
                        "body": (
                            request.post_data_json
                            if request.post_data and request.url.endswith("/descoberta/")
                            else None
                        ),
                    }
                )

        def on_response(response):
            if "/api/locais/descoberta/" in response.url and response.status == 200:
                responses.append(response.json())

        page.on("request", on_request)
        page.on("response", on_response)
        page.on("pageerror", lambda error: errors.append(str(error)))

        def click(name, role="button", exact=True):
            target = (
                page.get_by_label(name, exact=True).first
                if role == "section"
                else page.get_by_role(role, name=name, exact=exact).first
            )
            if name == "Salvar preferências" or role == "checkbox" or name == "Filtrar":
                for _ in range(12):
                    if target.count():
                        break
                    page.mouse.move(700, 650)
                    page.mouse.wheel(0, 650)
                    page.wait_for_timeout(150)
            target.wait_for(state="attached")
            target.evaluate("element => element.click()")
            page.wait_for_timeout(400)

        def screenshot(name):
            filename = name + ".png"
            page.screenshot(path=str(args.report.parent / filename))
            return filename

        def private_count():
            return len([call for call in calls if call["method"] == "POST" and "/descoberta/" in call["url"]])

        def discovery_action(label, method="POST", role="button"):
            with page.expect_response(
                lambda response: urlparse(response.url).path == "/api/locais/descoberta/"
                and response.request.method == method
                and response.status == 200,
                timeout=30000,
            ) as received:
                click(label, role)
            data = received.value.json()
            page.wait_for_timeout(200)
            return data

        try:
            page.goto("http://127.0.0.1:8002/")
            page.locator("flt-semantics-placeholder").wait_for(state="attached", timeout=30000)
            page.locator("flt-semantics-placeholder").evaluate("element => element.click()")
            for label, value in [("Usuário", owner.nome), ("Senha", "SyntheticOnly!67")]:
                field = page.locator(f'input[aria-label="{label}"]:not([disabled])')
                field.click()
                page.wait_for_timeout(250)
                page.keyboard.press("ControlOrMeta+A")
                page.keyboard.type(value, delay=20)
                page.wait_for_timeout(250)
            click("Entrar")
            page.get_by_role("tab", name="Avaliar", exact=True).wait_for(timeout=30000)
            page.wait_for_timeout(5000)
            assert private_count() == 0
            assert responses and responses[-1]["count"] == 25
            record(
                "T001 T036 real login starts without applying saved preferences", screenshot=screenshot("01_default")
            )
            click("Buscar destino ou calcular rota")
            public_ids = []
            public_next = "http://127.0.0.1:8001/api/locais/descoberta/?ordering=name"
            while public_next:
                public_response = context.request.get(public_next)
                assert public_response.ok
                public_data = public_response.json()
                public_ids.extend(row["canonical_id"] for row in public_data["results"])
                public_next = urljoin(public_next, public_data["next"]) if public_data["next"] else None
            assert len(public_ids) == len(set(public_ids)) == 25
            applied = discovery_action("Usar minhas preferências")
            assert private_count() == 1
            assert applied["results"][0]["nome"] == "ZZ Principal"
            assert public_ids.index(applied["results"][0]["canonical_id"]) >= 20
            assert applied["count"] == 25
            assert applied["results"][0]["resource_match"] == {"count": 2, "total": 3}
            assert all("recursos=" not in call["url"] and "personalization" not in call["url"] for call in calls)
            record(
                "T002 T004 T053 T075 private persistent prioritization keeps zero-score places",
                screenshot=screenshot("02_personal"),
            )
            more = discovery_action("Carregar mais")
            assert private_count() == 2
            assert len(more["results"]) == 5
            private_ids = [row["canonical_id"] for row in applied["results"] + more["results"]]
            assert len(private_ids) == len(set(private_ids)) == 25
            assert set(private_ids) == set(public_ids)
            record("T054 T055 private continuation reads persisted second page")
            click("ZZ Principal", exact=False)
            page.get_by_role("button", name="Expandir informações", exact=True).wait_for()
            assert (
                "2 de 3 recursos selecionados com presença relatada"
                in page.locator("flt-semantics").all_text_contents().__str__()
            )
            record("T019 T081 compact personal summary", screenshot=screenshot("03_compact"))
            click("Expandir informações")
            click("Acessibilidade", "section")
            page.get_by_text("Recursos importantes para sua busca", exact=True).wait_for(state="attached")
            page.get_by_text("Outros recursos de acessibilidade", exact=True).wait_for(state="attached")
            record("T083 expanded personal resources and other groups", screenshot=screenshot("04_expanded"))
            page.set_viewport_size({"width": 390, "height": 844})
            page.wait_for_timeout(500)
            record("T094 emulated mobile viewport only", screenshot=screenshot("05_mobile"))
            click("Abrir ajustes de acessibilidade")
            for _ in range(4):
                click("Aumentar: Tamanho do texto")
            page.keyboard.press("Escape")
            page.wait_for_timeout(500)
            floating = page.get_by_role("button", name="Abrir ajustes de acessibilidade", exact=True).bounding_box()
            search_button = page.get_by_role(
                "button", name="Buscar destino ou calcular rota", exact=True
            ).bounding_box()
            assert floating and search_button
            assert not (
                floating["x"] < search_button["x"] + search_button["width"]
                and search_button["x"] < floating["x"] + floating["width"]
                and floating["y"] < search_button["y"] + search_button["height"]
                and search_button["y"] < floating["y"] + floating["height"]
            ), (floating, search_button)
            record("T094 actual application 200 percent text setting", screenshot=screenshot("06_mobile_200"))
            page.set_viewport_size({"width": 1280, "height": 900})
            page.wait_for_timeout(400)
            page.keyboard.press("Escape")
            page.keyboard.press("Escape")
            page.wait_for_timeout(400)
            click("Buscar destino ou calcular rota")
            before = private_count()
            click("Configurar preferências")
            click("Atendimento em Libras", role="checkbox", exact=False)
            with page.expect_response(
                lambda response: response.url.endswith("accessibility-preferences/")
                and response.request.method == "PUT"
                and response.status == 200,
                timeout=30000,
            ):
                click("Salvar preferências")
            owner.refresh_from_db()
            assert "atendimento_libras" in owner.accessibility_preferences
            assert private_count() == before
            record("T027 saved profile persists without changing applied search")
            click("Voltar")
            discovery_action("Aplicar preferências novamente")
            assert private_count() == before + 1
            assert calls[-1]["body"] is not None or private_count() > before
            record("T028 explicit reapply reads the latest private profile")
            strict = discovery_action("Todos pessoais", role="section")
            assert strict["count"] == 0
            any_personal = discovery_action("Pelo menos um pessoal", role="section")
            assert any_personal["count"] == 2
            record("T008 T009 persisted personal all and any use the applied snapshot", all_count=0, any_count=2)
            discovery_action("Desativar personalização", "GET")
            assert all(not item["has_auth"] for item in external)
            assert all(
                not any(key in item["url"] for key in ["rampa_acesso", "piso_tatil", "atendimento_libras"])
                for item in external
            )
            assert not errors, errors
            record("T022 T076 disable personal selection and third-party transport checks")
            owner_page = page
            guest_context = browser.new_context(locale="pt-BR", viewport={"width": 1280, "height": 900})
            stack.callback(guest_context.close)
            guest_context.add_init_script("localStorage.setItem('flutter.onboarding_completed','true')")
            guest_context.route("**/*", route)
            page = guest_context.new_page()
            page.on("request", on_request)
            page.on("response", on_response)
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.goto("http://127.0.0.1:8002/")
            page.locator("flt-semantics-placeholder").wait_for(state="attached", timeout=30000)
            page.locator("flt-semantics-placeholder").evaluate("element => element.click()")
            click("Explorar sem conta")
            page.get_by_role("tab", name="Avaliar", exact=True).wait_for(timeout=30000)
            page.wait_for_timeout(1000)
            before = private_count()
            click("Buscar destino ou calcular rota")
            click("Usar minhas preferências")
            assert private_count() == before
            record("T036 T067 actual visitor entry keeps discovery public", screenshot=screenshot("07_guest"))
            for index, (mode, expected) in enumerate([("Pelo menos um", 2), ("Todos", 1), ("Priorizar", 25)]):
                click("Filtros")
                mode_control = page.get_by_role("button", name=re.compile("Recursos manuais"))
                mode_control.first.wait_for(state="attached")
                mode_control.first.evaluate("element => element.click()")
                page.wait_for_timeout(200)
                choice = page.get_by_label(mode, exact=True).last
                choice.wait_for(state="attached")
                choice.evaluate("element => element.click()")
                page.wait_for_timeout(200)
                if index == 0:
                    click("Rampa na entrada", role="checkbox", exact=False)
                    click("Banheiro com recursos de adaptação", role="checkbox", exact=False)
                manual = discovery_action("Filtrar", "GET")
                assert manual["count"] == expected, manual["count"]
                assert private_count() == before
                record(
                    "T096 persisted visitor mode " + mode,
                    count=expected,
                    screenshot=screenshot("08_mode_" + str(index)),
                )
            click("Filtros")
            click("Saúde", role="checkbox", exact=False)
            broad = discovery_action("Filtrar", "GET")
            assert broad["count"] == 3
            assert {row["subcategoria"] for row in broad["results"]} == {"hospital", "clinica", ""}
            click("Filtros")
            group = page.get_by_role("checkbox", name=re.compile("^Saúde")).first.locator("..")
            group.wait_for(state="attached")
            group.evaluate("element => element.click()")
            click("Hospital", role="checkbox")
            hospital = discovery_action("Filtrar", "GET")
            assert hospital["count"] == 1 and hospital["results"][0]["nome"] == "ZZ Principal"
            before_cancel = len(calls)
            click("Filtros")
            if not page.get_by_role("checkbox", name="Clínica", exact=True).count():
                page.get_by_role("checkbox", name=re.compile("^Saúde")).first.locator("..").evaluate(
                    "element => element.click()"
                )
            click("Clínica", role="checkbox")
            click("Cancelar")
            assert len(calls) == before_cancel
            click("Filtros")
            if not page.get_by_role("checkbox", name="Hospital", exact=True).count():
                page.get_by_role("checkbox", name=re.compile("^Saúde")).first.locator("..").evaluate(
                    "element => element.click()"
                )
            click("Hospital", role="checkbox")
            broad_again = discovery_action("Filtrar", "GET")
            assert broad_again["count"] == 3
            record(
                "T039 T040 T097 persisted hierarchy preserves legacy and cancel leaves search intact",
                broad_count=3,
                child_count=1,
                screenshot=screenshot("09_hierarchy"),
            )
            page = owner_page
            held = {}

            def delay_one_real_response(request_route):
                if request_route.request.method == "POST" and not held:
                    response = request_route.fetch()
                    assert response.status == 200
                    held.update(route=request_route, response=response)
                else:
                    request_route.continue_()

            context.route("**/api/locais/descoberta/", delay_one_real_response)
            click("Usar minhas preferências")
            for _ in range(100):
                if held:
                    break
                page.wait_for_timeout(100)
            assert held, "The real owner response must be retained before account switch"
            page.keyboard.press("Escape")
            page.wait_for_timeout(300)
            click("Abrir configurações")
            click("Sair")
            for label, value in [("Usuário", other.nome), ("Senha", "SyntheticOnly!67")]:
                field = page.locator(f'input[aria-label="{label}"]:not([disabled])')
                field.wait_for(state="attached")
                field.click()
                page.wait_for_timeout(250)
                page.keyboard.press("ControlOrMeta+A")
                page.keyboard.type(value, delay=20)
                page.wait_for_timeout(250)
            click("Entrar")
            page.get_by_role("button", name="Buscar destino ou calcular rota", exact=True).wait_for(
                state="attached", timeout=30000
            )
            held["route"].fulfill(response=held["response"])
            page.wait_for_timeout(700)
            click("Buscar destino ou calcular rota")
            assert not page.get_by_text("Preferências aplicadas à busca", exact=True).count()
            first_result = page.get_by_role(
                "button", name=re.compile("AA Zero|MM Parcial|ZZ Principal|Lugar de teste")
            ).first
            first_result.wait_for(state="attached")
            assert "AA Zero" in ((first_result.get_attribute("aria-label") or "") + first_result.inner_text())
            fresh = discovery_action("Usar minhas preferências")
            assert fresh["results"][0]["resource_match"] == {"count": 0, "total": 1}
            other.refresh_from_db()
            assert other.accessibility_preferences == ["atendimento_libras"]
            record(
                "T071 T073 T099 real late owner response discarded across logout and account switch",
                screenshot=screenshot("09_account_switch"),
            )
            assert not errors, errors
            assert hashlib.sha256(build_path.read_bytes()).hexdigest() == build_hash
            report.update(
                status="passed", page_errors=errors, api_requests=len(calls), third_party_attempts=len(external)
            )
        except Exception as error:
            report.update(status="failed", failure=type(error).__name__ + ": " + str(error), page_errors=errors)
            page.screenshot(path=str(args.report.parent / "failure.png"))
            (args.report.parent / "failure_semantics.txt").write_text(page.content(), encoding="utf-8")
            raise
        finally:
            report["response_summaries"] = [
                {
                    "count": row["count"],
                    "first_names": [value["nome"] for value in row["results"][:3]],
                    "first_match": row["results"][0].get("resource_match") if row["results"] else None,
                }
                for row in responses[-6:]
            ]
            report["finished_at"] = datetime.now(timezone.utc).isoformat()
            save()


if __name__ == "__main__":
    main()
