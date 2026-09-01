# Release 3 — Dispatch Directory pagination

## Date

2026-09-01

## Baseline

This slice was built from verified production application SHA:

```text
6d4e8361211d921136e1d54358b88d413e64adc8
```

## User problem closed

The Dispatch Directory repository already returned bounded cursor pages, but the Directory UI stopped after the first page and displayed a placeholder saying pagination would be wired later.

Release 3 now gives users a real **Load more companies** action when the server reports another page.

## Behavior

- Requests the next bounded Directory page with the existing Firestore cursor.
- Merges the next page into the companies already shown.
- Deduplicates providers by Directory entry id.
- Re-sorts the merged list alphabetically by operating name.
- Keeps the existing page visible if loading another page fails.
- Shows a retryable load-more error without replacing successful existing results.
- Prevents an older page request from being appended after filters have changed by checking the existing load generation.
- Does not expose load-more behavior for deterministic seeded widget fixtures.

## Preserved architecture

This slice does **not** change:

- `dispatch_directory_entries` server-owned public projection;
- private/public Dispatch profile separation;
- Firestore security rules;
- Firebase Functions;
- provider signup or approval;
- Directory service/filter taxonomy;
- Get Quote behavior;
- provider messaging;
- View Business behavior;
- Stripe, membership, Dispatch payments, or marketplace payments.

The Directory continues to use only public projected provider data. Exact private addresses, private contacts, credentials, account-only fields, and moderation data remain outside the public Directory projection.

## Verification

Guarded Release 3 verification run:

```text
33507861995
```

Final successful rerun passed:

- dependency restore;
- repository-wide analyzer;
- focused Directory pagination/projection/filter tests;
- full Flutter regression;
- repository release-contract tests;
- both Firebase Functions codebase validations;
- diff-format validation.

Verified implementation commit:

```text
db14ecf7715ab42d82d6b4e5671f5ce059fc5566
```

## Next bounded Directory work

The next Release 3 Directory closure should be evaluated against the remaining real user gaps, especially:

1. synchronized List / OpenStreetMap view using only the existing public approximate `mapPoint`;
2. a dedicated public company detail experience if the current business view does not already satisfy the Directory detail requirements;
3. geography/radius filtering using public approximate location data without exposing private home-base coordinates.

Do not rebuild the existing projection, quote request flow, messaging, or provider profile foundation to implement those next slices.
