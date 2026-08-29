from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one match, found {count}\n--- needle ---\n{old[:500]}")
    p.write_text(text.replace(old, new, 1))


def insert_after_once(path: str, needle: str, addition: str) -> None:
    replace_once(path, needle, needle + addition)


# 1) Readiness: add an audited tax-collection-deferred mode without impersonating tax readiness.
path = "firebase/functions/payment_readiness_admin.js"
replace_once(
    path,
    '  "stripeTaxPendingBillingApproved",\n',
    '  "stripeTaxPendingBillingApproved",\n  "marketplaceTaxCollectionDeferredApproved",\n',
)
replace_once(
    path,
    '  if (next.stripeTaxReady && next.stripeTaxRegistrationPending) {\n',
    '  if (next.stripeTaxReady && next.marketplaceTaxCollectionDeferredApproved) {\n'
    '    throw new HttpsError(\n'
    '        "failed-precondition",\n'
    '        "Registered automatic tax and deferred marketplace tax collection cannot both be enabled.",\n'
    '    );\n'
    '  }\n'
    '  if (next.stripeTaxReady && next.stripeTaxRegistrationPending) {\n',
)
replace_once(
    path,
    '    next.stripeWebhookVerified &&\n    next.stripeTaxReady &&\n    next.stripeReconciliationReady\n',
    '    next.stripeWebhookVerified &&\n    (next.stripeTaxReady || next.marketplaceTaxCollectionDeferredApproved) &&\n    next.stripeReconciliationReady\n',
)
replace_once(
    path,
    '        "Full marketplace checkout requires production mode, Connect onboarding, verified webhooks, active tax registration, and reconciliation readiness.",\n',
    '        "Full marketplace checkout requires production mode, Connect onboarding, verified webhooks, reconciliation readiness, and either registered automatic tax or an audited deferred tax-collection decision.",\n',
)

# 2) Shared pending/deferred tax policy for subscriptions, fee billing and checkout metadata.
path = "firebase/functions/pending_tax_policy.js"
replace_once(
    path,
    '  if (readiness.stripeTaxRegistrationPending === true) {\n    return "registration_pending";\n  }\n',
    '  if (readiness.marketplaceTaxCollectionDeferredApproved === true) {\n'
    '    return "collection_deferred";\n'
    '  }\n'
    '  if (readiness.stripeTaxRegistrationPending === true) {\n'
    '    return "registration_pending";\n'
    '  }\n',
)
replace_once(
    path,
    '  return readiness.stripeTaxReady === true ||\n    (readiness.stripeTaxRegistrationPending === true &&\n      readiness.stripeTaxPendingBillingApproved === true);\n',
    '  return readiness.stripeTaxReady === true ||\n'
    '    readiness.marketplaceTaxCollectionDeferredApproved === true ||\n'
    '    (readiness.stripeTaxRegistrationPending === true &&\n'
    '      readiness.stripeTaxPendingBillingApproved === true);\n',
)

# 3) Provider readiness must expose the deferred decision to checkout and fee billing.
path = "firebase/functions/stripe_marketplace_commands.js"
replace_once(
    path,
    '    stripeTaxReady: data.stripeTaxReady === true,\n',
    '    stripeTaxReady: data.stripeTaxReady === true,\n'
    '    marketplaceTaxCollectionDeferredApproved:\n'
    '      data.marketplaceTaxCollectionDeferredApproved === true,\n',
)

