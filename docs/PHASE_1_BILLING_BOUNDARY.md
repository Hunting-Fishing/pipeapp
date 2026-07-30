# Phase 1 billing boundary

Phase 1 requires **Google Cloud/Firebase project billing**, not in-app buyer,
seller, carrier, escrow, or auction-fee payment processing.

## Required for Phase 1

- Active Cloud Billing on staging and production Firebase projects.
- Budget alerts and a named billing owner.
- Cloud Build, Artifact Registry, Cloud Functions, Cloud Run, Firestore,
  Storage, and Firebase Cloud Messaging APIs enabled.
- Backup retention and restoration costs reviewed before scheduled backups are
  activated.
- Deployment stops before mutation when billing or a required API is absent.

The controlled deployment workflow performs this read-only billing and service
preflight after workload-identity authentication. It does not link a billing
account or enable an API automatically.

## Not part of the Phase 1 launch

- Holding buyer or seller funds.
- Escrow, trust accounts, deposits, payment release, or refunds.
- Carrier invoices or carrier-payment settlement.
- Paid listing boosts.
- Paid custom-auction listing and completion fees.
- Marketplace transaction commissions.

Those features require an approved payment provider, merchant terms, tax and
jurisdiction review, receipts, reconciliation, disputes, refunds, chargebacks,
and financial-operations ownership. Until that Phase 2 work is approved,
`paidFeatures` remains false and the server rejects attempts to create paid
boosts or custom auctions.

## Owner-controlled checks before launch

1. Confirm staging and production are linked to active billing accounts.
2. Configure budgets and billing alerts with at least two recipients.
3. Give the deployment service account read-only billing-status and Service
   Usage visibility; do not grant it billing-account administration.
4. Run the protected staging deployment and retain its billing/API preflight.
5. Confirm that disabling `paidFeatures` leaves all Phase 1 Marketplace,
   standard Auction, Offer, and Dispatch journeys usable.
