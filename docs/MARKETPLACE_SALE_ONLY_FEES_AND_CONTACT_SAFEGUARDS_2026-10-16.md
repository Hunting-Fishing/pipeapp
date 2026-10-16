# Marketplace sale-only fees and contact safeguards — 2026-10-16

Status: implementation-branch launch record. No production payment, Apple,
readiness, notification-mutation, migration, or feature flag was enabled by
this change.

## Product decision

Pipe Buyer will not charge an upfront marketplace or auction listing fee at
launch. For an on-platform sale, the server-calculated seller fee is collected
when the buyer's payment succeeds. Seller proceeds remain pending until
physical fulfillment is confirmed and financial release checks pass. Timed
Buying sales and accepted Marketplace offers use the same fee policy so
changing the sale format cannot change the fee.

## Two sale paths, one payment pipeline

The user journeys remain deliberately distinct before a sale commitment:

| Path | How a sale is formed | What does not create a fee |
| --- | --- | --- |
| Marketplace | A buyer submits an offer and the seller accepts it. A full-price offer is handled by the same acceptance command. | Creating, viewing, messaging about, or making an offer on a listing. |
| Timed Buying | The server records a winning bid after expiry, a seller-accepted leading bid below reserve, or an exercised Buy It Now price. | Creating the timed listing, watching it, or placing a bid. |

After that commitment, both paths create an authoritative
`marketplace_transactions` record. Timed Buying first records its immutable
winner in `auction_transactions`, then mirrors it to
`marketplace_transactions/auction_{listingId}`. The shared transaction is the
only route into fee snapshotting, Stripe checkout, webhook reconciliation,
refund/dispute handling, and seller-proceeds release. Clients cannot select a
different fee schedule by choosing a different sale path.

Wanted Ads are discovery only. A Wanted Ad may connect a buyer with suitable
inventory, but it cannot be accepted, paid, completed, or charged as a third
sale type. A matched item must continue through a Marketplace offer or a Timed
Buying listing before any authoritative transaction or seller fee can exist.

Marketplace offers may reserve less than the full available quantity. The
server snapshots that inventory when the seller accepts, prevents another
sale from changing the reserved lot, and only decrements and reopens the
remaining listing after paid completion. A cancelled pre-payment transaction
releases the reservation. Timed Buying sells the configured auction lot as a
single outcome; it does not silently split the winning lot after bidding.

New Marketplace and Timed Buying listings are USD-only. Existing accepted
transactions keep their original immutable currency and fee snapshot; this
change does not reprice or convert legacy CAD records.

At launch, sale-forming price bases are deliberately limited to totals and
server-verifiable item counts: total price, per item/piece/joint/machine as
appropriate. Per-foot, per-metre, per-acre, per-hectare, per-bundle, lease, and
call-for-price labels may still describe a Wanted Ad, but cannot form a sale or
auction until Pipe Buyer can snapshot their authoritative measure. Sale and
auction quantities must be whole numbers from 1 through 1,000,000. Malformed
legacy basis, quantity, reserve, or conflicting prior auction-result records
fail closed for administrator repair instead of being silently repriced.

### Equipment and other assets

The equipment fee is progressive. Each percentage applies only to the portion
of the agreed sale price inside that bracket:

| Portion of agreed sale price | Seller fee on that portion |
| --- | ---: |
| First $5,000 | 3.0% |
| Over $5,000 through $25,000 | 2.5% |
| Over $25,000 through $100,000 | 2.0% |
| Over $100,000 through $250,000 | 1.5% |
| Over $250,000 | 1.0% |

The overall equipment fee has a $1 minimum and a $2,500 maximum in each
configured currency. It can never exceed the agreed sale value. Example fees
before applicable tax are $150 on $5,000, $650 on $25,000, $2,150 on $100,000,
and the $2,500 cap on $250,000.

### Pipe, tubing, and casing

The fee is $1 per sold item, stick, or joint, capped at the lower of:

- 3% of the agreed sale value; or
- $2,500 in the configured sale currency.

This lower-of calculation protects a low-value bulk lot from an unreasonable
unit fee. The percentage cap can produce a fee below $1 for a very small sale.

The server policy revision is `2026-10-16-sale-only-v4`, with collection timing
`sale_payment`. Accepted transactions retain an immutable fee snapshot,
including the revision and calculation inputs. Existing accepted transactions
must not be repriced or backfilled to v4.

