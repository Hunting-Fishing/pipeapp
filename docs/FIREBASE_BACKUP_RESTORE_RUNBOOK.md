# Firebase backup, restore, and rollback runbook

Date: July 20, 2026

Status: Procedure prepared; isolated-project rehearsal not yet completed

## Purpose and safety rules

This runbook protects Pipe Buyer from accidental deletion, application-level
data corruption, and a defective release. It does not authorize a production
restore.

Before any backup or restore operation:

1. Confirm the exact Firebase project ID and database ID in writing.
2. Record the release manifest, active Hosting version, deployed Functions,
   rules/index versions, operator, incident or rehearsal ID, and UTC time.
3. Disable affected high-risk features if continued writes could increase harm.
4. Use a least-privilege backup or restore identity, never a personal
   service-account key committed to source.
5. Restore into a new isolated database first. Never overwrite or import into
   the active production database as the first recovery step.
6. Record operation IDs and wait for completion; starting a command is not
   evidence that recovery succeeded.

Firestore scheduled backups require a billing-enabled Blaze project and incur
storage and restore costs. Approval of billing and retention remains an
external owner decision.

## Required access

Separate responsibilities where possible:

- backup schedule administration:
  `roles/datastore.backupSchedulesAdmin`
- backup inspection:
  `roles/datastore.backupsViewer`
- restore execution:
  `roles/datastore.restoreAdmin`
- managed export/import:
  `roles/datastore.importExportAdmin` plus the required bucket access

Do not grant broad owner access when a narrower role is sufficient.

## Configure and verify scheduled backups

After confirming the target project explicitly:

```bash
firebase firestore:backups:schedules:list \
  --project PROJECT_ID \
  --database '(default)'
```

An approved daily schedule with a documented retention period can be created
with:

```bash
firebase firestore:backups:schedules:create \
  --project PROJECT_ID \
  --database '(default)' \
  --recurrence DAILY \
  --retention 14w
```

The retention example is the current maximum, not an automatic product
decision. Record the selected retention and cost approval before creation.

Verify available backups:

```bash
firebase firestore:backups:list \
  --project PROJECT_ID \
  --location FIRESTORE_LOCATION
```

Then inspect the selected full backup resource:

```bash
firebase firestore:backups:get \
  --project PROJECT_ID \
  BACKUP_RESOURCE_NAME
```

## Restore rehearsal

Restores must target a new database ID:

```bash
firebase firestore:databases:restore \
  --project ISOLATED_PROJECT_ID \
  --backup BACKUP_RESOURCE_NAME \
  --database RESTORE_DATABASE_ID
```

The restore evidence must include:

- source project, database, backup resource, creation time, and state
- isolated target project and new database ID
- restore operation ID, start/end time, and terminal state
- representative document counts for users, listings, offers, conversations,
  auctions, Dispatch jobs, reports, and control-plane configuration
- access-control checks proving ordinary users cannot read private collections
- application smoke tests against the isolated restoration
- reviewer and final pass/fail decision

A cancelled restore can leave partial changes. Do not treat cancellation as an
automatic rollback.

## Managed export for migration rehearsals

Managed export/import is separate from scheduled backups. Use it only when the
rehearsal requires collection-level migration or transfer between databases.
It requires billing, a compatible Cloud Storage bucket, and explicit Firestore
service-agent access.

```bash
gcloud firestore export gs://APPROVED_BUCKET/pipe-buyer/REHEARSAL_ID \
  --project SOURCE_PROJECT_ID \
  --database '(default)' \
  --async
```

Record the returned operation and monitor it:

```bash
gcloud firestore operations describe OPERATION_NAME \
  --project SOURCE_PROJECT_ID
```

Never import an incomplete or partially cancelled export.

## Application release rollback

1. Activate the relevant server kill switches.
2. In Firebase Hosting release history, roll back to the recorded prior version
   or clone the recorded version to the live channel.
3. Run the exact-commit deployment workflow against the last accepted commit
   to restore Functions, rules, indexes, Storage rules, and Hosting together.
4. Compare the generated release manifest with the accepted manifest,
   including all source and artifact hashes and expected Function names.
5. Run login, listing read, messaging, offer, auction, Dispatch, report, and
   administrator smoke checks appropriate to the enabled feature set.
6. Re-enable features only after the incident owner approves the evidence.

Hosting rollback does not roll back Functions, rules, indexes, or data.
Each component must be checked explicitly.

## Rehearsal exit evidence

Gate 1 backup/restore work is complete only when:

- staging and production schedules are approved and recorded
- an isolated Firestore restore reaches a terminal successful state
- restored data and security behavior pass the acceptance checklist
- recovery time and recovery point observations are recorded
- the prior Hosting and backend release is successfully restored in staging
- named engineering and operational owners approve the evidence

Until then, this document is a prepared control, not proof of recovery.
