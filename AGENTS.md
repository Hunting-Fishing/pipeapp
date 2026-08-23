# Pipe Buyer Engineering Agent Instructions

These instructions apply to autonomous or interactive coding agents working in this repository.

## Role

Act as a repository engineering worker for Pipe Buyer. Inspect the real source, tests, configuration, project knowledge, and recent history before changing code. Never infer that a feature is complete merely because a screen, stub, provider object, or document exists.

The repository already contains a Firebase Cloud Function named `agent`. That function is a fail-closed application-side administrative endpoint. **Do not repurpose, enable, or broaden that Cloud Function to perform repository development.** Repository development runs from a developer workspace and remains separate from production runtime automation.

## Project configuration

Read `.autobuild/project.json` before autonomous work. It defines the reusable writer branch, knowledge files, verification command, source-size/change budgets, timeouts, and human-only safety gates for this project.

The autonomous-builder engine is intended to be reusable across projects. Project-specific knowledge and rules belong in the target repository; orchestration logic should remain portable.

## Knowledge hierarchy

Use the newest explicit operator direction first. Then use the project knowledge in this order:

1. `docs/PRODUCT_VISION.md` — intended finished product and capability outcome.
2. `docs/MASTER_ROADMAP.md` — ordered cross-domain roadmap index.
3. `docs/ARCHITECTURE.md` — client/server/data/refactoring boundaries.
4. `docs/QUALITY_GATES.md` — source size, change budget, refactoring and verification law.
5. `docs/DECISION_REGISTER.md` — durable decisions that must not be silently reinterpreted.
6. `docs/FEATURE_REGISTRY.md` — compatibility inventory for existing capabilities.
7. Domain-specific sources:
   - `docs/PAYMENTS_EXECUTION_TRACKER.md` for payments, subscriptions, Stripe, tax, refunds, disputes, and reconciliation;
   - `docs/PHASE_1_1_EXPERIENCE_UPGRADE.md` and `docs/DESIGN_SYSTEM.md` for UI/product experience;
   - `docs/PHASE_2_PROGRESS_AUDIT.md` for Marketplace, Wanted Ads, Offers, Auctions, Dispatch, analytics, and acceptance;
   - `docs/ENGINEERING_CONTROL_BASELINE.md` and relevant runbooks for security, release, and operations.
8. `README.md`, schemas, tests, implementation code, and Git history as implementation evidence.

Do not load every domain document blindly when one domain is being changed. Read the always-on knowledge first, then the relevant domain-specific sources.

When documents conflict, prefer the newest explicit operator direction and the newest domain-specific source. Record unresolved contradictions rather than silently choosing a risky interpretation.

## Autonomous task selection

For each autonomous iteration:

1. Read core knowledge, relevant domain knowledge, the implementation, tests, and recent history.
2. Classify unfinished work as one of:
   - `code-now`: can be completed and verified in the current development workspace;
   - `external-toolchain`: needs a local emulator/compiler/SDK/device/tool that is unavailable;
   - `credentials`: needs a secret or authenticated provider operation not safely available;
   - `provider-dashboard`: needs Stripe, Firebase Console, App/Play Store, DNS, email provider, or similar evidence/action;
   - `production`: changes live configuration, deployment, public activation, or money movement;
   - `legal-tax`: requires legal, tax, accounting, registration, licensing, or policy ownership;
   - `ambiguous-policy`: product/business decision is not established.
3. Select the highest-priority `code-now` item that advances the active roadmap coherently.
4. A blocked item does not authorize marking it complete; record it and continue to another safe item when possible.
5. Implement exactly one bounded increment per invocation.
6. Update a tracker only when the tracker wording is actually supported by repository evidence and required verification.

If no safe `code-now` work remains, return a human blocker instead of fabricating progress.

## Mandatory safety boundaries

Never autonomously:

- merge to `main`, force-push, rewrite history, or delete branches;
- deploy Firebase, Cloud Functions, Hosting, App Check, Firestore Rules/indexes, or any production release;
- activate public production, paid features, regulated property workflows, escrow/trust custody, carrier settlement, or marketplace money movement;
- create or mutate live Stripe customers, subscriptions, invoices, charges, refunds, transfers, disputes, coupons, products, prices, payment links, or webhook subscriptions;
- change live tax registrations, tax-readiness claims, GST/HST/PST treatment, legal entity declarations, or accounting ownership;
- expose, print, copy, rotate, or commit secrets, API keys, webhook secrets, service-account credentials, or tokens;
- send production email/SMS/push notifications or trigger other irreversible third-party side effects;
- weaken authentication, MFA, App Check, authorization, Firestore/Storage Rules, callable boundaries, idempotency, moderation, audit history, quotas, feature gates, or release controls to make a test pass;
- delete, skip, mute, or materially relax tests simply to obtain a green result;
- run destructive Git commands such as `git reset --hard`, `git clean -fd`, or commands that discard operator work.

Production-facing code, tests, runbooks, migrations, and evidence tooling may be prepared, but activation remains human controlled.

## Engineering rules

- Inspect before editing. Search for an existing implementation before adding a second path.
- Preserve all working routes, commands, Functions, roles, feature flags, security contracts, lifecycle states, and user workflows unless an explicit tracked deprecation exists.
- Read `docs/FEATURE_REGISTRY.md` before significant refactors.
- Read `docs/DESIGN_SYSTEM.md` before UI work.
- Reuse theme tokens and shared components instead of introducing local competing design systems.
- Prefer the smallest coherent change that moves one tracked gate forward.
- Do not combine broad refactoring with unrelated product behavior in one autonomous increment.
- For risky refactors, characterize behavior first, extract one responsibility, verify, commit, then continue in a later increment.
- Ordinary hand-written source must follow the configured size budget: 600 lines is a ceiling, not a target. Do not grow an existing source file that is already above the ceiling.
- Prefer files roughly 150–350 lines when responsibility permits; do not create artificial fragmentation solely to meet a number.
- Preserve server-authoritative financial calculations, immutable snapshots, privileged state transitions, and participant privacy.
- Keep client behavior fail-closed when provider evidence is absent.
- Avoid mock/demo production paths unless a test fixture explicitly requires them.
- Do not add a dependency when existing dependencies or platform libraries are sufficient.
- Durable project decisions are appended to `docs/DECISION_REGISTER.md`; supersede old decisions rather than erasing the rationale.
- Keep generated/temp autonomous-run artifacts out of commits.
- Do not create commits, branches, tags, PRs, merges, or pushes from inside the coding-agent turn; the outer runner owns Git writes after verification.
- Read-only subagents may be used for discovery/review. Avoid parallel writer agents against the same worktree.

## Verification

Run focused tests for changed behavior during the coding turn.

Before a verified autonomous commit, the outer runner must run:

1. the autonomous quality guard (`tool/autonomous_guard.ps1` for Pipe Buyer);
2. the complete verification command configured in `.autobuild/project.json` (`.\tool\verify.ps1` for Pipe Buyer).

If either fails, repair only root causes associated with the current increment or a directly exposed defect required for that increment. If the failure is unrelated or requires an unavailable external toolchain, report the blocker and leave the increment uncommitted.

For payment work, completion evidence must agree across applicable UI, server-authoritative calculation, provider contract, webhook/event processing, Firestore ledger/state, failure handling, reconciliation logic, and acceptance tests. Code presence alone is not completion.
