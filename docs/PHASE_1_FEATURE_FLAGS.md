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

## Build approval + runtime approval

Higher-risk production features use two independent controls:

1. **Build approval** — the exact Flutter artifact must be compiled with the
   appropriate `--dart-define`.
2. **Runtime approval** — the revision-controlled Firestore feature flag must
   also be true.

Remote configuration can always disable a feature; it cannot override a
stricter build artifact.

For Dispatch subscriptions, the accepted P2 artifact requires both:

```text
PIPE_ENABLE_DISPATCH=true
PIPE_ENABLE_PAID_FEATURES=true
```

and the runtime document must contain both:

```text
dispatch: true
paidFeatures: true
```

Neither build approval activates billing. Stripe subscription readiness,
Billing Portal verification, webhook lifecycle verification, recovery,
reconciliation, tax evidence, and the separate
`stripeSubscriptionsEnabled` control must also pass.

The verified Firebase deployment workflow defaults both build approvals to
**false**. Each controlled Dispatch-paid release must deliberately select them,
and the exact values are recorded in `build/release-manifest.json` beside the
release SHA and web-artifact hash.

Regulated listings remain prohibited in production by the compile-time policy.
Their runtime flag must remain false unless a separate reviewed release plan
changes that policy.

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

This is the safe baseline. Do not enable a higher-risk feature until its own
acceptance gate is complete.

For the accepted P2 Dispatch subscription cutover only, `dispatch` and
`paidFeatures` may be enabled together during the controlled acceptance window
after the exact artifact was built with both approvals. They remain immediate
runtime kill switches and can be returned to false without deleting existing
subscription or accounting records.

## Change procedure

1. Confirm the feature's launch gate and staging acceptance evidence.
2. Confirm the exact release manifest records the required build approvals.
3. Read the current configuration and revision.
4. Change only the intended boolean(s), increment revision by exactly one, set
   `updatedAt` to a server timestamp, and set `updatedByUid`.
5. Verify the client navigation, callable rejection/acceptance, and Firestore
   rule behavior in staging or the documented controlled acceptance window.
6. Record the revision, operator, environment, release SHA, reason, build
   approvals, and acceptance evidence in the release record.

For P2 Dispatch subscriptions, the runtime `dispatch` and `paidFeatures` flags
must agree with the accepted artifact before `stripeSubscriptionsEnabled` can
be enabled. The server readiness command independently rejects Dispatch
subscription activation when either runtime flag is false.

## Emergency rollback

1. Set the affected runtime feature flag to `false`.
2. Increment revision by exactly one and record the administrator and server
   timestamp.
3. Verify that navigation/new purchase actions disappear and new callable
   operations are rejected.
4. Preserve existing records. Do not delete auctions, offers, Dispatch jobs,
   subscription records, invoices, or the configuration document as a rollback
   technique.
5. If client behavior does not stop, roll Hosting/app artifacts back to the
   last verified release and investigate the feature-configuration diagnostic
   event.

Disabling a feature stops new user actions. Existing history remains intact
for administrative recovery and a later controlled re-enable.
