# Wanted Ads matching

Wanted Ads use the existing Marketplace listing model. A request is a
`public_listings` document with `transactionType: Wanted / Seeking`; a supply
listing uses `transactionType: For Sale`. Clients cannot set the Wanted Ads
lifecycle, response totals, or match totals.

## Production behavior

The existing `onPublicListingCreated` trigger performs one bounded counterpart
query after a new Wanted Ad or For Sale listing is published. It considers at
most 100 recent active listings in the same category and stores at most the 20
strongest qualifying matches. No second listing-create trigger is introduced.

Each match has a deterministic SHA-256 document identifier. Trigger retries
therefore cannot produce duplicate match records, counters, or notifications.
The match document is readable only by the Wanted Ad owner, the supply seller,
or an administrator. Exact locations, private profiles, unrestricted listing
descriptions, and contact information are not copied into it.

Matching is explainable. The score can include:

- exact product type, brand, model, or pipe size;
- shared specification terms;
- whether the available quantity meets all or part of the request;
- price compatibility only when both listings use the same pricing basis; and
- same-region or same-country proximity.

A score below 45 is not stored. Stored scores are capped at 100 and include a
bounded list of plain-language reasons for the owner interface.

## Lifecycle

Wanted Ads use `open`, `paused`, `fulfilled`, and `archived` semantics. They are
marked fulfilled, never sold, and cannot be moved to an auction. Relisting
creates a new listing identifier so prior matches and revisions remain intact.

Match suggestions also have participant-specific states. Either participant can
mark a match contacted, dismiss it from their own active list, or restore it.
One participant's dismissal never hides the suggestion from the other. Every
action is performed through the authenticated `manageWantedMatch` command and
appended to the match's immutable event history. Direct client writes remain
disabled. The first contact action increments the request response count once,
even when both participants later open the conversation.

Both sides use the existing listing details and conversation routes. Wanted Ad
owners see matching supply listings; supply owners see potential Wanted buyers.
The interface separates active and dismissed matches and exposes the bounded
activity history for each suggestion.

## Rollout and backfill

The creation trigger only evaluates newly published listings. Before enabling
Wanted Ads for production traffic:

1. deploy and confirm the required Firestore indexes;
2. exercise both creation directions in the staging project;
3. verify participant-only reads with authenticated buyer and seller accounts;
4. measure trigger duration and match quality with representative categories;
5. run an approved, resumable backfill for existing open Wanted Ads; and
6. record backfill totals and rejected candidates without storing private data.

No production backfill is performed automatically by application startup or by
this repository change. A future backfill must use the same scoring policy and
deterministic identifiers so it remains idempotent and safely resumable.

The tracked backfill command is dry-run-only unless every staging mutation lock
is supplied. The default dry run inspects at most 25 open Wanted Ads:

```powershell
cd firebase/functions
npm run backfill:wanted-matches -- --project pipebuyer-5c77f
```

An approved staging application requires the exact environment and project
confirmation and writes a tamper-evident checkpoint before creating matches:

```powershell
npm run backfill:wanted-matches -- `
  --project pipebuyer-5c77f `
  --environment staging `
  --confirm-project pipebuyer-5c77f `
  --apply `
  --checkpoint ../../build/evidence/wanted-matches-checkpoint.json
```

Interrupted applications can use `--resume <checkpoint> --apply` with the same
staging locks. `--rollback <checkpoint> --apply` removes only matches created by
that exact run which have never been contacted, dismissed, restored, or
otherwise revised. Interacted matches fail closed as rollback conflicts.

The 500-document saved-seller and keyword-watch fan-out limits are intentional
cost and timeout controls. Moving beyond those limits requires a queued,
paginated fan-out design rather than removing the bounds.
