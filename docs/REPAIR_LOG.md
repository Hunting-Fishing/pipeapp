# Pipe Buyer Repair Log

This log records root causes and permanent repair rules so the same failure is not diagnosed repeatedly.

## 2026-08-16 - Windows PowerShell 5.1 parser failure in Carrier Quote V2 runner

### Symptom

`tool/apply_carrier_quote_premium_v2.ps1` failed before executing its first migration step. Windows PowerShell reported parser errors around text containing an em dash in strings such as the unknown-weight UI marker.

### Root cause

The script was stored as UTF-8 without a BOM and contained non-ASCII punctuation. Windows PowerShell 5.1 can interpret UTF-8 bytes using the active Windows code page. The UTF-8 byte sequence for typographic punctuation can then decode into characters that PowerShell treats as quote delimiters, producing false string termination and cascading parser errors.

This was a tooling defect, not a Flutter, Firebase, Dispatch, or marketplace-data defect.

### Permanent repair

1. PowerShell runner files used by the Windows development workflow must remain ASCII-only unless the repository deliberately standardizes on a BOM-aware encoding or PowerShell 7.
2. `tool/assert_windows_powershell_safe.ps1` checks both raw bytes and the Windows PowerShell parser before a runner is executed.
3. UI text may still use typographic punctuation in Dart/JavaScript. PowerShell validation should test stable ASCII substrings instead of copying typographic UI text into `.ps1` files.
4. New repair runners must be parser-checked before they are handed to the developer.

### Carrier Quote V2 status at failure

The parser failure occurred before `apply_carrier_quote_premium_v1.mjs` or the deferred-weight finalizer executed. The product form was therefore not partially migrated by that failed run.

## 2026-08-16 - Carrier Quote moved from migration chain to exact-file replacement

### Decision

The developer supplied the exact local `marketplace_freight_quote.dart` that was running in the emulator. The formal branch now uses that exact source as the base for the Carrier Quote enhancement instead of applying V1/V2/V3 text migrations to an assumed layout.

### Permanent integration rule

- `lib/marketplace/marketplace_freight_quote.dart` is now a direct, complete branch file for this feature.
- Local installation should use a targeted `git restore --source=origin/design/formal-beautification-foundation --worktree -- lib/marketplace/marketplace_freight_quote.dart` after making an exact backup.
- Do not run the older Carrier Quote migration scripts against this file.
- Validate the direct file with `dart format` and strict analyzer before visual acceptance.
- The explicit unknown-weight path must send both `estimatedWeightKg` and `catalogWeightKg` as null so payload suitability checks do not treat an unconfirmed catalog number as confirmed shipper weight.
- Spec Assist may use reviewed catalog references immediately. A future AI equipment-spec service must be added behind a protected server endpoint and must never be presented as manufacturer-verified data unless a source actually supports that claim.

## 2026-08-16 - Multiple visible startup surfaces consolidated

### Symptom

Web startup visibly moved through three different surfaces: a dark HTML bootstrap card, a brief static HTML marketing header, and the existing large Pipe Buyer logo splash inside Flutter. The transitions looked like separate pages loading instead of one application startup.

### Root cause

Three independent startup layers were active at the same time:

1. `web/index.html` rendered a custom dark loading card and also contained a separate visible marketing header underneath it.
2. `main.dart` immediately called `runApp(PipeStartupMonitorApp(...))`, creating a second Flutter startup application before the real app initialized.
3. The router retained the existing Pipe Buyer logo splash while authentication state settled.

The diagnostics zone was also entered after `WidgetsFlutterBinding.ensureInitialized()`, while the final `runApp()` occurred inside that zone. That split binding initialization and frame rendering across zones and contributed to the earlier zone-mismatch diagnostics.

### Permanent repair

- `web/index.html` owns the pre-Flutter startup surface and uses the same large Pipe Buyer logo presentation as the in-app splash.
- The visible static marketing header and dark bootstrap card were removed from startup.
- Normal startup no longer performs an initial `runApp` for `PipeStartupMonitorApp`; the monitor remains headless and is shown only if bootstrap fails.
- `WidgetsFlutterBinding.ensureInitialized()`, diagnostics installation, bootstrap, and the successful `runApp()` now execute inside the same guarded zone.
- The arbitrary three-second splash timer was removed. The in-app logo splash clears when the first authentication state is actually received.
- `test/startup_single_surface_test.dart` locks these structural rules.
- Do not add a second visible startup page to troubleshoot loading. Add diagnostics behind the single branded startup surface instead.

## 2026-08-16 - Dispatch Phase 1 local-source mismatch stopped before mutation

### Symptom

The first Phase 1 Dispatch navigation gate stopped because the local `marketplace_dispatch_page.dart` Git blob was `b7cfbf585a63f8bb5d0b27331316710710c6a70a`, while the guarded integrator had been prepared against the earlier verified Phase 0 branch blob `f79998e4cfe41eea2d348ae91e12099dd7afc630`.

### Root cause

The local Dispatch page legitimately contained later accepted changes, including updated public Timed Buying wording, that were not byte-identical to the older Phase 0 branch copy. A hash guard designed to prevent accidental overwrite correctly rejected the mismatch.

This was not a Flutter, Firebase, emulator, or Dispatch backend failure. The product file was not changed by the failed attempt.

### Permanent repair

