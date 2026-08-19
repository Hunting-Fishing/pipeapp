# Pipe Buyer Active Build Handoff

**Updated:** 2026-08-20

**Canonical repository:** `D:\Game Development\pipeapp`

**Active branch:** `design/formal-beautification-foundation`

**Canonical local app:** `http://127.0.0.1:5050`

## Current authoritative Dispatch state

```text
Phase 0: GREEN
Phase 1: GREEN
Phase 2: GREEN
Phase 3: 15/15 GREEN
Phase 4: IN PROGRESS
```

Phase 3 browser acceptance is complete. The Phase 4 Directory projection/security foundation is installed and its continuation verifier passed without modifying production source.

Accepted Phase 4 continuation proof:

```text
PIPE BUYER PHASE 4 DIRECTORY PROJECTION CONTINUATION PASSED
Previously applied Directory source: PASS
Projection/privacy contracts: PASS
Functions syntax: PASS
Firebase CLI global-or-npx fallback: PASS
Firestore Rules emulator proof: PASS
Phase 3: 15/15 GREEN
Phase 4: IN PROGRESS
Production source modified by continuation: NO
Ready for next Phase 4 slice: YES
```

**Next permitted Dispatch task:** Directory repository/query layer, followed by real provider list cards, service/availability/geography filters, and synchronized OpenStreetMap pins.

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

## Phase 4 Directory foundation already installed

Phase 4 introduces the server-owned searchable projection:

```text
dispatch_directory_entries/{companyId}
```

The projection is designed to publish only bounded Directory/search information for eligible active providers. Client writes are blocked. Private email, phone, Auth UID, exact private address data, credentials, policy/evidence data and unsupported verification claims are excluded.

The accepted continuation gate proved:

- projection/privacy contracts;
- Functions syntax;
- Firebase CLI global-or-npx fallback;
- dedicated Firestore Rules emulator proof;
- no production source mutation by the continuation verifier.

## Next Phase 4 build shape

Build Phase 4 in bounded slices:

```text
Directory repository/query layer
    -> provider list cards
    -> service + availability filters
    -> geography/location filters
    -> synchronized list/map selection
    -> OpenStreetMap provider pins
    -> provider detail surface
    -> browser acceptance
    -> separate tracker finalization
```

The first visible Directory UX should remain simple for non-technical users:

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
