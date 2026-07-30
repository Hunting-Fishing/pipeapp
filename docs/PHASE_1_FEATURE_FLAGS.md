# Phase 1 feature controls

The authoritative runtime configuration is the Firestore document:

`platform_configuration/phase1_features`

The Flutter client observes this document, callable Functions check it before
performing commands, and Firestore rules check it before accepting supported
legacy direct writes. A hidden button is never the security boundary.

## Configuration shape

```text
marketplace: bool
wantedAds: bool
offers: bool
auctions: bool
dispatch: bool
paidFeatures: bool
regulatedListings: bool
revision: int
updatedAt: timestamp
updatedByUid: string
```

Only an authenticated administrator can create or update the document.
Creation must use revision `1`. Every update must increment the current
revision by exactly one. Unknown fields, missing booleans, non-timestamp
`updatedAt` values, deletion, and skipped revisions are denied by Firestore
rules.

## Safe defaults

If the configuration is absent or cannot be loaded:

| Feature | Callable default | Flutter default | Direct Firestore write |
| --- | --- | --- | --- |
| Marketplace | Enabled | Enabled | Denied |
| Wanted ads | Enabled | Enabled | Denied |
| Offers | Enabled | Enabled | Denied |
| Auctions | Disabled | Disabled | Denied |
| Dispatch | Disabled | Disabled | Denied |
| Paid features | Disabled | Disabled | Denied |
| Regulated listings | Disabled | Disabled | Denied |

Marketplace, Wanted-ad, and Offer commands continue through their reviewed
callable boundary. A missing control document does not authorize a stale
client to write directly.

Production Flutter builds also lock Auctions and Dispatch off unless the exact
release artifact was compiled with `PIPE_ENABLE_AUCTIONS=true` and
`PIPE_ENABLE_DISPATCH=true`. Those build approvals are added only after their
acceptance gates pass. The runtime configuration remains the immediate kill
switch, so both approvals are required. Paid and regulated workflows require
an explicit non-production build opt-in and the runtime flag. Remote
configuration can always disable a feature; it cannot override a stricter
build policy.

## Initial controlled configuration

Create the document using an administrator account or a reviewed Admin SDK
release script:

```text
marketplace: true
wantedAds: true
offers: true
auctions: false
dispatch: false
paidFeatures: false
regulatedListings: false
revision: 1
updatedAt: server timestamp
updatedByUid: administrator uid
```

Do not deploy an enabling configuration until the corresponding plan gate has
acceptance evidence. Never enable `paidFeatures` or `regulatedListings` for
Phase 1.

Before enabling Auctions or Dispatch in a production release:

1. Complete the applicable staging journey and retain its evidence.
2. Build the exact release SHA with only the approved build define enabled.
3. Confirm the feature remains unavailable while its runtime flag is false.
4. Enable the runtime flag by the revision-controlled procedure below.

## Change procedure

1. Confirm the feature's launch gate and staging acceptance evidence.
2. Read the current configuration and revision.
3. Change only the intended boolean, increment revision by one, set
   `updatedAt` to a server timestamp, and set `updatedByUid`.
4. Verify the client navigation, callable rejection/acceptance, and Firestore
   rule behavior in staging.
5. Record the revision, operator, environment, release SHA, reason, and
   acceptance evidence in the release record.

## Emergency rollback

1. Set the affected feature to `false`.
2. Increment revision by exactly one and record the administrator and server
   timestamp.
3. Verify that navigation disappears and new callable/direct-write operations
   are rejected.
4. Preserve existing records. Do not delete auctions, offers, Dispatch jobs,
   or the configuration document as a rollback technique.
5. If client behavior does not stop, roll Hosting/app artifacts back to the
   last verified release and investigate the feature-configuration diagnostic
   event.

Disabling a feature stops new user actions. Existing history remains intact
for administrative recovery and a later controlled re-enable.