# 4) Checkout: allow audited deferred collection, turn automatic tax off in that mode,
#    skip registration-only tax profile requirements, and make an existing open Checkout
#    session resumable after an app restart.
path = "firebase/functions/stripe_checkout_commands.js"
replace_once(
    path,
    '    readiness.stripeWebhookVerified &&\n    readiness.stripeTaxReady &&\n    readiness.stripeReconciliationReady;\n',
    '    readiness.stripeWebhookVerified &&\n'
    '    (readiness.stripeTaxReady ||\n'
    '      readiness.marketplaceTaxCollectionDeferredApproved) &&\n'
    '    readiness.stripeReconciliationReady;\n',
)
replace_once(
    path,
    '      const listing = listingSnapshot.data();\n      const taxComplianceSnapshot =\n        await taxCompliance.evaluateTransactionTaxCompliance(sale);\n      if (taxComplianceSnapshot.manualTaxReviewRequired) {\n        throw new HttpsError(\n            "failed-precondition",\n            "This transaction has a tax exemption claim that requires Pipe Buyer tax review before online checkout.",\n        );\n      }\n      if (!taxComplianceSnapshot.eligibleForAutomatedCheckout) {\n        throw new HttpsError(\n            "failed-precondition",\n            "Buyer and seller tax profiles must be current and verified before online marketplace checkout.",\n        );\n      }\n',
    '      const listing = listingSnapshot.data();\n'
    '      const automaticTax = readiness.stripeTaxReady === true;\n'
    '      const taxCollectionStatus = automaticTax ?\n'
    '        "registered" : "collection_deferred";\n'
    '      const taxComplianceSnapshot = automaticTax ?\n'
    '        await taxCompliance.evaluateTransactionTaxCompliance(sale) : {\n'
    '          collectionMode: "deferred",\n'
    '          taxPolicyVersion: "marketplace-tax-collection-deferred-v1",\n'
    '          taxResponsibilityPolicyVersion: "marketplace-tax-collection-deferred-v1",\n'
    '          manualTaxReviewRequired: false,\n'
    '          eligibleForAutomatedCheckout: true,\n'
    '        };\n'
    '      if (automaticTax && taxComplianceSnapshot.manualTaxReviewRequired) {\n'
    '        throw new HttpsError(\n'
    '            "failed-precondition",\n'
    '            "This transaction has a tax exemption claim that requires Pipe Buyer tax review before online checkout.",\n'
    '        );\n'
    '      }\n'
    '      if (automaticTax && !taxComplianceSnapshot.eligibleForAutomatedCheckout) {\n'
    '        throw new HttpsError(\n'
    '            "failed-precondition",\n'
    '            "Buyer and seller tax profiles must be current and verified before automatic-tax marketplace checkout.",\n'
    '        );\n'
    '      }\n',
)
replace_once(
    path,
    '      if (existingSessionId &&\n          ["checkout_created", "processing", "paid"].includes(\n              String(sale.paymentProviderStatus || ""),\n          )) {\n        return {\n          transactionId,\n          checkoutSessionId: existingSessionId,\n          alreadyCreated: true,\n        };\n      }\n',
    '      if (existingSessionId &&\n'
    '          ["checkout_created", "processing", "paid"].includes(\n'
    '              String(sale.paymentProviderStatus || ""),\n'
    '          )) {\n'
    '        if (sale.paymentProviderStatus === "paid") {\n'
    '          return {\n'
    '            transactionId,\n'
    '            checkoutSessionId: existingSessionId,\n'
    '            alreadyCreated: true,\n'
    '            alreadyPaid: true,\n'
    '          };\n'
    '        }\n'
    '        const existingSession = await stripeFormRequest({\n'
    '          secretKey: stripeSecretKey.value(),\n'
    '          path: `/v1/checkout/sessions/${encodeURIComponent(existingSessionId)}`,\n'
    '          method: "GET",\n'
    '        });\n'
    '        const existingUrl = String(existingSession.url || "");\n'
    '        if (existingUrl.startsWith("https://") &&\n'
    '            String(existingSession.status || "") === "open") {\n'
    '          return {\n'
    '            transactionId,\n'
    '            checkoutSessionId: existingSessionId,\n'
    '            checkoutUrl: existingUrl,\n'
    '            alreadyCreated: true,\n'
    '            alreadyPaid: false,\n'
    '          };\n'
    '        }\n'
    '      }\n',
)
replace_once(
    path,
    '          "tax_id_collection[enabled]": "true",\n          "automatic_tax[enabled]": "true",\n',
    '          "tax_id_collection[enabled]": automaticTax ? "true" : "false",\n'
    '          "automatic_tax[enabled]": automaticTax ? "true" : "false",\n',
)
replace_once(
    path,
    '          "line_items[0][price_data][tax_behavior]": "exclusive",\n          "line_items[0][price_data][product_data][name]":\n            String(listing.title || "Pipe Buyer marketplace purchase").slice(0, 240),\n          "line_items[0][price_data][product_data][tax_code]": taxCode,\n',
    '          ...(automaticTax ? {\n'
    '            "line_items[0][price_data][tax_behavior]": "exclusive",\n'
    '          } : {}),\n'
    '          "line_items[0][price_data][product_data][name]":\n'
    '            String(listing.title || "Pipe Buyer marketplace purchase").slice(0, 240),\n'
    '          ...(automaticTax ? {\n'
    '            "line_items[0][price_data][product_data][tax_code]": taxCode,\n'
    '          } : {}),\n',
)
replace_once(
    path,
    '          "metadata[taxCollectionStatus]": "registered",\n',
    '          "metadata[taxCollectionStatus]": taxCollectionStatus,\n',
)
replace_once(
    path,
    '        taxCollectionStatus: "registered",\n',
    '        taxCollectionStatus,\n        stripeAutomaticTaxEnabled: automaticTax,\n',
)

