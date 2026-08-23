# Repair Record — P3 Provider-Backed Marketplace Fee Reconciliation

Date: 2026-08-23  
Workstream: Payments Execution Tracker #4 / P3 external-settlement Marketplace fee  
Branch: `p3-external-settlement-checkout`  
PR: #95

## Observed gap

The external-settlement fee path already stored the Stripe Checkout Session, PaymentIntent, and Charge references and verified the seller receipt against the stored Pipe Buyer fee total. That was not enough for exact accounting reconciliation.

A paid Charge can only be reconciled to Stripe's actual processor economics after its Balance Transaction is read. Without that object, Pipe Buyer could not prove the provider gross amount, Stripe fee, provider net amount, currency, and zero-difference arithmetic against the immutable Firestore fee snapshot.

## Root cause

P3 originally treated the paid Stripe Charge as the final provider evidence. The Charge proves payment collection, but the Balance Transaction is the provider accounting object that exposes fee and net settlement amounts.

## Exact repair

1. Added `firebase/functions/external_settlement_reconciliation_policy.js`.
   - Cross-checks Firestore immutable fee snapshot against Stripe Checkout Session subtotal.
   - Cross-checks stored tax and total against Stripe Session tax and total.
   - Verifies Session transaction metadata and billing type.
   - Verifies Session -> PaymentIntent -> Charge identity chain.
   - Requires succeeded PaymentIntent and paid Charge.
   - Verifies Charge amount/currency.
   - Verifies Charge -> Balance Transaction identity.
   - Verifies Balance Transaction gross/currency.
   - Verifies `gross - Stripe fee == Stripe net`.
   - Verifies `Pipe Buyer fee + tax == buyer charged total`.
   - Returns a deterministic failed-check list and zero-difference values.

2. Added `firebase/functions/external_settlement_reconciliation_commands.js`.
   - MFA administrator only.
   - Refuses reconciliation until Firestore records the marketplace fee as `collected`.
   - Re-reads the Stripe Checkout Session, PaymentIntent, Charge, and Balance Transaction from Stripe.
   - Never trusts client-supplied financial amounts or provider IDs.
   - Writes latest reconciliation state to `marketplace_fee_reconciliations/{transactionId}`.
   - Appends an immutable-style audit event under `marketplace_fee_reconciliation_audit`.
   - Updates the transaction with reconciliation status, Balance Transaction ID, provider gross, Stripe fee, and provider net.
   - Does not change fee-paid state, payment-path choice, seller proceeds, refund state, or any other money-movement authority.

3. Exported `reconcileExternalSettlementFee` behind the existing App Check / Stripe-secret callable configuration in `bootstrap.js`.

4. Added the reconciliation policy and command to Functions `npm run check`.

5. Extended `/admin/settlement-fees`.
   - Paid fee transactions expose `Reconcile Stripe ↔ Firestore`.
   - The button calls only the MFA/server reconciliation command.
   - Flutter still performs no direct authoritative financial writes.
   - Balance Transaction, Stripe fee/net, and BALANCED/MISMATCH state are displayed from Firestore.

## Tests added

- `firebase/functions/test/external_settlement_reconciliation_policy.test.js`
  - exact provider/Firestore values produce zero difference;
  - unexpected charge amount fails;
  - provider fee arithmetic mismatch fails;
  - wrong transaction metadata/billing type fails.

- `firebase/functions/test/external_settlement_reconciliation_commands.test.js`
  - re-reads the full provider chain and records balanced evidence;
  - provider mismatch is persisted as `mismatch`, never falsely `balanced`;
  - unpaid fee state is rejected before any Stripe request;
  - malformed transaction/provider IDs fail closed.

- `test/marketplace_external_settlement_admin_contract_test.dart`
  - admin UI calls only the server reconciliation command;
  - Balance Transaction and reconciliation state are surfaced;
  - no direct Flutter `.set`, `.update`, or `.delete` financial mutations are introduced.

## Executed focused verification in ChatGPT runtime

The public repository could not be cloned because the execution sandbox blocks outbound GitHub DNS. Exact branch source files were therefore retrieved through the connected GitHub API and mounted under `/mnt/data/pipeapp` for focused Node execution.

Node 22 consolidated focused P3 run:

- 48 tests executed;
- 48 passed;
- 0 failed;
- syntax checks passed for the mounted payment-path, retry, tax/readiness, threshold, receipt, and reconciliation modules.

This is real execution evidence, but it is **not** a substitute for repository-wide `tool/verify.ps1`, Flutter analysis/tests/builds, Firebase emulator integration, or a controlled live Stripe payment.

## Acceptance still required

Do not mark exact Stripe ↔ Firestore reconciliation financially complete until one controlled real fee payment produces all of the following from the same transaction:

- one Stripe Checkout Session;
- one succeeded PaymentIntent;
- one paid Charge;
- one linked Balance Transaction;
- exact immutable Pipe Buyer fee subtotal;
- correct tax amount for the active tax state;
- exact buyer charged total;
- provider gross / Stripe fee / provider net arithmetic with zero unexplained difference;
- Firestore `marketplaceFeeReconciliationStatus=balanced`;
- provider-backed seller receipt;
- duplicate webhook/reconciliation attempts do not create duplicate money movement.

## Do not repeat

Do not reconcile a Stripe payment by comparing only the Checkout Session or Charge to Firestore. The Balance Transaction is required to prove Stripe fee/net accounting.

Do not allow the client to declare reconciliation success. The client may request reconciliation; only the server may re-read provider objects and write BALANCED/MISMATCH evidence.

Do not mark P3 financially complete from unit tests alone. The final acceptance record must reference a controlled provider transaction and show a zero unexplained difference.
