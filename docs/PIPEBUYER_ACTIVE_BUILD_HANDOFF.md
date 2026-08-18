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

If emulators are not running, or Functions wiring changed and the emulator must reload it, use:

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

### Browser stale-client rule

A Firebase/Flutter restart does not force an already-open Chrome tab to reload the new compiled client. If direct demo Auth passes but the browser reports an incorrect password after a restart, first use:

```text
Ctrl + Shift + R
```

This exact condition was reproduced and the hard refresh restored the correct Auth-emulator connection. Do not reseed or change credentials until the direct Auth verifier fails.

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

## Dispatch Phase 3 current evidence

The authoritative tracker remains `docs/DISPATCH_NETWORK_MASTER_PLAN.md`. Its ledger remains unchanged until Phase 3 browser acceptance is complete and the dedicated finalizer is run.

Current authoritative ledger:

```text
Overall: 50/100 = 50%
Phase 0: GREEN
Phase 1: GREEN
Phase 2: GREEN
Phase 3: 13/15 - IN PROGRESS
Phase 4: BLOCKED
```

### Service area / home-base browser acceptance

**Browser acceptance: PASS.**

Accepted behavior includes:

- Towns and Regions are classified separately;
- Fort St. John and Dawson Creek do not become Peace River Regional District town selections;
- larger regional polygons belong under Regions;
- Region selection requires region geometry rather than silently substituting a pin;
- service-area state persists after leaving and reopening Company Profile;
- exact service-area geometry remains private while public discovery uses approximate geography.

This accepted browser evidence is preserved for the Phase 3 finalizer. Do not re-diagnose the service-area system unless a new runtime symptom contradicts it.

### Credentials & insurance engineering gate

**Engineering gate: PASS on 2026-08-18. Browser acceptance still required.**

The accepted engineering gate proved:

```text
Declared PowerShell controls parse before mutation: PASS
Credential migration formatter/idempotency preflight: PASS
Credential dialog immediate persistence: PASS
Insurance coverage fields: PASS
Analytics & alerts discoverability: PASS
Credential reminder engine: PASS
Private credential boundary: PASS
Primary-admin roster management: PASS
Generic profile role cannot grant Administrator claims: PASS
Flutter admin UI contains no administrator email allowlist: PASS
Dispatch tracker modified by this gate: NO
Ready for browser acceptance: YES
```

Root cause of the prior credential persistence defect: the dialog's old **Save metadata** action changed only Flutter in-memory state; durable Firestore persistence happened only through the later page-level Save All action. The repair makes dialog **Save & close** persist immediately and roll back the displayed record if the Firestore write fails.

Analytics is now intentionally discoverable in two places:

- the **Analytics & alerts** tab;
- a visible **Analytics & alerts** shortcut card on the Records page.

Credential coverage supports primary amount, optional aggregate amount, and currency while keeping exact private policy data in the private business record.

### Administrator policy

Initial approved administrator accounts are:

- `jordilwbailey@gmail.com` — administrator and sole in-app administrator roster manager;
- `goldcity4u@icloud.com` — administrator but cannot add/remove administrators.

Email alone never grants authority. Real administrator access requires trusted Firebase custom claims plus MFA. The generic users/profile role menu must never grant Administrator access by editing a Firestore role field.

The protected administrator roster manager:

- lists active administrator-role records;
- lets only the primary administrator manager grant/revoke admin access;
- requires the target account to have verified email and enrolled MFA;
- prevents the primary manager from removing itself in-app;
- revokes refresh tokens after role changes;
- records an administrator-role audit event.

The Carrier demo account correctly shows **Administrator role not assigned**.

## Immediate next browser acceptance

Because the credential/admin repair changed Flutter source and Functions wiring, restart the full formal environment once before browser acceptance.

Using the Carrier demo account:

1. Open Dispatch -> Company Profile -> Credentials & insurance.
2. Confirm both `Records` and `Analytics & alerts` are visible.
3. Confirm the Records screen also has the visible Analytics & alerts shortcut card.
4. Edit General liability insurance with fake test data, including a primary coverage amount, currency, aggregate amount, and expiry date.
5. Press **Save & close**.
6. Leave Credentials & insurance completely without relying on the page-level Save All button.
7. Reopen Credentials & insurance and prove the saved values persisted.
8. Open Analytics & alerts and confirm readiness, insurance-limit, expiry, and reminder sections are present.
9. Enable/select reminder windows, save them, leave the page, reopen it, and confirm persistence.
10. Confirm the UI continues to state that credential information is self-reported and is not Pipe Buyer verification.
11. If evidence upload is tested, use only a harmless test image and confirm upload does not imply verification.

Only after this browser acceptance passes should Phase 3 be finalized to 15/15 and Phase 4 be formally opened.

## Operator command standard

Every PowerShell instruction supplied during future Pipe Buyer work must state:

- **Changes being applied** — what the command can modify.
- **What to test** — the exact UI/functional acceptance after it passes.

If a command fails, capture the first failing stage and nearby error. Do not repeatedly rerun or layer new repairs before the first failure is understood.

Normal subsystem flow:

```text
scoped control sync
-> parse/preflight declared controls
-> bounded source change
-> focused formatter/analyzer/tests
-> source-read-only verifier
-> browser acceptance
-> separate acceptance recorder/finalizer
```

Do not couple feature migrations to Dispatch completion scoring.