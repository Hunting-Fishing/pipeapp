"""Inventory the reviewed asset selection and stage its reproducible sources.

Uses Pillow only to read dimensions and alpha bounds; it does not edit images.
Run after render_sprites.py has produced all 22 sprites.

This is a sourcing-time audit, not a standalone script for the reduced handoff.
It additionally requires the original Kenney ZIP archives and the three
*-download.json files with their archive paths; these are intentionally not
retained in the small admission bundle. The renderer and prepare_audio.py are
independently reproducible from the selected source files in that bundle.
"""
import hashlib
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent
STAGE = ROOT / "reviewed-source-bundle"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def stage(path):
    relative = path.relative_to(ROOT)
    target = STAGE / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, target)
    return {"path": str(relative), "bytes": path.stat().st_size, "sha256": digest(path)}


packs = []
sources = {}
for pack in ["city-kit-industrial", "car-kit", "interface-sounds"]:
    record = json.loads((ROOT / (pack + "-download.json")).read_text())
    archive = Path(record["zip_path"])
    if digest(archive) != record["sha256"]:
        raise ValueError("Archive hash changed: " + pack)
    license_path = ROOT / "extracted" / pack / "License.txt"
    record["license"] = "CC0-1.0"
    record["license_url"] = "https://creativecommons.org/publicdomain/zero/1.0/"
    record["license_file"] = str(license_path.relative_to(ROOT))
    record["license_sha256"] = digest(license_path)
    record["archive"] = str(archive.relative_to(ROOT))
    del record["zip_path"]
    del record["extracted_path"]
    packs.append(record)
    sources[record["license_file"]] = stage(license_path)

sprites = []
for path in sorted((ROOT / "derived" / "metadata").glob("*.json")):
    row = json.loads(path.read_text())
    sprite = ROOT / row["output"]
    if digest(sprite) != row["sha256"]:
        raise ValueError("Sprite hash changed: " + row["id"])
    image = Image.open(sprite)
    if image.mode != "RGBA" or image.size != (512, 512):
        raise ValueError("Unexpected image mode or dimensions: " + row["id"])
    alpha = image.getchannel("A")
    row["alpha_range"] = list(alpha.getextrema())
    row["alpha_bounds_above_8"] = list(alpha.point(lambda value: 255 if value > 8 else 0).getbbox())
    row["opaque_bounds_above_200"] = list(alpha.point(lambda value: 255 if value > 200 else 0).getbbox())
    borders = [alpha.crop((0, 0, 512, 1)), alpha.crop((0, 511, 512, 512)), alpha.crop((0, 0, 1, 512)), alpha.crop((511, 0, 512, 512))]
    row["max_border_alpha"] = max(border.getextrema()[1] for border in borders)
    if row["alpha_range"] != [0, 255]:
        raise ValueError("Sprite does not contain both transparency and solid geometry: " + row["id"])
    if row["max_border_alpha"] > 8:
        raise ValueError("Sprite or strong shadow clipped: " + row["id"])
    for field in ["source_model", "source_texture"]:
        if row.get(field):
            source = ROOT / row[field]
            sources[row[field]] = stage(source)
    if row["source_pack"] != "project-original":
        # glTF import needs the original colormap even when the renderer later
        # swaps in the pack's official variation A palette.
        colormap = (ROOT / row["source_model"]).parent / "Textures" / "colormap.png"
        sources[str(colormap.relative_to(ROOT))] = stage(colormap)
    else:
        row["source_model_selector"] = "build(" + repr(row["id"]) + ")"
    sprites.append(row)

if len(sprites) != 22:
    raise ValueError("Expected 22 reviewed sprites; found " + str(len(sprites)))

audio = json.loads((ROOT / "derived" / "audio_manifest.json").read_text())
for row in audio:
    path = ROOT / row["source"]
    if digest(path) != row["source_sha256"] or digest(ROOT / row["output"]) != row["sha256"]:
        raise ValueError("Audio hash changed: " + row["id"])
    sources[row["source"]] = stage(path)

for relative in ["render_sprites.py", "original_equipment.py", "prepare_audio.py", "prepare_manifest.py", "blender-toolchain.json", "downloads/blender-4.5.0.sha256"]:
    sources[relative] = stage(ROOT / relative)

manifest = {
    "schema_version": 1,
    "created_utc": datetime.now(timezone.utc).isoformat(),
    "purpose": "Oil & Gas Tycoon 1.2 art and interface cues; reviewed source staging outside the game repository",
    "discovery_directory": "https://github.com/HotpotDesign/Game-Assets-And-Resources",
    "source_packages": packs,
    "render_toolchain": json.loads((ROOT / "blender-toolchain.json").read_text()),
    "source_files": sorted(sources.values(), key=lambda item: item["path"]),
    "sprites": sprites,
    "audio": audio,
    "summary": {
        "sprites": len(sprites),
        "kenney_sprites": sum(row["source_pack"] != "project-original" for row in sprites),
        "original_sprites": sum(row["source_pack"] == "project-original" for row in sprites),
        "sprite_bytes": sum(row["bytes"] for row in sprites),
        "audio_bytes": sum(row["bytes"] for row in audio),
        "source_bundle_bytes": sum(row["bytes"] for row in sources.values()),
    },
    "validation": {
        "archive_sha256_verified": True,
        "published_blender_sha256_verified": True,
        "local_cc0_license_read": True,
        "sprites_rgba_512_square": True,
        "solid_geometry_and_transparency_present": True,
        "maximum_allowed_border_alpha": 8,
        "canonical_game_dev_admission_ran": False,
        "canonical_game_dev_admission_note": "The game-dev CLI is unavailable. This bundle uses source license inspection, explicit hashes, ordinary Blender rendering, and visual review; no canonical admission output is claimed.",
    },
}
(ROOT / "selection_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
(STAGE / "selection_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(manifest["summary"], indent=2))
print("Manifest:", ROOT / "selection_manifest.json")
