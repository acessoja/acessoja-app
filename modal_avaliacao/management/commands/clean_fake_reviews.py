"""Safely remove development reviews and their derived accessibility records."""

import hashlib
import sqlite3
from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.db import connection, transaction
from django.db.models import Q
from django.utils import timezone

from contribuicoes.models import (
    ContributionPointEvent,
    PointActivity,
    ReportRewardAttribution,
    UserAchievement,
)
from contribuicoes.services import reconcile_user
from evidencias.models import (
    ContentReport,
    EvidenceConfirmation,
    EvidenceRevision,
    ResourceEvidence,
    ReviewRevision,
)
from locais.models import Local
from modal_avaliacao.models import ModalAvaliacao, ReviewOperation
from midia.models import ImageAsset, ImageOperation, PhotoRevision, ReviewPhoto
from usuarios.models import Usuario


class Command(BaseCommand):
    help = "Dry-run by default; with --execute, back up and remove development reviews only."

    def add_arguments(self, parser):
        parser.add_argument("--execute", action="store_true")
        parser.add_argument("--backup-path")

    def _assert_development_sqlite(self):
        database = Path(connection.settings_dict["NAME"]).resolve()
        base = Path(settings.BASE_DIR).resolve()
        if (
            not settings.DEBUG
            or connection.vendor != "sqlite"
            or database.parent != base
            or database.name != "db.sqlite3"
        ):
            raise CommandError(
                "Refusing cleanup: this command requires DEBUG=True and BASE_DIR/db.sqlite3."
            )
        return database, base

    def _scope(self):
        review_ids = list(ModalAvaliacao.objects.order_by("pk").values_list("pk", flat=True))
        evidence_ids = list(
            ResourceEvidence.objects.filter(review_id__in=review_ids, kind="review")
            .order_by("pk")
            .values_list("pk", flat=True)
        )
        evidence_revision_ids = list(
            EvidenceRevision.objects.filter(evidence_id__in=evidence_ids)
            .order_by("pk")
            .values_list("pk", flat=True)
        )
        review_revision_ids = list(
            ReviewRevision.objects.filter(review_id__in=review_ids)
            .order_by("pk")
            .values_list("pk", flat=True)
        )
        report_filter = Q(review_revision_id__in=review_revision_ids)
        if evidence_ids:
            report_filter |= Q(evidence_id__in=evidence_ids)
        if evidence_revision_ids:
            report_filter |= Q(evidence_revision_id__in=evidence_revision_ids)
        report_ids = list(
            ContentReport.objects.filter(report_filter)
            .order_by("protocol")
            .values_list("protocol", flat=True)
        )
        photo_revision_ids = list(
            PhotoRevision.objects.filter(photo__review_id__in=review_ids)
            .order_by("pk")
            .values_list("pk", flat=True)
        )
        asset_ids = list(
            PhotoRevision.objects.filter(pk__in=photo_revision_ids)
            .values_list("asset_id", flat=True)
            .distinct()
        )
        user_ids = sorted(set(ModalAvaliacao.objects.filter(pk__in=review_ids).values_list("user_id", flat=True)))
        local_ids = sorted(set(ModalAvaliacao.objects.filter(pk__in=review_ids).values_list("local_id", flat=True)))
        return {
            "review_ids": review_ids,
            "evidence_ids": evidence_ids,
            "evidence_revision_ids": evidence_revision_ids,
            "review_revision_ids": review_revision_ids,
            "report_ids": report_ids,
            "photo_revision_ids": photo_revision_ids,
            "asset_ids": asset_ids,
            "user_ids": user_ids,
            "local_ids": local_ids,
        }

    def _counts(self, scope):
        reviews = scope["review_ids"]
        evidence = scope["evidence_ids"]
        evidence_revisions = scope["evidence_revision_ids"]
        review_revisions = scope["review_revision_ids"]
        reports = scope["report_ids"]
        photo_revisions = scope["photo_revision_ids"]
        return {
            "ModalAvaliacao": len(reviews),
            "ReviewPhoto (deleted with reviews)": ReviewPhoto.objects.filter(review_id__in=reviews).count(),
            "ImageOperation (preserved, review reference cleared)": (
                ImageOperation.objects.filter(review_id__in=reviews).count()
            ),
            "ReviewRevision (removed snapshot)": len(review_revisions),
            "ResourceEvidence kind=review (removed derived evidence)": len(evidence),
            "EvidenceRevision (removed with review evidence)": len(evidence_revisions),
            "EvidenceConfirmation (removed with review evidence)": EvidenceConfirmation.objects.filter(
                revision_id__in=evidence_revisions
            ).count(),
            "ContentReport (closed, audit retained)": len(reports),
            "ReportRewardAttribution (preserved, review link cleared)": ReportRewardAttribution.objects.filter(
                review_id__in=reviews
            ).count(),
            "ContributionPointEvent (preserved, eligibility reconciled)": ContributionPointEvent.objects.filter(
                evaluation_id__in=reviews
            ).count(),
            "PointActivity (preserved ledger history)": PointActivity.objects.filter(
                event__evaluation_id__in=reviews
            ).count(),
            "ReviewOperation (preserved idempotency receipts)": ReviewOperation.objects.filter(
                review_id__in=reviews
            ).count(),
            "PhotoRevision (detached and preserved)": len(photo_revisions),
            "ImageAsset (preserved; no physical files removed)": len(scope["asset_ids"]),
            "UserAchievement (reconciled, not bulk-deleted)": UserAchievement.objects.filter(
                user_id__in=scope["user_ids"]
            ).count(),
            "Local (preserved)": Local.objects.filter(pk__in=scope["local_ids"]).count(),
            "Usuario (preserved)": Usuario.objects.filter(pk__in=scope["user_ids"]).count(),
        }

    def _backup(self, raw_connection, backup_path, base, database, expected_tables):
        if not backup_path:
            raise CommandError("--execute requires --backup-path outside the repository.")
        target = Path(backup_path).expanduser().resolve()
        if target == database or target.is_relative_to(base):
            raise CommandError("Backup must be outside the project and different from the live database.")
        if target.exists() or not target.parent.exists():
            raise CommandError("Backup path must not exist and its parent directory must already exist.")
        if target.suffix.lower() not in {".sqlite3", ".db"}:
            raise CommandError("Backup path must end in .sqlite3 or .db.")
        destination = sqlite3.connect(str(target))
        try:
            raw_connection.backup(destination)
            result = destination.execute("PRAGMA quick_check").fetchone()
            if not result or result[0] != "ok":
                raise CommandError("SQLite backup failed integrity verification.")
            for table in expected_tables:
                quoted = '"' + table.replace('"', '""') + '"'
                if destination.execute(f"SELECT COUNT(*) FROM {quoted}").fetchone()[0] != raw_connection.execute(
                    f"SELECT COUNT(*) FROM {quoted}"
                ).fetchone()[0]:
                    raise CommandError(f"Backup row count mismatch for {table}.")
        except Exception:
            destination.close()
            target.unlink(missing_ok=True)
            raise
        destination.close()
        digest = hashlib.sha256(target.read_bytes()).hexdigest()
        self.stdout.write(f"Verified SQLite backup: {target} (sha256 {digest})")
        return target

    def handle(self, *args, **options):
        scope = self._scope()
        counts = self._counts(scope)
        self.stdout.write("Review cleanup scope (no mutations unless --execute is supplied):")
        for name, count in counts.items():
            self.stdout.write(f"  {name}: {count}")
        if not options["execute"]:
            self.stdout.write(self.style.WARNING("Dry-run only. No records changed."))
            return

        database, base = self._assert_development_sqlite()
        if not scope["review_ids"]:
            self.stdout.write(self.style.SUCCESS("No reviews to clean; database is unchanged."))
            return
        connection.ensure_connection()
        expected_tables = sorted(
            {
                model._meta.db_table
                for model in (
                    ModalAvaliacao,
                    ReviewPhoto,
                    ImageOperation,
                    ReviewRevision,
                    ResourceEvidence,
                    EvidenceRevision,
                    EvidenceConfirmation,
                    ContentReport,
                    ReportRewardAttribution,
                    ContributionPointEvent,
                    PointActivity,
                    ReviewOperation,
                    PhotoRevision,
                    ImageAsset,
                    UserAchievement,
                    Local,
                    Usuario,
                )
            }
        )
        self._backup(connection.connection, options.get("backup_path"), base, database, expected_tables)

        now = timezone.now()
        with transaction.atomic(using=connection.alias):
            ContentReport.objects.filter(protocol__in=scope["report_ids"]).update(
                state="closed", outcome="target_removed", updated_at=now
            )
            ReportRewardAttribution.objects.filter(review_id__in=scope["review_ids"]).update(review=None)
            ResourceEvidence.objects.filter(
                pk__in=scope["evidence_ids"], kind="review", review_id__in=scope["review_ids"]
            ).delete()
            ReviewRevision.objects.filter(pk__in=scope["review_revision_ids"]).delete()
            ModalAvaliacao.objects.filter(pk__in=scope["review_ids"]).delete()
            for user_id in scope["user_ids"]:
                reconcile_user(user_id, apply=True)

            if ModalAvaliacao.objects.filter(pk__in=scope["review_ids"]).exists():
                raise CommandError("Review rows remain after cleanup; transaction rolled back.")
            if ResourceEvidence.objects.filter(pk__in=scope["evidence_ids"]).exists():
                raise CommandError("Review-derived evidence remains; transaction rolled back.")

        self.stdout.write(self.style.SUCCESS(
            "Reviews and derived review evidence removed. Users, places, independent evidence, point history, "
            "operation receipts, report decisions, detached photo revisions, and physical media were preserved."
        ))
