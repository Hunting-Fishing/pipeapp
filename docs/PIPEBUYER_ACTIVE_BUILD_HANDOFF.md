# Pipe Buyer Active Build Handoff

## 2026-09-01 Release 1 simple-flow production release

Release 1 is **complete in production** at application SHA `996bd3f782a89639aaf12527193cb1ecf4d92f84`, merged through PR #168 and deployed by protected Firebase run `33493435243` (#56) with App Check `enforce`. The release simplifies the ordinary-user entry flow to Browse inventory, Sell something, Request service, and Post wanted / RFQ; compact navigation uses Home, Browse, Sell, Messages, and Account while existing server-authoritative Firebase, Stripe, Trust & Safety, and release controls remain unchanged.

Production evidence: `firebase-release-evidence-production-996bd3f782a89639aaf12527193cb1ecf4d92f84-33493435243` (artifact `9794901956`) and `visual-acceptance-production-33493435243` (artifact `9794932834`). Production passed full Flutter analysis/tests, release-manifest controls, deployed Function parity controls, both Functions codebases, Firestore security rules, authenticated callable workflows/retries, exact web build, Firebase deploy, post-deploy parity, release identity, and responsive mobile/desktop visual acceptance.

Permanent Release 1 repair boundaries: keep the repository-wide analyzer strict and fix exact lint blockers rather than bypassing it; do not run broad formatter churn over the large Marketplace source for a tiny bounded edit because source-contract tests protect existing catalog-photo integration.

## 2026-09-01 P1 Marketplace blocking production release

