"""Deployment diagnosis without external traffic unless --probe is explicitly selected."""

import json
import uuid

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from locais.services.external_places_service import geocode, validate_geocoder_configuration
from locais.services.geographic_runtime import (
    ExternalServiceError,
    ProviderGate,
    coordination_mode,
    validate_budgets,
)


class Command(BaseCommand):
    help = "Verifica configuração geográfica sem rede. --probe faz uma única pesquisa explícita."

    def add_arguments(self, parser):
        parser.add_argument("--probe", action="store_true")
        parser.add_argument("--query", default="")
        parser.add_argument("--check-cache", action="store_true")
        parser.add_argument("--require-geocoder", action="store_true")

    def handle(self, *args, **options):
        try:
            validate_budgets()
            mode = coordination_mode()
            config = validate_geocoder_configuration() if settings.NOMINATIM_URL else {"configured": False}
            result = {
                "geocoder": config,
                "coordination": mode,
                "cache_checked": False,
                "network_probe": False,
                "connect_seconds": settings.GEO_CONNECT_TIMEOUT,
                "read_seconds": settings.GEO_READ_TIMEOUT,
                "total_seconds": settings.GEO_TOTAL_TIMEOUT,
                "fresh_seconds": settings.EXTERNAL_PLACES_CACHE_SECONDS,
                "max_age_seconds": settings.EXTERNAL_PLACES_MAX_AGE_SECONDS,
                "local_mode_note": (
                    "um processo" if mode == "process" else "Redis compartilhado, líder de escrita"
                ),
            }
            if options["require_geocoder"] and not config["configured"]:
                raise CommandError("Geocodificador desativado. Configure uma base Nominatim JSONv2 compatível.")
            if options["check_cache"]:
                gate = ProviderGate("configuration-check", settings.OVERPASS_URL, uuid.uuid4().hex)
                gate.acquire()
                gate.release(0)
                result["cache_checked"] = True
            if options["probe"]:
                if not options["query"].strip():
                    raise CommandError("--probe exige --query com um local público não pessoal.")
                rows = geocode({"q": options["query"].strip()})
                result.update(network_probe=True, candidates=len(rows), kinds=sorted({r["kind"] for r in rows}))
            self.stdout.write(json.dumps(result, ensure_ascii=False, sort_keys=True))
        except ExternalServiceError as exc:
            raise CommandError(f"{exc.code}: {exc.detail}") from None
