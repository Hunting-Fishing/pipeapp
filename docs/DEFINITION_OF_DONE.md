# Pipe Buyer Definition of Done

Status: mandatory completion contract

A feature, bug fix, refactor, migration, or release task is not complete because code compiles or a screen exists. Completion requires evidence appropriate to the risk and scope.

## Universal completion criteria

Before work is marked complete:

1. The intended behavior is traceable to an active roadmap item, issue, operator decision, or defect.
2. Existing behavior and compatibility surfaces affected by the change were identified before editing.
3. Implementation uses existing architecture and design-system paths unless an explicit architecture decision authorizes a new pattern.
4. Error, loading, empty, denied, offline/retry, and partial-failure states are handled where relevant.
5. Authentication, authorization, App Check, validation, idempotency, privacy, and server-authority boundaries remain intact.
6. Focused tests cover the changed behavior and meaningful failure paths.
7. The autonomous guard passes.
8. The complete project verification command passes.
9. No required external/provider/legal/physical-device acceptance is represented as complete without actual evidence.
10. Documentation, feature registry, decision register, schema/runbook, or migration notes are updated when the change alters durable project knowledge.
11. The change has a defined rollback/recovery path when it can alter persisted data, provider state, release configuration, or money-related state.
12. No secrets, credentials, private user data, or production-only values are added to source control.

## UI completion

A UI task additionally requires:

- canonical design tokens/components are reused;
- phone, tablet, and desktop/web implications are considered;
- keyboard/focus/semantics/text-scaling behavior is preserved where applicable;
- copy does not claim capabilities, payment state, verification, or provider evidence that the backend does not prove;
- existing user actions and navigation are not lost during visual refactoring.

## Backend/Function completion

A backend task additionally requires:

- inputs are bounded and validated;
- authorization is explicit;
- retries are safe and idempotent where an operation can be repeated;
- client-authored privileged fields are rejected;
- audit/history behavior is preserved for privileged state changes;
- error responses do not expose secrets or unnecessary internal details;
- callable/event/scheduled handler compatibility is covered by tests or parity controls.

## Data/schema completion

A data change additionally requires:

- schema impact is documented;
- backward/forward compatibility is assessed;
- migration/backfill is dry-run capable when mutation is non-trivial;
- the mutation is environment locked and bounded;
- resume/checkpoint strategy exists for long-running jobs;
- rollback or restore procedure exists before apply;
- representative staging evidence exists before production approval.

## Payment/billing completion

A payment or billing item additionally requires agreement across every applicable layer:

- UI amount/terms;
- server-authoritative calculation;
- immutable transaction/fee snapshot;
- provider object and mode;
- webhook/event processing;
- Firestore entitlement/ledger/state;
- retry/idempotency behavior;
- failure/cancellation/refund/dispute behavior;
- reconciliation;
- tax/legal gates;
- controlled acceptance evidence.

Code presence, a Stripe Dashboard object, or a successful redirect alone is never proof of completion.

## Dependency/provider completion

A new dependency or provider additionally requires:

- documented capability gap;
- maintenance/security review;
- licence suitability;
- version pin/lock strategy;
- failure/degradation behavior;
- cost/budget impact;
- data/privacy implications;
- exit/replacement strategy for business-critical providers.

## Refactor completion

A refactor is complete only when:

- behavior intentionally preserved before/after is identified;
- characterization coverage exists for high-risk behavior;
- external interfaces remain compatible unless explicitly changed;
- no unrelated product behavior is mixed into the same increment;
- removed code is proven unreachable/replaced rather than assumed obsolete;
- the resulting responsibilities are more cohesive and the change does not merely move complexity between files.

## Release completion

A release is complete only after the exact reviewed SHA passes the applicable staging and production gates in `docs/RELEASE_GOVERNANCE.md`. Autonomous development cannot satisfy production approval by itself.