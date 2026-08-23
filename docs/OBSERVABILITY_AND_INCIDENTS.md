# Pipe Buyer Observability and Incident Policy

Status: active engineering contract

## Objective

Operational failures must be diagnosable without exposing secrets or private user data. Logs and alerts exist to support recovery, not to collect everything.

## Observability principles

- High-risk server operations should produce bounded, structured success/failure evidence.
- User-visible failures should map to safe categories rather than raw backend exceptions.
- Correlation identifiers should be used where they materially help trace multi-step workflows.
- Sensitive payloads, credentials, access tokens, payment secrets, private messages, identity evidence, and unnecessary exact locations must not be logged.
- Logging volume and retention are cost-controlled.

## Minimum operational evidence for high-risk operations

Where applicable, retain safe metadata such as:

- operation/command name;
- stable request or transaction identifier;
- actor/role identifier in a privacy-appropriate form;
- lifecycle transition attempted;
- provider object/event identifier when required for reconciliation;
- success/failure classification;
- idempotency/retry outcome;
- timestamp;
- environment/release SHA or version;
- audit record reference.

Do not log complete prompts, secrets, payment method data, or entire Firestore documents merely for convenience.

## User-facing errors

Errors should tell the user what can be done next without leaking internals. Distinguish at least where relevant:

- validation problem;
- authorization/denied state;
- offline/network failure;
- temporarily unavailable provider/backend;
- stale/conflicting state;
- action already completed/idempotent duplicate;
- unknown safe failure with retry/support path.

## Alert ownership

An operational alert is incomplete unless there is:

- a named owner/team;
- a severity threshold;
- a response expectation;
- a runbook or first diagnostic steps;
- suppression/deduplication strategy to avoid alert storms.

Autonomous development may implement alerting code/configuration templates but cannot claim operational readiness until routing/ownership is actually verified.

## Incident severity

- `SEV-1`: security breach, financial integrity issue, widespread data corruption/loss, critical production outage.
- `SEV-2`: major feature unavailable or material subset of users blocked, no immediate data/financial loss.
- `SEV-3`: degraded behavior with workaround or limited blast radius.
- `SEV-4`: minor defect/operational nuisance.

## Incident response sequence

1. Stop/disable unsafe behavior using approved feature/configuration controls if required.
2. Preserve evidence; do not destroy logs/history while trying to clean up.
3. Identify affected environment, release SHA, provider state, data scope, and user impact.
4. Prefer rollback/feature disable over speculative production patching when safer.
5. Reconcile financial/data/provider state before declaring recovery for high-risk incidents.
6. Record root cause, contributing factors, exact remediation, and tests added.
7. Add/update a risk, decision, runbook, or guard when the incident exposed a missing control.

## Autonomous incident behavior

The autonomous builder is not an incident commander and must not make live production changes. It may:

- analyze repository evidence/log files supplied locally;
- prepare a candidate fix on an isolated branch;
- add regression tests;
- update runbooks and risk controls;
- prepare rollback/audit tooling that remains non-live.

It must not deploy an emergency fix, rotate credentials, disable production security, refund/transfer money, or mutate live data without human control.

## Diagnostics privacy review

New telemetry must state:

- what fields are collected;
- why each is needed;
- retention/aggregation behavior;
- who can access it;
- whether a third party receives it;
- how the feature behaves when remote diagnostics are disabled.

Existing `docs/PRODUCTION_DIAGNOSTICS_RUNBOOK.md` remains authoritative for current Crashlytics/remote diagnostics rollout.