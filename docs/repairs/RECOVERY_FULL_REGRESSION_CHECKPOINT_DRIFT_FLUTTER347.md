# Recovery Full Regression Checkpoint Drift + Flutter 3.47

**Date:** 2026-08-22
**Scope:** isolated recovery worktree only
**Original active repo:** untouched

## Symptom

The consolidated recovery gate passed, Firebase Functions lint/check/tests passed,
but the complete Flutter regression ended at 406 passed / 8 failed.

## Root causes

The eight failures were not eight product regressions:

1. The Directory repository nullability contract still required an eager,
   non-null Firestore repository. The accepted seed-safe Directory intentionally
   uses a nullable repository and creates Firestore only when no seed fixture is
   supplied.
2. The Directory runtime hygiene test searched another test file for quoted
   source text and therefore matched the forbidden expression inside a negative
   assertion. This was a meta-test false positive.
3. Four legacy quote-planner assertions required the retired Dashboard quote
   editor, mapped-location state and `_DispatchUnitRequirementDraft`. Quote V2
   deliberately removed those private Dashboard internals and moved carrier
   pricing into the shared `MarketplaceDispatchQuoteForm`.
4. `marketplace_listing_form_presentation.dart` used the removed
   `Ink.constraints` named parameter. Flutter 3.47 rejects that API.
5. `startup_observability_test.dart` still required the retired duplicate splash
   and cache-repair controls, while the accepted startup is the single branded
   Pipe Buyer truck/pumpjack surface.

## Exact repair

- Kept the Directory repository lazy and seed-safe; updated the stale contract.
- Changed runtime hygiene to inspect production lifecycle semantics directly.
- Retained the historical quote-planner test path but changed its contract to
  protect the accepted shared Quote V2 architecture. It now explicitly prevents
  the retired Dashboard editor/unit draft from returning.
- Replaced `Ink.constraints` with an outer `ConstrainedBox(minHeight: 78)` so
  the original minimum-height intent survives Flutter 3.47 without forcing an
  exact height.
- Updated startup observability to the current one-surface
  `pipe-startup` / truck / pumpjack / first-frame contract.

## Do not repeat

Do **not** run the legacy source/map/units applicator to put
`_DispatchUnitRequirementDraft` or the old Dashboard quote editor back into
production. Quote V2 is the newer accepted architecture.

Do **not** make the Directory repository eager merely to satisfy old tests.
Seed fixtures must remain Firebase-free.

Do **not** restore the retired `splash-*` startup controls over the accepted
single branded startup surface.

## Verification

Required closure sequence:

1. Dart formatter on repaired Dart/test files.
2. `git diff --check`.
3. Formal Fast Gate.
4. Previously failing regression files plus Quote V2/seed/startup controls.
5. Complete `flutter test --no-pub`.
6. Confirm no unexpected working-tree paths were introduced.

Firebase Functions were not changed by this repair; their immediately preceding
full gate was 265/265 passing.