# Marketplace search index

Marketplace keyword search uses server-generated, bounded prefix tokens on
`public_listings`. Clients cannot supply or modify `searchTokens` or
`searchIndexVersion`; listing publication and reviewed listing edits rebuild
them through Cloud Functions.

The index covers listing title, category, product type, brand, model,
condition, public location, nearest town, region, country, and description.
Tokens are lower-case, ASCII-normalized adjacent phrases of up to three words,
bounded to 480 values and 64 characters per value.

## Deployment order

1. Deploy `firebase/firestore.indexes.json` and wait until the
   `public_listings` search index is ready.
2. Deploy the reviewed Functions release.
3. Dry-run the existing-listing backfill from `firebase/functions`:

   ```powershell
   npm run backfill:search-index -- --project <firebase-project-id>
   ```

4. Review the reported `inspected` and `changed` counts.
5. Apply only to the confirmed project:

   ```powershell
   npm run backfill:search-index -- `
     --project <firebase-project-id> `
     --apply `
     --confirm-project <firebase-project-id>
   ```

6. Repeat the dry run and require `changed: 0`.
7. Verify title, make/model, category, town, and multi-word searches on staging
   before production promotion.

The script is dry-run by default and refuses apply mode unless the confirmation
project exactly matches the target. It updates only the two server-owned search
fields and is safe to repeat.
