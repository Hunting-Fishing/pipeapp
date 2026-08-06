# Pipe Buyer Payment Provider Architecture

Status: Security foundation only — payments remain disabled  
Initial markets: United States and Canada  
Target providers: Stripe Connect and PayPal Multiparty

## Release boundary

This document defines the approved implementation direction. It does not enable
checkout, token purchases, platform fees, payouts, refunds, settlement, or
custody.

The following remain false in the application safety policy:

- `paymentsEnabled`
- `tokenPurchasesEnabled`
- `platformCustodyEnabled`
- `directBankDetailsAllowed`
- `clientSecretEntryAllowed`

Activation requires provider approval, legal and policy review, production
credentials, signed webhook verification, reconciliation evidence, and a
separate reviewed release.

## Core custody model

Pipe Buyer must not operate a client-controlled escrow balance or publish a raw
company bank account for buyer transfers.

The selected payment provider owns the regulated payment flow:

1. the seller completes provider-managed identity and business onboarding
2. the buyer checks out through provider-hosted or provider-tokenized UI
3. the server creates the provider payment using an immutable transaction and
   fee-schedule snapshot
4. the provider records the charge and routes the seller payout according to
   the approved marketplace account model
5. Pipe Buyer's commission is collected as a provider-supported application or
   partner fee
6. signed provider webhooks author the local payment lifecycle
7. reconciliation compares provider events, balances, payouts, refunds, and
   disputes with Pipe Buyer records

Provider processing reduces direct handling of payment credentials and bank
information. It does not remove the platform's obligations for accurate terms,
provider fees, disputes, refunds, taxes, sanctions screening, consumer law,
or operational controls.

## Provider A — Stripe Connect

Planned capabilities:

- connected seller accounts
- Stripe-hosted or embedded onboarding
- card and eligible wallet checkout
- supported bank-transfer methods using processor-generated virtual account
  details and transaction references
- provider payouts to connected sellers
- server-calculated application fees
- signed webhook events and provider reconciliation

The final Connect charge model must be selected with Stripe and legal counsel.
Destination charges can collect an `application_fee_amount`, but the platform
can be responsible for Stripe fees, refunds, and chargebacks under that model.
Direct charges or another account model may allocate responsibilities
differently and must not be assumed without approval.

Official references:

- https://docs.stripe.com/connect/marketplace
- https://docs.stripe.com/connect/destination-charges
- https://docs.stripe.com/connect/marketplace/tasks/app-fees
- https://docs.stripe.com/payments/bank-transfers
- https://docs.stripe.com/payments/bank-transfers/accept-a-payment

## Provider B — PayPal Multiparty

Planned capabilities:

- approved partner platform account
- seller onboarding through Partner Referrals
- seller capability and onboarding-status checks
- PayPal, eligible card, wallet, and alternative payment methods
- approved `PARTNER_FEE` collection
- onboarding, payment, refund, dispute, and permission webhooks
- provider reports and reconciliation

PayPal Multiparty features depend on partner approval and the capabilities
enabled for the platform REST application. Pipe Buyer must not show PayPal as
available until the seller and platform capability checks are complete.

Official references:

- https://developer.paypal.com/docs/multiparty/seller-onboarding/before-payment/
- https://developer.paypal.com/docs/multiparty/seller-onboarding/onboarding-checklist/
- https://developer.paypal.com/docs/multiparty/embedded-integration/create-onboarding-credentials/

## Administrator billing controls

The Admin Control Panel will manage non-secret, versioned policy only.

### Commission schedule

Each approved revision should define:

- percentage in basis points
- optional fixed fee in minor currency units
- minimum and maximum platform fee
- payer: buyer, seller, or split
- transaction types covered
- provider and payment-method applicability
- country and currency applicability
- tax treatment metadata
- effective date and retirement date
- administrator UID, reason, revision, and approval evidence

Every checkout must store the exact schedule revision and computed fee snapshot.
Changing the current schedule must never change an existing transaction.

### Internal token policy

Tokens are app entitlements, not money:

- non-cash
- non-transferable
- no withdrawal or redemption for currency
- no peer-to-peer transfer
- issued only after a verified provider payment or an audited administrator
  adjustment
- consumed only by an idempotent server command
- append-only ledger with balance derived from entries
- reversal linked to the original entry
- configurable expiration only when clearly disclosed and legally approved

Token bundles can be drafted in Admin Control, but purchasing and consumption
remain disabled until the paid-feature release is approved.

### Provider readiness metadata

The client may display only non-secret readiness data, such as:

- provider disabled, sandbox, review, or production-ready state
- platform account country
- enabled currencies and payment methods
- seller onboarding availability
- webhook health timestamp
- reconciliation status
- policy revision

Secret keys, client secrets, webhook signing secrets, merchant credentials,
raw payout account details, and full bank information must never be stored in a
Flutter-controlled Firestore document.

## User transaction flow

1. Buyer and seller must be authenticated and eligible.
2. Seller provider account must be active for charges and payouts.
3. Server validates listing ownership, price, quantity, currency, location,
   sanctions/jurisdiction policy, and current transaction state.
4. Server snapshots the listing, parties, approved fee schedule, and provider
   routing data.
5. Server creates a provider checkout session or payment intent with a unique
   idempotency key.
6. Client receives only the minimum provider client secret or approval URL
   required by the provider SDK.
7. Provider webhook verifies the signature before changing local status.
8. Duplicate and out-of-order events are ignored or reconciled safely.
9. Completion, refund, dispute, payout, and reversal events remain linked to
   the provider identifiers and original command receipt.

No client may directly mark a payment paid, release funds, issue a refund,
change a commission, or create a token credit.

## Bank transfer flow

Bank transfer is enabled only through a supported processor flow:

- provider-generated virtual account details or payment references
- country and currency eligibility checks
- pending state until provider confirmation
- underpayment and overpayment handling
- automated or reviewed reconciliation
- no raw Pipe Buyer operating account displayed to marketplace users
- no client-authored paid status

## Server secret storage

Provider secrets belong in protected server configuration, such as Firebase or
Google Cloud Secret Manager and protected GitHub deployment environments.

Required production secrets are expected to include provider API credentials,
webhook signing secrets, and any approved account identifiers. Secret values
must never be committed, logged, returned to Flutter, or written to Firestore.

## Webhooks and idempotency

Every webhook handler must:

- read the exact raw request body required for signature verification
- validate the provider signature and timestamp
- reject unsupported event types
- persist the provider event ID as an idempotency key
- process events transactionally
- tolerate duplicate and out-of-order delivery
- record previous and next state
- record provider object IDs, timestamps, and reconciliation metadata
- exclude secret payload fields and sensitive payment data from logs

## Data boundaries

Pipe Buyer may store:

- provider name
- connected account or merchant ID
- checkout, payment, order, transfer, refund, dispute, and payout IDs
- bounded status and timestamps
- currency and minor-unit amounts
- fee schedule revision and computed fee snapshot
- webhook receipt and reconciliation state

Pipe Buyer must not store:

- card number, CVV, full magnetic-stripe data, or PIN data
- online banking credentials
- PayPal passwords
- provider secret keys or webhook signing secrets
- unencrypted raw payout bank details
- identity documents already held by the payment provider unless separately
  required and approved

## Activation checklist

- [ ] Stripe marketplace account and Connect model approved
- [ ] PayPal partner account and required Multiparty features approved
- [ ] Seller onboarding and KYC/KYB requirements documented
- [ ] Commission and token policies approved for each launch jurisdiction
- [ ] Buyer, seller, refund, dispute, tax, sanctions, and privacy terms published
- [ ] Server secrets configured in sandbox and production
- [ ] Signed webhook handlers and replay tests complete
- [ ] Idempotent checkout, refund, dispute, and reconciliation commands complete
- [ ] Firestore and Storage rules tests complete
- [ ] Sandbox end-to-end evidence retained
- [ ] Finance reconciliation owner and runbook assigned
- [ ] Separate paid-feature release reviewed and approved