# 5) Webhook: record successful buyer payment but do NOT transfer seller proceeds yet.
path = "firebase/functions/stripe_webhook.js"
replace_once(
    path,
    '    if (sale.paymentProviderStatus === "paid" &&\n        sale.stripeSellerTransferId) return;\n',
    '    if (sale.paymentProviderStatus === "paid") return;\n',
)
old_transfer_block = '''    const sellerProvider = await db.collection("payment_provider_accounts")
        .doc(String(sale.sellerUid || "")).get();
    if (!sellerProvider.exists ||
        sellerProvider.data().transferStatus !== "active") {
      throw new Error("The seller Stripe recipient account is not payout-ready.");
    }
    if (sellerProvider.data().sellerPayoutHold === true) {
      throw new Error("The seller account has an unresolved financial hold.");
    }
    const destination = String(sellerProvider.data().stripeAccountId || "");
    if (!destination.startsWith("acct_")) {
      throw new Error("The seller Stripe recipient account is invalid.");
    }
'''
replace_once(path, old_transfer_block, '')
old_transfer_create = '''    let transfer = null;
    if (sellerProceedsMinor > 0) {
      transfer = await stripeFormRequest({
        secretKey: stripeSecretKey.value(),
        path: "/v1/transfers",
        idempotencyKey: `pipebuyer-seller-transfer-${transactionId}`,
        fields: {
          amount: sellerProceedsMinor,
          currency: String(fee.currency || sale.currency || "CAD").toLowerCase(),
          destination,
          source_transaction: chargeId,
          transfer_group: transferGroup,
          "metadata[pipeBuyerTransactionId]": transactionId,
          "metadata[listingId]": String(sale.listingId || ""),
          "metadata[feeScheduleRevision]": String(fee.scheduleRevision || ""),
        },
      });
    }

'''
replace_once(path, old_transfer_create, '')
replace_once(
    path,
    '      if (currentData.paymentProviderStatus === "paid" &&\n          currentData.stripeSellerTransferId) return;\n',
    '      if (currentData.paymentProviderStatus === "paid") return;\n',
)
replace_once(
    path,
    '        stripeSellerTransferId: transfer ? String(transfer.id || "") : null,\n',
    '        stripeSellerTransferId: null,\n        sellerPayoutStatus: "pending_release",\n',
)
replace_once(
    path,
    '        financialStatus: "settled",\n',
    '        financialStatus: "paid_pending_fulfillment",\n',
)

