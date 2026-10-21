# Oil & Gas Tycoon — Buyer & Trader

A playable single-player company game for Android, iOS, and the web, built with
Flutter. Start with **$150,000 in fictional cash**, a developed Cedar Creek oil
lease, a pumpjack, a field haul fleet, an operator, and a driver. Run shifts,
sell production, and grow into a company that owns leases, equipment, vehicles,
supporting businesses, and a trained crew.

The simulation runs locally. A shift advances one game day only when you choose
**Run next shift**; your company does not produce, incur costs, or expire
contracts while the game is closed. Prices, money, companies, and leases are
fictional. Trading uses the game's simulated market and supply contracts.

## Play the hosted game

Open the [private playable preview](https://pipeapp-oil-gas-tycoon.jordilwbailey.chatgpt.site)
in a modern desktop or mobile browser. Use the owning ChatGPT account if sign-in
is requested. The game itself still runs locally and stores its company in that
browser. The first complete load needs a connection.

### Version 1.1 — Auctions & Research

- **Exchange → Used equipment auctions:** inspect three rotating lots, compare
  their condition and retail price, and bid against simulated rival companies.
  Your leading bid is held separately from spendable cash. An outbid returns
  that money; a winning bid delivers the used asset to Fleet at the displayed
  condition. Bids and closing dates advance only when you run a shift.
- **Company → Research & technology:** hire an engineer and fund one research
  project at a time. Each technology has three levels. Projects need two,
  three, then four staffed shifts; dismissing the last engineer pauses progress.
  Cancelling does not refund the research investment. Completed technology
  remains learned after a company restructuring.
- **Existing companies continue:** the new game reads saves and portable
  backups from the original release and preserves their company, funds,
  inventory, assets, leases, employees, contracts, and career progress.

| Technology | Improvement per completed level |
| --- | --- |
| Production | 5% more potential field output, subject to reserves, transport, and storage |
| Logistics | 10% more staffed haul capacity |
| Storage | 15% more oil and gas storage |
| Maintenance | Eight percentage points added to the repair discount, alongside crew, workshop, and business discounts |
| Drilling | 5% reduction to development costs after drilling-rig savings |
| Trading | One percentage point added to commodity sale quotes, capped at the buy quote |

Research is a company investment with no resale value. Its full cost is charged
up front. Bid cash remains part of company net worth while held, and a leading
auction bid reserves a fleet slot so its delivered asset fits the fleet limit.

Web updates wait for existing game tabs to close so a running session keeps a
consistent set of game files. After an update downloads, close all game tabs
and reopen the link. **Settings → Export backup** provides an independent copy
of your company before changing devices or installations. Version 1.1 saves
cannot be opened in the original version 1.0 game.

## Run the game

Use **Flutter 3.44.6 stable**. The game package depends on Flutter and
`shared_preferences`; it does not need Firebase configuration, an account, API
keys, or payment credentials.

From the repository root:

```sh
cd games/oil_gas_tycoon
flutter pub get
flutter run -d chrome
```

For mobile development, connect an Android device or start an emulator, then use
`flutter devices` and `flutter run -d DEVICE_ID`. On macOS, the same command can
target an iOS simulator or a properly configured, signed physical-device build.
Android development requires the Android SDK and Java 17 or 21; iOS development
requires macOS and Xcode.

### Standalone and embedded entrypoints

| Entry | How to open it | Behavior |
| --- | --- | --- |
| Standalone game | Run this package's `lib/main.dart`, as above. | Independent mobile/web app with local persistence and no marketplace startup services. |
| Embedded in Pipe Buyer | Open **Oil & Gas Tycoon** from the marketplace home card or drawer; the route is `/tycoon`. | Opens the same game inside the existing application. **Settings → Return to Pipe Buyer** saves before returning. |
| Root development shortcut | From the repository root, run `flutter pub get`, then `flutter run -d chrome -t lib/tycoon_main.dart`. | Starts the game through the root project's toolchain without initializing marketplace services. The root project still has its own dependency set. |

The standalone app and Pipe Buyer have separate application storage. Different
web origins, ports, browser profiles, or installed apps also have separate save
locations. Use **Export backup** and **Restore backup** to move a company
between them.

## Your first shifts

1. Enter a company name and choose **Start my company**. Cedar Creek is already
   developed, staffed, equipped, and running.
2. On **Operations**, choose **Run next shift**. Review oil/gas production,
   wages, upkeep, interest, and any operating issues in the shift report.
   Production goes into storage; commodity sales are a separate action.
3. Open **Exchange** and sell stored oil. Prices change with each shift, and
   buying uses a higher quote than selling, so repeated instant trades have a
   cost. Buy commodities only when there is enough cash and storage.
4. Keep operating cash available. Repair worn equipment and fleet vehicles in
   **Fleet**. Conditions at or below 20% prevent the relevant asset from
   operating.
5. Acquire another lease from **Operations**, pay its development cost, and use
   **Manage well** to assign compatible production equipment and an operator.
   Buy the equipment in **Fleet** and hire the operator in **Company**. The
   company's drivers and haul fleets supply shared transport capacity.
6. Buy and upgrade supporting businesses in **Company**, train employees, and
   consider supply contracts in **Exchange**. A contract requires a deposit;
   delivering the full quantity by its deadline returns the deposit and
   pays the contract. Missing the deadline forfeits the deposit once.

**Settings → Career guide** shows the eight objectives and their one-time
rewards. The tycoon career goal is **$5 million net worth and four developed
leases**. You can continue playing after reaching it.

## Feature inventory

| Area | Included gameplay |
| --- | --- |
| Oil and gas leases | Eight fictional sites; acquisition, development, equipment/operator assignment, pause/resume, finite underground reserves, and resale. Reacquisition preserves depletion and requires new development. |
| Equipment, vehicles, and storage | Eight asset types: pumpjack, gas gathering skid, high-output pumpjack, drilling rig, field haul fleet, heavy haul fleet, workshop truck, and storage terminal. Buy, sell, repair, and use their production, development, maintenance, haul, or storage effects. |
| Businesses | Refinery, logistics company, and parts/repair yard; each can be bought, upgraded through three levels, and sold. Income, upkeep, and operating benefits change with ownership and upgrades. |
| Employees | Operators, drivers, engineers, and mechanics; hiring, training, role effects, payroll, assignment where relevant, and dismissal. |
| Market and contracts | Oil/gas inventory trading, changing prices and recent price history, quantity/cash/storage validation, supply offers, deposits, deadlines, delivery, and expiry. |
| Used asset auctions | Three rotating equipment and vehicle lots, simulated rival bids, cash held/refunded, condition-aware delivery, fleet capacity reservations, and recent outcomes. |
| Research and technology | Six technologies with three levels each; upfront funding, engineer staffing, shift-based progress, pause/resume, and permanent operating benefits. |
| Company finance | Cash, asset valuation, net worth, operating costs, ledger, credit, repayment, and interest at 0.2% of outstanding debt per shift. |
| Production | Equipment/crew compatibility, condition, staffing, transport and storage constraints, depletion, daily events, and production reports. |
| Career and interface | Milestone rewards, contextual operating hints, four mobile tabs, wider-screen navigation rail, an animated oilfield, and reduced-motion support. |
| Persistence and recovery | Local autosave, previous-good-save recovery, portable JSON backup, validated restore, confirmed new company, and insolvency restructuring. |

## Save, resume, and recovery

Successful game actions queue an automatic local save. Reopening the game loads
your saved company. The app also attempts to save when it is backgrounded and
before returning to Pipe Buyer. A storage failure displays a warning; exporting
the current company lets you retain progress even if a local write fails.

- **Export:** open **Settings → Export backup → Copy backup** and keep the
  complete text in a file or note. If clipboard access is unavailable, select
  and copy the displayed backup manually.
- **Restore:** use **Restore backup** in Settings, or **Restore a backup** on
  the welcome screen. Paste the complete text, choose **Review backup**, check
  the company summary, and confirm **Restore company**. Validation happens
  before replacement; an invalid backup leaves the current company intact.
- **Corrupt latest save:** the game attempts to load the previous good save and
  displays a recovery notice. The most recent action may need to be repeated.
  If both local copies are unreadable, restore an exported backup or explicitly
  start a new company.
- **New career:** **Settings → Start a new company** asks for confirmation.
  Export the current company first if you want to keep it.
- **Negative cash:** sell inventory or surplus holdings, or use available credit
  in **Company**. Further shifts pause until cash is nonnegative. If necessary,
  **Restructure company** replaces holdings and contracts with a starter
  operation and $25,000, clears debt, and retains the current day and earned
  achievements. This is a confirmed recovery action, not a free cash top-up.

There is no automatic cloud synchronization. Clearing browser/app data or
uninstalling can remove local saves; an exported backup is the portable copy.
Imports use the version 1 backup envelope and have a 512 KiB size limit. The
game data inside that envelope is schema 2 in version 1.1; original schema 1
companies are migrated automatically. The device storage keys stay unchanged.

## Build and test

Run these commands from `games/oil_gas_tycoon/` after `flutter pub get`:

```sh
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
dart run tool/verify_expansion.dart
```

The tests cover economic actions, production constraints, contract settlement,
solvency, malformed saves, save failures/recovery, interface actions, and
responsive layouts. The engine suite retains seeded 800-shift career tests.
The deterministic expansion script replays 11,200 mixed actions across 16
seeds and checks rejected-action atomicity, exact save/reload replay, cash and
fleet reservation limits, storage bounds, and commodity quote bounds. It uses
a larger test treasury to exercise purchases; the real starting cash is unchanged.
See the [version 1.1 release record](../../docs/OIL_GAS_TYCOON_1_1_RELEASE.md)
for the expansion's executed checks and the
[original audit](../../docs/OIL_GAS_TYCOON_AUDIT_2026-10-20.md) for the application
inventory and initial release evidence. The existing Pipe Buyer regression
suite is run separately from the repository root.

### Web release and offline bundle

Node 22 or newer runs the dependency-free post-build script:

```sh
flutter build web --release --no-pub --no-web-resources-cdn --pwa-strategy=none
node tool/prepare_offline_web.mjs
python3 -m http.server 8080 --directory build/web
```

Open `http://localhost:8080`. The output is the complete `build/web/` directory;
serve it through HTTP locally or HTTPS when hosted, rather than opening
`index.html` directly. The post-build step creates a versioned cache manifest
and service worker with local Flutter renderer assets. Web offline use requires
one successful initial load and cache installation. A browser can later evict
cached files, so retain exported saves independently. For a subdirectory host,
add the corresponding `--base-href /your-path/` when building, then rerun the
post-build script.

### Android local test APK

Install Android SDK platforms 35 and 36, plus build-tools 36.0.0, through Android
Studio's SDK Manager or `sdkmanager`. The application targets platform 36;
platform 35 is also needed by an Android plugin dependency. With the Android SDK
command-line tools configured:

```sh
sdkmanager "platforms;android-35" "platforms;android-36" "build-tools;36.0.0"
flutter build apk --profile --no-pub
```

Output: `build/app/outputs/flutter-apk/app-profile.apk`.

For an ARM64-only installer, use an ABI split so dependency libraries cannot
advertise unsupported processor types:

```sh
flutter build apk --profile --target-platform android-arm64 --split-per-abi --no-pub
```

That output is `build/app/outputs/flutter-apk/app-arm64-v8a-profile.apk`.

This **profile APK is a local test build**, intended for installation and
performance checks on a test device. It is not a production-signed Google Play
release. For interactive debugging, use `flutter run` or
`flutter build apk --debug` instead.

The profile app uses the application ID `com.pipebuyer.oil_gas_tycoon.preview`;
debug uses `.dev`, while a signed release uses `com.pipebuyer.oil_gas_tycoon`.
They can be installed separately. Export and restore a company to move progress
between build types.

The Android project requires a private release keystore for release tasks.
`android/key.properties.example` describes the local signing configuration;
private signing files are ignored by Git. Store packaging, upload signing,
versioning, listing setup, and physical-device acceptance remain separate
release work.

### iOS unsigned compilation

On macOS with Xcode:

```sh
flutter build ios --release --no-codesign --no-pub
```

Output: `build/ios/iphoneos/Runner.app`. This is an **unsigned compilation
artifact**, not an installable signed IPA or an App Store submission. A valid
Apple development team, provisioning, signing, device checks, and store
validation are required before distributing the game on iOS.

## GitHub validation

The repository workflow
[Oil & Gas Tycoon — Validation](../../.github/workflows/tycoon-game.yml)
runs on pull requests that change the game or its workflow. These checks run
analysis, tests, web packaging, and an ARM64 Android profile build. It can also
be started through **Actions → Run workflow**; select the game branch and choose
the optional platform builds:

| Output | Default | Workflow behavior |
| --- | --- | --- |
| Web bundle | Always | Flutter 3.44.6 analysis/tests, web release build, offline preparation, and downloadable web artifact. |
| Android ARM64 profile APK | Enabled | Linux build with Temurin Java 17, SDK platforms 35/36, and build-tools 36.0.0; uploads the local test APK. |
| Unsigned iOS app | Disabled | Optional macOS compilation with `--no-codesign`; uploads a ZIP of the unsigned `.app`. |

The workflow has read-only repository permissions, needs no production secrets,
and uploads review artifacts without deployment or store submission. The web
artifact includes the hidden build ID required by its offline cache. Check the
actual run result before treating a platform build as verified.

## Implementation map and limits

- `lib/src/tycoon_engine.dart`: catalog, validated state, economy, and game actions.
- `lib/src/save_store.dart`: local persistence, versioned backup format, and
  serialized writes.
- `lib/src/app.dart`: startup, resume, restore/reset, and save-aware navigation.
- `lib/src/ui/`: responsive game interface, theme, and original oilfield drawing.
- `test/`: engine, storage, and widget regression coverage.
- `tool/prepare_offline_web.mjs`: self-contained web cache preparation.

This implementation has no multiplayer, player-to-player online trading,
real-money transactions, cloud saves, or store billing. Its state is independent
of Pipe Buyer's real listings, accounts, payments, and regulated property
policies. Physical Android/iOS testing and store release approval remain
explicit acceptance gates.
