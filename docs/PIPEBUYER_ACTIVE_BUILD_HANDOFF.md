# Pipe Buyer Active Build Handoff

**Updated:** 2026-08-18

**Canonical repository:** `D:\Game Development\pipeapp`

**Active branch:** `design/formal-beautification-foundation`

**Canonical local app:** `http://127.0.0.1:5050`

## Current accepted development controls

Use these controls instead of rebuilding ad-hoc terminal repair blocks:

```powershell
.\tool\pipebuyer_doctor.ps1
.\tool\formal_fast_gate.ps1
.\tool\launch_formal_flutter_client.ps1
```

`launch_formal_flutter_client.ps1` is the normal fast launch when the Firebase emulator suite is already running. Before opening Chrome it runs the formal readiness gate and proves the published email/password credentials directly against the Auth emulator.

Formal emulator ports:

```text
Auth        19099
Firestore   18080
Functions   15001
Storage     19199
Emulator UI 14000
Web app      5050
```

If emulators are not running, use:

```powershell
.\tool\start_formal_acceptance_environment.ps1
```

Never switch to `pipebuyer-premium-ui` merely to launch or test current work. Never run broad `git reset --hard`, `git restore .`, `git clean`, or branch switching against the active dirty working tree.

## Deterministic local demo accounts

All four accounts must be proven by the launch readiness gate before Flutter opens:

```text
VIP Buyer        buyer.visual@pipebuyer.test
Standard Buyer   standard.visual@pipebuyer.test
Business Seller  seller.visual@pipebuyer.test
Dispatch Carrier carrier.visual@pipebuyer.test
Password         PipeBuyerDemo!2026
```

When Firestore fixtures are healthy but these passwords fail, the accepted repair is Auth-only. Do not immediately perform a full reseed.

## Accepted startup/auth behavior

- one branded startup surface;
- large Pipe Buyer logo;
- service truck advances toward a pumpjack as startup progresses;
- signed-out users are blocked from the Marketplace shell;
- existing Sign In / Sign Up flow is preserved;
- Marketplace Home opens only after Firebase authentication.

## Accepted Dispatch quote-planner foundation correction

The Saved Quote / lane planner now uses the same structured concepts required by the later universal Request Service workflow:

```text
sourceType: listing | standalone
listingId?
listingTitle?
originLocation {}
destinationLocation {}
requestedUnits[]
    unitTypeCode
    minQuantity
    maxQuantity
requirementsVersion
```

Accepted UX requirements:

- **Select Marketplace listing** or **Custom / standalone job**;
- Marketplace listing can prefill pickup context but the pickup pin can still be refined;
- Origin/Pickup is map-selected;
- Destination is map-selected;
- existing Pipe Buyer OpenStreetMap/location-picker stack is reused;
- multiple equipment classes can be requested in one job;
- quantity ranges are supported, e.g. 2-4 pilot trucks plus 1-12 hauling tractors;
- saved quotes reopen with the source, mapped locations, and requested units preserved;
- `minQuantity > maxQuantity` is rejected;
- the quote-planner Dart source is now the source of truth; its normal verifier is read-only and must not rerun the historical generator.

This foundation correction does **not** award Phase 5 points early.

## Dispatch master-plan position

The authoritative tracker remains `docs/DISPATCH_NETWORK_MASTER_PLAN.md`.

Current verified score before Phase 3 closeout browser acceptance:

```text
Overall: 50/100 = 50%
Phase 0: 5/5
Phase 1: 10/10
Phase 2: 15/15
Phase 3: 13/15 - IN PROGRESS
Phase 4: early foundation work exists but Phase 3 gate still controls entry
```

The two uncredited Phase 3 points are:

1. Service area and home-base map setup — 1 point.
2. Credential/insurance metadata with private document separation — 1 point.

Engineering implementations and focused verifiers already exist for both. Do not award the points merely because code or tests exist. Browser acceptance must prove them first.

## Next permitted Dispatch work: Phase 3 closeout

### A. Service area / home-base acceptance

Using the Carrier demo account:

1. Open Dispatch -> Company Profile.
2. Set or edit the mapped service area/home base using the existing Pipe Buyer map picker.
3. Save.
4. Leave Company Profile completely.
5. Reopen Company Profile.
6. Confirm the service-area label/map state survived.
7. Confirm public-facing geography is approximate while the exact service-area geometry remains owner-private.

Engineering gate:

```powershell
.\tool\verify_dispatch_phase3_service_area_map.ps1
```

Passing engineering tests alone does not award the point; browser acceptance is still required.

### B. Credentials / insurance acceptance

Using the Carrier demo account:

1. Open Dispatch -> Company Profile -> Manage credentials.
2. Enter representative metadata for at least one insurance/authority credential.
3. Save.
4. Leave the credential screen completely.
5. Reopen it.
6. Confirm the metadata survived.
7. If evidence upload is exercised, use a non-sensitive test image only.
8. Confirm credential references/evidence are not displayed in the public business profile or Directory.
9. Confirm the UI does not claim a credential is platform-verified merely because the provider entered metadata or uploaded evidence.

Engineering gate:

```powershell
.\tool\verify_dispatch_phase3_credentials.ps1
```

Passing engineering tests alone does not award the point; browser acceptance is still required.

### C. Phase 3 finalization

Only after both browser acceptance paths are explicitly confirmed should the Phase 3 finalizer be run. It is allowed to change `docs/DISPATCH_NETWORK_MASTER_PLAN.md` from 13/15 at 50% to 15/15 at 52% and open Phase 4 as the current phase.

Do not run the finalizer before that evidence exists.

## Operator command standard

Every PowerShell instruction supplied during future Pipe Buyer work must state:

- **Changes being applied** — what the command can modify.
- **What to test** — the exact UI/functional acceptance after it passes.

If a command fails, capture the first failing stage and the nearby error. Do not repeatedly rerun or layer new repairs before the first failure is understood.
