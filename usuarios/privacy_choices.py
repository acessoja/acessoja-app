"""Functional preferences and purpose-specific consent are separate concepts."""
from django.conf import settings

from .models import PrivacyConsent

PURPOSES = {
    "route_history": {
        "title": "Guardar meu histórico de rotas",
        "description": "Guardar destinos, horários e estimativas das navegações iniciadas para consultar depois. "
                       "É privado. Desligar impede novas gravações; você pode apagar os registros já guardados.",
    },
    "route_origin": {
        "title": "Guardar a origem aproximada",
        "description": "Opcional dentro do histórico. Arredonda a origem para cerca de 1 km e permite consultá-la "
                       "depois. Não publica sua posição nem substitui a permissão de GPS do dispositivo.",
    },
}


def consent_record(user, purpose):
    return PrivacyConsent.objects.filter(user=user, purpose=purpose).order_by("-recorded_at", "-pk").first()


def choice_enabled(user, purpose):
    enabled = user.save_route_history if purpose == "route_history" else user.save_route_origin
    record = consent_record(user, purpose)
    return bool(enabled and record and record.granted)


def record_choice(user, purpose, granted):
    previous = consent_record(user, purpose)
    if previous and previous.granted == granted and previous.notice_version == settings.PRIVACY_NOTICE_VERSION:
        return False
    PrivacyConsent.objects.create(user=user, purpose=purpose, granted=granted,
                                  notice_version=settings.PRIVACY_NOTICE_VERSION)
    return True


def choices_document(user):
    choices = []
    for purpose, description in PURPOSES.items():
        record = consent_record(user, purpose)
        legacy = user.save_route_history if purpose == "route_history" else user.save_route_origin
        choices.append({"purpose": purpose, **description, "enabled": choice_enabled(user, purpose),
                        "state": ("granted" if record.granted else "revoked") if record else "not_recorded",
                        "legacy_choice": bool(legacy and not record),
                        "notice_version": record.notice_version if record else None,
                        "recorded_at": record.recorded_at if record else None})
    return {"notice_version": settings.PRIVACY_NOTICE_VERSION, "choices": choices}
