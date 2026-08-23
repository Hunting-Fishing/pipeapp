# Pipe Buyer Non-Functional Requirements

Status: active product-quality contract

These requirements apply across feature work even when a roadmap item focuses only on visible functionality.

## Reliability and correctness

- Privileged and financial state transitions are server authoritative.
- Retryable commands are idempotent or otherwise protected against duplicate effects.
- Partial provider/backend failures leave recoverable, explainable state.
- User-visible success is not shown before the authoritative layer confirms success.
- Existing working capability is preserved unless an explicit deprecation decision exists.

## Availability and graceful degradation

- Non-critical provider failure must not unnecessarily break unrelated core workflows.
- Offline/unavailable/retry states are explicit where network access is required.
- Provider-dependent features fail closed when required safety/configuration evidence is missing.
- Production fallback from local/staging environments is prohibited.

## Performance

- Avoid unbounded Firestore reads, fan-out, list rendering, polling, retries, and background work.
- Paginate or bound potentially large datasets.
- Do not move expensive filtering or aggregation to the client merely to simplify implementation.
- Large-screen layouts must not achieve responsiveness by rendering uncontrolled amounts of data.
- Material performance regressions require profiling/measurement rather than assumption.

## Scalability

- New workflows should be safe for materially larger user/data volumes than test fixtures.
- Server operations need explicit query/write bounds.
- Scheduled/background jobs must have bounded batches, checkpoints, and rate/cost awareness.
- Hot documents, single global counters, and retry amplification should be avoided or justified.

## Accessibility

- Critical actions remain keyboard reachable on web/desktop.
- Interactive controls expose useful semantics/labels.
- Text scaling must not make critical workflows unusable.
- Color alone must not communicate important state.
- Contrast and focus treatment use the design system.
- Existing accessibility acceptance requirements remain authoritative.

## Security

- Least privilege is the default.
- Authentication is not authorization.
- Client inputs are untrusted, including client-calculated totals, roles, lifecycle values, analytics, and provider identifiers.
- Secrets never enter client bundles or source control.
- Security controls are not disabled to make local development or tests easier.

## Privacy

- Collect/store only data required for an identified product or operational purpose.
- Public documents and logs must not expose participant-private fields.
- Diagnostics must avoid credentials, private messages, unnecessary exact locations, payment secrets, and sensitive identity evidence.
- New third-party data sharing requires explicit provider/privacy review.

## Data integrity

- Immutable/revision/audit history is not rewritten for convenience.
- Schema changes remain backward compatible through the migration window.
- Destructive data changes require explicit human approval and restore evidence.
- Time, currency, units, and locale assumptions must be explicit in durable business records.

## Observability

- High-risk server operations expose enough safe diagnostics to classify failures without leaking sensitive payloads.
- Important background/provider operations have identifiable success/failure state and correlation where practical.
- Logging volume is bounded and cost-aware.
- An alert with no named owner/runbook is not considered operational coverage.

## Maintainability

- Ordinary hand-written source uses the configured file-size and change budgets.
- Duplication is reduced through coherent shared components/services, not giant generic abstractions.
- New frameworks/patterns require an architecture decision.
- Comments explain non-obvious invariants and trade-offs rather than restating syntax.

## Portability and provider resilience

- Business-critical provider usage should be behind a clear internal contract when practical.
- Provider identifiers are not unnecessarily spread through presentation code.
- Failure/disable behavior and replacement strategy are documented for critical third parties.

## Cost efficiency

- New cloud/provider/AI usage must have bounded invocation or query patterns.
- Autonomous development cannot enable paid infrastructure, subscriptions, production minimum instances, or new billable providers without human approval.
- Cost is part of architecture review for high-volume jobs, AI inference, maps/routing, media, storage, notifications, and analytics.

## Release safety

- Release artifacts are tied to an exact reviewed commit.
- Staging and production remain isolated.
- High-risk release changes have a rollback/recovery path before production approval.
- Production is not used to discover whether code compiles, migrations work, or provider configuration is correct.