# 6) Add the common payment lifecycle: Timed Buying mirror + settlement sync + delayed Connect release.
Path("firebase/functions/marketplace_payment_lifecycle.js").write_text(r'''"use strict";

const {stripeSecretKey} = require("./stripe_marketplace_commands");
const {stripeFormRequest} = require("./stripe_checkout_commands");

function transactionIdForAuction(listingId) {
  return `auction_${String(listingId || "").trim()}`;
}

function releaseEligible(sale = {}) {
  const completionReached = sale.status === "completed" ||
    sale.auctionSettlementStatus === "completed";
  return completionReached &&
    sale.paymentProvider === "stripe" &&
    sale.paymentProviderStatus === "paid" &&
    sale.sellerPayoutStatus !== "released" &&
    !sale.stripeSellerTransferId &&
    sale.financialHold !== true &&
    String(sale.financialStatus || "") !== "disputed" &&
    String(sale.disputeStatus || "") !== "open" &&
    Number(sale.refundedMinor || 0) === 0;
}

function createMarketplacePaymentLifecycle(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  async function mirrorAuctionTransaction({listingId, transactionData}) {
    const sale = transactionData || {};
    const buyerUid = String(sale.buyerUid || "").trim();
    const sellerUid = String(sale.sellerUid || "").trim();
    if (!listingId || !buyerUid || !sellerUid) return {created: false};
    const mirrorId = transactionIdForAuction(listingId);
    const mirrorRef = db.collection("marketplace_transactions").doc(mirrorId);
    const existing = await mirrorRef.get();
    if (existing.exists) return {created: false, transactionId: mirrorId};
    const listingSnapshot = await db.collection("public_listings").doc(listingId).get();
    const listing = listingSnapshot.exists ? listingSnapshot.data() : {};
    const agreedQuantity = Math.max(1, Number(sale.agreedQuantity || 1));
    const agreedTotal = Number(sale.agreedTotal || sale.winningBidAmount || 0);
    if (!Number.isFinite(agreedTotal) || agreedTotal <= 0) return {created: false};
    const agreedUnitPrice = Number(sale.agreedUnitPrice || agreedTotal / agreedQuantity);
    await mirrorRef.create({
      listingId,
      listingTitle: String(listing.title || "Timed Buying purchase").slice(0, 240),
      buyerUid,
      sellerUid,
      source: "timed_buying_winner",
      paymentOrigin: "timed_buying",
      auctionTransactionId: listingId,
      status: "pending_payment",
      auctionSettlementStatus: String(sale.status || "pending_completion"),
      buyerConfirmed: sale.buyerConfirmed === true,
      sellerConfirmed: sale.sellerConfirmed === true,
      agreedUnitPrice,
      agreedQuantity,
      agreedTotal,
      currency: String(sale.currency || listing.currency || "CAD").toUpperCase(),
      priceBasis: String(sale.priceBasis || listing.priceBasis || "total"),
      revision: 1,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return {created: true, transactionId: mirrorId};
  }

  async function syncAuctionTransaction({listingId, transactionData}) {
    const sale = transactionData || {};
    const mirrorId = transactionIdForAuction(listingId);
    const mirrorRef = db.collection("marketplace_transactions").doc(mirrorId);
    const mirrorSnapshot = await mirrorRef.get();
    if (!mirrorSnapshot.exists) {
      return mirrorAuctionTransaction({listingId, transactionData: sale});
    }
    const mirror = mirrorSnapshot.data();
    const auctionStatus = String(sale.status || "pending_completion");
    const terminalWithoutPayment = new Set([
      "cancelled", "disputed", "buyer_default_reported", "seller_default_reported",
    ]);
    let marketplaceStatus = String(mirror.status || "pending_payment");
    if (terminalWithoutPayment.has(auctionStatus)) marketplaceStatus = auctionStatus;
    else if (mirror.paymentProviderStatus === "paid") marketplaceStatus = auctionStatus;
    else marketplaceStatus = "pending_payment";
    await mirrorRef.set({
      status: marketplaceStatus,
      auctionSettlementStatus: auctionStatus,
      buyerConfirmed: sale.buyerConfirmed === true,
      sellerConfirmed: sale.sellerConfirmed === true,
      ...(String(sale.reason || "").trim() ? {reason: String(sale.reason).slice(0, 2000)} : {}),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return {synced: true, transactionId: mirrorId};
  }

  async function releaseSellerFunds({transactionId}) {
    const transactionRef = db.collection("marketplace_transactions").doc(transactionId);
    const snapshot = await transactionRef.get();
    if (!snapshot.exists) return {released: false, reason: "missing"};
    const sale = snapshot.data();
    if (!releaseEligible(sale)) return {released: false, reason: "not_ready"};
    const sellerProvider = await db.collection("payment_provider_accounts")
        .doc(String(sale.sellerUid || "")).get();
    if (!sellerProvider.exists || sellerProvider.data().transferStatus !== "active") {
      await transactionRef.set({
        sellerPayoutStatus: "blocked_seller_not_ready",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {released: false, reason: "seller_not_ready"};
    }
    if (sellerProvider.data().sellerPayoutHold === true) {
      await transactionRef.set({
        sellerPayoutStatus: "blocked_financial_hold",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {released: false, reason: "financial_hold"};
    }
    const destination = String(sellerProvider.data().stripeAccountId || "");
    const chargeId = String(sale.stripeChargeId || "");
    const amount = Number(sale.sellerProceedsMinor || 0);
    if (!destination.startsWith("acct_") || !chargeId.startsWith("ch_") ||
        !Number.isSafeInteger(amount) || amount < 0) {
      throw new Error("Paid marketplace transaction has invalid seller release data.");
    }
    if (amount === 0) {
      await transactionRef.set({
        sellerPayoutStatus: "released",
        financialStatus: "settled",
        sellerReleasedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {released: true, transferId: null};
    }
    const transferGroup = String(sale.stripeTransferGroup || `PB_${transactionId}`).slice(0, 200);
    const transfer = await stripeFormRequest({
      secretKey: stripeSecretKey.value(),
      path: "/v1/transfers",
      idempotencyKey: `pipebuyer-seller-release-${transactionId}`,
      fields: {
        amount,
        currency: String(sale.currency || "CAD").toLowerCase(),
        destination,
        source_transaction: chargeId,
        transfer_group: transferGroup,
        "metadata[pipeBuyerTransactionId]": transactionId,
        "metadata[listingId]": String(sale.listingId || ""),
        "metadata[releaseReason]": "confirmed_physical_goods_completion",
      },
    });
    const transferId = String(transfer.id || "");
    if (!transferId.startsWith("tr_")) {
      throw new Error("Stripe did not return a valid seller transfer.");
    }
    await transactionRef.set({
      stripeSellerTransferId: transferId,
      sellerPayoutStatus: "released",
      financialStatus: "settled",
      sellerReleasedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      ...(sale.paymentOrigin === "timed_buying" &&
          sale.auctionSettlementStatus === "completed" ? {status: "completed"} : {}),
    }, {merge: true});
    return {released: true, transferId};
  }

  return {mirrorAuctionTransaction, syncAuctionTransaction, releaseSellerFunds};
}

module.exports = {createMarketplacePaymentLifecycle, releaseEligible, transactionIdForAuction};
''')

