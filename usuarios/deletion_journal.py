"""Durable independent deletion receipts prevent resurrection from older backups.

An unresolved intent blocks restoration rather than guessing whether deletion
committed. Reconciliation must use the authoritative live database.
"""
import json
import os
from pathlib import Path
import tempfile
import uuid

from django.conf import settings
from django.utils import timezone


def sync_directory(root):
    if os.name != "nt":
        descriptor = os.open(root, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(descriptor)
        finally:
            os.close(descriptor)


def journal_identity(initialize=False):
    """An absent/replaced journal must not look like an empty valid journal."""
    root = Path(settings.DELETION_JOURNAL_DIR)
    if initialize:
        root.mkdir(parents=True, exist_ok=True, mode=0o700)
    if not root.is_dir() or root.is_symlink():
        raise OSError("Independent deletion journal unavailable.")
    marker = root / "JOURNAL_ID"
    if initialize and not marker.exists():
        fd, temporary = tempfile.mkstemp(dir=root, prefix=".identity-")
        try:
            with os.fdopen(fd, "w", encoding="ascii") as handle:
                handle.write(str(uuid.uuid4()))
                handle.flush()
                os.fsync(handle.fileno())
            try:
                os.link(temporary, marker)  # Exclusive: never replace a concurrent initialization.
            except FileExistsError:
                pass
            sync_directory(root)
        finally:
            Path(temporary).unlink(missing_ok=True)
    if marker.is_symlink() or not marker.is_file() or marker.stat().st_size != 36:
        raise OSError("Deletion journal identity unavailable.")
    identity = marker.read_text(encoding="ascii")
    if str(uuid.UUID(identity)) != identity:
        raise ValueError("Invalid deletion journal identity.")
    return identity


def journal_document(receipt, state):
    return {"format_version": 1, "operation_id": str(receipt.operation_id),
            "privacy_id": str(receipt.privacy_id), "deleted_at": receipt.deleted_at.isoformat(), "state": state}


def write_receipt(receipt, state):
    journal_identity(initialize=settings.APP_ENV != "staging")
    root = Path(settings.DELETION_JOURNAL_DIR)
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    if root.is_symlink():
        raise OSError("Deletion journal must not be a symbolic link.")
    target = root / f"{receipt.operation_id}.json"
    fd, temporary = tempfile.mkstemp(dir=root, prefix=".receipt-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(journal_document(receipt, state), handle, separators=(",", ":"))
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, target)
        # Windows has no directory fsync. NTFS atomic replacement is used there;
        # staging uses Linux with an independently persisted, protected volume.
        sync_directory(root)
    finally:
        Path(temporary).unlink(missing_ok=True)


def read_receipts():
    journal_identity()
    root = Path(settings.DELETION_JOURNAL_DIR)
    if not root.is_dir() or root.is_symlink():
        raise ValueError("Independent deletion journal unavailable.")
    records = []
    for path in sorted(root.glob("*.json")):
        if path.is_symlink() or path.stat().st_size > 2048:
            raise ValueError("Invalid deletion receipt.")
        record = json.loads(path.read_text(encoding="utf-8"))
        if record.get("format_version") != 1 or record.get("state") not in {"pending", "committed", "cancelled"}:
            raise ValueError("Invalid deletion receipt.")
        uuid.UUID(record["privacy_id"])
        if str(uuid.UUID(record["operation_id"])) != path.stem:
            raise ValueError("Invalid deletion receipt identity.")
        if timezone.datetime.fromisoformat(record["deleted_at"]).tzinfo is None:
            raise ValueError("Invalid deletion receipt date.")
        records.append(record)
    return records
