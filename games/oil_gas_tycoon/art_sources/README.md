# Oil & Gas Tycoon — reviewed industrial artwork

This directory retains the source and provenance for the version 1.2 artwork.
The game bundles **22 transparent 512 × 512 sprites** and **four short PCM WAV
cues**, totaling **2,917,984 bytes**. Source models and production tools remain
outside Flutter's runtime asset declarations.

## Sources and rights

The user supplied the
[Hotpot game resources directory](https://github.com/HotpotDesign/Game-Assets-And-Resources).
It links asset publishers; it is the discovery source, not the license for the
selected art. The actual downloaded Kenney packs and their original license
notices were inspected separately.

| Publisher/source | Selected material | License |
| --- | --- | --- |
| [Kenney City Kit Industrial 2.0](https://kenney.nl/assets/city-kit-industrial) | Eleven buildings, tanks, and industrial details | CC0-1.0 |
| [Kenney Car Kit 3.1](https://kenney.nl/assets/car-kit) | Five support vehicles | CC0-1.0 |
| [Kenney Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds) | Click, confirmation, open, and error cues | CC0-1.0 |
| Project-authored geometry | Pumpjack, heavy pumpjack, drilling rig, gas skid, field tanker, and heavy tanker | Original project work; no additional license grant |

The downloaded licenses are retained verbatim under `sources/extracted/` and
appear in the game's **Settings → Licenses** page. The Kenney logo is not used.
The project-authored models and original Flutter terrain, pipelines, controls,
and illustration surfaces are kept separate from the Kenney CC0 designation.

## Review and exact-file verification

`inventory.json` records source URLs, original archive SHA256 values, selected
source-file hashes, runtime-file hashes, dimensions, transparent bounds, model
selectors, render settings, audio conversion commands, and decoded PCM hashes.
The source roster includes all selected GLBs and their local texture dependencies.

Before integration, both the producing agent and the integrating agent checked
every retained source and runtime hash. The integrating check also established
that all sprites were 512 × 512 RGBA, contained both transparent and opaque
pixels, had **zero alpha on every outer edge**, and had local GLB dependencies.
The complete contact sheet and the original oilfield models were visually
reviewed for clipped or missing geometry. Ground shadows are drawn in Flutter;
transparent sprites retain soft self-shadow lighting.

The WAVs contain signed 16-bit PCM at 44,100 Hz with source channel counts
preserved. Decoding the original OGG and derived WAV produced identical PCM for
each cue. No gain, resampling, mixing, or explicit trimming was applied.

Run the independent, dependency-free review-record check from the game folder:

```sh
python3 tool/verify_art.py
```

It validates the exact runtime roster, source/runtime SHA256 values, license
records, PNG headers, and PCM bytes. CI runs the same command before analysis.
It does not replace visual review of newly authored or changed artwork.

The game-development skill's `game-dev` executable was unavailable in this
environment. Its canonical package admission workflow was **not run**. These
records describe the ordinary publisher-license, hash, Blender, image, and
audio checks that actually ran.

## Reproduce the derived art

The official Blender 4.5.0 Linux archive was checked against its publisher's
SHA256 file before execution. Its source URL and checksum are retained in the
inventory and `sources/downloads/blender-4.5.0.sha256`; the executable and archive
are not committed. With Blender 4.5.0 available, from this directory:

```sh
blender --background --factory-startup --python sources/render_sprites.py
python3 sources/prepare_audio.py
```

The second command requires `ffmpeg` and `ffprobe`. Both commands use retained
selected sources and write to `sources/derived/`. The renderer uses an
orthographic camera, consistent orientation, three soft lights, a fixed Cycles
seed, CPU rendering, and 64 samples. Its `--only` option can rebuild one model:

```sh
blender --background --factory-startup --python sources/render_sprites.py -- --only pumpjack
```

Rendering on different hardware or toolchain versions may produce different
PNG bytes; review the regenerated art and update hashes deliberately before
replacing runtime files. Reproduction does not overwrite the admitted runtime
selection automatically.

`sources/prepare_manifest.py` records the original sourcing audit. It also needs
the three original Kenney ZIP archives, their corresponding `*-download.json`
files with valid local archive paths, regenerated metadata, and Pillow. Those
archives and path-specific download JSON files are deliberately omitted from
this reduced source bundle. They are not needed by the sprite and audio
production commands above.
