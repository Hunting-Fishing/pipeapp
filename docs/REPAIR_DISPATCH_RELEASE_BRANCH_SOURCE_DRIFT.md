# Dispatch Release Branch Source Drift Repair

Date: 2026-08-17
Status: repair procedure prepared; final production proof pending

## Symptom

The clean production release worktree passed dependency bootstrap, strict analysis for the mapped service-area files, mapped geography tests, Phase 3 profile/equipment tests, and Phase 2/Phase 1 regressions until the Dispatch auth-reactivity contract inspected `lib/marketplace/marketplace_dispatch_page.dart`.

That contract found the old synchronous guard:

```dart
if (FirebaseAuth.instance.currentUser == null) {
  return const Center(child: Text('Sign in to use Dispatch.'));
}
```

instead of the accepted `FirebaseAuth.instance.authStateChanges()` integration.

## Root cause

The accepted Dispatch auth-reactivity repair and registered-provider Company Profile wiring were proven in the developer's local product page, while the formal GitHub branch retained the earlier Phase 1 `marketplace_dispatch_page.dart`.

Support files, tests, repair tools, and later Phase 3 files were committed, but the actual locally repaired Dispatch product page was never promoted as the canonical branch copy.

The clean production worktree correctly exposed this source drift because it builds only from GitHub and does not inherit the developer's dirty local worktree.

This is not a new Firebase Auth defect and not a failure of the mapped service-area implementation.

## Permanent repair

1. Keep the auth-reactivity regression test. Do not weaken or remove it.
2. Canonicalize the formal branch product page using the already-reviewed, idempotent integrations:
   - `tool/repair_dispatch_auth_reactivity.mjs`
   - `tool/apply_dispatch_phase3_profile_persistence.mjs`
3. Format and strictly analyze the resulting `marketplace_dispatch_page.dart`.
4. Re-run auth, navigation, taxonomy, and Company Profile persistence regression tests.
5. Commit only `lib/marketplace/marketplace_dispatch_page.dart` from a clean worktree and fast-forward the formal branch. Never force push.
6. Production release worktrees must continue to build from GitHub rather than silently borrowing local modified source. This ensures source drift is detected before deployment.
7. After canonicalization, rerun the hosting-only production release. Production is considered updated only after the deployed release marker reports the exact verified GitHub SHA.

## Canonical repair runner

`tool/canonicalize_dispatch_page_for_release.ps1`

The runner uses a clean temporary worktree, checks `pubspec.lock` stability, applies the two reviewed integrations, runs strict analysis and targeted regression tests, stages only `marketplace_dispatch_page.dart`, and verifies the pushed commit on GitHub.
