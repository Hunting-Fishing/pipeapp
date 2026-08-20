# Dispatch Quote V2 Candidate Hygiene

## Symptom

The Quote V2 V2 gate stopped before production mutation while analyzing the exact transformed Dashboard candidate. The analyzer reported three strict-warning failures:

1. one `unused_import` in the transformed Dashboard candidate;
2. `_DispatchUnitRequirementDraft` was no longer referenced;
3. `_DispatchUnitRequirementDraft.fromMap` was no longer referenced.

The gate correctly reported that production source was not changed.

## Root cause

The local Dashboard contains additional private support code that is not present in the formal remote baseline. After Quote V2 replaces the old Dashboard quote-authoring path and removes the retired Quote V1 dialog, some local-only support declarations and an associated import become unreachable.

The previous Quote V2 migration validated the shared quote form and removed the retired quote dialog, but it still assumed that all other local private Dashboard declarations would remain referenced. That assumption was false for the exact local source.

This is a migration-hygiene issue, not a Quote V2 pricing, Firebase, Firestore, or Functions defect.

## Permanent control

Quote V2 now uses an exact-candidate promotion gate:

1. fingerprint the existing production sources;
2. build the Quote V2 candidate from the exact local source;
3. remove `_DispatchUnitRequirementDraft` only when the class has no references outside its own top-level declaration;
4. run the Dart analyzer in machine format against the candidate Dashboard;
5. permit at most one remaining `UNUSED_IMPORT` diagnostic and remove exactly the analyzer-identified import line from the candidate only;
6. reject any other analyzer diagnostic before production mutation;
7. format and strictly analyze repository, Dashboard, and Jobs candidate files;
8. run the candidate server quote-calculation tests;
9. prove production hashes are unchanged;
10. promote the exact analyzed candidate instead of rerunning a separate mutation transform;
11. strictly analyze promoted production before regressions;
12. restore all pre-existing production sources automatically if a post-promotion gate fails;
13. prove the Dispatch master tracker was not modified.

## Why exact-candidate promotion matters

A migration can be structurally correct against the remote baseline yet expose dead private code in a user's exact local source. Re-running another generic transform after the candidate has passed analysis can reintroduce a mismatch between what was proven and what was written.

For migrations with local-source divergence, the preferred pattern is:

```text
exact local source
  -> temporary transformed candidate
  -> candidate-specific hygiene
  -> formatter/analyzer/runtime or policy proof
  -> production hash still unchanged
  -> promote that exact proven candidate
  -> production analyzer/regressions
  -> rollback on any post-promotion failure
```

Do not suppress `unused_import` or `unused_element` warnings merely to get a green gate. Remove dead migration artifacts only when their unreferenced status is proven.

## Current focused gate

Use:

`tool/run_dispatch_quote_v2_foundation_gate_v3.ps1`

Do not rerun the earlier Quote V2 foundation or V2 gate once this exact-candidate gate is available.