# 7) Wire lifecycle triggers into the production function surface.
path = "firebase/functions/bootstrap.js"
replace_once(
    path,
    'const {onDocumentCreated} = require("firebase-functions/v2/firestore");\n',
    'const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");\n',
)
insert_after_once(
    path,
    'const {createStripeCheckoutCommands} = require("./stripe_checkout_commands");\n',
    'const {\n  createMarketplacePaymentLifecycle,\n} = require("./marketplace_payment_lifecycle");\n',
)
insert_after_once(
    path,
    'const stripeCheckoutCommands = createStripeCheckoutCommands(admin);\n',
    'const marketplacePaymentLifecycle = createMarketplacePaymentLifecycle(admin);\n',
)
append = r'''

// Timed Buying produces an authoritative auction settlement record. Mirror the
// winning purchase into the normal marketplace transaction pipeline so pricing,
// fees, checkout, refunds and seller release have one implementation.
exports.onAuctionTransactionCreatedPaymentMirror = onDocumentCreated(
    {
      document: "auction_transactions/{listingId}",
      retry: true,
    },
    async (event) => marketplacePaymentLifecycle.mirrorAuctionTransaction({
      listingId: event.params.listingId,
      transactionData: event.data && event.data.data(),
    }),
);

exports.onAuctionTransactionUpdatedPaymentMirror = onDocumentUpdated(
    {
      document: "auction_transactions/{listingId}",
      retry: true,
    },
    async (event) => marketplacePaymentLifecycle.syncAuctionTransaction({
      listingId: event.params.listingId,
      transactionData: event.data && event.data.after && event.data.after.data(),
    }),
);

// Physical-goods seller proceeds are intentionally released after completion,
// not from the Checkout-completed webhook. Stripe idempotency prevents duplicate
// transfers if this retryable trigger runs more than once.
exports.onMarketplaceTransactionUpdatedSellerRelease = onDocumentUpdated(
    {
      document: "marketplace_transactions/{transactionId}",
      retry: true,
      secrets: [stripeSecretKey.name],
    },
    async (event) => marketplacePaymentLifecycle.releaseSellerFunds({
      transactionId: event.params.transactionId,
    }),
);
'''
Path(path).write_text(Path(path).read_text().rstrip() + append + "\n")

