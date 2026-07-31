# Marketplace search index

Marketplace keyword search uses server-generated, bounded prefix tokens on
`public_listings`. Clients cannot supply or modify `searchTokens` or
`searchIndexVersion`; listing publication and reviewed listing edits rebuild
them through Cloud Functions.

The index covers listing title, category, product type, brand, model,
condition, public location, nearest town, region, country, and description.
Tokens are lower-case, Latin-diacritic-folded adjacent phrases of up to three
words, bounded to 480 values and 64 characters per value. Search index version
2 keeps common French and Spanish place names equivalent to their unaccented
input, such as `Montréal`/`Montreal` and `México`/`Mexico`.

Search, category, listing type, condition, price range, and price/newest sort
are applied together by bounded Firestore queries. The client does not apply a
second, narrower text filter after a page is returned.

## Deployment order

1. Deploy `firebase/firestore.indexes.json` and wait until the
   `public_listings` search index is ready.
2. Deploy the reviewed Functions release.
3. Authenticate with approved short-lived Application Default Credentials.
   Do not use a downloaded service-account key.
4. Run a bounded read-only canary from `firebase/functions`:

   ```powershell
   npm run backfill:search-index -- `
     --project pipebuyer-5c77f `
     --page-size 25 `
     --max-documents 100
   ```

5. Review `inspected`, `changed`, and `searchIndexValid`, then run the complete
   staging dry run by removing `--max-documents`.
6. Apply only to the approved isolated staging project. Use a unique checkpoint
   path under ignored local build output:

   ```powershell
   npm run backfill:search-index -- `
     --project pipebuyer-5c77f `
     --environment staging `
     --apply `
     --confirm-project pipebuyer-5c77f `
     --checkpoint ../../build/search-index/staging-search-v2-<timestamp>.json
   ```

   The checkpoint is written before the first update and contains the exact
   prior and planned values for only `searchTokens` and
   `searchIndexVersion`. The command refuses to overwrite a checkpoint.
7. Require a clean post-apply validation. Exit code `2` means drift remains:

   ```powershell
   npm run backfill:search-index -- `
     --project pipebuyer-5c77f `
     --require-clean
   ```

8. Verify title, make/model, category, town, and multi-word searches on staging
   before production promotion.

## Recovery

If staging acceptance finds a search-index regression, restore the checkpoint:

```powershell
npm run backfill:search-index -- `
  --project pipebuyer-5c77f `
  --environment staging `
  --apply `
  --confirm-project pipebuyer-5c77f `
  --rollback ../../build/search-index/staging-search-v2-<timestamp>.json
```

Rollback validates the checkpoint checksum and target, then restores only
documents whose two search fields still exactly match the backfill result.
Documents changed afterward are reported as conflicts and are not overwritten;
any conflict produces exit code `2` for manual review.

## Safety controls

- The script is read-only by default.
- Every mutation is hard-locked to approved staging project
  `pipebuyer-5c77f`; production apply is intentionally unavailable.
- Apply requires `--environment staging`, `--apply`, exact project
  confirmation, and a new checkpoint path.
- Reads are paged and may be capped with `--max-documents` for a canary.
- Backfill writes use the document update-time precondition, preventing a
  concurrent listing edit from being overwritten.
- Only the two server-owned search fields are updated.
- Checkpoints live under ignored `build/` output and must be retained with the
  staging acceptance evidence until the release is approved or rolled back.
