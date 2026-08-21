# Dispatch Quote V2 Canonical Mirror Preflight

## Symptom

The Quote V2 V4 gate reached strict analysis of the cleaned Jobs candidate and reported compile issues because renamed preflight files were being analyzed against a mixed candidate/production graph.

V5 corrected that by building a temporary canonical-filename mirror of the package. The repository and Dashboard then analyzed cleanly, but the mirrored Jobs page reported three identical `argument_type_not_assignable` errors.

All three errors said a `MarketplaceDispatchRepository` defined in:

`pipebuyer_dispatch_repository_quote_v2_preflight.dart`

could not be assigned to a `MarketplaceDispatchRepository` defined in:

`marketplace_dispatch_repository.dart`.

Production source was not changed.

## Root cause

There were two distinct preflight-identity problems.

### 1. V4 mixed renamed candidates with production neighbors

V4 analyzed renamed preflight files one at a time inside the live package. That is not a coherent cross-file migration graph.

### 2. Initial V5 mirror preserved preflight-only import identities

`prepare_dispatch_quote_v2_foundation_candidate_v2.mjs` intentionally isolates temporary candidate files by rewriting imports:

- Dashboard imports `pipebuyer_dispatch_repository_quote_v2_preflight.dart`;
- Jobs imports `pipebuyer_dispatch_repository_quote_v2_preflight.dart`;
- Jobs imports `pipebuyer_dispatch_dashboard_quote_v2_preflight.dart`.

That isolation is correct while the candidate files live under renamed preflight filenames in the live repository.

However, the first V5 mirror copied those candidate files under their canonical filenames without first converting the isolated imports back to canonical names. Because the mirror also contained the copied preflight files, Dart loaded both libraries:

- `pipebuyer_dispatch_repository_quote_v2_preflight.dart`;
- `marketplace_dispatch_repository.dart`.

Dart treats those as two different libraries even though both define a class named `MarketplaceDispatchRepository`. A repository object created from one library is therefore not assignable to a parameter typed from the other library. This produced the three real type-identity errors in the mirrored Jobs page.

This is a preflight-library-identity defect. It is not Firebase, Flutter runtime state, Chrome, quote data, or user procedure.

## Permanent rule

A multi-file Dart migration must be proved using the same import identities that production promotion will use.

Use this sequence:

1. fingerprint all live production sources;
2. build isolated renamed candidate files so candidate construction cannot accidentally bind to live production during transformation;
3. perform deterministic candidate hygiene;
4. before canonical-mirror analysis, normalize candidate imports from preflight filenames back to the canonical production filenames that promotion will use;
5. assert no preflight-only Dart import remains in the Dashboard or Jobs candidate;
6. copy the exact local `lib` tree to a temporary mirror so local uncommitted dependencies are preserved;
7. place the transformed repository, Dashboard, and Jobs candidates into the mirror under canonical filenames;
8. run strict analyzer inside that mirror;
9. prove live production hashes remain unchanged;
10. run server Quote V2 policy tests;
11. promote the same candidate sources;
12. immediately analyze promoted production and rollback on any post-promotion failure.

## Why canonical library identity matters

Dart types are identified by their defining library URI/path, not only by their class name.

These are different types:

`MarketplaceDispatchRepository` from `pipebuyer_dispatch_repository_quote_v2_preflight.dart`

and

`MarketplaceDispatchRepository` from `marketplace_dispatch_repository.dart`.

Therefore a canonical mirror is not correct merely because files are copied under canonical filenames. Their internal imports must also match the canonical import graph.

Correct mirror reasoning:

```text
isolated candidate build
  -> preflight-only imports protect live source
  -> deterministic cleanup
  -> normalize imports to canonical production identities
  -> copy candidate contents under canonical filenames in mirror
  -> strict analyzer sees one repository library identity
  -> promotion uses the same canonical identities
```

Incorrect mirror reasoning:

```text
copy preflight candidate under canonical filename
  -> leave import pointing at preflight repository file
  -> mirror contains both repository libraries
  -> same class name, different Dart type identity
  -> argument_type_not_assignable
```

## Current gate

Use:

`tool/run_dispatch_quote_v2_foundation_gate_v5.ps1`

The V5 support synchronization fetches the corrected deterministic hygiene helper before candidate creation. Explicitly re-fetch the V5 gate itself before rerunning if the local runner predates this repair.

Do not rerun V1, V2, V3, or V4.