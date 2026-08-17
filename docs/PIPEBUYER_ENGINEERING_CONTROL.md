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

## Proven fast build loop

The accepted working loop for formal development is now:

```text
Pipe Buyer Doctor
    -> bounded source change
    -> subsystem read-only verifier / formal fast gate
    -> formal emulator readiness + direct demo-password proof
    -> Flutter launch
    -> browser acceptance
    -> record the accepted result once
```

Rules for this loop:

- `tool/pipebuyer_context.ps1` is the canonical PowerShell/.NET repository context. Direct .NET file operations must use absolute paths rooted there; do not trust a relative path merely because the PowerShell prompt displays the right directory.
- Prefer direct Dart/source edits plus read-only verification over repeatedly executing source generators after a feature has been materialized.
- Once a repair has produced accepted application source, that source becomes the source of truth. Keep the repair only as history/recovery unless there is a specific reason to rerun it.
- A verifier must not silently rewrite application source or advance a Dispatch score. Browser-acceptance/finalizer actions are separate and explicit.
- A source verifier must not require a particular documentation/progress score in order to prove source behavior. Tracker state is informational during engineering verification.
- Support-bundle synchronization must not blindly overwrite production Dart, Functions, rules, or progress-tracker files.
- If production source must be normalized to a known revision, the updater must recognize both the exact known-old state and exact new state; unknown local source must be preserved and cause a safety stop.
- Verifiers for active subsystems should fingerprint protected production files before and after running and fail if the verifier itself changes them.
- If a gate fails, stop at the first failing layer and fix that layer only. Do not stack speculative patches or repeatedly reseed data.
- Existing emulator data is verified before repair. Healthy Firestore data plus failed demo passwords triggers Auth-only repair, not a full reseed.

## Subsystem single-entry gates

When a subsystem has a dedicated gate, operators should run that gate rather than manually chaining several repair and verification commands.

For the current Dispatch Phase 3 credential slice:

```powershell
.\tool\run_dispatch_phase3_credential_gate.ps1
```

That gate performs:

```text
Pipe Buyer Doctor
    -> recognize/update only the one known broken reminder-engine revision
    -> focused reminder regression
    -> source-read-only credential verifier
```

It does not edit the Dispatch progress tracker. Browser acceptance and progress finalization remain separate.

## PowerShell command communication standard

Whenever a build, repair, verifier, or launcher command is handed to the operator, the accompanying instructions must state both:

1. **Changes being applied** — exactly which source, control, fixture, or documentation behavior the command may modify.
2. **What to test** — the exact browser/UI/functional behavior that proves the change after the command passes.

Commands should be short and use permanent repo tools whenever one exists rather than embedding large ad-hoc repair programs in the terminal.

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
- Phase 3 Dispatch profile/geography/credential persistence and privacy contracts;
- startup/auth and Dispatch navigation regression contracts.

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
