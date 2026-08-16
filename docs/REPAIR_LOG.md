# Pipe Buyer Repair Log

This log records root causes and permanent repair rules so the same failure is not diagnosed repeatedly.

## 2026-08-16 - Windows PowerShell 5.1 parser failure in Carrier Quote V2 runner

### Symptom

`tool/apply_carrier_quote_premium_v2.ps1` failed before executing its first migration step. Windows PowerShell reported parser errors around text containing an em dash in strings such as the unknown-weight UI marker.

### Root cause

The script was stored as UTF-8 without a BOM and contained non-ASCII punctuation. Windows PowerShell 5.1 can interpret UTF-8 bytes using the active Windows code page. The UTF-8 byte sequence for typographic punctuation can then decode into characters that PowerShell treats as quote delimiters, producing false string termination and cascading parser errors.

This was a tooling defect, not a Flutter, Firebase, Dispatch, or marketplace-data defect.

### Permanent repair

1. PowerShell runner files used by the Windows development workflow must remain ASCII-only unless the repository deliberately standardizes on a BOM-aware encoding or PowerShell 7.
2. `tool/assert_windows_powershell_safe.ps1` checks both raw bytes and the Windows PowerShell parser before a runner is executed.
3. UI text may still use typographic punctuation in Dart/JavaScript. PowerShell validation should test stable ASCII substrings instead of copying typographic UI text into `.ps1` files.
4. New repair runners must be parser-checked before they are handed to the developer.

### Carrier Quote V2 status at failure

The parser failure occurred before `apply_carrier_quote_premium_v1.mjs` or the deferred-weight finalizer executed. The product form was therefore not partially migrated by that failed run.

## Process rule going forward

Avoid repeated V1/V2/V3-style repair chains when a stable integration path can be used. Prefer:

- one canonical runner per feature,
- additive components over large exact-text rewrites,
- preflight syntax/parser checks before mutation,
- exact file backups and hash-based rollback for any mutation,
- strict analyzer/tests after mutation,
- recording the root cause and successful fix here.
