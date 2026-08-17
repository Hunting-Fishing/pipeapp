# Dispatch quote planner Node.js generator compatibility repair

## Symptoms

Running `tool/verify_dispatch_quote_planner_source_map_units.ps1` exposed three generator failures before the Dispatch UI repair could complete.

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

Third failure after adding the interpolation preflight:

```text
Error: Missing models template end marker. Stop instead of guessing.
```

## Root causes

### 1. RegExp uniqueness helper

`String.prototype.matchAll()` requires a RegExp carrying the global (`g`) flag. The repair helper accepted non-global exact-match patterns and passed them directly to `matchAll()`.

### 2. Dart interpolation embedded inside JavaScript template strings

The quote-planner repair generator stores blocks of Dart source inside JavaScript backtick strings. Dart expressions using `${...}` were not escaped for the outer JavaScript template literal. Node.js therefore attempted to evaluate Dart identifiers such as `data`, `widget`, `listing`, and `doc` as JavaScript variables before the generator could write anything.

### 3. Windows CRLF line endings made the preflight boundary matcher brittle

The first interpolation preflight searched for an exact LF-only template terminator. On the Windows checkout the generator could contain CRLF line endings, so the logically identical template boundary was not found and the preflight stopped.

## Proven fix

`tool/repair_dispatch_quote_planner_matchall.mjs` is now a generator-compatibility preflight. It:

1. normalizes CRLF/CR line endings to LF in memory before any exact structural matching;
2. repairs the `matchAll()` uniqueness counter by cloning the supplied RegExp with `g` only for counting;
3. locates generator template endings using a whitespace-tolerant structural boundary rather than one exact newline sequence;
4. escapes unescaped Dart `${...}` interpolation inside the generator's `models`, `restore`, and `helpers` template blocks;
5. validates known interpolation markers after the repair;
6. remains idempotent and stops if the expected generator structure is not found.

`tool/verify_dispatch_quote_planner_source_map_units.ps1` runs this preflight automatically and then runs `node --check` on the repaired generator before allowing it to touch Dart source files.

## Control rule

Do not weaken the exact-target protection in `replaceOne()`. The generator must still stop unless exactly one intended source target exists. Generator-language or platform compatibility issues are repaired before source modification rather than bypassing the safety checks.
