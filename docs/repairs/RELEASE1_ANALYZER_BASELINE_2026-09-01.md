# Release 1 analyzer baseline repair — 2026-09-01

## Symptom

The guarded Release 1 builder reached the repository-wide Flutter analyzer and stopped on an existing `unnecessary_import` finding in `lib/marketplace/membership_plan_management.dart`.

## Root cause

`membership_plan_management.dart` imported both `package:flutter/foundation.dart` and `package:flutter/material.dart`. The symbols used by this file are already exported by Material, so the direct Foundation import was redundant. The canonical production deployment also runs a repository-wide analyzer, so suppressing or narrowing the gate would have deferred the same failure to release time.

## Repair

Remove only the redundant Foundation import. Do not weaken analyzer severity and do not alter membership behavior, Stripe logic, Firebase calls, entitlement state, or UI behavior.

## Verification

Release 1 must pass the unchanged repository-wide analyzer, focused Home/navigation tests, the full Flutter regression suite, and the canonical protected production deployment before this repair is considered closed.

## Do not repeat

When a bounded feature exposes an unrelated pre-existing analyzer blocker that would also fail the canonical deployment, repair the exact lint defect and record it. Do not bypass the full analyzer or expand into speculative refactoring.