# 8) Reusable Flutter hosted-checkout control for web + mobile physical goods.
Path("lib/marketplace/marketplace_secure_payment.dart").write_text(r'''import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/accessibility/pipe_status_feedback.dart';
import '../core/diagnostics/app_diagnostics.dart';
import 'marketplace_command_client.dart';

class MarketplaceSecurePaymentPanel extends StatefulWidget {
  const MarketplaceSecurePaymentPanel({
    super.key,
    required this.transactionId,
    required this.isBuyer,
    this.payLabel = 'Pay securely',
  });

  final String transactionId;
  final bool isBuyer;
  final String payLabel;

  @override
  State<MarketplaceSecurePaymentPanel> createState() =>
      _MarketplaceSecurePaymentPanelState();
}

class _MarketplaceSecurePaymentPanelState
    extends State<MarketplaceSecurePaymentPanel> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('marketplace_transactions')
            .doc(widget.transactionId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text(
              'Secure payment status is temporarily unavailable.',
              style: TextStyle(fontSize: 11, color: Colors.redAccent),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Row(children: [
              SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Expanded(child: Text('Preparing secure payment…')),
            ]);
          }
          final sale = snapshot.data!.data() ?? const <String, dynamic>{};
          final paymentStatus = '${sale['paymentProviderStatus'] ?? 'not_started'}';
          final payoutStatus = '${sale['sellerPayoutStatus'] ?? ''}';
          final feeReady = sale['marketplaceFeeSnapshot'] is Map;
          final paid = paymentStatus == 'paid';
          if (paid) {
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle_outline, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    payoutStatus == 'released'
                        ? 'Payment received • seller proceeds released'
                        : 'Payment received • seller proceeds pending completion release',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ]),
            );
          }
          if (!widget.isBuyer) {
            return const Row(children: [
              Icon(Icons.schedule_outlined, size: 19),
              SizedBox(width: 8),
              Expanded(child: Text('Awaiting secure payment from the buyer.')),
            ]);
          }
          if (!feeReady) {
            return const Row(children: [
              SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Expanded(child: Text('Calculating the server-verified transaction total…')),
            ]);
          }
          return SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _startPayment,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_outline),
              label: Text(
                _busy
                    ? 'Opening secure payment…'
                    : paymentStatus == 'checkout_created'
                        ? 'Continue secure payment'
                        : widget.payLabel,
              ),
            ),
          );
        },
      );

  Future<void> _startPayment() async {
    setState(() => _busy = true);
    try {
      final result = await MarketplaceCommandClient().execute(
        'createMarketplaceCheckout',
        {'transactionId': widget.transactionId},
      );
      if (result['alreadyPaid'] == true) {
        if (mounted) {
          PipeFeedback.show(
            context,
            message: 'This purchase is already paid.',
            tone: PipeStatusTone.success,
          );
        }
        return;
      }
      final rawUrl = '${result['checkoutUrl'] ?? ''}'.trim();
      final uri = Uri.tryParse(rawUrl);
      if (uri == null || uri.scheme != 'https') {
        throw StateError('Stripe did not return a secure checkout URL.');
      }
      final opened = await launchUrl(
        uri,
        mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      );
      if (!opened) throw StateError('Secure checkout could not be opened.');
    } catch (error, stackTrace) {
      AppDiagnostics.record(
        error,
        stackTrace,
        subsystem: 'marketplace_payments',
        operation: 'open_secure_checkout',
        fatal: false,
      );
      if (mounted) {
        PipeFeedback.show(
          context,
          message: marketplaceCommandErrorMessage(
            error,
            fallback: 'Secure payment could not be opened. No charge was created.',
          ),
          tone: PipeStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
''')

