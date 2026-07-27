# Phase 1 release acceptance evidence

Phase 1 cannot be declared ready from source code or a successful build alone.
The final decision must be tied to one full Git commit SHA and retain evidence
for every acceptance journey, recovery rehearsal, defect review, and owner
approval.

## Evidence bundle

Create a private working directory outside source control, for example
`build/acceptance`. Store screenshots, test logs, device records, rollback
output, and restore output beneath that directory. Do not include passwords,
authentication codes, private identity documents, raw access tokens, or
customer data.

Copy `docs/phase1_acceptance_template.json` to
`build/acceptance/phase1-acceptance.json`, then replace every pending value.
Every evidence path must be relative to `build/acceptance`; parent-directory
paths are rejected.

The acceptance JSON and `build/release-manifest.json` must name the same:

- `staging` or `production` environment;
- full 40-character Git commit SHA; and
- tested release artifact.

## Required acceptance

The ten journeys cover account ownership and profile media, listing lifecycle,
saved-state recovery, communications and moderation, offers, auctions,
Dispatch, failure/retry behavior, administrator security, and deployment
recovery.

Recovery evidence must include measured Hosting rollback, Functions/Rules
rollback, and Firestore backup restore results. A release remains blocked while
any P0, critical, or high defect is not closed.

Named approvals are required from product, engineering, security, Trust &
Safety, support, privacy, and legal owners. Use organizational role names or
approved business identities in retained release evidence; do not put private
contact details in the repository.

## Validation

After the exact release build and its release manifest exist, run:

```powershell
node tool/phase1_acceptance.mjs `
  --release-manifest build/release-manifest.json `
  --evidence build/acceptance/phase1-acceptance.json `
  --evidence-root build/acceptance `
  --output build/acceptance/phase1-readiness.json
```

The command exits non-zero for missing, stale, incomplete, unsafe, or
mismatched evidence. A successful result includes SHA-256 hashes and sizes for
each retained artifact so the approval record can be audited later.

The resulting readiness JSON is release evidence, not a replacement for the
original screenshots, logs, restore records, approvals, or protected GitHub
Environment review.
