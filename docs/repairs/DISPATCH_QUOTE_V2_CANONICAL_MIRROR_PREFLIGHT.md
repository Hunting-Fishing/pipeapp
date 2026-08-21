# Dispatch Quote V2 Canonical Mirror Preflight

## Symptom

The Quote V2 V4 gate reached strict analysis of the cleaned Jobs candidate and reported three compile issues in `pipebuyer_dispatch_page_quote_v2_preflight.dart` even though the repository candidate had already been transformed for the new Quote V2 `bid(...)` contract.

Production source was not changed.

## Root cause

V4 analyzed renamed preflight files one at a time inside the live package. That is not a coherent cross-file migration graph.

The transformed Jobs candidate still contains the canonical import:

`import 'marketplace_dispatch_repository.dart';`

When the renamed file `pipebuyer_dispatch_page_quote_v2_preflight.dart` is analyzed in the live package, that import resolves to the old production repository, not to `pipebuyer_dispatch_repository_quote_v2_preflight.dart`.

Likewise, imports such as `marketplace_dispatch_dashboard.dart` resolve to the old production neighbor rather than the transformed Dashboard candidate.

A cross-file migration therefore can produce false preflight compiler diagnostics because the renamed candidate is being type-checked against a mixture of new candidate code and old production code.

This is a preflight-graph defect. It is not Firebase, Flutter runtime state, Chrome, quote data, or user procedure.

## Permanent rule

Do not prove a multi-file Dart migration by analyzing renamed candidates that still import canonical production filenames.

Instead build a temporary mirror of the current local package:

1. copy the current local `lib` tree so all uncommitted local dependencies are preserved;
2. copy the local `pubspec.yaml`, lockfile, analysis options, and `.dart_tool/package_config.json`;
3. place the transformed Quote V2 repository, Dashboard, and Jobs candidates into the mirror under their real canonical filenames;
4. run strict analyzer inside the mirror;
5. prove the live production hashes remain unchanged;
6. only after the mirror graph is green, promote the exact transformed candidates to production;
7. immediately analyze promoted production and rollback on any post-promotion failure.

## Why canonical filenames matter

Dart type resolution follows imports, not the intent of the migration gate. A renamed file such as:

`pipebuyer_dispatch_page_quote_v2_preflight.dart`

can still import:

`marketplace_dispatch_repository.dart`

and therefore compile against the old repository API.

The mirror preserves the exact import text while making the imported canonical filenames point to the transformed candidate graph. This gives an accurate pre-mutation compile proof without touching live production source.

## Current gate

Use:

`tool/run_dispatch_quote_v2_foundation_gate_v5.ps1`

Do not rerun V1, V2, V3, or V4 after this gate is available.
