# Pipe Buyer Test Strategy

Status: mandatory engineering contract

## Objective

Testing exists to prevent regression, prove intended behavior, and expose unsafe assumptions before merge or release. Autonomous agents may add tests but may never weaken them merely to make a change pass.

## Testing layers

### 1. Static analysis and formatting safety

Use analyzer/linter/compiler checks to catch type, import, dead-code, and language-level defects. `tool/verify.ps1` remains the project-wide baseline.

### 2. Unit tests

Use unit tests for deterministic domain logic such as calculations, validation, scoring, parsing, normalization, state transitions, policy evaluation, and provider response interpretation.

Financial, permissions, lifecycle, and matching logic should prefer explicit input/output tests over UI-only coverage.

### 3. Widget/component tests

Use widget tests for interaction, semantics, state presentation, navigation intent, responsive composition, validation, error recovery, and preservation of important controls.

### 4. Server/Function tests

Privileged commands require tests for:

- allowed and denied roles;
- invalid/bounded inputs;
- duplicate/retry behavior;
- lifecycle preconditions;
- immutable snapshots/history;
- fail-closed provider/config states;
- safe error classification.

### 5. Security Rules tests

Firestore and Storage Rules changes require emulator tests for both permitted and forbidden reads/writes. A happy-path client test is not authorization evidence.

### 6. Contract/parity tests

Maintain tests for externally meaningful compatibility surfaces, including Function inventory, release manifests, routes or deep links where practical, provider command contracts, schema invariants, and feature-preservation anchors.

### 7. Integration/emulator tests

Cross-layer flows should use local emulators where possible. Test the actual authenticated call path rather than replacing every boundary with mocks.

### 8. Build/compile tests

A change affecting platform code, configuration, packages, routing, Firebase setup, or conditional compilation must compile the relevant supported targets before release acceptance.

### 9. Visual/responsive/accessibility acceptance

For material UI work, verify representative phone, tablet, and desktop/web layouts. Retain screenshot or deterministic visual evidence where the existing workflow supports it. Verify keyboard/focus/semantics/text scaling for affected critical flows.

### 10. Staging acceptance

Staging is required for provider integrations, environment-specific configuration, migrations/backfills, App Check, routing providers, payment flows, notification delivery, and other behaviors that cannot be fully proven locally.

Production is not a test environment.

## Regression-first rule

Before modifying high-risk behavior, locate existing tests. If behavior is important but untested, add characterization coverage before or alongside the refactor.

A refactor that deletes a test because implementation changed is suspect. Prefer rewriting the test against the preserved public behavior.

## Negative-path requirement

High-risk features must test failure as deliberately as success. Examples:

- unauthorized user;
- missing App Check;
- stale state/revision;
- duplicate event;
- provider timeout/failure;
- invalid amount or currency;
- missing required data;
- offline client;
- cancelled flow;
- partial migration failure;
- denied private-data access.

## Payment testing rule

Payment tests must distinguish:

- local deterministic policy tests;
- provider contract tests;
- webhook/event idempotency tests;
- emulator state/ledger tests;
- controlled provider acceptance;
- reconciliation evidence.

A mocked Stripe response cannot prove live configuration or financial reconciliation.

## Data migration testing rule

Migration/backfill tooling requires at minimum:

- dry run;
- bounded canary;
- deterministic selection;
- clean-state or precondition checks;
- checkpoint/resume behavior when needed;
- rollback refusal when participant/live changes make reversal unsafe;
- isolated staging rehearsal.

## Flaky-test policy

Do not automatically retry a failing test until green and call it success. Classify the failure. If a test is genuinely flaky, record the cause and create a bounded repair. Repeated retry without root-cause analysis is not acceptance evidence.

## Test deletion policy

A test may be deleted only when:

- the covered behavior is explicitly deprecated or replaced;
- the replacement coverage is identified;
- the change is traceable to a product/architecture decision;
- no safety or compatibility coverage is lost.

## Autonomous worker requirement

Every autonomous result must state:

- focused tests run;
- tests not run and why;
- compatibility checks performed;
- whether data, dependency, security, billing, provider, or release behavior changed.

The independent reviewer and full verification gate may reject an increment even when the worker's focused tests pass.