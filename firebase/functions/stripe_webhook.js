"use strict";

const crypto = require("node:crypto");
const {stripeMarketplaceConfig} = require("./stripe_marketplace_config");
const {stripeSecretKey} = require("./stripe_marketplace_commands");
const {
  affiliateEconomics,
} = require("./affiliate_revenue_policy");
const {
  createSubscriptionMonetization,
} = require("./subscription_monetization");

const STRIPE_WEBHOOK_SECRET_NAME = "STRIPE_WEBHOOK_SECRET";
const stripeWebhookSecret = Object.freeze({
  name: STRIPE_WEBHOOK_SECRET_NAME,
  value() {
    const value = String(process.env[STRIPE_WEBHOOK_SECRET_NAME] || "").trim();
    if (!value) throw new Error("Stripe webhook credentials are unavailable.");
    return value;
  },
});
const SIGNATURE_TOLERANCE_SECONDS = 5 * 60;
const AFFILIATE_REFUND_WINDOW_DAYS = 30;

function safeEqualHex(left, right) {
  if (!/^[a-f0-9]+$/i.test(left) || !/^[a-f0-9]+$/i.test(right)) return false;
  const leftBuffer = Buffer.from(left, "hex");
  const rightBuffer = Buffer.from(right, "hex");
  return leftBuffer.length === rightBuffer.length &&
    crypto.timingSafeEqual(leftBuffer, rightBuffer);
}

function verifyStripeSignature(rawBody, signatureHeader, secret, nowSeconds) {
  if (!Buffer.isBuffer(rawBody) || rawBody.length === 0) return false;
  const parts = String(signatureHeader || "").split(",");
  let timestamp = null;
  const signatures = [];
  for (const part of parts) {
    const separator = part.indexOf("=");
    if (separator < 1) continue;
    const key = part.slice(0, separator).trim();
    const value = part.slice(separator + 1).trim();
    if (key === "t") timestamp = Number(value);
    if (key === "v1") signatures.push(value);
  }
  const currentSeconds = Number.isFinite(nowSeconds) ?
    Number(nowSeconds) : Math.floor(Date.now() / 1000);
  if (!Number.isFinite(timestamp) ||
      Math.abs(currentSeconds - timestamp) > SIGNATURE_TOLERANCE_SECONDS) {
    return false;
  }
  const expected = crypto.createHmac("sha256", secret)
      .update(`${timestamp}.${rawBody.toString("utf8")}`)
      .digest("hex");
  return signatures.some((candidate) => safeEqualHex(candidate, expected));
}

async function stripeFormRequest({
  secretKey,
  path,
  fields,
  idempotencyKey,
  method = "POST",
}) {
  const form = new URLSearchParams();
  for (const [key, value] of Object.entries(fields || {})) {
    if (value == null) continue;
    if (Array.isArray(value)) {
      for (const item of value) form.append(`${key}[]`, String(item));
    } else {
      form.append(key, String(value));
    }
  }
  const response = await fetch(`https://api.stripe.com${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${secretKey}`,
      "Stripe-Version": stripeMarketplaceConfig.apiVersion,
      ...(method === "GET" ? {} : {
        "Content-Type": "application/x-www-form-urlencoded",
      }),
      ...(idempotencyKey ? {"Idempotency-Key": idempotencyKey} : {}),
    },
    ...(method === "GET" ? {} : {body: form.toString()}),
  });
  let payload = null;
  try {
    payload = await response.json();
  } catch (_) {
    payload = null;
  }
  if (!response.ok) {
    const code = String(
        payload && payload.error &&
        (payload.error.code || payload.error.type) || "",
    ).slice(0, 120);
    const error = new Error("Stripe provider request failed.");
    error.stripeStatus = response.status;
    error.stripeCode = code;
    throw error;
  }
  return payload || {};
}