P1 Marketplace conversation blocking is **complete in production**. The deployed app remains `main` at `0dd8f9c4ab69868b4b8fc8e6cb2c05dbf1ca80de`, released by protected Firebase run `33464230471` (#55) with App Check `enforce`. Pre-merge Quality `33463954448` and Callable Safety `33463955489` both succeeded. Production also passed Firestore security rules, authenticated callable workflows/retries, exact web build, Firebase deployment, post-deploy Function parity, release identity, and responsive production visual acceptance (job `99722538441`).

Evidence retained: `firebase-release-evidence-production-0dd8f9c4ab69868b4b8fc8e6cb2c05dbf1ca80de-33464230471` (artifact `9784473533`) and `visual-acceptance-production-33464230471` (artifact `9784489576`). New production callables are `readMarketplaceUserBlockStatus` and `setMarketplaceUserBlocked`. Function inventory is generated from `firebase.json` plus exported entrypoints; do not add or resurrect a static Function allowlist.

Permanent repair lesson: the reciprocal-block defect was a client permission check, not a backend block-model defect. When the other party had already blocked first, the UI incorrectly prevented the viewer from placing their own durable block. Remove only that client restriction; preserve directional/mutual server blocks, message history, and Trust & Safety evidence. The regression contract test records this so the same repair is not repeated.

A documentation-only merge after this release does not change the deployed application identity `0dd8f9c4ab69868b4b8fc8e6cb2c05dbf1ca80de` and does not justify another Firebase deployment.


**Updated:** 2026-09-01

**Canonical repository:** `D:\Game Development\pipeapp`

**Production branch:** `main`

**Current deployed production baseline:** `996bd3f782a89639aaf12527193cb1ecf4d92f84` (verified run `33493435243` #56)

**Completed P1 release:** PR #166 merged to `main` at `0dd8f9c4ab69868b4b8fc8e6cb2c05dbf1ca80de`

**Canonical local app:** `http://127.0.0.1:5050`

## Current launch/build position

The older `design/formal-beautification-foundation` and Phase 4 Hotshot/geography blocker notes below are historical. Open-map/geolocation foundations and later Directory repairs have superseded that blocker. The current launch authority is `docs/PIPE_BUYER_LAUNCH_READINESS_AUDIT_2026-08-30.md`.

Controlled North American web launch remains in late P1 acceptance. Marketplace user block/unblock is now production deployed and verified. Remaining P1 acceptance includes ordinary-user buyer/seller/Timed Buying/report-admin/Dispatch journeys, physical mobile push/deep-link validation for native launch, and representative Dispatch provider data/privacy acceptance.

## Current authoritative Dispatch state

```text
Phase 0: GREEN
Phase 1: GREEN
Phase 2: GREEN
Phase 3: 15/15 GREEN
Phase 4: IN PROGRESS
```

Phase 3 browser acceptance is complete.

Phase 4 has these accepted engineering foundations:

```text
Directory projection/schema/security foundation: PASS
Directory projection continuation verifier: PASS
Directory repository/query + provider-list engineering gate: PASS
```

The query/list slice is still in browser acceptance because a real Firestore-backed Hotshot filter exposed a runtime loading-lifecycle defect after the engineering gate passed. That defect is now isolated behind a focused repair; do not proceed to geography/map work until the Hotshot browser re-test passes.

**Current next permitted Dispatch task:** complete the read-only Directory runtime continuation, then re-test Directory -> Hotshot in the browser. After that passes, proceed to geography/radius + synchronized OpenStreetMap pins.

## Permanent local controls

Use permanent repository tools instead of rebuilding ad-hoc terminal repair blocks:

```powershell
.\tool\pipebuyer_doctor.ps1
.\tool\formal_fast_gate.ps1
.\tool\launch_formal_flutter_client.ps1
```

If the emulator suite is not running, or Functions/rules changed and must reload, use:

```powershell
.\tool\start_formal_acceptance_environment.ps1
```

Formal emulator ports:

```text
Auth        19099
Firestore   18080
Functions   15001
Storage     19199
Emulator UI 14000
Web app      5050
```

Never switch to `pipebuyer-premium-ui` merely to launch or test current work. Never run broad `git reset --hard`, `git restore .`, `git clean`, broad branch switching, or speculative mass repair against the active dirty working tree.

## Windows Firebase CLI control - proven and mandatory

A Windows machine may not have a global `firebase` executable even though the project can run Firebase CLI correctly through `npx firebase-tools`.

The canonical shared resolver is:

```text
tool/pipebuyer_firebase_cli.ps1
```

It resolves Firebase CLI in this order:

```text
global firebase available
    -> use firebase
otherwise npx available
    -> use npx --yes firebase-tools
otherwise
    -> STOP during preflight
```

Windows PowerShell gates must not call bare `firebase` directly. They must source the shared helper, run `Assert-PipeBuyerFirebaseCli` before later Firebase-dependent work, and invoke Firebase through `Invoke-PipeBuyerFirebaseCli`.

The permanent root-cause record is:

```text
docs/repairs/FIREBASE_CLI_WINDOWS_FALLBACK.md
```

This exact fallback was proven by the Phase 4 Directory continuation gate on 2026-08-20.

## Late-failure continuation rule

Once a bounded source mutation has already succeeded, a later tooling/test/environment failure must not automatically cause the mutation to run again.

Use this order:

```text
successful bounded mutation
    -> focused source tests pass
    -> later tooling/environment failure
    -> preserve/fingerprint production source
    -> fix only failed tooling layer
    -> continue with read-only verifier
    -> prove production source hash unchanged
```

For the accepted Phase 4 Directory projection, the continuation verifier is:

```powershell
.\tool\verify_dispatch_phase4_directory_projection_continuation.ps1
```

Do not rerun the Phase 4 projection installer merely because a later Firebase CLI or rules-emulator step failed.

### Read-only formatter boundary - proven rule

A read-only continuation protects **production/source-of-record files**. Freshly synchronized test/support files are not production artifacts and may be normalized before execution.

Use this separation:

```text
production source
    -> hash
    -> dart format --output=none --set-exit-if-changed
    -> analyzer
    -> never rewrite

synchronized tests/support
    -> dart format is allowed
    -> formatter-stability check
    -> hygiene/tests/analyzer

final
    -> production hash unchanged
    -> tracker hash unchanged
```

Do not combine production source and freshly fetched support tests into one read-only formatter-stability command. That can misreport an unformatted helper test as a production regression.

The Directory runtime continuation implementing this rule is:

```powershell
.\tool\verify_dispatch_phase4_directory_filter_runtime_continuation.ps1
```

The permanent repair record is:

```text
docs/repairs/DISPATCH_DIRECTORY_FILTER_RUNTIME_STABILITY.md
```

## Deterministic local demo accounts

```text
VIP Buyer        buyer.visual@pipebuyer.test
Standard Buyer   standard.visual@pipebuyer.test
Business Seller  seller.visual@pipebuyer.test
Dispatch Carrier carrier.visual@pipebuyer.test
Password         PipeBuyerDemo!2026
```

The launch readiness gate must prove these passwords directly against the Auth emulator before Flutter opens.

If Firestore fixtures are healthy but demo passwords fail, use the accepted Auth-only repair path. Do not immediately perform a full reseed.

### Browser stale-client rule

Restarting Firebase/Flutter does not force an already-open Chrome tab to discard the previous in-memory Flutter client.

If direct demo Auth passes but Chrome reports an incorrect password after a restart, first use:

```text
Ctrl + Shift + R
```

This exact condition has been reproduced. A hard refresh restored the correct Auth-emulator connection. Do not change credentials or reseed until the direct Auth verifier actually fails.

## Accepted startup/auth behavior

- one branded startup surface;
- large Pipe Buyer logo;
- service truck progresses toward the pumpjack;
- signed-out users are blocked from the Marketplace shell;
- existing Sign In / Sign Up flow is preserved;
- Marketplace Home opens only after Firebase authentication.

## Accepted Dispatch Phase 3 behavior

Phase 3 is complete at 15/15.

Accepted service-area behavior includes:

- Towns and Regions are classified separately;
- Fort St. John and Dawson Creek do not become Peace River Regional District town selections;
- broader regional polygons belong under Regions;
- region selection requires region geometry rather than silently substituting a pin;
- service-area state persists after leaving/reopening Company Profile;
- exact service-area geometry remains private while public discovery uses approximate geography.

Accepted Credentials & Insurance behavior includes:

- General Liability metadata persists immediately on `Save & close`;
- coverage amount, aggregate amount, currency and expiry persist;
- `Records` and `Analytics & alerts` top tabs are the canonical navigation;
- duplicate Analytics shortcut cards were removed;
- Current, Expired, Not provided, Evidence files and Insurance limits support drill-down actions;
- credential reminders persist;
- credential/evidence data remains private and self-reported rather than presented as Pipe Buyer verification;
- strict analyzer, formatter stability, persistence regressions and private-boundary tests pass.

## Administrator policy

Initial approved administrator accounts are:

- `jordilwbailey@gmail.com` - administrator and sole in-app administrator roster manager;
- `goldcity4u@icloud.com` - administrator but cannot add/remove administrators.

Email alone never grants authority. Real administrator access requires trusted Firebase custom claims plus MFA. The generic profile role field must never create Administrator access.

The Carrier demo account correctly shows `Administrator role not assigned`.

## Phase 4 Directory foundation

Phase 4 uses the server-owned searchable projection:

```text
dispatch_directory_entries/{companyId}
```

The projection publishes only bounded Directory/search information for eligible active providers. Client writes are blocked. Private email, phone, Auth UID, exact private address data, credentials, policy/evidence data and unsupported verification claims are excluded.

Accepted projection proof includes:

- projection/privacy contracts;
- Functions syntax;
- Firebase CLI global-or-npx fallback;
- dedicated Firestore Rules emulator proof;
- no production source mutation by the continuation verifier.

## Phase 4 query/list slice

The repository/query + provider-list engineering gate passed with:

```text
PIPE BUYER DISPATCH PHASE 4 DIRECTORY QUERY + LIST GATE PASSED
Server-owned Directory repository/query layer: PASS
Service filter wiring: PASS
Availability/business/capability filters: PASS
Real provider list cards: PASS
Loading/error/empty states: PASS
Deterministic six-provider Directory fixture: PASS
Server projection/privacy regression: PASS
Strict analyzer: PASS
Dispatch tracker modified by this gate: NO
Ready for browser acceptance: YES
```

The formal local acceptance environment seeds six representative Directory providers:

1. Northline Heavy Haul;
2. Peace Country Pilot & Escort;
3. Grande Prairie Picker & Crane;
4. Dawson Creek Road & Site Services;
5. Prairie Hotshot Services;
6. Northern Mobile Mechanical.

### Directory filter runtime browser defect and repair

Browser acceptance found that selecting Hotshot could replace the entire Directory body with a white/loading surface while Firestore refreshed. The root cause is not projection/privacy or provider data. The page was replacing `_loadFuture` immediately on every filter change, and `FutureBuilder` discarded the usable Directory whenever the new future entered `waiting`.

Permanent repair record:

```text
docs/repairs/DISPATCH_DIRECTORY_FILTER_RUNTIME_STABILITY.md
```

Focused current-worktree repair gate:

```powershell
.\tool\run_dispatch_phase4_directory_filter_runtime_repair.ps1
```

Read-only continuation after the source mutation is already applied:

```powershell
.\tool\verify_dispatch_phase4_directory_filter_runtime_continuation.ps1
```

The repaired lifecycle is:

```text
last successful Directory data
    -> filter changes immediately
    -> visible results refine immediately
    -> debounce remote refresh
    -> keep prior results while waiting
    -> generation guard rejects stale async completion
    -> inline updating/error state instead of blank page
```

The main `run_dispatch_phase4_directory_query_list_gate.ps1` now includes this runtime-stability control so a fresh checkout does not recreate the bug.

## Next Phase 4 build shape

After the Directory filter browser re-test passes:

```text
geography/location filters
    -> radius search
    -> synchronized list/map selection
    -> OpenStreetMap provider pins
    -> provider detail surface
    -> browser acceptance
    -> separate tracker finalization
```

The first visible Directory UX remains simple for non-technical users:

```text
Search service/location
    -> provider results list
    -> synchronized map pins
```

Desktop may show list + map together. Mobile should provide a clear List/Map switch rather than overcrowding the screen.

Do not invent ratings, trust scores, verification badges or precise private addresses merely to fill the Directory UI.

## Repair discipline

When a gate fails:

1. stop at the first failing stage;
2. identify whether the failure is source logic, formatter, analyzer, contract test, emulator, Auth, Firebase CLI/tooling, or browser acceptance;
3. preserve every previously passing layer;
4. fix only the failed layer;
5. continue from the nearest deterministic/read-only checkpoint when possible;
6. record the root cause and proven fix under `docs/repairs/`;
7. do not repeat a mutation after it has already succeeded unless new evidence proves the mutation itself is wrong.

## Operator command standard

Every PowerShell instruction supplied during future Pipe Buyer work must state:

- **Changes being applied** - exactly what the command may modify.
- **What to test** - the exact UI/functional acceptance after it passes.

Normal subsystem flow:

```text
scoped control sync
-> parse/preflight declared controls
-> bounded source change
-> deterministic formatter/analyzer/tests
-> source-read-only verifier
-> browser acceptance
-> separate acceptance recorder/finalizer
```

Do not couple feature migrations to Dispatch completion scoring.