New listings default to the equipment schedule. Seller-selected category,
product type, title, or fee-class fields never grant the cheaper pipe rate. An
MFA-authorized administrator must review the listing and write a separate
server-only approval with source `administrator_approved_catalog`. That
approval is bound to the listing ID, seller, exact catalog category/product
type, and listing revision. A missing, revoked, stale, malformed, or mismatched
approval fails closed to equipment pricing. Before fee activation, legacy pipe
listings still need individual review; no automatic approval or classification
backfill has been run.

## Membership and yearly target

Membership does not replace the seller's sale-payment fee obligation. It
supports ongoing paid features, including the controlled contact-sharing path
described below.

The approved Apple United States targets are USD 24.99 monthly and USD 249.99
yearly. The yearly target is about two monthly payments, or approximately 17%,
less than twelve monthly payments. The yearly product was last verified in App
Store Connect at USD 299.99. USD 249.99 remains pending an external App Store
Connect price-schedule change, saved-state verification, localized storefront
review, Sandbox testing, and normal submission approval.

## Contact-sharing safeguards

The launch design keeps ordinary in-app text messaging available while making
direct contact exchange a controlled capability:

- Phone numbers, email addresses, websites, and recognized contact handles are
  rejected from new or edited public listing fields, location/access notes,
  offer notes, and Dispatch access notes.
- Firestore rules reject explicit contact keys and obvious email, web, phone,
  and social-handle patterns in public seller/business names and descriptions.
  Industrial identifiers such as `CAT-320-2026` remain valid.
- Public seller and business screens do not intentionally render phone, email,
  or website fields. Dispatch directory projections and search results omit the
  website field.
- Server-derived public seller, bidder, and offer names reject phone, email,
  URL, and recognized handle signals. Authentication email is never used as a
  public fallback; unsafe or absent names become a neutral marketplace alias.
- Profile editing stores direct contact details under the owner's private
  business document and deletes the corresponding public keys.
- A message containing a recognized phone, email, website, or contact handle —
  and every chat attachment — requires the sender to have a current paid
  Dispatch or VIP membership.
- Membership alone is insufficient. The server must also confirm that the two
  conversation members are the accepted buyer and seller, the auction winner
  and seller, or the awarded Dispatch customer and carrier.
- Fee calculation and relationship authorization remain server-owned. Client
  copy is explanatory and is not the enforcement boundary.

## Known limitations and launch blockers

- Text detection is heuristic. It can have false positives and false negatives,
  and cannot guarantee detection of spelled-out numbers, novel obfuscation,
  unrecognized domains or services, QR codes, or contact details embedded in
  images, audio, video, archives, and other media.
- Attachments are entirely gated by membership and a confirmed relationship;
  their contents are not currently OCR-scanned or semantically moderated.
- Unlocking contact after a legitimate transaction relationship does not prove
  that later activity stays on-platform. Terms enforcement, audit signals,
  reporting, repeat-offender review, and fair fee collection remain necessary.
  No technical filter can guarantee that circumvention never occurs.
- The current contact relationship gate starts after an offer is accepted or
  an auction winner is recorded, not after buyer payment. Paid membership is
  an additional backstop, but this still cannot guarantee collection of every
  commission if the parties deliberately move the sale off-platform.
- Legacy public data must be migrated. The guarded utility scans both
  `public_business_profiles` and `public_seller_profiles`, moves recognized
  contact values without overwriting current private values, and removes the
  matching Dispatch-directory website field. A dry run still must verify that
  no legacy key variant or derived public collection falls outside that known
  inventory.
- The migration is dry-run by default. Apply mode requires the allowlisted
  `flutter-flow-pipe` project twice, and the utility logs the target endpoint
  and a deterministic fingerprint before Firebase access. Those controls do
  not replace an approved backup, credential review, reconciled dry-run counts,
  or explicit action-time approval; write mode has not been run.
- The fee engine retains CAD support for immutable legacy transactions, while
  new Marketplace and Timed Buying listings are USD-only. Worldwide listing
  visibility does not mean every payment method, tax treatment, settlement
  jurisdiction, or regulated marketplace service is launch-ready worldwide.
