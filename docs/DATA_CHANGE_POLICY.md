# Pipe Buyer Data Change Policy

Status: mandatory engineering contract

## Scope

Applies to Firestore documents/collections, Storage metadata, indexes, durable transaction records, backfills, migrations, normalization jobs, cleanup jobs, imports/exports, and any script or Function capable of changing persisted user/business data.

## Default rule

Data mutations are higher risk than ordinary code edits because rollback may not equal deploying an older commit. The autonomous system may prepare migration tooling and run local/emulator dry runs; production mutation remains human-controlled.

## Schema evolution

Prefer additive, backward-compatible evolution:

- add optional/new-version fields before removing old fields;
- readers tolerate supported older records during the migration window;
- do not repurpose an existing field to mean something materially different;
- use explicit version/policy identifiers where historical interpretation matters;
- update schema documentation and relevant security rules/tests.

## Migration/backfill requirements

A non-trivial migration must provide:

1. explicit source and target schema/meaning;
2. environment hard lock;
3. dry-run mode that performs no writes;
4. bounded page/batch size;
5. deterministic selection/order when possible;
6. precondition or update-time protection against racing participant changes;
7. progress/checkpoint state for long runs;
8. resumability without duplicating effects;
9. canary mode before full apply;
10. clear counters/results for scanned, eligible, changed, skipped, conflicted, failed;
11. rollback/restore strategy before apply;
12. refusal to roll back records that have changed in ways that make reversal unsafe;
13. isolated staging rehearsal and retained evidence before production approval.

## Destructive changes

Deletion, destructive rewrite, irreversible compaction, or removal of historical/audit data is `CRITICAL` unless explicitly proven otherwise.

Autonomous code must not execute destructive production mutation. A destructive proposal requires a decision record, retention/privacy assessment, backup/restore evidence, exact targeting, and human approval.

## Financial and audit records

Do not rewrite historical accepted financial policy snapshots, provider IDs, webhook event IDs, transaction IDs, dispute/refund IDs, reconciliation fields, or immutable revision history merely to simplify the current schema.

Corrections should normally append a correction/revision/audit record rather than erase the original evidence.

## Security and privacy

Migration tools must use least privilege and must not move private fields into public documents. Logs/checkpoints must not store secrets or unnecessary sensitive payloads.

Exact Dispatch locations, identity evidence, private messages, payment-related sensitive fields, and other participant-private data retain their existing access boundary during and after migration.

## Index changes

Index changes are reviewed with the query contract. Removing an index requires evidence that no supported query/release depends on it. New high-cardinality or high-write-cost indexing should include cost/scalability consideration.

## Imports

Imports require:

- provenance/source identification;
- validation and normalization rules;
- duplicate/idempotency handling;
- rejection/quarantine of invalid records;
- dry-run/sample report;
- bounded apply.

Do not treat externally supplied data as trusted merely because it came from an administrator.

## Exports

Exports containing user/business data require authorization, least-data selection, safe storage/retention, and explicit handling of private/sensitive fields. Accountant/reconciliation exports must preserve exact financial identifiers and currency/policy context.

## Backup/restore relationship

A source-code rollback does not restore mutated data. Before a high-risk production data change, use `docs/FIREBASE_BACKUP_RESTORE_RUNBOOK.md` and the migration-specific rollback procedure.

If restore has not been rehearsed for the affected data class and the change is not safely reversible by construction, production approval remains blocked.

## Autonomous result requirements

If an increment changes schema/migration/backfill behavior, the worker result must declare `data_change=true`, summarize compatibility, name migration/rollback implications, and identify the tests/dry-runs actually performed.