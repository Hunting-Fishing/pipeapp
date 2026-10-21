"""Decode four Kenney CC0 UI cues to native-friendly signed 16-bit PCM WAV.

The decoded PCM from each source OGG must equal the decoded PCM of its WAV.
No gain, resampling, channel mixing, or explicit trimming is applied. Vorbis
container duration can include codec padding; decoded PCM duration is retained.
"""
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUTPUT = ROOT / "derived" / "audio"
OUTPUT.mkdir(parents=True, exist_ok=True)
SELECTION = [("tap", "click_001"), ("success", "confirmation_001"), ("shift", "open_001"), ("error", "error_001")]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def probe(path):
    command = ["ffprobe", "-v", "error", "-show_entries", "format=duration:stream=codec_name,sample_rate,channels", "-of", "json", str(path)]
    return json.loads(subprocess.run(command, capture_output=True, text=True, check=True).stdout)


def pcm(path):
    command = ["ffmpeg", "-v", "error", "-i", str(path), "-map", "0:a:0", "-c:a", "pcm_s16le", "-f", "s16le", "pipe:1"]
    return subprocess.run(command, capture_output=True, check=True).stdout


rows = []
for name, original in SELECTION:
    source = ROOT / "extracted" / "interface-sounds" / "Audio" / (original + ".ogg")
    target = OUTPUT / (name + ".wav")
    command = ["ffmpeg", "-y", "-v", "error", "-i", str(source), "-map", "0:a:0", "-c:a", "pcm_s16le", str(target)]
    subprocess.run(command, check=True)
    source_pcm, target_pcm = pcm(source), pcm(target)
    if source_pcm != target_pcm:
        raise ValueError("Decoded audio differs: " + name)
    info, source_info = probe(target), probe(source)
    source_stream, output_stream = source_info["streams"][0], info["streams"][0]
    if source_stream["sample_rate"] != output_stream["sample_rate"] or source_stream["channels"] != output_stream["channels"]:
        raise ValueError("Audio format changed: " + name)
    rows.append({
        "id": name,
        "source_pack": "interface-sounds",
        "source": str(source.relative_to(ROOT)),
        "output": str(target.relative_to(ROOT)),
        "bytes": target.stat().st_size,
        "sha256": digest(target.read_bytes()),
        "source_sha256": digest(source.read_bytes()),
        "license": "CC0-1.0",
        "duration_seconds": float(info["format"]["duration"]),
        "source_container_duration_seconds": float(source_info["format"]["duration"]),
        "audio_stream": output_stream,
        "derivation": {
            "tool": "ffmpeg",
            "version": subprocess.run(["ffmpeg", "-version"], capture_output=True, text=True, check=True).stdout.splitlines()[0],
            "command": ["ffmpeg", "-y", "-v", "error", "-i", str(source.relative_to(ROOT)), "-map", "0:a:0", "-c:a", "pcm_s16le", str(target.relative_to(ROOT))],
            "audio_processing": "Vorbis decode to signed 16-bit PCM; source sample rate and channels preserved; no gain, resampling, mixing or explicit trimming",
            "decoded_pcm_sha256": digest(source_pcm),
            "decoded_pcm_equal": True,
        },
    })
(ROOT / "derived" / "audio_manifest.json").write_text(json.dumps(rows, indent=2) + "\n")
print("Prepared and PCM-verified", len(rows), "WAV cues;", sum(row["bytes"] for row in rows), "bytes total")
