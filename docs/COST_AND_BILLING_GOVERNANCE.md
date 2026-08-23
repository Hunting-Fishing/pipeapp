# Pipe Buyer Cost and Billing Governance

Status: mandatory cost-control contract

## Objective

Prevent development tools, cloud infrastructure, providers, background jobs, AI features, and product billing from creating unplanned spend or financially inconsistent behavior.

## Autonomous no-spend rule

The autonomous builder must not, without explicit human approval:

- enable a paid cloud service or paid provider;
- upgrade a provider plan;
- create or modify live payment products/prices/subscriptions/charges/refunds/transfers;
- increase production minimum instances or other always-on paid capacity;
- activate a high-volume scheduled job;
- purchase credits or usage bundles;
- turn on production AI inference, routing, maps, messaging, email, SMS, media processing, analytics, or other metered service merely because code is ready.

It may prepare code, tests, cost estimates, configuration templates, and staging/sandbox verification where already approved.

## Cost ownership

Every material recurring provider or cloud cost needs:

- named business/technical owner;
- billing account/project/account identity;
- cost driver (requests, seats, storage, compute, tokens, messages, transactions, etc.);
- expected baseline usage;
- alert/budget mechanism where supported;
- shutdown/degradation plan if cost exceeds expectation.

## Architecture cost review

A high-volume feature must identify likely cost multipliers before implementation is considered complete. Examples:

- Firestore read/write fan-out;
- unbounded listeners;
- scheduled scans of entire collections;
- Functions/Cloud Run warm instances;
- image/video storage and transformation;
- map/routing calls;
- email/SMS/push volume;
- AI tokens/inference;
- search indexing;
- logs/diagnostics retention;
- backup retention;
- payment/provider transaction fees.

Prefer bounded, paginated, event-driven, cached, or incremental designs where correct.

## Development AI/tool spending

Coding assistants and app builders are productivity tools, not authoritative engineering systems. Their spend should be evaluated against verified output rather than message volume or generated code volume.

The reusable autonomous builder should reduce duplicated paid work by:

- maintaining durable project knowledge in Git;
- resuming from verified commits rather than re-explaining the project;
- using one bounded worker per increment;
- stopping on repeated verification failure rather than consuming unlimited attempts;
- avoiding multiple parallel writer agents on the same task;
- using independent review only where it adds a separate safety signal.

Do not run several paid agents to independently rebuild the same feature unless the task explicitly requires comparison/review.

## Product billing correctness

Product billing and cloud-service billing are separate concerns. `docs/PAYMENTS_EXECUTION_TRACKER.md` is authoritative for user/customer payment flows.

A product payment amount must come from the server-authoritative policy, not UI text or a client-supplied amount. Provider state, webhook/event state, entitlement/ledger state, reconciliation, and user-visible state must agree.

## Free trials/coupons/discounts

A free or 100%-discount transaction must not be represented as revenue. Coupon/entitlement behavior must preserve the same authoritative lifecycle and reconciliation rules as paid subscriptions where applicable.

## Budget failure behavior

If a metered provider becomes unavailable because of quota, billing, budget, or plan restrictions:

- do not silently route to production credentials from another environment;
- fail closed for privileged/financial behavior;
- degrade optional features cleanly where a safe alternative exists;
- record the provider/configuration failure without exposing secrets;
- alert the named owner where operational alerts exist.

## Cost evidence for new providers

Before production activation of a new paid provider, retain:

- pricing model/date reviewed;
- expected initial usage range;
- estimated monthly low/base/high cost;
- hard/soft quota options;
- budget/alert setup;
- cancellation/exit implications;
- data export/retention implications.

## Billing secrets

Billing/payment credentials never belong in source, screenshots, prompts, logs, or issue text. Verification should prove presence/configuration without printing the secret value.

## Review cadence

Revisit cost assumptions after significant user growth, new high-volume features, provider price changes, architecture changes, or unexpected billing events. A cost estimate is not permanent truth.