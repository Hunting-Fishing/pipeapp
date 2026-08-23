# Pipe Buyer Architecture Contract

Status: active engineering contract

## System shape

Pipe Buyer is a Flutter application backed by Firebase services and server-side Functions. The application must keep privileged commercial, moderation, identity, lifecycle, and payment decisions server authoritative.

This document defines boundaries for autonomous refactoring. It is not a complete code map; implementation and domain runbooks remain the evidence source.

## Client responsibilities

Flutter may:

- render responsive UI;
- collect and validate user input;
- maintain view/session presentation state;
- perform bounded reads allowed by security rules;
- invoke authenticated server commands;
- present provider/server outcomes;
- cache or derive presentation-only values when the contract allows it.

Flutter must not become authoritative for:

- fees, commissions, taxes, settlement amounts, or immutable accepted snapshots;
- privileged role assignment or account verification;
- auction/offer/transaction lifecycle transitions that require server authority;
- moderation outcomes;
- provider evidence;
- private Dispatch location authorization;
- idempotency or money movement.

## Server responsibilities

Firebase Functions and security rules own privileged state transitions and validation. Existing callable/event handlers must be extended rather than duplicated unless a deliberate migration/deprecation decision exists.

Financial and privileged commands require explicit authorization, bounded input schemas, idempotency where retry is possible, safe audit history, and fail-closed behavior.

## Data responsibilities

- Firestore public documents must not contain participant-private data merely for client convenience;
- exact Dispatch points, addresses, postal details, and access notes remain participant protected;
- immutable/revision history must not be rewritten for cosmetic simplification;
- migrations/backfills that mutate data must be bounded, resumable where appropriate, dry-run first, environment locked, and rollback-aware;
- demo/sample runtime data must not leak into production paths.

## UI architecture

The shared design layer under `lib/core/design` is the primary home for product-wide theme and visual primitives. Reusable workflow components should be extracted when duplication becomes meaningful, but pages should not be decomposed into microscopic one-use widgets solely to satisfy a line-count metric.

Prefer separation by responsibility:

- page/screen orchestration;
- reusable presentation components;
- state/controller/view-model logic where the repository pattern supports it;
- domain services/repositories;
- server command/API boundary;
- data models/contracts.

## Refactoring contract

A refactor must preserve external behavior unless the task explicitly changes behavior.

Before moving or splitting a large file:

1. identify the public routes, callbacks, commands, state inputs, state outputs, and domain dependencies;
2. identify or add characterization tests for behavior at risk;
3. extract one coherent responsibility at a time;
4. keep public interfaces stable where practical;
5. run targeted tests after each extraction;
6. run the complete project quality gate before commit.

Do not combine a broad architecture rewrite with a product feature in one autonomous increment.

## Dependency policy

Use existing project dependencies or platform libraries when they satisfy the requirement. A new dependency requires a clear capability gap, maintenance/security review, and compatibility with the supported Flutter/Node toolchains.

Do not add an alternate state-management, routing, design-system, Firebase abstraction, or networking framework merely to make a localized task easier.

## Repository integrity

Existing routes, callable handlers, scheduled/event Functions, feature flags, security boundaries, admin capabilities, and user workflows are part of the compatibility surface unless explicitly deprecated through a tracked decision.

The feature registry and automated tests provide an additional inventory, but absence from the registry does not authorize deletion of working behavior.

## Generated and derived artifacts

Generated files, dependency lockfiles, build output, emulator state, screenshots, and run logs may exceed ordinary source limits where appropriate. Generated output must not be manually split solely to satisfy a source-length rule.

## Production boundary

Repository code may prepare release artifacts, migrations, provider adapters, or readiness tooling. Autonomous development does not authorize deployment, production activation, live-provider mutation, legal/tax declarations, or merging to `main`.
