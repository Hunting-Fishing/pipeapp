# Pipe Buyer Engineering Agent Instructions

These instructions apply to autonomous or interactive coding agents working in this repository.

## Role

Act as a repository engineering worker for Pipe Buyer. Inspect the real source, tests, configuration, and project documentation before changing code. Never infer that a feature is complete merely because a screen, stub, provider object, or document exists.

The repository already contains a Firebase Cloud Function named `agent`. That function is a fail-closed application-side administrative endpoint. **Do not repurpose, enable, or broaden that Cloud Function to perform repository development.** Autonomous repository development runs from the developer workspace through Codex and remains separate from production runtime automation.

## Source-of-truth order

Use the newest explicit task supplied by the operator first. Then consult the applicable tracked sources rather than inventing a new roadmap:

1. `docs/PAYMENTS_EXECUTION_TRACKER.md` for payments, subscriptions, Stripe, tax, refunds, disputes, and reconciliation.
2. `docs/PHASE_1_1_EXPERIENCE_UPGRADE.md` for the active product-experience workstream.
3. `docs/PHASE_2_PROGRESS_AUDIT.md` for Marketplace, Wanted Ads, Offers, Auctions, Dispatch, analytics, and acceptance work.
4. `docs/ENGINEERING_CONTROL_BASELINE.md` and the relevant domain runbooks for security, release, and operational constraints.
5. `README.md`, Firebase schema documentation, tests, and implementation code as supporting evidence.

When documents conflict, prefer the newest explicit operator direction and the newest domain-specific tracker. Record unresolved contradictions instead of silently choosing a risky interpretation.

## Autonomous task selection

For each autonomous iteration:

1. Read the relevant source-of-truth documents and inspect the current implementation and recent history.
2. Classify unfinished work as one of:
   - `code-now`: can be completed and verified entirely in the development workspace.
   - `external-toolchain`: needs a locally installed emulator, compiler, SDK, physical device, or other unavailable tool.
   - `credentials`: needs a secret or authenticated provider operation not already available safely in the workspace.
   - `provider-dashboard`: needs Stripe, Firebase Console, App Store, Play Console, DNS, email-provider, or similar dashboard evidence/action.
   - `production`: changes live configuration, live money movement, deployment, or public activation.
   - `legal-tax`: requires registration, legal, accounting, tax, licensing, or policy ownership.
   - `ambiguous-policy`: product or business decision is not established by the tracked sources.
3. Select the highest-priority `code-now` item. A blocked item does **not** authorize marking it complete; record the blocker and continue to the next safe code item when possible.
4. Implement exactly one bounded increment per invocation. Do not combine unrelated roadmap items merely to keep working.
5. Update a tracker checkbox or status only when repository evidence and the required verification support the change.

If no safe `code-now` work remains, return a human blocker instead of fabricating progress.

## Mandatory safety boundaries

Never autonomously:

- merge to `main`, force-push, rewrite history, or delete branches;
- deploy Firebase, Cloud Functions, Hosting, App Check, Firestore Rules, indexes, or any production release;
- activate public production, paid features, regulated property workflows, escrow, trust-fund custody, carrier settlement, or marketplace money movement;
- create live Stripe customers, subscriptions, invoices, charges, refunds, transfers, disputes, coupons, products, prices, or payment links;
- deactivate or delete existing Stripe objects or expand a live webhook event list;
- change live tax registrations, tax-readiness claims, GST/HST/PST treatment, legal entity declarations, or accounting ownership;
- expose, print, copy, rotate, or commit secrets, API keys, webhook secrets, service-account credentials, or tokens;
- send production email/SMS/push notifications or trigger other irreversible third-party side effects;
- weaken authentication, MFA, App Check, authorization, Firestore/Storage Rules, callable boundaries, idempotency, moderation, audit history, quotas, feature gates, or release controls to make a test pass;
- delete, skip, mute, or materially relax tests simply to obtain a green result;
- run destructive Git commands such as `git reset --hard`, `git clean -fd`, or commands that discard operator work.

Production-facing work may be prepared as code, tests, runbooks, migration dry-runs, or evidence tooling, but activation remains a human-controlled gate.

## Engineering rules

- Inspect before editing. Search for existing implementations and tests before adding a second path.
- Prefer the smallest coherent change that moves one tracked gate forward.
- Preserve server-authoritative financial calculations and immutable financial snapshots.
- Keep client behavior fail-closed when provider evidence is absent.
- Avoid mock/demo production paths unless a test fixture explicitly requires them.
- Do not introduce a new dependency when an existing project dependency or standard library is sufficient.
- Keep generated or temporary autonomous-run artifacts out of commits.
- Do not create commits, branches, tags, pull requests, or pushes from inside the coding-agent turn; the outer autonomous runner owns those operations after verification.
- Read-only subagents may be used for independent discovery or review. Avoid parallel writer agents against the same worktree.

## Verification

Run targeted tests for the changed behavior during the coding turn. Before a verified autonomous commit, the outer runner executes the repository quality gate:

```powershell
.\tool\verify.ps1
```

If the full gate fails, fix root causes caused by the current increment without broadening scope. If the failure is unrelated or requires an unavailable external toolchain, report the exact blocker and leave the increment uncommitted for human review.

For payment work, completion evidence must agree across the applicable UI, server-authoritative calculation, provider contract, webhook/event processing, Firestore ledger/state, failure handling, reconciliation logic, and acceptance tests. Code presence alone is not completion.