# 9) Chat: expose secure payment and make completion follow paid/external-agreed state.
path = "lib/marketplace/marketplace_messages_page.dart"
insert_after_once(
    path,
    "import 'marketplace_data_state.dart';\n",
    "import 'marketplace_secure_payment.dart';\n",
)
replace_once(
    path,
    "          final userConfirmed =\n              widget.isSeller ? sellerConfirmed : buyerConfirmed;\n",
    "          final userConfirmed =\n              widget.isSeller ? sellerConfirmed : buyerConfirmed;\n"
    "          final paymentStatus =\n              '${transaction['paymentProviderStatus'] ?? 'not_started'}';\n"
    "          final paymentReadyForCompletion = paymentStatus == 'paid' ||\n"
    "              paymentStatus == 'external_agreed';\n",
)
replace_once(
    path,
    "                const SizedBox(height: 10),\n                Wrap(spacing: 7, runSpacing: 7, children: [\n                  if (!terminal && !userConfirmed)\n",
    "                const SizedBox(height: 10),\n"
    "                MarketplaceSecurePaymentPanel(\n"
    "                  transactionId: widget.offerId,\n"
    "                  isBuyer: !widget.isSeller,\n"
    "                ),\n"
    "                const SizedBox(height: 10),\n"
    "                Wrap(spacing: 7, runSpacing: 7, children: [\n"
    "                  if (!terminal && !userConfirmed && paymentReadyForCompletion)\n",
)
replace_once(
    path,
    "                const Text(\n                  'Payment and logistics remain between the parties. This checklist records confirmations; it does not hold or release funds.',\n                  style: TextStyle(fontSize: 10.5, color: Colors.black54),\n                ),\n",
    "                Text(\n"
    "                  paymentReadyForCompletion\n"
    "                      ? 'For Pipe Buyer Stripe payments, seller proceeds remain pending until completion is confirmed. Pipe Buyer is not an escrow or trust account.'\n"
    "                      : 'Secure payment is required before completion can be confirmed. Deposit/split payments are not enabled yet.',\n"
    "                  style: const TextStyle(fontSize: 10.5, color: Colors.black54),\n"
    "                ),\n",
)

# 10) Timed Buying: show winner payment through the same transaction engine.
path = "lib/marketplace/marketplace_auction_settlement.dart"
insert_after_once(
    path,
    "import 'marketplace_invoice_generator.dart';\n",
    "import 'marketplace_secure_payment.dart';\n",
)
replace_once(
    path,
    "                const SizedBox(height: 12),\n                SizedBox(\n                  width: double.infinity,\n                  child: OutlinedButton.icon(\n",
    "                const SizedBox(height: 12),\n"
    "                MarketplaceSecurePaymentPanel(\n"
    "                  transactionId: 'auction_${widget.listingId}',\n"
    "                  isBuyer: buyer,\n"
    "                  payLabel: 'Pay winning bid',\n"
    "                ),\n"
    "                const SizedBox(height: 10),\n"
    "                SizedBox(\n"
    "                  width: double.infinity,\n"
    "                  child: OutlinedButton.icon(\n",
)
replace_once(
    path,
    "                    'These confirmations record completion between the parties. They do not represent escrow, payment release, or a refund.',\n",
    "                    'The winning bidder pays through the same Pipe Buyer Stripe flow as a normal purchase. Seller proceeds are released only after paid completion; Pipe Buyer does not operate an escrow or trust account.',\n",
)

# 11) Tests: checkout readiness and deferred tax semantics.
path = "firebase/functions/test/stripe_checkout_readiness.test.js"
replace_once(
    path,
    'test("full marketplace checkout still requires actual tax readiness", () => {\n',
    'test("full marketplace checkout requires registered tax or audited deferral", () => {\n',
)
replace_once(
    path,
    '  assert.doesNotThrow(\n      () => requireCheckoutReady({\n        ...providerReady,\n        stripeCheckoutEnabled: true,\n        stripeTaxReady: true,\n      }),\n  );\n',
    '  assert.doesNotThrow(\n'
    '      () => requireCheckoutReady({\n'
    '        ...providerReady,\n'
    '        stripeCheckoutEnabled: true,\n'
    '        stripeTaxReady: true,\n'
    '      }),\n'
    '  );\n'
    '  assert.doesNotThrow(\n'
    '      () => requireCheckoutReady({\n'
    '        ...providerReady,\n'
    '        stripeCheckoutEnabled: true,\n'
    '        marketplaceTaxCollectionDeferredApproved: true,\n'
    '      }),\n'
    '  );\n',
)