- The exact local Dispatch page was uploaded and reviewed as the source of truth for Phase 1.
- Phase 1 was rebuilt as a complete direct `marketplace_dispatch_page.dart` based on that uploaded file instead of forcing the old patcher.
- The reviewed pre-Phase-1 local blob is `b7cfbf585a63f8bb5d0b27331316710710c6a70a`.
- The reviewed direct Phase 1 page blob before local formatter normalization is `9ba9e7c0fd8ff274bf7bf16628213fff24687641`.
- Do not run `apply_dispatch_phase1_navigation.mjs` against the current product file. Install the direct reviewed page with a targeted restore after making a local backup.

## 2026-08-16 - Dispatch Phase 1 formatting gate failed on unformatted generated Dart

### Symptom

The direct Phase 1 file passed its exact reviewed hash check and the Windows PowerShell parser check, but `dart format --output=none --set-exit-if-changed` reported all three new Phase 1 Dart files as `Changed` and stopped the gate before analyzer or tests ran.

### Root cause

The Phase 1 Dart files were authored and committed through repository text tooling without an actual Dart SDK formatter pass. The verifier was incorrectly described as fully non-mutating while simultaneously requiring formatter-clean source. The formatter therefore correctly rejected repository source that had never been normalized by the developer's installed Dart formatter.

This was a source-preparation/tooling failure, not a Dispatch runtime, Firebase, Firestore, emulator, or application logic failure. The outer installer restored the exact uploaded pre-Phase-1 Dispatch page after the gate stopped.

### Permanent repair

- The exact reviewed pre-format Phase 1 page hash remains the guard before any normalization occurs.
- `tool/verify_dispatch_phase1.ps1` now runs `dart format` deliberately as the first controlled source normalization step after the exact hash check.
- It immediately reruns `dart format --output=none --set-exit-if-changed` to prove the files are stable before analyzer/tests.
- Formatting is treated as deterministic source normalization, not as a product repair.
- New Dart files produced through repository text APIs must not be represented as formatter-clean until an actual Dart SDK formatter has run.
- Analyzer, widget/server tests, Phase 0 preservation tests, and emulator acceptance remain blocked until formatting is stable.

## 2026-08-17 - Dispatch could show signed-out content after sign-in

### Symptom

The account menu showed the authenticated visual buyer or carrier account, including a working Sign out action, while the Dispatch content area still displayed `Sign in to use Dispatch.`. The problem reproduced for more than one account after the local Auth fixtures were refreshed.

### Root cause

`MarketplaceDispatchPage` performed a synchronous one-time check of `FirebaseAuth.instance.currentUser` at the start of its `build()` method and returned the signed-out placeholder immediately when that value was null. The Dispatch page itself did not subscribe to Firebase Auth state changes. In the cached marketplace shell, authentication could complete after the Dispatch page had rendered, while other shell/account widgets rebuilt independently. That left Dispatch displaying a stale signed-out branch even though Firebase Auth later had a valid user.

This was not a Phase 2 taxonomy failure and did not require changing Auth emulator users, passwords, Firestore data, Dispatch commands, or provider records.

### Permanent repair

- `MarketplaceDispatchPage` must listen to `FirebaseAuth.instance.authStateChanges()` and use `FirebaseAuth.instance.currentUser` only as initial stream data.
- Authenticated Dispatch content is built only after the auth stream reports a user; sign-out returns to the signed-out placeholder reactively.
- `test/dispatch_auth_reactivity_contract_test.dart` locks the structural requirement so the page cannot regress to a one-time `currentUser == null` guard.
- `tool/repair_dispatch_auth_reactivity.mjs` is a narrow, idempotent repair for the current page shape; it does not alter provider/customer routing, service taxonomy, jobs, quotes, awards, or private-route behavior.
- `tool/verify_dispatch_auth_reactivity.ps1` formats and analyzes the repaired page, runs the auth contract, and reruns the Phase 1 navigation and Phase 2 taxonomy regressions.

## 2026-08-17 - Dispatch Phase 3 widget tests assumed off-screen controls were hittable

### Symptom

The Phase 3 company-profile analyzer passed, but the widget suite failed in two tests. `Pilot / Escort Vehicle` existed in the render tree below the 1000 px test viewport, so `tap()` missed it. The later `Save company profile` control had not yet been lazily built by the `ListView`, causing `ensureVisible()` to throw `Bad state: No element`. A second test expected the lower `Availability` controls before scrolling them into the lazy viewport.

### Root cause

The product editor uses a vertically scrollable `ListView`, which is correct for the long mobile/desktop form. The tests treated all descendants as if they were simultaneously on-screen and built. Flutter widget tests only hit-test visible coordinates, and lazily-built list children may not exist until the test scrolls them into view.

This was a test-harness failure, not a company-profile model, taxonomy, analyzer, or runtime UI failure.

### Permanent repair

- Widget tests for long Dispatch forms must explicitly scroll before tapping or asserting controls below the current viewport.
- When a target already exists in the tree but is off-screen, use `tester.ensureVisible(...)` before interaction.
- When a lazy `ListView` child may not yet exist, use `tester.dragUntilVisible(...)` against the form `Scrollable` so the finder can become available during scrolling.
- Do not enlarge the test viewport to hide scrolling defects; keep representative viewport sizes and test the actual scroll behavior.
- The product editor was not changed for this failure. Only `test/marketplace_dispatch_company_profile_test.dart` was hardened.

## Process rule going forward

Avoid repeated V1/V2/V3-style repair chains when a stable integration path can be used. Prefer:

- one canonical direct file or runner per feature,
- additive components over large exact-text rewrites,
- preflight syntax/parser checks before mutation,
- exact file backups and hash-based rollback for any mutation,
- actual formatter execution before calling generated Dart source formatter-clean,
- strict analyzer/tests after mutation,
- recording the root cause and successful fix here.
