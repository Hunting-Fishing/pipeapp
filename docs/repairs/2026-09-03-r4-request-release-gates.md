# R4 Dispatch Request Service release-gate repairs — 2026-09-03

## Scope

This record covers the defects found while preparing Release 4 (Dispatch Request Service) for merge and production publication. None were bypassed; each was repaired at the owning layer and locked with validation.

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

## 3. Mixed freight and field services could cross the R4 matching boundary

### Symptom

The multi-service selector allowed a customer to combine route-based work, such as pipe hauling, with on-site work, such as vacuum truck or crane service. The original path rule treated any request containing transportation or pilot work as `freight_route`. That meant a mixed request could enter the proven freight quote board even though R4 deliberately does not publish on-site service requests into matching yet.

### Root cause

The request-path derivation was designed to choose a form shape, not to enforce a release boundary between two different provider-matching lifecycles. Multi-select made that distinction operationally important.

### Permanent repair

- The client review identifies mixed route-based and field-service selections and tells the customer to create separate requests so each reaches the correct provider workflow.
- The server independently rejects mixed request paths with `invalid-argument`; bypassing the client cannot push field-service work into the freight board.
- Pure transportation/pilot requests continue through `freight_route` unchanged.
- Pure crane/field requests continue through the private R4 `field_service` draft lifecycle.
- Flutter and Functions tests lock the mixed-path rejection on both sides of the trust boundary.
- My Requests labels field-service drafts as `RECEIVED`, shows that provider matching is not opened yet, and directs customers to Directory → Get Quote for immediate provider-specific outreach instead of advertising freight quotes.

## 4. Cancellation privacy contract produced a false release failure

### Symptom

The protected Functions suite reported one failing contract even though the cancellation command writes `cancellationReason` only to `privateChanges`. The failing source test used a greedy expression beginning at `publicChanges` and therefore continued into the later `privateChanges` object, incorrectly reporting the private cancellation reason as public.

### Root cause

The test asserted privacy against an unbounded source range rather than the `publicChanges` object itself. This coupled the contract to unrelated source text that follows the public object and created a false negative without identifying an actual data-exposure defect.

### Permanent repair

- Production cancellation behavior was left unchanged because the implementation already separates public and private writes correctly.
- The contract now extracts the explicit `publicChanges` object with a non-greedy boundary and asserts that object does not contain `cancellationReason`.
- The test still requires the private cancellation reason and public cancellation lifecycle fields to be present, so it preserves coverage in both directions.
- Release policy: source-level privacy contracts must scope assertions to the actual object or operation being protected; a broad greedy match must not be used as a proxy for a data boundary.

## 5. R4 rules workflow used a different emulator project from Storage cross-service tests

### Symptom

The protected rules step failed five Storage tests. Valid chat attachments, listing media, Dispatch request attachments, and report evidence uploads were denied, while the Storage emulator logged null-value evaluation errors at the two `firestore.get(...)` calls used by upload authorization and listing-draft ownership.

### Root cause

The R4 workflow launched Firestore and Storage emulators with project `demo-pipe-buyer-r4-rules`, while the established Storage rules test environment and its Firestore fixtures use `demo-pipe-buyer-rules`. Storage rules make cross-service `firestore.get(...)` calls, so the project mismatch caused the authorization and listing-draft lookups to resolve outside the fixture namespace and return null. The production rules themselves matched the proven R3 rules pattern; this was a verification-environment wiring defect.

### Permanent repair

- Changed only the R4 rules-workflow emulator project from `demo-pipe-buyer-r4-rules` to the established `demo-pipe-buyer-rules` used by `storage_rules.test.js` and the protected deployment verification path.
- Did not weaken or bypass Storage or Firestore rules.
- Kept the R4 draft-only Firestore contract isolated under its own test project because it does not rely on a Storage-to-Firestore cross-service lookup.
- The full Firestore and Storage rules suite remains mandatory before callable integration and release build steps can run.

## Release rules going forward

1. Any new state introduced into a collection with broader historical read rules must receive an explicit read-visibility review and emulator contract before production. UI filtering is not a privacy boundary.
2. A multi-service request may combine services only when they share the same authoritative matching lifecycle. A convenient client form must never collapse separate server workflows into the wrong marketplace path.
3. Privacy/source contracts must assert a bounded object, write, or behavior. Do not allow a regex to traverse unrelated later code and turn a correct privacy boundary into a false release failure.
4. Emulator project IDs used by cross-service security rules must match the project ID used by the rule test fixtures. A verification workflow must not silently change that namespace when Storage rules depend on Firestore documents.
