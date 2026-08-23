# Dispatch Quote V2 Cascading Dead-Island Repair

## Symptom

During the Quote V2 exact-candidate gate, the candidate correctly removed the retired `_DispatchUnitRequirementDraft` class, but strict analyzer then exposed another unused element:

```text
The declaration '_dispatchQuoteUnitTypes' isn't referenced.
```

Production source was not changed because this occurred before candidate promotion.

## Root cause

The previous hygiene control treated `_DispatchUnitRequirementDraft` as an isolated dead declaration. It was actually the consumer of a small legacy dependency island. Removing the class made its supporting top-level `_dispatchQuoteUnitTypes` declaration newly unreachable.

This is a cascading migration-hygiene issue: deleting one retired consumer can expose formerly referenced helper declarations as dead code.

## Correct repair

`tool/clean_dispatch_quote_v2_candidate_hygiene.mjs` now performs dependency-ordered cleanup on the temporary Quote V2 candidate:

1. Remove `_DispatchUnitRequirementDraft` only if no references exist outside its own declaration.
2. Re-evaluate `_dispatchQuoteUnitTypes` after the class is removed.
3. Remove `_dispatchQuoteUnitTypes` only when it has exactly one remaining occurrence, its own bounded top-level `const`/`final` declaration.
4. Leave production untouched during cleanup.
5. Let the Dart analyzer identify any remaining unused import after the dead island has been removed.
6. Reject any unrelated diagnostic instead of broadly deleting local code.
7. Promote only the exact candidate that passed analyzer and server tests.

## Permanent rule

When a migration removes a private implementation, treat associated private helpers as a dependency island rather than assuming the first unused declaration is the entire cleanup. Re-run analyzer after each bounded dependency-layer removal and only delete analyzer-proven, unreferenced migration-owned symbols.

Do not use broad dead-code deletion or warning suppression to make the gate green.
