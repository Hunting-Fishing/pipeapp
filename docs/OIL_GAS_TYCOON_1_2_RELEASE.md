# Oil & Gas Tycoon 1.2 — Industrial District release evidence

**Version:** `1.2.0+3`

**Status:** final web release compiled; local automated checks and compiled-browser
acceptance passed. Remote CI and native build outcomes are reported on the
[implementation PR](https://github.com/Hunting-Fishing/pipeapp/pull/213); this
source checkpoint does not claim a completed remote run or device installation.

## What changed

- **Selectable industrial district:** Operations now displays all eight lease
  sites in an isometric scene. Site labels reflect the actual company state,
  including ownership, development, production readiness, paused operations,
  depleted reserves, missing equipment or crew, transport, repair, and storage
  constraints. Selecting a site opens acquisition or management actions.
- **Management from the map:** acquire, develop, assign, pause, resume, and sell
  through the existing validated engine actions. The open site sheet updates
  after an action and shows its success or error feedback. Confirmation dialogs
  preserve cancellation and revalidate cash and ownership when confirmed.
- **Illustrated equipment and businesses:** the welcome screen, district,
  fleet, used-equipment auctions, and business cards use locally bundled
  industrial artwork. The map supports horizontal panning, keyboard access,
  enlarged text, and reduced-motion preferences.
- **Optional local sound:** four short action and shift cues are available in
  **Settings → Sound effects**. Sound starts off, the choice persists locally,
  and enabling it does not autoplay. Audio failures, delayed starts, muting,
  and disposal are isolated from economic actions.

The district is a stylized overview of the fictional lease network. It is not
a geographical representation of the sites' named regions.

## Company and backup compatibility

Version 1.2 continues using game save schema **2**, introduced in 1.1, and the
portable backup envelope remains `oil-gas-tycoon`, version **1**. Original schema
1 companies retain the existing migration path. Auction escrow, research,
inventory, equipment, employees, contracts, and career progress remain part of
the saved company.

The first version 1.2 browser build resumed the existing version 1.1
**Frontier Energy** QA company on **day 4 with $16,815 cash**, its auction-won
rig, and completed storage research. A separate older game tab subsequently
rewrote that browser-local save when it closed. This exposed a pre-existing
multi-tab lifecycle-save problem, which is addressed by the guards below.
The final browser check uses the continuing QA company and records its exact
state in the acceptance section.

### Stale-tab save protection

Unchanged lifecycle saves now do no storage writes and do not rotate the
previous-good-save copy. Changed saves refresh SharedPreferences, compare the
current primary with the session's expected primary, and reject a sequential
conflict before either backup or primary is written. A distinct message asks
the player to export the current session before reloading. Explicit restore
and new-company actions still perform the comparison when their local state
is unchanged. A no-op save does not clear an existing recovery warning.

These checks retain the same storage keys and backup format. They are not an
atomic cross-tab lock or live synchronization. Keep one active game tab per
browser profile. Older versions 1.0/1.1 cannot be retroactively protected, so
export the desired company before closing legacy tabs during an update.

## Local verification

| Check | Observed result |
| --- | --- |
| Complete game test suite | **138 tests passed** |
| Flutter analyzer | **No issues found** |
| Deterministic expansion stress script | **11,200 actions across 16 seeds passed** |
| Reviewed artwork and audio verifier | **26 runtime files and 32 retained source files verified**, covering three CC0 publisher packs |
| Actual package asset manifest from the Pipeapp host | **One integration test passed** using the embedded package namespace |
| Final version 1.2 web release compilation | **Succeeded**, with `CupertinoIcons 1.0.9` included |
| Offline web preparation | Revision **`89771bd3a630ca252819`**, **70 cache files**, approximately **44.2 MiB** |

The game tests include engine and save compatibility, map management, stale
confirmation handling, asset loading, UI layouts, and optional audio behavior.
The stress script exercises the auction/research simulation with save
roundtrips, deterministic replay, rejected-action atomicity, and treasury,
inventory, storage, and asset-cap invariants. It remains available at
[`games/oil_gas_tycoon/tool/verify_expansion.dart`](../games/oil_gas_tycoon/tool/verify_expansion.dart).

The independent asset check is
[`games/oil_gas_tycoon/tool/verify_art.py`](../games/oil_gas_tycoon/tool/verify_art.py).
It verifies the exact runtime roster, source/runtime SHA256 records, publisher
license records, PNG encoding, and decoded PCM bytes. These are local results;
they do not establish a completed remote CI run or a native-device pass.

## Artwork and audio provenance

The runtime selection contains **22 transparent 512 × 512 PNG sprites and four
PCM WAV cues**, totaling **2,917,984 bytes**, approximately **2.8 MiB**.

| Origin | Runtime selection | Rights record |
| --- | --- | --- |
| [Kenney City Kit Industrial 2.0](https://kenney.nl/assets/city-kit-industrial) | Eleven buildings, tanks, and industrial details | Original CC0-1.0 pack license retained |
| [Kenney Car Kit 3.1](https://kenney.nl/assets/car-kit) | Five support vehicle sprites | Original CC0-1.0 pack license retained |
| [Kenney Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds) | Tap, success, shift, and error cues | Original CC0-1.0 pack license retained |
| Project-authored geometry | Pumpjack, heavy pumpjack, drilling rig, gas skid, field tanker, and heavy tanker | Six original sprites, separate from the Kenney CC0 designation |

The supplied
[Hotpot game resources directory](https://github.com/HotpotDesign/Game-Assets-And-Resources)
was used to discover publishers. Source-pack licenses were inspected
separately. Original notices are retained with the selected source files and
are accessible through **Settings → Licenses**.

The selected GLBs, their required local textures, original geometry, source
audio, production scripts, URLs, and hashes are retained under
[`games/oil_gas_tycoon/art_sources/`](../games/oil_gas_tycoon/art_sources/README.md).
The producing and integrating checks verified the retained source and runtime
hashes. All sprites contain transparent and opaque pixels and have **zero alpha
on every outer edge**. The complete contact sheet and original equipment were
visually reviewed for clipped or missing geometry. Flutter draws the ground
contact shadows; sprites retain consistent soft self-shadow lighting.

The cues use signed 16-bit PCM at 44,100 Hz, preserving source channel counts.
Decoded PCM from each original OGG matches its derived WAV. No gain,
resampling, mixing, or explicit trimming was applied.

### Reproduction and admission limits

The [art reproduction guide](../games/oil_gas_tycoon/art_sources/README.md)
documents the verified official Blender 4.5.0 archive checksum, the retained
renderer, and ffmpeg/ffprobe audio conversion. The selected sources are
sufficient to reproduce the PNGs and WAVs with those tools. Reproduction writes
separate derived outputs and does not automatically replace admitted runtime
files; different rendering environments may produce different PNG bytes.

`sources/prepare_manifest.py` records the sourcing-time audit and additionally
requires the original three Kenney ZIP archives, their `*-download.json` path
records, regenerated metadata, and Pillow. The archives and path-specific JSON
files are deliberately omitted from the reduced source bundle. They are not
needed by the sprite or audio production commands.

The game-development skill's `game-dev` executable was unavailable. Its
canonical admission workflow **was not run**. The provenance record describes
the ordinary license, hash, Blender, image, and audio checks that actually ran.

## Browser acceptance

Chrome was exercised against the compiled release through the managed local
preview. The desktop viewport was 1363 × 936. Phone and enlarged-text layouts
were checked by Flutter widget tests; a physical mobile device was not used.

- All eight map sites were exposed as actionable lease controls. Selecting an
  owned site opened its actual management sheet; pause and resume changed the
  engine-backed status and showed inline feedback.
- A failing web accessibility check exposed action buttons grouped beneath a
  progress-bar role. A semantics boundary and a regression test corrected it.
  The rebuilt browser exposed Manage well, Pause/Start well, and Sell lease as
  separate actions and successfully operated pause/resume through them.
- An unaffordable $80,000 lease was rejected after confirmation, with visible
  inline feedback and unchanged $16,815 cash.
- Selling 475 bbl at $80 paid $38,000; the first-trade career reward added $5,000,
  taking the QA company to $59,815. The next shift produced 153 bbl, charged
  $1,335, and left $58,480 on day 5.
- The fleet and auction screens displayed the original pumpjack, tanker,
  drilling rig, and gas-skid sprites alongside the admitted support vehicles.
  Business cards displayed the corresponding industrial buildings.
- The later QA company acquired Dry Creek Gas for $60,000, received the
  existing $10,000 expansion milestone, developed the site for $36,000, bought
  a $52,000 gas skid, hired a $2,160 operator, and assigned both. The next shift
  produced **156 bbl of oil and 1,000 Mcf of gas**, with **$1,230** operating
  expenses. The resulting day-3 company had **$12,855** cash and two ready sites.
- Sound was initially off, persisted after enabling, and Settings displayed
  version 1.2.0. A stale incremental Flutter web registrant initially omitted
  audioplayers; invalidating that generated cache and rebuilding registered
  the web plugin correctly. Subsequent sound-enabled actions produced no game
  exceptions. Physical speaker output is not claimed. The browser reported
  its CPU-rendering fallback and unrelated extension diagnostics.

The final build (offline revision `89771bd3a630ca252819`) reloaded the day-3
company with **$12,855**, **316 bbl**, **1,000 Mcf**, and **two ready leases**.
Two tabs then loaded that same snapshot. The first ran one shift, producing
153 bbl and 980 Mcf and paying $1,230. The second tried to pause Cedar Creek;
it displayed the explicit save-conflict warning. After closing that stale tab
and reloading the first, the saved company remained on **day 4 with $11,625,
469 bbl, 1,980 Mcf, and both leases ready**. The stale pause did not replace the
stored company.

The final complete suite passed 138 tests after the save guards, accessible
sheet controls, and site-status priority fix. The browser screenshot records
the resulting two-site district. No new disconnected-browser acceptance is
claimed here; the 70-file offline bundle and asset completeness were verified
locally. Browser cache eviction and physical-device behavior remain separate
acceptance checks.

## Remote CI and native status

- **GitHub CI:** a completed version 1.2 remote run is not yet recorded here.
  Local checks above are the available evidence.
- **Android:** no version 1.2 APK build, signing result, installation, or
  physical-device acceptance is claimed. Earlier release artifacts do not
  establish those results for this version.
- **iOS:** no signed build or physical-device acceptance is claimed. The audio
  backend requests an ambient audio category, but `audioplayers` applies the
  category through the app-shared `AVAudioSession` on iOS. It is not a
  player-specific session. Coexistence with host audio, background audio, the
  silent switch, and route changes requires native integration validation.

The web cache requires a successful connected load and installation. Browser
storage can subsequently be evicted. Exported company backups remain useful
independent copies of progress; see the [game README](../games/oil_gas_tycoon/README.md)
for play, update, backup, and local-run instructions.
