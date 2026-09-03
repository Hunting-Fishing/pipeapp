# R4 Dispatch Request Service release-gate repairs — 2026-09-03

## Scope

This record covers the two defects found while preparing Release 4 (Dispatch Request Service) for merge and production publication. Neither defect was bypassed; both were repaired at the owning layer and locked with validation.

## 1. Firebase Functions lint failure in request attachments

### Symptom

The protected R4 workflow reached Firebase Functions validation after the Flutter analyzer, focused R4 tests, and the full Flutter suite passed. ESLint stopped on `dispatch_request_attachment_commands.js` because `receiptReference` was defined but unused.

### Root cause

The attachment command was originally shaped around a command-receipt helper, but its final authorization/finalization implementation uses the existing media upload authorization record and idempotent request finalization instead. The helper and its `node:crypto` import were left behind after that design was finalized.

### Permanent repair

- Removed only the unused `receiptReference` helper and unused `node:crypto` import.
- Did not weaken ESLint or add an ignore.
- Did not alter attachment authorization, upload validation, finalization, privacy, limits, or idempotency behavior.
- The protected R4 workflow must continue to run `npm run lint` and `npm run check` for Functions before merge.

## 2. Field-service draft inherited freight job read visibility

### Symptom

R4 intentionally stores on-site/field-service requests as `draft` so they remain manageable in My Requests but do not enter the existing freight-only carrier quote board. During final diff review, the existing Firestore rule for `dispatch_jobs` was found to allow every signed-in Dispatch user to read every job document and revision. A field-service draft could therefore have been fetched directly by another signed-in user even though the UI did not advertise it.

### Root cause

The existing `dispatch_jobs` collection was designed for the legacy freight workflow, where `open` jobs are intentionally visible to signed-in Dispatch users. R4 added a private pre-matching `draft` state to the same collection without initially narrowing the collection read rule for that state.

### Permanent repair

- `dispatch_jobs` documents with `status == 'draft'` are readable only by the creating user or an MFA-authorized administrator.
- Draft revision history is protected by the same owner/admin rule using the parent job.
- Existing non-draft freight visibility is preserved, avoiding an unrelated behavior change to the proven freight board.
- Client writes remain denied; request lifecycle mutations stay server-authoritative.
- `firebase/rules-tests/dispatch_request_draft_rules.test.js` proves:
  - the request owner can read a draft and its revision;
  - an administrator can read a draft and its revision;
  - another signed-in user cannot read a draft or its revision;
  - another signed-in user can still read an open freight job and its revision.
- The rules test is part of the normal rules-test command and therefore part of the protected R4 release workflow.

## Release rule going forward

Any new state introduced into a collection with broader historical read rules must receive an explicit read-visibility review and emulator contract before production. UI filtering is not a privacy boundary.
