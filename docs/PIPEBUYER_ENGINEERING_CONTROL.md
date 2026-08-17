# Pipe Buyer Engineering Control

**Canonical repository:** `D:\Game Development\pipeapp`

**Canonical active development branch:** `design/formal-beautification-foundation`

**Legacy/base branch:** `pipebuyer-premium-ui` — never switch to this branch merely to launch or test current development.

## Purpose

Pipe Buyer now has enough parallel Flutter, Firebase, Dispatch, Timed Buying, and web work that ad-hoc repair commands are too risky. This document defines the permanent control surface for local development and automated verification.

## Mandatory local order

Before applying a generated repair, running a major verifier, or launching a formal acceptance session:

```powershell
Set-Location "D:\Game Development\pipeapp"
.\tool\pipebuyer_doctor.ps1
```

Before considering a local source change ready for browser acceptance:

```powershell
.\tool\formal_fast_gate.ps1
```

The fast gate is read-only. It checks the formal branch, pinned Node version, critical Node generator syntax, PowerShell syntax, Dart formatting, and strict analyzer status for changed files.

## Formal demo Auth control

The formal Flutter client must never open Chrome merely because emulator ports are listening. A listening Auth emulator can still have missing, stale, or unusable deterministic credentials.

Canonical fast launch:

```powershell
.\tool\launch_formal_flutter_client.ps1
```

That launcher now calls `tool/ensure_formal_acceptance_ready.ps1` before Flutter starts. The readiness gate:

1. verifies all formal emulator ports;
2. checks the deterministic Firestore/Auth fixture set without changing it;
3. proves the published password against the real Auth emulator `signInWithPassword` endpoint for VIP Buyer, Standard Buyer, Seller, and Carrier;
4. if Firestore fixtures are healthy but demo passwords fail, performs one Auth-only deterministic repair and re-proves all four passwords;
5. if the fixture set is missing or stale, performs one full deterministic reseed and verification;
6. stops before Flutter if the one controlled repair attempt does not pass.

`tool/reseed_formal_test_data.ps1` also runs the direct password verifier after seeding. Admin-SDK account existence alone is not accepted as proof that the login screen can authenticate.

For diagnosis without repair:

```powershell
.\tool\verify_formal_demo_auth.ps1
.\tool\ensure_formal_acceptance_ready.ps1 -NoRepair
```

This prevents the recurring failure mode where Chrome opens successfully but every published demo account fails at the sign-in screen.

## Repair standard

A repair is allowed only when all of the following are true:

1. The root cause is identified before source modification.
2. The repair is branch-locked to `design/formal-beautification-foundation` when it is formal-branch work.
3. Existing files that will be changed are backed up individually.
4. No broad `git reset --hard`, `git restore .`, `git clean`, or branch switch is used against an active dirty working tree.
5. Generator scripts pass `node --check` before they can modify Dart source.
6. Exact-target replacements stop unless the intended target count is exactly one.
7. Generated Dart is formatted and analyzed with `--fatal-infos --fatal-warnings` before browser acceptance.
8. Focused regression tests run for the subsystem being changed.
9. The proven root cause and fix are recorded under `docs/repairs/` or `docs/REPAIR_LOG.md`.

## Generator rule

Avoid embedding large blocks of one programming language inside another whenever practical. Prefer direct source changes or dedicated template files over JavaScript template literals containing Dart interpolation.

If a generator is unavoidable:

- standardize the file to LF;
- escape outer-language interpolation explicitly;
- run syntax validation before file writes;
- write through deterministic exact anchors;
- keep the generator idempotent;
- verify markers after modification;
- never let a generator bypass analyzer or focused tests.

## Line endings

`.gitattributes` and `.editorconfig` are authoritative:

- Dart/JS/MJS/CJS/JSON/Markdown/YAML/HTML/CSS/SVG: LF
- PowerShell: CRLF

This specifically prevents Windows CRLF from changing `.mjs` generator matching behavior.

## Runtime versions

- Node major comes from `.nvmrc`.
- Formal CI uses Flutter `3.44.6` stable until intentionally upgraded.
- A Flutter upgrade requires the strict analyzer to be clean before acceptance because SDK upgrades can introduce deprecations even when behavior still works.

## Automated branch gate

`.github/workflows/formal-fast-gate.yml` runs on pushes and pull requests targeting the formal development branch. It performs:

- Node/MJS syntax checks including the formal demo Auth verifier/repair scripts;
- PowerShell syntax checks for the formal demo Auth/readiness/reseed/launcher chain;
- strict Dart analysis with infos and warnings fatal;
- Dispatch quote-planner contract when present;
- startup/auth and Dispatch navigation regression contracts when present.

For strongest control, GitHub branch protection should require the **Formal Fast Gate** status before merging into `design/formal-beautification-foundation`.

## Canonical launch path

For formal acceptance/emulator work use the formal launchers only. Do not directly invoke the legacy `start_live_test_sandbox.ps1` from the active formal branch.

If the emulator suite is already running, use `tool/launch_formal_flutter_client.ps1`; it now proves/repairs deterministic readiness before opening Flutter.

If the emulator suite is not running, use `tool/start_formal_acceptance_environment.ps1`; it starts the suite, reseeds deterministic fixtures, verifies them, and then delegates to the guarded client launcher.

## Failure handling

When a gate fails:

1. stop at the first failing stage;
2. do not rerun repeatedly hoping for a different result;
3. identify whether the failure is environment, generator syntax, formatter, analyzer, contract test, emulator, Auth credential, or browser acceptance;
4. fix only that layer;
5. rerun from the nearest deterministic gate;
6. record the proven fix once it passes.