path = "firebase/functions/test/payment_readiness_admin.test.js"
replace_once(
    path,
    'test("full marketplace checkout still requires active tax registration", () => {\n',
    'test("full marketplace checkout requires tax registration or audited collection deferral", () => {\n',
)
replace_once(
    path,
    '      /active tax registration/i,\n',
    '      /registered automatic tax or an audited deferred tax-collection decision/i,\n',
)
needle = '''  assert.equal(ready.stripeCheckoutEnabled, true);
});

test("pending tax registration alone cannot authorize Dispatch billing", () => {
'''
replacement = '''  assert.equal(ready.stripeCheckoutEnabled, true);
  const deferred = validateReadiness({
    ...base,
    stripeMode: "production",
    stripeConnectOnboardingEnabled: true,
    stripeCheckoutEnabled: true,
    stripeWebhookVerified: true,
    marketplaceTaxCollectionDeferredApproved: true,
    stripeReconciliationReady: true,
  }, {confirmProduction: true});
  assert.equal(deferred.stripeCheckoutEnabled, true);
  assert.equal(deferred.stripeTaxReady, false);
});

test("registered tax and collection deferral cannot be enabled together", () => {
  assert.throws(
      () => validateReadiness({
        ...base,
        stripeMode: "production",
        stripeTaxReady: true,
        marketplaceTaxCollectionDeferredApproved: true,
      }, {confirmProduction: true}),
      /cannot both be enabled/i,
  );
});

test("pending tax registration alone cannot authorize Dispatch billing", () => {
'''
replace_once(path, needle, replacement)

# Pending tax policy test coverage.
path = "firebase/functions/test/pending_tax_policy.test.js"
text = Path(path).read_text()
if "collection deferral" not in text:
    text += r'''

test("audited marketplace tax collection deferral enables billing without automatic tax", () => {
  const readiness = {marketplaceTaxCollectionDeferredApproved: true};
  assert.equal(taxCollectionStatus(readiness), "collection_deferred");
  assert.equal(taxBillingPrepared(readiness), true);
  assert.equal(automaticTaxEnabled(readiness), false);
  assert.equal(provisionalTaxReserveMinor(100000, "collection_deferred"), 0);
});
'''
    Path(path).write_text(text)

# Payment lifecycle unit tests.
Path("firebase/functions/test/marketplace_payment_lifecycle.test.js").write_text(r'''"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  releaseEligible,
  transactionIdForAuction,
} = require("../marketplace_payment_lifecycle");

test("Timed Buying maps to one deterministic marketplace transaction id", () => {
  assert.equal(transactionIdForAuction("listing-123"), "auction_listing-123");
});

test("seller release requires paid physical-goods completion", () => {
  const paid = {
    status: "completed",
    paymentProvider: "stripe",
    paymentProviderStatus: "paid",
    sellerPayoutStatus: "pending_release",
    refundedMinor: 0,
    financialHold: false,
  };
  assert.equal(releaseEligible(paid), true);
  assert.equal(releaseEligible({...paid, status: "pending_completion"}), false);
  assert.equal(releaseEligible({...paid, paymentProviderStatus: "processing"}), false);
  assert.equal(releaseEligible({...paid, refundedMinor: 1}), false);
  assert.equal(releaseEligible({...paid, disputeStatus: "open"}), false);
});

test("Timed Buying completion may release after the winner has paid", () => {
  assert.equal(releaseEligible({
    status: "pending_payment",
    auctionSettlementStatus: "completed",
    paymentProvider: "stripe",
    paymentProviderStatus: "paid",
    sellerPayoutStatus: "pending_release",
    refundedMinor: 0,
  }), true);
});
''')

print("Marketplace payment flow repair applied deterministically.")
