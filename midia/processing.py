import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading

from django.conf import settings
from .exceptions import ImageRejected, ImageTooLarge, ImageUnavailable

SLOTS = threading.BoundedSemaphore(2)


def read_input(upload):
    if upload.size > settings.IMAGE_MAX_BYTES:
        raise ImageTooLarge()
    content = upload.read(settings.IMAGE_MAX_BYTES + 1)
    if len(content) > settings.IMAGE_MAX_BYTES:
        raise ImageTooLarge()
    if not content:
        raise ImageRejected()
    return content, Path(upload.name).suffix.lower(), (upload.content_type or "").lower()


def process_image(content, suffix, mime, purpose):
    if not SLOTS.acquire(blocking=False):
        raise ImageUnavailable("Processamento ocupado. Aguarde antes de tentar novamente.")
    try:
        with tempfile.TemporaryDirectory(prefix="acessoja-image-") as directory:
            path = Path(directory) / "input"
            path.write_bytes(content)
            path.chmod(0o600)
            worker = subprocess.run(
                [sys.executable, "-m", "midia.image_worker", directory, purpose, suffix, mime],
                capture_output=True,
                timeout=25,
                env={"PATH": os.environ.get("PATH", ""), "PYTHONIOENCODING": "utf-8"},
            )
            if worker.returncode != 0:
                raise ImageRejected()
            data = json.loads(worker.stdout)
            data["image"] = (Path(directory) / "image.jpg").read_bytes()
            data["thumb"] = (Path(directory) / "thumb.jpg").read_bytes()
            data["sha256"] = hashlib.sha256(data["image"]).hexdigest()
            return data
    except (subprocess.TimeoutExpired, ValueError, OSError):
        raise ImageRejected() from None
    finally:
        SLOTS.release()
