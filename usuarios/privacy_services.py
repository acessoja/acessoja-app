"""Owner-only export and transactional deletion of actual stored categories."""

import json
import logging

from django.conf import settings
from django.contrib.admin.models import LogEntry
from django.contrib.contenttypes.models import ContentType
from django.core.serializers.json import DjangoJSONEncoder
from django.db import DatabaseError, transaction
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from avaliacao.models import AvaliacaoLocal, Local as LegacyLocal
from contribuicoes.models import ContributionPointEvent, PointActivity, UserAchievement
from favoritos.models import Favorito
from locais.models import ManualPlaceRegistration, RouteHistorySession, VisitaRecente
from modal_avaliacao.models import ModalAvaliacao
from .account_services import reauthenticate, revoke_credentials
from .deletion_journal import write_receipt
from .models import AccountDeletionReceipt, PrivacyConsent, Usuario
from .security_throttles import SecurityUnavailable

logger = logging.getLogger("acessoja.security")

PROFILE_FIELDS = [
    "id_usuario",
    "nome",
    "email",
    "nome_completo",
    "telefone",
    "foto_perfil",
    "data_criacao",
    "idioma",
    "unidade_distancia",
    "permitir_sugestoes",
    "impedir_autobloqueio",
    "perfil_publico",
    "mostrar_avaliacoes",
    "compartilhar_localizacao",
    "historico_visivel",
    "accessibility_preferences",
    "save_route_history",
    "save_route_origin",
]


def export_queries(user):
    from evidencias.privacy import own_export_queries
    from midia.privacy import own_export_queries as media_export_queries

    return {
        **media_export_queries(user),
        **own_export_queries(user),
        "admin_activity": LogEntry.objects.filter(user=user).values(
            "action_time", "content_type__app_label", "content_type__model", "object_id", "action_flag"
        ),
        "favorites": Favorito.objects.filter(user=user).values("local_id", "criado_em"),
        "visits": VisitaRecente.objects.filter(user=user).values("local_id", "data_visita", "arrival_confirmed"),
        "route_history": RouteHistorySession.objects.filter(user=user, deleted_at=None).values(
            "session_id",
            "destination_name",
            "destination_source",
            "local_id",
            "external_id",
            "latitude",
            "longitude",
            "origin_latitude",
            "origin_longitude",
            "estimated_distance",
            "estimated_duration",
            "started_at",
            "ended_at",
            "status",
        ),
        "reviews": ModalAvaliacao.objects.filter(user=user).values(
            "id",
            "local_id",
            "estrelas",
            "comentario",
            "data_resposta",
            "questionnaire_version",
            "answers",
            "answer_dates",
            "answer_details",
            "pergunta_1",
            "pergunta_2",
            "pergunta_3",
            "pergunta_4",
            "is_current",
            "is_valid",
        ),
        "points": ContributionPointEvent.objects.filter(user=user).values(
            "local_id", "evaluation_id", "action", "points", "active", "created_at"
        ),
        "point_activity": PointActivity.objects.filter(event__user=user).values(
            "event__local_id", "delta", "created_at", "operation", "reason", "source_evaluation_id"
        ),
        "achievements": UserAchievement.objects.filter(user=user).values("code", "active", "unlocked_at"),
        "consents": PrivacyConsent.objects.filter(user=user).values(
            "purpose", "notice_version", "granted", "recorded_at"
        ),
        "manual_registrations": ManualPlaceRegistration.objects.filter(user=user).values(
            "local_id", "distinct_reason", "created_at"
        ),
        "legacy_establishments": LegacyLocal.objects.filter(user=user).values("id", "nome", "endereco"),
        "legacy_reviews": AvaliacaoLocal.objects.filter(user=user).values(
            "local_id", "comentario", "estrelas", "data_criacao"
        ),
    }


@transaction.atomic
def export_account(user_id, password):
    user = Usuario.objects.select_for_update().get(pk=user_id)
    reauthenticate(user, password)
    remaining = settings.PRIVACY_EXPORT_MAX_ROWS
    categories = {"profile": {field: getattr(user, field) for field in PROFILE_FIELDS}}
    for name, query in export_queries(user).items():
        rows = list(query.order_by("pk")[: remaining + 1])
        if len(rows) > remaining:
            raise ValidationError(
                {
                    "detail": "O volume excede a exportação imediata. Solicite uma exportação assistida "
                    "ao responsável indicado no aviso de privacidade."
                }
            )
        remaining -= len(rows)
        categories[name] = rows
    document = {
        "format_version": "acessoja.personal-data.v1",
        "generated_at": timezone.now(),
        "categories": categories,
        "not_included": [
            {"category": "security_credentials", "reason": "Senhas, hashes e tokens não são exportados."},
            {
                "category": "operational_logs_and_backups",
                "reason": "Não são indexados por conta. "
                "Contate o responsável do piloto para pedidos assistidos; não exponha registros de terceiros.",
            },
            {
                "category": "device_and_external_providers",
                "reason": "Preferências locais do dispositivo e "
                "registros de provedores externos não ficam neste banco. Consulte o aviso de privacidade.",
            },
        ],
    }
    result = json.dumps(document, cls=DjangoJSONEncoder, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    if len(result) > settings.PRIVACY_EXPORT_MAX_BYTES:
        raise ValidationError({"detail": "O arquivo excede o limite imediato. Solicite uma exportação assistida."})
    return result


def erase_relations(user):
    from midia.privacy import erase_user_media

    erase_user_media(user)
    from evidencias.privacy import erase_user_evidence

    erase_user_evidence(user)
    # Invoke the existing review deletion/point reconciliation signals before
    # deleting the owner's ledger. All operations stay in the owner transaction.
    for model, ids in (
        (Usuario, [user.pk]),
        (ModalAvaliacao, ModalAvaliacao.objects.filter(user=user).values_list("pk", flat=True)),
        (AvaliacaoLocal, AvaliacaoLocal.objects.filter(user=user).values_list("pk", flat=True)),
    ):
        content_type = ContentType.objects.get_for_model(model)
        LogEntry.objects.filter(content_type=content_type, object_id__in=[str(pk) for pk in ids]).update(
            object_repr="Registro removido", change_message="[]"
        )
    ModalAvaliacao.objects.filter(user=user).delete()
    # Catalog establishments have no owner FK; legacy creator links are SET_NULL.
    revoke_credentials(user)
    user.delete()


def delete_account(user_id, password):
    receipt = None
    try:
        with transaction.atomic(durable=True):
            user = Usuario.objects.select_for_update().get(pk=user_id)
            reauthenticate(user, password)
            receipt = AccountDeletionReceipt(privacy_id=user.privacy_id)
            # A durable intent precedes the relational change. An unresolved
            # intent blocks any restore until it is reconciled, never guesses.
            write_receipt(receipt, "pending")
            receipt.save()
            erase_relations(user)
    except (ValidationError, Usuario.DoesNotExist):
        raise
    except Exception as error:
        if receipt is not None and not isinstance(error, DatabaseError):
            try:
                write_receipt(receipt, "cancelled")
            except OSError:
                pass  # Still pending: restore must refuse until reconciled.
        raise SecurityUnavailable() from None
    try:
        write_receipt(receipt, "committed")
        AccountDeletionReceipt.objects.filter(pk=receipt.pk).update(published=True)
        published = True
    except Exception:
        # The durable intent and database receipt permit a recoverable retry.
        # 202 is explicitly pending; the UI clears the now invalid client session.
        published = False
    logger.info("privacy_deleted", extra={"security_event": "privacy_deleted"})
    return published