async function retrievePaymentIntent(secretKey, paymentIntentId) {
  const response = await fetch(
      `https://api.stripe.com/v1/payment_intents/${encodeURIComponent(paymentIntentId)}` +
      "?expand[]=latest_charge.balance_transaction",
      {
        headers: {
          Authorization: `Bearer ${secretKey}`,
          "Stripe-Version": stripeMarketplaceConfig.apiVersion,
        },
      },
  );
  const payload = await response.json();
  if (!response.ok) throw new Error("Stripe payment intent retrieval failed.");
  return payload;
}

function chargeEconomics(paymentIntent, expectedCurrency) {
  const latestCharge = paymentIntent && paymentIntent.latest_charge;
  const chargeId = typeof latestCharge === "string" ?
    latestCharge : String(latestCharge && latestCharge.id || "");
  if (!chargeId.startsWith("ch_")) {
    throw new Error("The successful payment has no Stripe charge.");
  }
  if (!latestCharge || typeof latestCharge !== "object") {
    throw new Error("Stripe charge economics are unavailable.");
  }
  const balanceTransaction = latestCharge.balance_transaction;
  if (!balanceTransaction || typeof balanceTransaction !== "object") {
    throw new Error("Stripe charge fee details are unavailable.");
  }
  const providerFeeMinor = Number(balanceTransaction.fee);
  if (!Number.isSafeInteger(providerFeeMinor) || providerFeeMinor < 0) {
    throw new Error("Stripe charge fee details are invalid.");
  }
  const currency = String(balanceTransaction.currency || "").toUpperCase();
  const expected = String(expectedCurrency || "").toUpperCase();
  if (!currency || (expected && currency !== expected)) {
    // Do not guess FX economics. Hold settlement for reconciliation instead of
    // transferring seller funds while Pipe Buyer's actual provider cost is in
    // another settlement currency.
    throw new Error("Stripe charge settlement currency requires financial review.");
  }
  return {
    chargeId,
    balanceTransactionId: String(balanceTransaction.id || ""),
    providerFeeMinor,
    netChargeImpactMinor: Number(balanceTransaction.net || 0),
    currency,
  };
}

function billingType(session) {
  return String(session && session.metadata && session.metadata.billingType || "")
      .trim();
}

