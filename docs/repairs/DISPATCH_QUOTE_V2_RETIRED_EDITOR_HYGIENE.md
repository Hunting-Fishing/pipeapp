# Dispatch Quote V2 Retired Editor Hygiene

## Symptom

During the first Quote V2 foundation candidate gate, the isolated Dashboard candidate failed strict analyzer before production mutation:

```text
warning - A value for optional parameter 'quoteId' isn't ever given.
pipebuyer_dispatch_dashboard_quote_v2_preflight.dart:953:57
unused_element_parameter

STOP: Candidate Quote V2 dashboard does not compile. Production source was not changed.
```

## Root cause

The Quote V2 transform correctly rewired `_newQuote(...)` to `MarketplaceDispatchQuoteForm.show(...)`, but it left the old private `_DispatchQuoteDialog` class and its Quote V1-only helper widgets at the end of `marketplace_dispatch_dashboard.dart`.

Once `_newQuote(...)` no longer constructed `_DispatchQuoteDialog`, that entire private editor became dead code. The optional `quoteId` constructor parameter therefore had no call sites, and strict analyzer correctly rejected the candidate under `--fatal-warnings`.

This was not a production application defect and not a reason to weaken analyzer settings. The candidate gate stopped before mutation, so all pre-existing production source remained unchanged.

## Correct repair

The corrected Quote V2 transform now owns the complete replacement invariant:

```text
Dashboard saved-quote entry point
  -> MarketplaceDispatchQuoteForm.show(...)
  -> old _DispatchQuoteDialog is retired
  -> old _QuoteSection is retired
  -> old _QuoteTotalCard is retired
  -> old _RoutePlanningNotice is retired
```

The retired Quote V1 editor is pruned from the transformed Dashboard candidate and from production only after candidate proof passes.

## Permanent controls

The corrected gate requires all of the following before production mutation:

1. Reusable Quote V2 form strict analyzer PASS.
2. Exact-local transform dry-run PASS.
3. Retired Dashboard quote editor absent from candidate.
4. Candidate repository strict analyzer PASS.
5. Candidate Dashboard strict analyzer PASS.
6. Candidate server-calculated quote-total test PASS.
7. Production hashes unchanged by candidate work.

After mutation it additionally requires:

- retired Dashboard quote editor absent from production;
- formatter stability;
- strict analyzer before regressions;
- Quote V2 server calculation regression;
- existing Dispatch command policy regression;
- Quote V2 Flutter contract;
- Dispatch tracker hash unchanged.

Any post-mutation failure restores all pre-existing production source files from the gate backup.

## Rule for future migrations

When a migration replaces a private implementation with a shared component, the migration must remove the retired implementation and its private-only helper widgets in the same candidate transform. Do not leave unreachable legacy UI in place and do not silence analyzer warnings caused by that dead implementation.

A replacement migration owns both sides of the invariant:

```text
new implementation installed
AND
retired implementation removed
```
