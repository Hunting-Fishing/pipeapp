# Pipe Buyer Contracts and Compatibility

Status: mandatory compatibility contract

## Purpose

This document defines what autonomous refactors and feature work must treat as externally meaningful behavior. Compatibility includes more than public APIs; user workflows, server commands, routes, lifecycle states, security behavior, durable records, and operational tooling can all be contracts.

## Protected compatibility surfaces

Unless an explicit tracked deprecation/migration decision exists, preserve:

- public and authenticated routes/deep links;
- navigation entry points needed to reach active features;
- callable Function names and request/response contracts;
- scheduled/event Function identifiers relied on by release/parity controls;
- Firestore/Storage security expectations;
- document fields required by current clients, Functions, Rules, reports, migrations, or reconciliation;
- lifecycle state names and permitted transitions;
- feature-flag meanings and safe defaults;
- notification/event identifiers consumed by clients or operational tooling;
- provider metadata required for webhook reconciliation or idempotency;
- user-role capabilities and denial behavior;
- immutable audit/revision history;
- exported reporting/reconciliation fields;
- release manifest/parity expectations.

## Before changing a contract

The engineer must identify:

1. producers;
2. consumers;
3. persistence/history implications;
4. security/authorization implications;
5. old-client compatibility implications;
6. retry/idempotency implications;
7. tests and release checks;
8. migration/deprecation path;
9. rollback path.

If those cannot be identified, the autonomous task is not ready for a contract-breaking change.

## Backward-compatible change preference

Prefer:

- additive optional fields before required-field replacement;
- new server behavior behind safe defaults/feature flags;
- dual-read or compatibility adapters during controlled migration windows;
- versioned policy/contract identifiers for durable financial/business records;
- server support for accepted older client records when practical during rollout.

Avoid silent renames, field reuse with changed meaning, and lifecycle-state repurposing.

## Route and UI compatibility

A redesign may move presentation components but should not silently remove an active user's ability to:

- find a feature;
- complete an existing workflow;
- view historical records;
- recover from failure;
- access required support/report/moderation actions.

If navigation changes intentionally, update route tests, feature registry, deep-link documentation, and any user-facing migration/redirect behavior.

## Function compatibility

Do not replace an existing Function with a second implementation solely because it is easier to write. Extend the established path or make a deliberate versioned migration.

A Function rename/removal requires release parity updates and evidence that no supported client, webhook, scheduled trigger, or operational script still depends on the old identifier.

## Data compatibility

Persisted data outlives one release. Never assume that every document was created by the newest client.

Readers should tolerate explicitly supported older versions during a migration window. Writers should use a documented current schema/version where versioning is required. Destructive cleanup occurs only after compatibility evidence and rollback/backup gates are satisfied.

## Payment compatibility

Accepted fee, currency, tax, affiliate, entitlement, and transaction snapshots must retain the policy/version context used at acceptance. A new policy must not reinterpret historical accepted records.

Provider event IDs and object IDs used for reconciliation must not be discarded during cosmetic schema cleanup.

## Machine-readable contract

`.autobuild/feature_contract.json` protects a deliberately small set of critical paths/text anchors. It supplements but does not replace this document, the feature registry, tests, Function parity, Rules tests, or release manifests.

The autonomous guard should fail when a protected anchor disappears without an explicit contract update in the same reviewed change.

## Deprecation requirements

Intentional removal requires:

- decision/register entry;
- affected feature-registry update;
- known consumers identified;
- migration/redirect/compatibility period if needed;
- replacement tests;
- data retention/deletion treatment;
- release/rollback plan.

Deletion without this evidence is treated as possible functionality loss.