# Dispatch quote planner Node.js 22 `matchAll` repair

## Symptom

Running `tool/verify_dispatch_quote_planner_source_map_units.ps1` failed before any Dispatch UI repair was applied with:

```text
TypeError: String.prototype.matchAll called with a non-global RegExp argument
```

The failure occurred in `tool/apply_dispatch_quote_planner_source_map_units.mjs` inside `replaceOne()`.

## Root cause

`String.prototype.matchAll()` requires a regular expression with the global (`g`) flag. The repair helper accepted both global and non-global regular expressions and passed them directly to `matchAll()`. Several exact replacement patterns are intentionally non-global, so Node.js 22 rejected the call before target-count validation could run.

## Proven fix

Before applying the Dispatch quote-planner repair, run `tool/repair_dispatch_quote_planner_matchall.mjs`. The preflight changes only the helper implementation so it clones the supplied RegExp with `g` added for match counting, while leaving the original RegExp available for the single replacement.

`tool/verify_dispatch_quote_planner_source_map_units.ps1` now runs this preflight automatically before the main repair.

## Control rule

Do not loosen the `replaceOne()` safety behavior. It must still stop unless exactly one intended source target is found. The fix is only to make the uniqueness check compatible with non-global regular expressions on Node.js 22.
