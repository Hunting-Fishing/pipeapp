"""Verify the exact reviewed art/audio files and their retained source records.

This dependency-free check is independent of the unavailable game-dev CLI.
It checks provenance hashes, local paths, runtime roster, PNG headers, and PCM
audio. Visual review and transparent-edge inspection are recorded separately.
"""
import hashlib
import json
import re
import struct
import wave
from pathlib import Path


GAME = Path(__file__).resolve().parents[1]
SOURCE = GAME / "art_sources"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def checked_path(root, relative):
    require(isinstance(relative, str) and relative, "Missing asset path")
    parts = Path(relative).parts
    require(not Path(relative).is_absolute() and ".." not in parts,
            "Unsafe asset path: " + relative)
    candidate = root / relative
    require(not candidate.is_symlink() and root in candidate.resolve().parents,
            "Asset escapes its root: " + relative)
    require(candidate.is_file(), "Missing asset: " + relative)
    return candidate


def verify_hash(path, digest, size=None):
    require(isinstance(digest, str) and re.fullmatch(r"[0-9a-f]{64}", digest),
            "Invalid SHA256 record: " + str(path))
    content = path.read_bytes()
    require(hashlib.sha256(content).hexdigest() == digest,
            "Changed reviewed file: " + str(path))
    if size is not None:
        require(len(content) == size, "Changed file length: " + str(path))
    return content


def main():
    manifest = json.loads((SOURCE / "inventory.json").read_text())
    require(manifest["schema_version"] == 1, "Unsupported art inventory")
    source_paths = set()
    for row in manifest["source_files"]:
        require(row["path"] not in source_paths, "Duplicate source record")
        source_paths.add(row["path"])
        verify_hash(checked_path(SOURCE, row["path"]), row["sha256"], row["bytes"])

    packs = {row["id"]: row for row in manifest["source_packages"]}
    for pack in packs.values():
        license_path = "sources/" + pack["license_file"]
        require(license_path in source_paths, "Untracked publisher license")
        content = verify_hash(checked_path(SOURCE, license_path), pack["license_sha256"])
        require(pack["license"] == "CC0-1.0" and b"CC0" in content,
                "Unreviewed publisher license")

    paths = set()
    total_bytes = 0
    sprite_count = audio_count = 0
    for row in manifest["entries"]:
        relative = row["runtime_relative_path"]
        require(relative not in paths, "Duplicate runtime asset: " + relative)
        paths.add(relative)
        require(row["source_path"] in source_paths, "Missing source record")
        verify_hash(checked_path(SOURCE, row["source_path"]), row["source_sha256"])
        if row.get("source_texture"):
            require(row["source_texture"] in source_paths, "Missing texture record")
            verify_hash(checked_path(SOURCE, row["source_texture"]),
                        row["source_texture_sha256"])
        if row["source_pack"] == "project-original":
            require(row["license"] == "project-authored", "Original art license mismatch")
        else:
            require(row["source_pack"] in packs and row["license"] == "CC0-1.0",
                    "Unreviewed source pack")
            require(bool(row["license_files"]), "Missing asset license")
            for license_path in row["license_files"]:
                require(license_path in source_paths, "Untracked asset license")
                checked_path(SOURCE, license_path)
        path = checked_path(GAME, relative)
        data = verify_hash(path, row["runtime_sha256"], row["runtime_bytes"])
        total_bytes += len(data)
        if row["kind"] == "sprite":
            sprite_count += 1
            require(re.fullmatch(r"assets/art/[a-z_]+\.png", relative), "Unexpected sprite path")
            require(data[:8] == b"\x89PNG\r\n\x1a\n" and data[12:16] == b"IHDR",
                    "Invalid PNG header")
            width, height, depth, color, compression, filtering, interlace = struct.unpack(
                ">IIBBBBB", data[16:29])
            require((width, height, depth, color, compression, filtering, interlace)
                    == (512, 512, 8, 6, 0, 0, 0), "Unexpected sprite encoding")
        elif row["kind"] == "audio":
            audio_count += 1
            require(re.fullmatch(r"assets/audio/[a-z_]+\.wav", relative), "Unexpected sound path")
            with wave.open(str(path), "rb") as audio:
                require(audio.getcomptype() == "NONE" and audio.getsampwidth() == 2,
                        "Sound must be signed 16-bit PCM")
                require(audio.getframerate() == int(row["pcm_metadata"]["sample_rate"]),
                        "Unexpected sample rate")
                require(audio.getnchannels() == row["pcm_metadata"]["channels"],
                        "Unexpected channel count")
                require(0 < audio.getnframes() / audio.getframerate() < .5,
                        "Sound must be a short interface cue")
                pcm = audio.readframes(audio.getnframes())
                require(hashlib.sha256(pcm).hexdigest() == row["derivation"]["decoded_pcm_sha256"],
                        "Sound differs from the reviewed decoded source")
        else:
            raise ValueError("Unknown runtime asset kind")

    actual = {str(path.relative_to(GAME)) for folder in ("art", "audio")
              for path in (GAME / "assets" / folder).rglob("*") if path.is_file()}
    require(actual == paths, "Runtime directory differs from the reviewed roster")
    require(sprite_count == 22 and audio_count == 4, "Incomplete reviewed selection")
    print(f"Verified {sprite_count} sprites, {audio_count} PCM cues, "
          f"{len(source_paths)} source files, {len(packs)} CC0 publisher packs; "
          f"{total_bytes:,} runtime bytes.")


if __name__ == "__main__":
    main()