function createStripeWebhookHandler(admin, options = {}) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;
  const financialResolution = options.marketplaceFinancialResolution || null;
  const subscriptionMonetization = createSubscriptionMonetization(
      admin,
      stripeMarketplaceConfig,
  );

  function affiliateEligibleAfter() {
    return Timestamp.fromMillis(
        Date.now() + AFFILIATE_REFUND_WINDOW_DAYS * 24 * 60 * 60 * 1000,
    );
  }

  async function updateAffiliateAfterFeeCollection(
      transactionId,
      chargeId,
      economics,
  ) {
    const affiliateLedgerRef = db.collection("affiliate_commission_ledger")
        .doc(`marketplace_${transactionId}`);
    const affiliateLedger = await affiliateLedgerRef.get();
    if (!affiliateLedger.exists ||
        affiliateLedger.data().status !== "pending_platform_fee_payment") {
      return;
    }
    const commissionMinor = Number(economics && economics.commissionMinor || 0);
    await affiliateLedgerRef.update({
      status: commissionMinor > 0 ?
        "pending_refund_window" : "void_no_eligible_revenue",
      eligibleAfter: commissionMinor > 0 ? affiliateEligibleAfter() : null,
      sourceChargeId: chargeId || null,
      affiliateRevenuePolicyRevision: String(
          economics && economics.policyRevision || "",
      ),
      commissionShareBps: Number(economics && economics.shareBps || 0),
      grossPlatformRevenueMinor: Number(
          economics && economics.grossPlatformRevenueMinor || 0,
      ),
      paymentProviderFeeMinor: Number(
          economics && economics.paymentProviderFeeMinor || 0,
      ),
      providerFeeRecoveredMinor: Number(
          economics && economics.providerFeeRecoveredMinor || 0,
      ),
      unrecoveredProviderFeeMinor: Number(
          economics && economics.unrecoveredProviderFeeMinor || 0,
      ),
      provisionalTaxReserveMinor: Number(
          economics && economics.provisionalTaxReserveMinor || 0,
      ),
      commissionableRevenueMinor: Number(
          economics && economics.commissionableRevenueMinor || 0,
      ),
      commissionMinor,
      adjustedCommissionMinor: commissionMinor,
      commissionProvisional: false,
      platformFeeCollectedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  }

  async function markCheckoutFailure(session) {
    const transactionId = String(
        session && session.metadata &&
        session.metadata.pipeBuyerTransactionId || "",
    ).trim();
    if (!transactionId) return;
    const feeOnly = billingType(session) === "marketplace_fee_only";
    await db.collection("marketplace_transactions").doc(transactionId).set(
        feeOnly ? {
          marketplaceFeeStatus: "payment_failed",
          stripeMarketplaceFeeSessionId: String(session.id || ""),
          marketplaceFeePaymentFailedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        } : {
          paymentProviderStatus: "failed",
          stripeCheckoutSessionId: String(session.id || ""),
          paymentFailedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
    );
  }

  async function settleMarketplaceFeeOnly(session) {
    const transactionId = String(
        session && session.metadata &&
        session.metadata.pipeBuyerTransactionId || "",
    ).trim();
    if (!transactionId) return;
    const transactionRef = db.collection("marketplace_transactions")
        .doc(transactionId);
    const transactionSnapshot = await transactionRef.get();
    if (!transactionSnapshot.exists) {
      throw new Error("Pipe Buyer transaction for fee checkout was not found.");
    }
    const sale = transactionSnapshot.data();
    if (sale.marketplaceFeeStatus === "collected") return;
    const fee = sale.marketplaceFeeSnapshot || {};
    const expectedFeeMinor = Number(fee.marketplaceFeeMinor);
    const subtotalMinor = Number(session.amount_subtotal || 0);
    const taxCollectedMinor = Number(
        session.total_details && session.total_details.amount_tax || 0,
    );
    if (!Number.isSafeInteger(expectedFeeMinor) || expectedFeeMinor <= 0 ||
        subtotalMinor !== expectedFeeMinor) {
      throw new Error(
          "Stripe fee checkout does not match the immutable fee snapshot.",
      );
    }
    const paymentIntentId = typeof session.payment_intent === "string" ?
      session.payment_intent :
      String(session.payment_intent && session.payment_intent.id || "");
    if (!paymentIntentId.startsWith("pi_")) {
      throw new Error("The fee checkout has no Stripe payment intent.");
    }
    const paymentIntent = await retrievePaymentIntent(
        stripeSecretKey.value(),
        paymentIntentId,
    );
    if (paymentIntent.status !== "succeeded") return;
    const charge = chargeEconomics(
        paymentIntent,
        String(fee.currency || sale.currency || "CAD"),
    );
    const provisionalReserveMinor = Math.max(
        0,
        Number(sale.marketplaceFeeProvisionalTaxReserveIfCollectedMinor || 0),
    );
    const economics = affiliateEconomics({
      grossPlatformRevenueMinor: expectedFeeMinor,
      paymentProviderFeeMinor: charge.providerFeeMinor,
      providerFeeRecoveredMinor: 0,
      provisionalTaxReserveMinor: provisionalReserveMinor,
      shareBps: Number(fee.affiliateShareBps || 500),
    });
    await transactionRef.set({
      marketplaceFeeStatus: "collected",
      stripeMarketplaceFeeSessionId: String(session.id || ""),
      stripeMarketplaceFeePaymentIntentId: paymentIntentId,
      stripeMarketplaceFeeChargeId: charge.chargeId,
      stripeMarketplaceFeeBalanceTransactionId: charge.balanceTransactionId,
      marketplaceFeePaymentProviderFeeMinor: charge.providerFeeMinor,
      platformMarketplaceFeeMinor: expectedFeeMinor,
      platformNetEligibleRevenueMinor: economics.commissionableRevenueMinor,
      affiliateRevenuePolicyRevision: economics.policyRevision,
      marketplaceFeeTaxCollectedMinor: taxCollectedMinor,
      marketplaceFeeBuyerChargedMinor: Number(session.amount_total || 0),
      marketplaceFeeCollectedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    await updateAffiliateAfterFeeCollection(
        transactionId,
        charge.chargeId,
        economics,
    );
  }

  async function settleSuccessfulCheckout(session) {
    if (billingType(session) === "marketplace_fee_only") {
      await settleMarketplaceFeeOnly(session);
      return;
    }
    if (billingType(session) === "dispatch_subscription") {
      await db.collection("subscription_checkout_sessions")
          .doc(String(session.id || "")).set({
            status: session.payment_status === "paid" ? "active" : "processing",
            stripeSubscriptionId: typeof session.subscription === "string" ?
              session.subscription :
              String(session.subscription && session.subscription.id || ""),
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
      return;
    }
    const transactionId = String(
        session && session.metadata &&
        session.metadata.pipeBuyerTransactionId || "",
    ).trim();
    if (!transactionId) return;
    const transactionRef = db.collection("marketplace_transactions")
        .doc(transactionId);
    const transactionSnapshot = await transactionRef.get();
    if (!transactionSnapshot.exists) {
      throw new Error("Pipe Buyer transaction for Stripe Checkout was not found.");
    }
    const sale = transactionSnapshot.data();
    if (sale.paymentProviderStatus === "paid" &&
        sale.stripeSellerTransferId) return;
    const fee = sale.marketplaceFeeSnapshot || {};
    const marketplaceFeeMinor = Number(fee.marketplaceFeeMinor);
    const sellerProceedsBeforeProviderFeesMinor = Number(
        fee.sellerProceedsBeforeProviderFeesMinor ??
        fee.sellerProceedsBeforeTaxMinor,
    );
    if (!Number.isSafeInteger(marketplaceFeeMinor) || marketplaceFeeMinor < 0 ||
        !Number.isSafeInteger(sellerProceedsBeforeProviderFeesMinor) ||
        sellerProceedsBeforeProviderFeesMinor < 0) {
      throw new Error("The immutable Pipe Buyer fee snapshot is unavailable.");
    }
    const saleSubtotalMinor = Number(session.amount_subtotal || 0);
    if (saleSubtotalMinor !== Number(fee.agreedTotalMinor)) {
      throw new Error(
          "Stripe sale checkout does not match the immutable sale snapshot.",
      );
    }
    const sellerProvider = await db.collection("payment_provider_accounts")
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
    const paymentIntentId = typeof session.payment_intent === "string" ?
      session.payment_intent :
      String(session.payment_intent && session.payment_intent.id || "");
    if (!paymentIntentId.startsWith("pi_")) {
      throw new Error("The Stripe Checkout session has no payment intent.");
    }
    const paymentIntent = await retrievePaymentIntent(
        stripeSecretKey.value(),
        paymentIntentId,
    );
    if (paymentIntent.status !== "succeeded") return;
    const expectedCurrency = String(fee.currency || sale.currency || "CAD");
    const charge = chargeEconomics(paymentIntent, expectedCurrency);
    const providerFeeRecoveredMinor = Math.min(
        sellerProceedsBeforeProviderFeesMinor,
        charge.providerFeeMinor,
    );
    const sellerProceedsMinor = Math.max(
        0,
        sellerProceedsBeforeProviderFeesMinor - providerFeeRecoveredMinor,
    );
    const economics = affiliateEconomics({
      grossPlatformRevenueMinor: marketplaceFeeMinor,
      paymentProviderFeeMinor: charge.providerFeeMinor,
      providerFeeRecoveredMinor,
      shareBps: Number(fee.affiliateShareBps || 500),
    });
    const transferGroup = String(
        sale.stripeTransferGroup || paymentIntent.transfer_group ||
        `PB_${transactionId}`,
    ).slice(0, 200);

    let transfer = null;
    if (sellerProceedsMinor > 0) {
      transfer = await stripeFormRequest({
        secretKey: stripeSecretKey.value(),
        path: "/v1/transfers",
        idempotencyKey: `pipebuyer-seller-transfer-${transactionId}`,
        fields: {
          amount: sellerProceedsMinor,
          currency: expectedCurrency.toLowerCase(),
          destination,
          source_transaction: charge.chargeId,
          transfer_group: transferGroup,
          "metadata[pipeBuyerTransactionId]": transactionId,
          "metadata[listingId]": String(sale.listingId || ""),
          "metadata[feeScheduleRevision]": String(fee.scheduleRevision || ""),
          "metadata[providerFeeRecoveredMinor]": providerFeeRecoveredMinor,
        },
      });
    }

    const amountTotal = Number(session.amount_total || 0);
    const taxCollectedMinor = Number(
        session.total_details && session.total_details.amount_tax || 0,
    );
    const affiliateLedgerRef = db.collection("affiliate_commission_ledger")
        .doc(`marketplace_${transactionId}`);
    await db.runTransaction(async (firestoreTransaction) => {
      const current = await firestoreTransaction.get(transactionRef);
      const affiliateLedger = await firestoreTransaction.get(affiliateLedgerRef);
      if (!current.exists) return;
      const currentData = current.data();
      if (currentData.paymentProviderStatus === "paid" &&
          currentData.stripeSellerTransferId) return;
      firestoreTransaction.set(transactionRef, {
        paymentMethod: "stripe_checkout",
        paymentProvider: "stripe",
        paymentProviderStatus: "paid",
        marketplaceFeeStatus: "collected",
        stripeCheckoutSessionId: String(session.id || ""),
        stripePaymentIntentId: paymentIntentId,
        stripeChargeId: charge.chargeId,
        stripeChargeBalanceTransactionId: charge.balanceTransactionId,
        stripeChargeFeeMinor: charge.providerFeeMinor,
        stripeSellerTransferId: transfer ? String(transfer.id || "") : null,
        stripeTransferGroup: transferGroup,
        buyerChargedMinor: amountTotal,
        refundedMinor: 0,
        taxCollectedMinor,
        sellerProceedsBeforeProviderFeesMinor,
        sellerPaymentProviderCostMinor: charge.providerFeeMinor,
        sellerPaymentProviderCostRecoveredMinor: providerFeeRecoveredMinor,
        originalSellerProceedsMinor: sellerProceedsMinor,
        sellerProceedsMinor,
        platformMarketplaceFeeMinor: marketplaceFeeMinor,
        platformNetEligibleRevenueMinor: economics.commissionableRevenueMinor,
        affiliateRevenuePolicyRevision: economics.policyRevision,
        financialStatus: "settled",
        financialHold: false,
        paidAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      if (affiliateLedger.exists &&
          affiliateLedger.data().status === "pending_platform_fee_payment") {
        const commissionMinor = economics.commissionMinor;
        firestoreTransaction.update(affiliateLedgerRef, {
          status: commissionMinor > 0 ?
            "pending_refund_window" : "void_no_eligible_revenue",
          eligibleAfter: commissionMinor > 0 ? affiliateEligibleAfter() : null,
          sourceChargeId: charge.chargeId,
          affiliateRevenuePolicyRevision: economics.policyRevision,
          commissionShareBps: economics.shareBps,
          grossPlatformRevenueMinor: economics.grossPlatformRevenueMinor,
          paymentProviderFeeMinor: economics.paymentProviderFeeMinor,
          providerFeeRecoveredMinor: economics.providerFeeRecoveredMinor,
          unrecoveredProviderFeeMinor: economics.unrecoveredProviderFeeMinor,
          commissionableRevenueMinor: economics.commissionableRevenueMinor,
          commissionMinor,
          adjustedCommissionMinor: commissionMinor,
          commissionProvisional: false,
          platformFeeCollectedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    });
  }

  async function markCheckoutProcessing(session) {
    if (billingType(session) === "dispatch_subscription") {
      await db.collection("subscription_checkout_sessions")
          .doc(String(session.id || "")).set({
            status: "processing",
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
      return;
    }
    const transactionId = String(
        session && session.metadata &&
        session.metadata.pipeBuyerTransactionId || "",
    ).trim();
    if (!transactionId) return;
    const feeOnly = billingType(session) === "marketplace_fee_only";
    await db.collection("marketplace_transactions").doc(transactionId).set(
        feeOnly ? {
          marketplaceFeeStatus: "processing",
          stripeMarketplaceFeeSessionId: String(session.id || ""),
          updatedAt: FieldValue.serverTimestamp(),
        } : {
          paymentProviderStatus: "processing",
          stripeCheckoutSessionId: String(session.id || ""),
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
    );
  }

  async function handleEvent(event) {
    const type = String(event && event.type || "");
    const object = event && event.data && event.data.object || null;
    if (!object) return;
    if (type === "checkout.session.completed") {
      if (object.payment_status === "paid") {
        await settleSuccessfulCheckout(object);
      } else {
        await markCheckoutProcessing(object);
      }
      return;
    }
    if (type === "checkout.session.async_payment_succeeded") {
      await settleSuccessfulCheckout(object);
      return;
    }
    if (type === "checkout.session.async_payment_failed") {
      await markCheckoutFailure(object);
      return;
    }
    if (type === "invoice.paid") {
      await subscriptionMonetization.handleDispatchInvoicePaid(
          object,
          stripeSecretKey.value(),
      );
      return;
    }
    if (type === "charge.refunded") {
      await subscriptionMonetization.voidPendingCommissionForRefund(object);
      if (financialResolution) {
        await financialResolution.reconcileChargeRefund(object);
      }
      return;
    }
    if (["refund.created", "refund.updated", "refund.failed"].includes(type)) {
      if (financialResolution) {
        await financialResolution.handleRefundStatusEvent(object, type);
      }
      return;
    }
    if ([
      "charge.dispute.created",
      "charge.dispute.updated",
      "charge.dispute.closed",
      "charge.dispute.funds_withdrawn",
      "charge.dispute.funds_reinstated",
    ].includes(type)) {
      if (financialResolution) {
        await financialResolution.handleDisputeEvent(object, type);
      }
    }
  }

  return async (request, response) => {
    const rawBody = request.rawBody;
    const signature = request.get("stripe-signature");
    if (!verifyStripeSignature(
        rawBody,
        signature,
        stripeWebhookSecret.value(),
    )) {
      response.status(400).send("Invalid Stripe signature");
      return;
    }
    let event;
    try {
      event = JSON.parse(rawBody.toString("utf8"));
    } catch (_) {
      response.status(400).send("Invalid JSON");
      return;
    }
    const eventId = String(event.id || "");
    if (!eventId.startsWith("evt_")) {
      response.status(400).send("Invalid Stripe event");
      return;
    }
    const eventRef = db.collection("stripe_webhook_events").doc(eventId);
    const existing = await eventRef.get();
    if (existing.exists && existing.data().status === "processed") {
      response.status(200).send("Already processed");
      return;
    }
    try {
      await handleEvent(event);
      await eventRef.set({
        eventId,
        type: String(event.type || ""),
        status: "processed",
        processedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      response.status(200).send("OK");
    } catch (error) {
      console.error("Stripe webhook processing failed", {
        eventId,
        type: event.type,
        error,
      });
      await eventRef.set({
        eventId,
        type: String(event.type || ""),
        status: "failed",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      response.status(500).send("Webhook processing failed");
    }
  };
}

module.exports = {
  AFFILIATE_REFUND_WINDOW_DAYS,
  SIGNATURE_TOLERANCE_SECONDS,
  STRIPE_WEBHOOK_SECRET_NAME,
  billingType,
  chargeEconomics,
  createStripeWebhookHandler,
  retrievePaymentIntent,
  stripeWebhookSecret,
  verifyStripeSignature,
};
