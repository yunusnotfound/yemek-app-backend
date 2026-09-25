#!/usr/bin/env python3
"""Generate the small offline fallbacks for CDN artwork; never alter originals.

Requires Pillow with WebP support. The recorded generation environment uses:
    python3 -m pip install Pillow==12.2.0
Run from any directory:
    python3 bitir_yemek_mobile/tool/generate_artwork_previews.py

The explicit list intentionally excludes the unused surprise-package artwork.
Use the recorded Pillow/libwebp versions for byte-identical regeneration.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, __version__ as pillow_version, features


MOBILE_ROOT = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = MOBILE_ROOT.parent
CDN_ROOT = "https://api.bitirgitsin.com/uploads/app-artwork-v1"
PREVIEW_SIZE = (128, 128)
QUALITY = 70
ALPHA_QUALITY = 100
METHOD = 6
ARTWORK = (
    "categories/bufe.webp",
    "categories/firin.webp",
    "categories/kafe.webp",
    "categories/kasap.webp",
    "categories/manav.webp",
    "categories/market.webp",
    "categories/pastane.webp",
    "categories/restoran.webp",
    "onboarding/foodbox-bakery.webp",
    "onboarding/foodbox-dessert.webp",
    "onboarding/foodbox-meal.webp",
    "onboarding/kraft-texture.webp",
    "onboarding/rescue-bag.webp",
    "onboarding/waste-bin.webp",
)
RETAINED_ASSETS = (
    "assets/images/food_box.png",
    "assets/images/google-mark.png",
    "assets/icon/app_icon.png",
    "assets/fonts/Korolev Thin.otf",
    "assets/fonts/Korolev Light.otf",
    "assets/fonts/Korolev Medium.otf",
    "assets/fonts/Korolev Bold.otf",
    "assets/fonts/Korolev Heavy.otf",
)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def generate() -> None:
    if not features.check("webp"):
        raise RuntimeError("Pillow must be installed with WebP support")

    records = []
    for suffix in ARTWORK:
        source_asset = f"assets/images/{suffix}"
        preview_asset = f"assets/previews/{suffix}"
        source_path = MOBILE_ROOT / source_asset
        preview_path = MOBILE_ROOT / preview_asset
        source_bytes = source_path.read_bytes()

        with Image.open(source_path) as original:
            source_size = original.size
            source_mode = original.mode
            source_rgba_hash = sha256(original.convert("RGBA").tobytes())
            preview = original.convert("RGBA" if "A" in original.getbands() else "RGB")

        # thumbnail preserves aspect ratio and never enlarges a smaller source.
        preview.thumbnail(PREVIEW_SIZE, Image.Resampling.LANCZOS, reducing_gap=3.0)
        preview_path.parent.mkdir(parents=True, exist_ok=True)
        preview.save(
            preview_path,
            format="WEBP",
            lossless=False,
            quality=QUALITY,
            alpha_quality=ALPHA_QUALITY,
            method=METHOD,
            exact=True,
        )
        preview_bytes = preview_path.read_bytes()
        with Image.open(preview_path) as decoded:
            alpha_matches = (
                preview.getchannel("A").tobytes() == decoded.getchannel("A").tobytes()
                if preview.mode == "RGBA"
                else None
            )
            preview_size = decoded.size
            preview_mode = decoded.mode

        if source_path.read_bytes() != source_bytes:
            raise RuntimeError(f"Original artwork changed during generation: {source_asset}")
        if alpha_matches is False:
            raise RuntimeError(f"Preview alpha channel changed: {preview_asset}")

        records.append({
            "canonical_asset": source_asset,
            "preview_asset": preview_asset,
            "cdn_url": f"{CDN_ROOT}/{suffix}",
            "source": {
                "bytes": len(source_bytes),
                "sha256": sha256(source_bytes),
                "rgba_pixel_sha256": source_rgba_hash,
                "width": source_size[0],
                "height": source_size[1],
                "mode": source_mode,
                "bytes_preserved": True,
            },
            "preview": {
                "bytes": len(preview_bytes),
                "sha256": sha256(preview_bytes),
                "width": preview_size[0],
                "height": preview_size[1],
                "mode": preview_mode,
                "alpha_matches_resized_source": alpha_matches,
            },
        })

    retained = [
        {"asset": asset, "bytes": (MOBILE_ROOT / asset).stat().st_size,
         "sha256": sha256((MOBILE_ROOT / asset).read_bytes())}
        for asset in RETAINED_ASSETS
    ]
    original_bytes = sum(record["source"]["bytes"] for record in records)
    preview_bytes = sum(record["preview"]["bytes"] for record in records)
    retained_bytes = sum(record["bytes"] for record in retained)
    manifest = {
        "schema_version": 1,
        "date": "2026-09-25",
        "generator": "bitir_yemek_mobile/tool/generate_artwork_previews.py",
        "pillow_version": pillow_version,
        "libwebp_version": features.version("webp"),
        "cdn_root": CDN_ROOT,
        "generation": {
            "maximum_dimensions": list(PREVIEW_SIZE),
            "resampling": "LANCZOS",
            "reducing_gap": 3.0,
            "quality": QUALITY,
            "alpha_quality": ALPHA_QUALITY,
            "method": METHOD,
            "exact": True,
            "lossless": False,
            "aspect_ratio_preserved": True,
            "originals_modified": False,
        },
        "summary": {
            "artwork_count": len(records),
            "original_artwork_bytes": original_bytes,
            "bundled_preview_bytes": preview_bytes,
            "retained_small_images_and_fonts_bytes": retained_bytes,
            "application_asset_bytes_before": original_bytes + retained_bytes,
            "application_asset_bytes_after": preview_bytes + retained_bytes,
            "application_asset_bytes_saved": original_bytes - preview_bytes,
            "artwork_reduction_percent": round((1 - preview_bytes / original_bytes) * 100, 4),
            "note": "Asset bytes only; installed app and store download sizes require a release build.",
        },
        "artwork": records,
        "retained_bundled_assets": retained,
    }
    manifest_path = REPOSITORY_ROOT / "docs/app-artwork-cdn-2026-09-25-assets.json"
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(manifest["summary"], ensure_ascii=False, indent=2))


if __name__ == "__main__":
    generate()