- Full-GMV card checkout is not yet economically approved for high-value
  equipment. A percentage-based processor charge can exceed Pipe Buyer's
  $2,500 seller-fee cap on a six-figure sale. The launch payment-method policy
  must either preserve a positive margin with an approved high-value rail and
  pricing model, or route the parties through the fee-only external-settlement
  path; production checkout stays disabled until that decision is tested.
- Stripe sandbox work must use an isolated non-production project/secret,
  webhook destination, and environment identity. Sandbox events and records
  must not be able to mutate production transactions, and production payment,
  payout, and readiness switches remain false until the full test matrix is
  reconciled.
- Timed Buying still needs an explicit product decision for hard close versus
  anti-sniping extensions, and for the payment grace/default/reoffer sequence.
  The scheduler uses durable rotating cursors so one repeatedly failing auction
  cannot indefinitely prevent later expired auctions from being examined, but
  operational retry/alert evidence is still required in sandbox.
- An administrator approval is operational evidence, not a permanent product
  entitlement. Any seller detail revision invalidates it and requires a new
  review before another transaction can receive pipe pricing.

## Safe deployment and migration order

1. Freeze the exact release commit and run the Functions, rules, Flutter, and
   fee-boundary test suites. Confirm fee examples, bracket boundaries, cap,
   immutable snapshots, listing/offer rejection, message authorization, and
   public-profile security behavior.
   Dry-run the legacy fee-class inventory and manually review each intended
   pipe listing. Confirm that seller category/product type alone still produces
   equipment pricing and only a current server-only administrator approval can
   select the pipe rate.
2. Keep `phase1_feature_flags` paid features false and keep every Stripe,
   Apple, readiness, notification-mutation, and Production switch false. A
   source deployment must not authorize payment or entitlement mutation.
3. Take and verify the approved Firestore backup/export. Inventory contact keys
   in `public_business_profiles`, `public_seller_profiles`, and
   `dispatch_directory_entries` without copying personal values into logs or
   evidence.
4. Deploy the new server validation, MFA administrator approval command, and
   fee code to the sandbox/staging path while money movement remains disabled.
   Deploy the tightened Firestore rules before migrating legacy values so
   clients cannot write fee approvals or reintroduce public contact keys during
   the migration window.
5. Review the guarded migration against both public profile collections and
   every known derived directory/index. Run dry-run first, reconcile its counts
   to the inventory, and stop on any unexpected target, fingerprint, key, or
   count.
6. Only after backup review and explicit operator approval, apply the contact
   migration to the intended environment. Verify private copies exist for the
   correct owner and that public documents and directory results contain none
   of the prohibited keys.
7. Release the matching Flutter UI, including the fee information control and
   protected-contact explanations. Verify an old client cannot restore public
   contact fields or bypass server-owned message checks.
8. Run the full Stripe sandbox matrix for both on-platform and external
   settlement. Confirm no charge occurs for listing creation, the seller fee is
   collected when buyer payment succeeds, seller payout remains pending until
   fulfillment and release checks pass, and old transaction snapshots are not
   recalculated. Include response-loss retries, expired Checkout Sessions,
   out-of-order completion/refund/dispute events, partial and full refunds,
   simultaneous payout/refund attempts, and exact-once compensation checks.
   Completion must stay blocked while any settlement-reconciliation token,
   refund exposure, dispute, chargeback, or financial hold is present.
9. Separately change the Apple yearly price schedule to USD 249.99 only with
   action-time approval. Re-read the saved App Store Connect state, then update
   screenshots, localized disclosures, and Sandbox/TestFlight evidence.
10. Production activation is a later, separately approved decision after
    migration verification, privacy/security review, tax and settlement gates,
    reconciliation, monitoring, App Store prerequisites, and acceptance
    evidence pass. Do not combine deployment with activation.

## Required fee information UI

The marketplace fee information control should make these points visible
before a seller confirms a sale:

- "List free. The seller fee is collected when the buyer pays."
- the seller is the fee payer;
- seller payout remains pending until fulfillment is confirmed and release
  checks pass;
- progressive brackets apply marginally;
- the $1 minimum and $2,500 maximum for equipment;
- the pipe $1-per-item rule and its lower-of 3%/$2,500 cap;
- representative fee examples;
- taxes, payment processing, inspection, logistics, and other optional services
  are separate when applicable; and
- the authoritative fee is the server snapshot shown for that transaction.

The UI must not claim that production billing, Apple pricing, worldwide
payments, tax collection, or migration is active until separately verified.
