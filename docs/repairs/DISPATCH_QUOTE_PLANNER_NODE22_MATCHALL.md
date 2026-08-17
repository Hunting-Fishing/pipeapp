# Dispatch quote planner Node.js generator compatibility repair

## Symptoms

Running `tool/verify_dispatch_quote_planner_source_map_units.ps1` exposed two generator failures before the Dispatch UI repair could complete.

First failure:

```text
TypeError: String.prototype.matchAll called with a non-global RegExp argument
```

Second failure after correcting `matchAll`:

```text
ReferenceError: data is not defined
```

The second error occurred while Node.js evaluated embedded Dart source inside a JavaScript template literal, for example:

```text
final type = '${data['unitTypeCode'] ?? 'hauling_tractor'}';
```

## Root causes

### 1. RegExp uniqueness helper

`String.prototype.matchAll()` requires a RegExp carrying the global (`g`) flag. The repair helper accepted non-global exact-match patterns and passed them directly to `matchAll()`.

### 2. Dart interpolation embedded inside JavaScript template strings

The quote-planner repair generator stores blocks of Dart source inside JavaScript backtick strings. Dart expressions using `${...}` were not escaped for the outer JavaScript template literal. Node.js therefore attempted to evaluate Dart identifiers such as `data`, `widget`, `listing`, and `doc` as JavaScript variables before the generator could write anything.

## Proven fix

`tool/repair_dispatch_quote_planner_matchall.mjs` is now a generator-compatibility preflight. It:

1. repairs the `matchAll()` uniqueness counter by cloning the supplied RegExp with `g` only for counting;
2. escapes unescaped Dart `${...}` interpolation inside the generator's `models`, `restore`, and `helpers` template blocks;
3. validates known interpolation markers after the repair;
4. remains idempotent and stops if the expected generator structure is not found.

`tool/verify_dispatch_quote_planner_source_map_units.ps1` runs this preflight automatically and then runs `node --check` on the repaired generator before allowing it to touch Dart source files.

## Control rule

Do not weaken the exact-target protection in `replaceOne()`. The generator must still stop unless exactly one intended source target exists. Generator-language compatibility issues are repaired before source modification rather than bypassing the safety checks.
