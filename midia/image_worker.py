"""Separate bounded decoder. No Django, credentials, public originals or arbitrary formats."""

import json
import os
from pathlib import Path
import sys
import warnings


def run(directory, purpose, suffix, declared_mime):
    from PIL import Image, ImageOps

    Image.MAX_IMAGE_PIXELS = 24_000_000
    warnings.simplefilter("error", Image.DecompressionBombWarning)
    allowed = {
        "JPEG": ({".jpg", ".jpeg"}, "image/jpeg"),
        "PNG": ({".png"}, "image/png"),
        "WEBP": ({".webp"}, "image/webp"),
    }
    source = Path(directory) / "input"
    with Image.open(source, formats=list(allowed)) as probe:
        fmt = probe.format
        extensions, mime = allowed[fmt]
        if suffix not in extensions or declared_mime not in {"", "application/octet-stream", mime}:
            raise ValueError("format")
        width, height = probe.size
        if (
            min(width, height) < 1
            or max(width, height) > 12000
            or width * height > 24_000_000
            or getattr(probe, "n_frames", 1) != 1
        ):
            raise ValueError("dimensions")
        probe.verify()
    with Image.open(source, formats=list(allowed)) as source_image:
        source_image.load()
        oriented = ImageOps.exif_transpose(source_image)
        rgba = oriented.convert("RGBA")
        clean = Image.new("RGB", rgba.size, (255, 255, 255))
        clean.paste(rgba, mask=rgba.getchannel("A"))
        clean.thumbnail((512, 512) if purpose == "avatar" else (2048, 2048), Image.Resampling.LANCZOS)
        width, height = clean.size
        clean.save(Path(directory) / "image.jpg", "JPEG", quality=85, exif=b"", icc_profile=None)
        clean.thumbnail((160, 160) if purpose == "avatar" else (320, 320), Image.Resampling.LANCZOS)
        clean.save(Path(directory) / "thumb.jpg", "JPEG", quality=82, exif=b"", icc_profile=None)
    print(json.dumps({"width": width, "height": height}))


if __name__ == "__main__":
    os.umask(0o077)
    try:
        import resource

        resource.setrlimit(resource.RLIMIT_AS, (768 * 1024**2, 768 * 1024**2))
        resource.setrlimit(resource.RLIMIT_CPU, (20, 20))
    except ImportError:  # Windows: byte/pixel checks and parent wall timeout still apply.
        pass
    try:
        run(*sys.argv[1:])
    except Exception:
        sys.exit(2)
