"use strict";

const crypto = require("node:crypto");
const {stripeMarketplaceConfig} = require("./stripe_marketplace_config");
const {stripeSecretKey} = require("./stripe_marketplace_commands");
const {
  assertMarketplaceFeeCheckoutSessionIdentity,
  assertMarketplaceCheckoutSessionIdentity,
  marketplaceExecutionCurrency,
} = require("./stripe_checkout_commands");
const {
  createSubscriptionMonetization,
} = require("./subscription_monetization");
const {
  createVipSubscriptionMonetization,
} = require("./vip_subscription_monetization");
const {
  createStripeWebhookEventStore,
} = require("./stripe_webhook_event_store");

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

async function retrievePaymentIntent(secretKey, paymentIntentId) {
  const response = await fetch(
      `https://api.stripe.com/v1/payment_intents/${encodeURIComponent(paymentIntentId)}` +
      "?expand[]=latest_charge",
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

function billingType(session) {
  return String(session && session.metadata && session.metadata.billingType || "")
      .trim();
}

function marketplaceChargeState(charge, existing = {}) {
  if (!charge || typeof charge !== "object" ||
      !String(charge.id || "").startsWith("ch_")) {
    throw new Error(
        "Stripe did not expand the latest Charge for financial settlement.",
    );
  }
  const amount = Math.max(0, Number(charge.amount || 0));
  const refundedMinor = Math.max(
      Math.max(0, Number(existing.refundedMinor || 0)),
      Math.max(0, Number(charge.amount_refunded || 0)),
  );
  const fullRefund = amount > 0 && refundedMinor >= amount;
  const partialRefund = refundedMinor > 0 && !fullRefund;
  const dispute = charge.dispute;
  const disputeId = typeof dispute === "string" ? dispute :
    String(dispute && dispute.id || "");
  const disputed = charge.disputed === true || disputeId.startsWith("du_");
  return {
    amount,
    refundedMinor,
    fullRefund,
    partialRefund,
    disputed,
    disputeId: disputeId.startsWith("du_") ? disputeId : null,
    financialHold: disputed || refundedMinor > 0,
  };
}

function assertStripeCurrencyMatches(value, expectedCurrency, source) {
  const normalized = String(value || "").trim().toLowerCase();
  const expected = String(expectedCurrency || "").trim().toLowerCase();
  if (!/^[a-z]{3}$/.test(normalized) ||
      !/^[a-z]{3}$/.test(expected) ||
      normalized !== expected) {
    throw new Error(
        `${source} currency does not match the immutable marketplace currency.`,
    );
  }
  return normalized;
}

function marketplaceCheckoutSessionIsActive({
  sale,
  session,
  transactionId,
  feeOnly,
}) {
  try {
    if (feeOnly) {
      assertMarketplaceFeeCheckoutSessionIdentity({
        sale,
        session,
        transactionId,
      });
    } else {
      assertMarketplaceCheckoutSessionIdentity({sale, session, transactionId});
    }
    return true;
  } catch (_) {
    return false;
  }
}

function createStripeWebhookHandler(admin, options = {}) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;
  const financialResolution = options.marketplaceFinancialResolution || null;
  const webhookEventStore = options.webhookEventStore ||
    createStripeWebhookEventStore({db, admin});
  const readPaymentIntent = options.retrievePaymentIntent ||
    retrievePaymentIntent;
  const readStripeSecret = options.stripeSecret ||
    (() => stripeSecretKey.value());
  const subscriptionMonetization = createSubscriptionMonetization(
      admin,
      stripeMarketplaceConfig,
  );
  const vipSubscriptionMonetization = createVipSubscriptionMonetization(
      admin,
      stripeMarketplaceConfig,
  );

  function affiliateEligibleAfter() {
    return Timestamp.fromMillis(
        Date.now() + AFFILIATE_REFUND_WINDOW_DAYS * 24 * 60 * 60 * 1000,
    );
  }

  async function recordUnresolvedMarketplaceFinancialEvent(event, object) {
    const charge = object && object.charge;
    const chargeId = String(
        object && object.id && String(object.id).startsWith("ch_") ?
          object.id : typeof charge === "string" ? charge :
            charge && charge.id || "",
    );
    const safeObject = JSON.parse(JSON.stringify(object || {}));
    const metadata = object && object.metadata ||
      charge && typeof charge === "object" && charge.metadata || {};
    const trustedTransactionId = String(
        metadata.pipeBuyerTransactionId || "",
    ).trim();
    const documentRef = db.collection("marketplace_unresolved_stripe_events")
        .doc(String(event.id || ""));
    await documentRef.set({
          stripeEventId: String(event.id || ""),
          stripeEventType: String(event.type || ""),
          stripeEventCreated: Math.max(0, Number(event.created || 0)),
          stripeObjectId: String(object && object.id || ""),
          stripeChargeId: chargeId,
          paymentIntentId: String(
              object && object.payment_intent || "",
          ),
          trustedTransactionId: trustedTransactionId || null,
          stripeObject: safeObject,
          status: "pending_marketplace_match",
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
    return {documentRef, trustedTransactionId};
  }

  async function resolveUnmatchedFinancialEvents(chargeId, transactionId) {
    const unresolved = await db
        .collection("marketplace_unresolved_stripe_events")
        .where("stripeChargeId", "==", chargeId)
        .where("status", "==", "pending_marketplace_match")
        .limit(100)
        .get();
    for (const document of unresolved.docs) {
      const data = document.data();
      const object = data.stripeObject || {};
      let resolution = null;
      if (financialResolution && data.stripeEventType === "charge.refunded") {
        resolution = await financialResolution.reconcileChargeRefund(object);
      } else if (financialResolution &&
          String(data.stripeEventType || "").startsWith("charge.dispute.")) {
        resolution = await financialResolution.handleDisputeEvent(
            object,
            data.stripeEventType,
        );
      } else {
        resolution = {transactionId};
      }
      if (!resolution) continue;
      await document.ref.set({
        status: "resolved_at_checkout_settlement",
        transactionId,
        resolvedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
  }

  async function updateAffiliateAfterFeeCollection(transactionId, chargeId) {
    const affiliateLedgerRef = db.collection("affiliate_commission_ledger")
        .doc(`marketplace_${transactionId}`);
    const affiliateLedger = await affiliateLedgerRef.get();
    if (!affiliateLedger.exists ||
        affiliateLedger.data().status !== "pending_platform_fee_payment") {
      return;
    }
    await affiliateLedgerRef.update({
      status: "pending_refund_window",
      eligibleAfter: affiliateEligibleAfter(),
      sourceChargeId: chargeId || null,
      platformFeeCollectedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  }

  async function markCheckoutFailure(session) {
    if (billingType(session) === "dispatch_subscription") {
      await db.collection("subscription_checkout_sessions")
          .doc(String(session.id || "")).set({
            status: "payment_failed",
            paymentFailedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
      return;
    }
    if (billingType(session) === "vip_subscription") {
      await db.collection("vip_subscription_checkout_sessions")
          .doc(String(session.id || "")).set({
            status: "payment_failed",
            paymentFailedAt: FieldValue.serverTimestamp(),
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
    const transactionRef = db.collection("marketplace_transactions")
        .doc(transactionId);
    await db.runTransaction(async (firestoreTransaction) => {
      const snapshot = await firestoreTransaction.get(transactionRef);
      if (!snapshot.exists) {
        throw new Error("Pipe Buyer transaction for Stripe Checkout was not found.");
      }
      const sale = snapshot.data();
      if (feeOnly) {
        assertMarketplaceFeeCheckoutSessionIdentity({
          sale,
          session,
          transactionId,
        });
        if (["collected", "refunded", "partially_refunded"].includes(
            String(sale.marketplaceFeeStatus || ""),
        )) return;
        firestoreTransaction.set(transactionRef, {
          marketplaceFeeStatus: "payment_failed",
          stripeMarketplaceFeeSessionId: String(session.id || ""),
          marketplaceFeePaymentFailedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return;
      }
      assertMarketplaceCheckoutSessionIdentity({sale, session, transactionId});
      if (["paid", "refunded", "partially_refunded"].includes(
          String(sale.paymentProviderStatus || ""),
      )) return;
      firestoreTransaction.set(transactionRef, {
        paymentProviderStatus: "failed",
        stripeCheckoutSessionId: String(session.id || ""),
        paymentFailedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    });
  }

  async function markCheckoutExpired(session) {
    if (billingType(session) === "dispatch_subscription") {
      await db.collection("subscription_checkout_sessions")
          .doc(String(session.id || "")).set({
            status: "expired",
            expiredAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
      return;
    }
    if (billingType(session) === "vip_subscription") {
      await db.collection("vip_subscription_checkout_sessions")
          .doc(String(session.id || "")).set({
            status: "expired",
            expiredAt: FieldValue.serverTimestamp(),
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
    const transactionRef = db.collection("marketplace_transactions")
        .doc(transactionId);
    await db.runTransaction(async (firestoreTransaction) => {
      const snapshot = await firestoreTransaction.get(transactionRef);
      if (!snapshot.exists) {
        throw new Error("Pipe Buyer transaction for Stripe Checkout was not found.");
      }
      const sale = snapshot.data();
      if (!marketplaceCheckoutSessionIsActive({
        sale,
        session,
        transactionId,
        feeOnly,
      })) {
        return;
      }
      if (feeOnly) {
        if (["collected", "refunded", "partially_refunded"].includes(
            String(sale.marketplaceFeeStatus || ""),
        )) return;
        firestoreTransaction.set(transactionRef, {
          marketplaceFeeStatus: "payment_failed",
          stripeMarketplaceFeeSessionId: String(session.id || ""),
          marketplaceFeeCheckoutExpiredAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return;
      }
      if (["paid", "refunded", "partially_refunded"].includes(
          String(sale.paymentProviderStatus || ""),
      )) return;
      firestoreTransaction.set(transactionRef, {
        paymentProviderStatus: "failed",
        stripeCheckoutSessionId: String(session.id || ""),
        stripeCheckoutExpiredAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    });
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
    assertMarketplaceFeeCheckoutSessionIdentity({
      sale,
      session,
      transactionId,
    });
    if (["collected", "refunded", "partially_refunded", "disputed",
      "charged_back"].includes(String(sale.marketplaceFeeStatus || ""))) {
      return;
    }
    const fee = sale.marketplaceFeeSnapshot || {};
    const expectedCurrency = marketplaceExecutionCurrency(fee, sale);
    assertStripeCurrencyMatches(
        session.currency,
        expectedCurrency,
        "Stripe fee Checkout session",
    );
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
    const paymentIntent = await readPaymentIntent(
        readStripeSecret(),
        paymentIntentId,
    );
    assertStripeCurrencyMatches(
        paymentIntent.currency,
        expectedCurrency,
        "Stripe fee PaymentIntent",
    );
    if (paymentIntent.status !== "succeeded") return;
    const latestCharge = paymentIntent.latest_charge;
    const chargeId = typeof latestCharge === "string" ?
      latestCharge : String(latestCharge && latestCharge.id || "");
    if (!chargeId.startsWith("ch_")) {
      throw new Error("The paid marketplace fee has no Stripe charge.");
    }
    const chargeState = marketplaceChargeState(latestCharge);
    assertStripeCurrencyMatches(
        latestCharge.currency,
        expectedCurrency,
        "Stripe fee Charge",
    );
    if (typeof options.afterMarketplaceChargeLookup === "function") {
      await options.afterMarketplaceChargeLookup({
        billingType: "marketplace_fee_only",
        transactionId,
        chargeId,
        chargeState,
      });
    }
    const reconciliationId = [
      "marketplace_fee",
      String(session.id || ""),
      paymentIntentId,
      chargeId,
    ].join(":");
    const affiliateLedgerRef = db.collection("affiliate_commission_ledger")
        .doc(`marketplace_${transactionId}`);
    const bound = await db.runTransaction(async (firestoreTransaction) => {
      const current = await firestoreTransaction.get(transactionRef);
      const affiliateLedger = await firestoreTransaction.get(affiliateLedgerRef);
      if (!current.exists) {
        throw new Error("Pipe Buyer transaction for fee checkout was not found.");
      }
      const currentSale = current.data();
      assertMarketplaceFeeCheckoutSessionIdentity({
        sale: currentSale,
        session,
        transactionId,
      });
      if (["collected", "refunded", "partially_refunded", "disputed",
        "charged_back"].includes(
          String(currentSale.marketplaceFeeStatus || ""),
      )) return false;
      const currentFee = currentSale.marketplaceFeeSnapshot || {};
      if (Number(currentFee.marketplaceFeeMinor) !== expectedFeeMinor ||
          marketplaceExecutionCurrency(currentFee, currentSale) !==
            expectedCurrency) {
        throw new Error(
            "The immutable Pipe Buyer fee snapshot changed before settlement.",
        );
      }
      const alreadyReconciling =
        currentSale.marketplaceFeeStatus === "settlement_reconciling" &&
        Boolean(currentSale.stripeSettlementReconciliationId);
      const preexistingFinancialHold = alreadyReconciling ?
        currentSale.stripeSettlementPreexistingFinancialHold === true :
        currentSale.financialHold === true;
      firestoreTransaction.set(transactionRef, {
        marketplaceFeeStatus: "settlement_reconciling",
        marketplaceFeeFinancialStatus: "settlement_reconciling",
        stripeMarketplaceFeeSessionId: String(session.id || ""),
        stripeMarketplaceFeePaymentIntentId: paymentIntentId,
        stripeMarketplaceFeeChargeId: chargeId,
        platformMarketplaceFeeMinor: expectedFeeMinor,
        marketplaceFeeTaxCollectedMinor: taxCollectedMinor,
        marketplaceFeeBuyerChargedMinor: Number(session.amount_total || 0),
        stripeSettlementReconciliationId: reconciliationId,
        stripeSettlementFinancialEpoch:
          Number(currentSale.financialEpoch || 0),
        stripeSettlementPreexistingFinancialHold: preexistingFinancialHold,
        financialHold: true,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      if (affiliateLedger.exists &&
          affiliateLedger.data().status === "pending_platform_fee_payment") {
        firestoreTransaction.update(affiliateLedgerRef, {
          status: "eligible_financial_review_required",
          stripeSettlementReconciliationId: reconciliationId,
          sourceChargeId: chargeId,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      return true;
    });
    if (!bound) return;
    await resolveUnmatchedFinancialEvents(chargeId, transactionId);
    const refreshedPaymentIntent = await readPaymentIntent(
        readStripeSecret(),
        paymentIntentId,
    );
    assertStripeCurrencyMatches(
        refreshedPaymentIntent.currency,
        expectedCurrency,
        "refreshed Stripe fee PaymentIntent",
    );
    if (refreshedPaymentIntent.status !== "succeeded") {
      throw new Error("The marketplace fee payment changed during settlement.");
    }
    const refreshedCharge = refreshedPaymentIntent.latest_charge;
    const refreshedChargeId = typeof refreshedCharge === "string" ?
      refreshedCharge : String(refreshedCharge && refreshedCharge.id || "");
    if (refreshedChargeId !== chargeId) {
      throw new Error("The marketplace fee Charge changed during settlement.");
    }
    assertStripeCurrencyMatches(
        refreshedCharge && refreshedCharge.currency,
        expectedCurrency,
        "refreshed Stripe fee Charge",
    );
    await db.runTransaction(async (firestoreTransaction) => {
      const current = await firestoreTransaction.get(transactionRef);
      const affiliateLedger = await firestoreTransaction.get(affiliateLedgerRef);
      if (!current.exists) {
        throw new Error("Pipe Buyer transaction for fee checkout was not found.");
      }
      const currentSale = current.data();
      if (currentSale.stripeSettlementReconciliationId !== reconciliationId ||
          currentSale.stripeMarketplaceFeeChargeId !== chargeId) {
        if (["collected", "refunded", "partially_refunded", "disputed",
          "charged_back"].includes(
            String(currentSale.marketplaceFeeStatus || ""),
        )) return;
        throw new Error("Marketplace fee settlement ownership changed.");
      }
      const currentChargeState = marketplaceChargeState(refreshedCharge, {
        refundedMinor: currentSale.marketplaceFeeRefundedMinor,
      });
      const activeDisputeIds = [...new Set([
        ...(Array.isArray(currentSale.activeMarketplaceFeeDisputeIds) ?
          currentSale.activeMarketplaceFeeDisputeIds : []),
        ...(currentChargeState.disputeId ?
          [currentChargeState.disputeId] : []),
      ])];
      const lostDisputeIds = Array.isArray(
          currentSale.lostMarketplaceFeeDisputeIds,
      ) ? currentSale.lostMarketplaceFeeDisputeIds : [];
      const hasLostDispute = lostDisputeIds.length > 0 ||
        String(currentSale.marketplaceFeeDisputeStatus || "") === "lost" ||
        String(currentSale.marketplaceFeeStatus || "") === "charged_back";
      const hasActiveDispute = currentChargeState.disputed ||
        activeDisputeIds.length > 0 ||
        String(currentSale.marketplaceFeeDisputeStatus || "") === "open";
      const feeStatus = hasLostDispute ? "charged_back" :
        hasActiveDispute ? "disputed" :
          currentChargeState.fullRefund ? "refunded" :
            currentChargeState.partialRefund ?
              "partially_refunded" : "collected";
      const financialLabel = hasLostDispute ? "charged_back" :
        hasActiveDispute ? "disputed" :
          currentChargeState.fullRefund ? "refunded" :
            currentChargeState.partialRefund ?
              "partially_refunded" : "settled";
      const settlementEpoch = Number(
          currentSale.stripeSettlementFinancialEpoch || 0,
      );
      const currentEpoch = Number(currentSale.financialEpoch || 0);
      const concurrentFinancialHold = currentEpoch !== settlementEpoch &&
        currentSale.financialHold === true;
      const financialHold =
        currentSale.stripeSettlementPreexistingFinancialHold === true ||
        concurrentFinancialHold || currentChargeState.refundedMinor > 0 ||
        hasActiveDispute || hasLostDispute;
      firestoreTransaction.set(transactionRef, {
        marketplaceFeeStatus: feeStatus,
        marketplaceFeeFinancialStatus: financialLabel,
        marketplaceFeeRefundedMinor: currentChargeState.refundedMinor,
        activeMarketplaceFeeDisputeIds: activeDisputeIds,
        marketplaceFeeDisputeStatus: hasActiveDispute ? "open" :
          hasLostDispute ? "lost" :
            currentSale.marketplaceFeeDisputeStatus || null,
        financialHold,
        stripeSettlementReconciliationId: null,
        stripeSettlementFinancialEpoch: null,
        stripeSettlementPreexistingFinancialHold: null,
        marketplaceFeeCollectedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      if (affiliateLedger.exists) {
        const ledger = affiliateLedger.data();
        if (ledger.status === "eligible_financial_review_required" &&
            ledger.stripeSettlementReconciliationId === reconciliationId) {
          const commission = Math.max(0, Number(ledger.commissionMinor || 0));
          const exposureMinor = hasActiveDispute || hasLostDispute ?
            currentChargeState.amount : currentChargeState.refundedMinor;
          const adjustedCommission = currentChargeState.amount > 0 ?
            Math.floor(commission * Math.max(
                0,
                currentChargeState.amount - exposureMinor,
            ) / currentChargeState.amount) : 0;
          firestoreTransaction.update(affiliateLedgerRef, {
            status: financialHold ? adjustedCommission === 0 ?
              "void_financial_event" :
              "eligible_financial_review_required" :
              "pending_refund_window",
            eligibleAfter: affiliateEligibleAfter(),
            adjustedCommissionMinor: adjustedCommission,
            financialExposureMinor: exposureMinor,
            financialRecoveryTargetMinor:
              Math.max(0, commission - adjustedCommission),
            contingentDisputeHold: hasActiveDispute || hasLostDispute,
            stripeSettlementReconciliationId: null,
            platformFeeCollectedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
      }
    });
    await resolveUnmatchedFinancialEvents(chargeId, transactionId);
    await updateAffiliateAfterFeeCollection(transactionId, chargeId);
  }

  async function settleSuccessfulCheckout(session) {
    if (billingType(session) === "marketplace_fee_only") {
      await settleMarketplaceFeeOnly(session);
      return;
    }
    if (billingType(session) === "dispatch_subscription") {
      const customerId = typeof session.customer === "string" ?
        session.customer : String(session.customer && session.customer.id || "");
      await db.collection("subscription_checkout_sessions")
          .doc(String(session.id || "")).set({
            status: session.payment_status === "paid" ? "active" : "processing",
            stripeSubscriptionId: typeof session.subscription === "string" ?
              session.subscription :
              String(session.subscription && session.subscription.id || ""),
            stripeCustomerId: customerId.startsWith("cus_") ? customerId : null,
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
      return;
    }
    if (billingType(session) === "vip_subscription") {
      const customerId = typeof session.customer === "string" ?
        session.customer : String(session.customer && session.customer.id || "");
      await db.collection("vip_subscription_checkout_sessions")
          .doc(String(session.id || "")).set({
            status: session.payment_status === "paid" ? "processing" : "processing",
            stripeSubscriptionId: typeof session.subscription === "string" ?
              session.subscription :
              String(session.subscription && session.subscription.id || ""),
            stripeCustomerId: customerId.startsWith("cus_") ? customerId : null,
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
    assertMarketplaceCheckoutSessionIdentity({sale, session, transactionId});
    if (["paid", "refunded", "partially_refunded"].includes(
        String(sale.paymentProviderStatus || ""),
    ) && sale.stripeChargeId) return;
    const fee = sale.marketplaceFeeSnapshot || {};
    const expectedCurrency = marketplaceExecutionCurrency(fee, sale);
    assertStripeCurrencyMatches(
        session.currency,
        expectedCurrency,
        "Stripe sale Checkout session",
    );
    const marketplaceFeeMinor = Number(fee.marketplaceFeeMinor);
    const sellerProceedsMinor = Number(fee.sellerProceedsBeforeTaxMinor);
    if (!Number.isSafeInteger(marketplaceFeeMinor) || marketplaceFeeMinor < 0 ||
        !Number.isSafeInteger(sellerProceedsMinor) || sellerProceedsMinor < 0) {
      throw new Error("The immutable Pipe Buyer fee snapshot is unavailable.");
    }
    const saleSubtotalMinor = Number(session.amount_subtotal || 0);
    if (saleSubtotalMinor !== Number(fee.agreedTotalMinor)) {
      throw new Error(
          "Stripe sale checkout does not match the immutable sale snapshot.",
      );
    }
    const paymentIntentId = typeof session.payment_intent === "string" ?
      session.payment_intent :
      String(session.payment_intent && session.payment_intent.id || "");
    if (!paymentIntentId.startsWith("pi_")) {
      throw new Error("The Stripe Checkout session has no payment intent.");
    }
    const paymentIntent = await readPaymentIntent(
        readStripeSecret(),
        paymentIntentId,
    );
    assertStripeCurrencyMatches(
        paymentIntent.currency,
        expectedCurrency,
        "Stripe sale PaymentIntent",
    );
    if (paymentIntent.status !== "succeeded") return;
    const latestCharge = paymentIntent.latest_charge;
    const chargeId = typeof latestCharge === "string" ?
      latestCharge : String(latestCharge && latestCharge.id || "");
    if (!chargeId.startsWith("ch_")) {
      throw new Error("The successful payment has no Stripe charge.");
    }
    const chargeState = marketplaceChargeState(latestCharge);
    assertStripeCurrencyMatches(
        latestCharge.currency,
        expectedCurrency,
        "Stripe sale Charge",
    );
    if (typeof options.afterMarketplaceChargeLookup === "function") {
      await options.afterMarketplaceChargeLookup({
        billingType: "marketplace_sale",
        transactionId,
        chargeId,
        chargeState,
      });
    }
    const transferGroup = String(
        sale.stripeTransferGroup || paymentIntent.transfer_group ||
        `PB_${transactionId}`,
    ).slice(0, 200);

    const amountTotal = Number(session.amount_total || 0);
    const taxCollectedMinor = Number(
        session.total_details && session.total_details.amount_tax || 0,
    );
    const affiliateLedgerRef = db.collection("affiliate_commission_ledger")
        .doc(`marketplace_${transactionId}`);
    const reconciliationId = [
      "marketplace_sale",
      String(session.id || ""),
      paymentIntentId,
      chargeId,
    ].join(":");
    const bound = await db.runTransaction(async (firestoreTransaction) => {
      const current = await firestoreTransaction.get(transactionRef);
      const affiliateLedger = await firestoreTransaction.get(affiliateLedgerRef);
      if (!current.exists) return;
      const currentData = current.data();
      assertMarketplaceCheckoutSessionIdentity({
        sale: currentData,
        session,
        transactionId,
      });
      if (["paid", "refunded", "partially_refunded"].includes(
          String(currentData.paymentProviderStatus || ""),
      ) && currentData.stripeChargeId) return false;
      const currentFee = currentData.marketplaceFeeSnapshot || {};
      if (Number(currentFee.agreedTotalMinor) !== saleSubtotalMinor ||
          Number(currentFee.marketplaceFeeMinor) !== marketplaceFeeMinor ||
          Number(currentFee.sellerProceedsBeforeTaxMinor) !==
            sellerProceedsMinor ||
          marketplaceExecutionCurrency(currentFee, currentData) !==
            expectedCurrency) {
        throw new Error(
            "The immutable marketplace payment snapshot changed before settlement.",
        );
      }
      const alreadyReconciling =
        currentData.paymentProviderStatus === "settlement_reconciling" &&
        Boolean(currentData.stripeSettlementReconciliationId);
      const preexistingFinancialHold = alreadyReconciling ?
        currentData.stripeSettlementPreexistingFinancialHold === true :
        currentData.financialHold === true;
      firestoreTransaction.set(transactionRef, {
        paymentMethod: "stripe_checkout",
        paymentProvider: "stripe",
        paymentProviderStatus: "settlement_reconciling",
        marketplaceFeeStatus: "settlement_reconciling",
        stripeCheckoutSessionId: String(session.id || ""),
        stripePaymentIntentId: paymentIntentId,
        stripeChargeId: chargeId,
        stripeSellerTransferId: currentData.stripeSellerTransferId || null,
        sellerPayoutStatus: "blocked_financial_hold",
        stripeTransferGroup: transferGroup,
        buyerChargedMinor: amountTotal,
        taxCollectedMinor,
        sellerProceedsMinor,
        platformMarketplaceFeeMinor: marketplaceFeeMinor,
        financialStatus: "settlement_reconciling",
        financialHold: true,
        stripeSettlementReconciliationId: reconciliationId,
        stripeSettlementFinancialEpoch:
          Number(currentData.financialEpoch || 0),
        stripeSettlementPreexistingFinancialHold: preexistingFinancialHold,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      if (affiliateLedger.exists &&
          affiliateLedger.data().status === "pending_platform_fee_payment") {
        firestoreTransaction.update(affiliateLedgerRef, {
          status: "eligible_financial_review_required",
          stripeSettlementReconciliationId: reconciliationId,
          sourceChargeId: chargeId,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      return true;
    });
    if (!bound) return;
    await resolveUnmatchedFinancialEvents(chargeId, transactionId);
    const refreshedPaymentIntent = await readPaymentIntent(
        readStripeSecret(),
        paymentIntentId,
    );
    assertStripeCurrencyMatches(
        refreshedPaymentIntent.currency,
        expectedCurrency,
        "refreshed Stripe sale PaymentIntent",
    );
    if (refreshedPaymentIntent.status !== "succeeded") {
      throw new Error("The marketplace payment changed during settlement.");
    }
    const refreshedCharge = refreshedPaymentIntent.latest_charge;
    const refreshedChargeId = typeof refreshedCharge === "string" ?
      refreshedCharge : String(refreshedCharge && refreshedCharge.id || "");
    if (refreshedChargeId !== chargeId) {
      throw new Error("The marketplace Charge changed during settlement.");
    }
    assertStripeCurrencyMatches(
        refreshedCharge && refreshedCharge.currency,
        expectedCurrency,
        "refreshed Stripe sale Charge",
    );
    await db.runTransaction(async (firestoreTransaction) => {
      const current = await firestoreTransaction.get(transactionRef);
      const affiliateLedger = await firestoreTransaction.get(affiliateLedgerRef);
      if (!current.exists) {
        throw new Error("Pipe Buyer transaction for Stripe Checkout was not found.");
      }
      const currentData = current.data();
      if (currentData.stripeSettlementReconciliationId !== reconciliationId ||
          currentData.stripeChargeId !== chargeId) {
        if (["paid", "refunded", "partially_refunded"].includes(
            String(currentData.paymentProviderStatus || ""),
        )) return;
        throw new Error("Marketplace settlement ownership changed.");
      }
      const currentChargeState = marketplaceChargeState(refreshedCharge, {
        refundedMinor: currentData.refundedMinor,
      });
      const activeDisputeIds = [...new Set([
        ...(Array.isArray(currentData.activeDisputeIds) ?
          currentData.activeDisputeIds : []),
        ...(currentChargeState.disputeId ?
          [currentChargeState.disputeId] : []),
      ])];
      const lostDisputeIds = Array.isArray(currentData.lostDisputeIds) ?
        currentData.lostDisputeIds : [];
      const hasLostDispute = lostDisputeIds.length > 0 ||
        String(currentData.disputeStatus || "") === "lost" ||
        String(currentData.financialStatus || "") === "charged_back";
      const hasActiveDispute = currentChargeState.disputed ||
        activeDisputeIds.length > 0 ||
        String(currentData.disputeStatus || "") === "open";
      const paymentProviderStatus = currentChargeState.fullRefund ?
        "refunded" : currentChargeState.partialRefund ?
          "partially_refunded" : "paid";
      const financialStatus = hasLostDispute ? "charged_back" :
        hasActiveDispute ? "disputed" :
          currentChargeState.fullRefund ? "refunded" :
            currentChargeState.partialRefund ?
              "partially_refunded" : "paid_pending_fulfillment";
      const settlementEpoch = Number(
          currentData.stripeSettlementFinancialEpoch || 0,
      );
      const currentEpoch = Number(currentData.financialEpoch || 0);
      const concurrentFinancialHold = currentEpoch !== settlementEpoch &&
        currentData.financialHold === true;
      const financialHold =
        currentData.stripeSettlementPreexistingFinancialHold === true ||
        concurrentFinancialHold || currentChargeState.refundedMinor > 0 ||
        hasActiveDispute || hasLostDispute;
      firestoreTransaction.set(transactionRef, {
        paymentProviderStatus,
        marketplaceFeeStatus: hasLostDispute ? "charged_back" :
          hasActiveDispute ? "disputed" :
            currentChargeState.fullRefund ? "refunded" :
              currentChargeState.partialRefund ?
                "partially_refunded" : "collected",
        sellerPayoutStatus: financialHold ?
          "blocked_financial_hold" : "pending_release",
        refundedMinor: currentChargeState.refundedMinor,
        financialStatus,
        financialHold,
        activeDisputeIds,
        activeDisputeId: activeDisputeIds[0] || null,
        disputeStatus: hasActiveDispute ? "open" :
          hasLostDispute ? "lost" : currentData.disputeStatus || null,
        stripeSettlementReconciliationId: null,
        stripeSettlementFinancialEpoch: null,
        stripeSettlementPreexistingFinancialHold: null,
        paidAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      if (affiliateLedger.exists) {
        const ledger = affiliateLedger.data();
        if (ledger.status === "eligible_financial_review_required" &&
            ledger.stripeSettlementReconciliationId === reconciliationId) {
          const commission = Math.max(0, Number(ledger.commissionMinor || 0));
          const exposureMinor = hasActiveDispute || hasLostDispute ?
            currentChargeState.amount : currentChargeState.refundedMinor;
          const adjustedCommission = currentChargeState.amount > 0 ?
            Math.floor(commission * Math.max(
                0,
                currentChargeState.amount - exposureMinor,
            ) / currentChargeState.amount) : 0;
          firestoreTransaction.update(affiliateLedgerRef, {
            status: financialHold ? adjustedCommission === 0 ?
              "void_financial_event" :
              "eligible_financial_review_required" :
              "pending_refund_window",
            eligibleAfter: affiliateEligibleAfter(),
            adjustedCommissionMinor: adjustedCommission,
            financialExposureMinor: exposureMinor,
            financialRecoveryTargetMinor:
              Math.max(0, commission - adjustedCommission),
            contingentDisputeHold: hasActiveDispute || hasLostDispute,
            stripeSettlementReconciliationId: null,
            platformFeeCollectedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
      }
    });
    await resolveUnmatchedFinancialEvents(chargeId, transactionId);
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
    if (billingType(session) === "vip_subscription") {
      await db.collection("vip_subscription_checkout_sessions")
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
    const transactionRef = db.collection("marketplace_transactions")
        .doc(transactionId);
    await db.runTransaction(async (firestoreTransaction) => {
      const snapshot = await firestoreTransaction.get(transactionRef);
      if (!snapshot.exists) {
        throw new Error("Pipe Buyer transaction for Stripe Checkout was not found.");
      }
      const sale = snapshot.data();
      if (feeOnly) {
        assertMarketplaceFeeCheckoutSessionIdentity({
          sale,
          session,
          transactionId,
        });
        if (["collected", "payment_failed", "refunded", "partially_refunded"]
            .includes(String(sale.marketplaceFeeStatus || ""))) return;
        firestoreTransaction.set(transactionRef, {
          marketplaceFeeStatus: "processing",
          stripeMarketplaceFeeSessionId: String(session.id || ""),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return;
      }
      assertMarketplaceCheckoutSessionIdentity({sale, session, transactionId});
      if (["paid", "failed", "refunded", "partially_refunded"].includes(
          String(sale.paymentProviderStatus || ""),
      )) return;
      firestoreTransaction.set(transactionRef, {
        paymentProviderStatus: "processing",
        stripeCheckoutSessionId: String(session.id || ""),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    });
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
    if (type === "checkout.session.expired") {
      await markCheckoutExpired(object);
      return;
    }
    if (type === "invoice.paid") {
      await subscriptionMonetization.handleDispatchInvoicePaid(
          object,
          stripeSecretKey.value(),
      );
      await vipSubscriptionMonetization.handleVipInvoicePaid(
          object,
          stripeSecretKey.value(),
      );
      return;
    }
    if (type === "invoice.payment_failed") {
      await subscriptionMonetization.handleDispatchInvoicePaymentFailed(
          object,
          stripeSecretKey.value(),
      );
      await vipSubscriptionMonetization.handleVipInvoicePaymentFailed(
          object,
          stripeSecretKey.value(),
      );
      return;
    }
    if (type === "charge.refunded") {
      await subscriptionMonetization.voidPendingCommissionForRefund(object);
      let resolution = null;
      if (financialResolution) {
        resolution = await financialResolution.reconcileChargeRefund(object);
      }
      if (!resolution) {
        const unresolved = await recordUnresolvedMarketplaceFinancialEvent(
            event,
            object,
        );
        if (financialResolution) {
          resolution = await financialResolution.reconcileChargeRefund(object);
        }
        if (resolution) {
          await unresolved.documentRef.set({
            status: "resolved_after_charge_binding",
            transactionId: resolution.transactionId,
            resolvedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
        } else if (unresolved.trustedTransactionId) {
          throw new Error(
              "Marketplace refund is waiting for Checkout charge binding.",
          );
        }
      }
      return;
    }
    if (["refund.created", "refund.updated", "refund.failed"].includes(type)) {
      if (financialResolution) {
        await financialResolution.handleRefundStatusEvent(
            object,
            type,
            Number(event.created || 0),
            String(event.id || ""),
        );
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
      let resolution = null;
      if (financialResolution) {
        resolution = await financialResolution.handleDisputeEvent(object, type);
      }
      if (!resolution) {
        const unresolved = await recordUnresolvedMarketplaceFinancialEvent(
            event,
            object,
        );
        if (financialResolution) {
          resolution = await financialResolution.handleDisputeEvent(object, type);
        }
        if (resolution) {
          await unresolved.documentRef.set({
            status: "resolved_after_charge_binding",
            transactionId: resolution.transactionId,
            resolvedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
        } else if (unresolved.trustedTransactionId) {
          throw new Error(
              "Marketplace dispute is waiting for Checkout charge binding.",
          );
        }
      }
    }
  }

  const handler = async (request, response, processingContext = {}) => {
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
    let event = processingContext.event || null;
    if (!event) {
      try {
        event = JSON.parse(rawBody.toString("utf8"));
      } catch (_) {
        response.status(400).send("Invalid JSON");
        return;
      }
    }
    const eventId = String(event.id || "");
    if (!eventId.startsWith("evt_")) {
      response.status(400).send("Invalid Stripe event");
      return;
    }
    const activeEventStore = processingContext.webhookEventStore ||
      webhookEventStore;
    let claim = processingContext.claim || null;
    if (!claim) {
      try {
        claim = await activeEventStore.begin({
          eventId,
          type: String(event.type || ""),
        });
      } catch (error) {
        console.error("Stripe webhook claim failed", {eventId, error});
        response.status(500).send("Webhook claim failed");
        return;
      }
    }
    if (claim.state === "duplicate") {
      response.status(200).send("Already processed");
      return;
    }
    if (claim.state !== "acquired") {
      response.status(409).send("Webhook processing in progress");
      return;
    }
    try {
      await handleEvent(event);
      await activeEventStore.complete(eventId, claim);
      response.status(200).send("OK");
    } catch (error) {
      console.error("Stripe webhook processing failed", {
        eventId,
        type: event.type,
        error,
      });
      await activeEventStore.fail(eventId, error, claim);
      response.status(500).send("Webhook processing failed");
    }
  };
  handler.webhookEventStore = webhookEventStore;
  return handler;
}

module.exports = {
  AFFILIATE_REFUND_WINDOW_DAYS,
  SIGNATURE_TOLERANCE_SECONDS,
  STRIPE_WEBHOOK_SECRET_NAME,
  assertStripeCurrencyMatches,
  assertMarketplaceFeeCheckoutSessionIdentity,
  billingType,
  createStripeWebhookHandler,
  marketplaceCheckoutSessionIsActive,
  stripeWebhookSecret,
  verifyStripeSignature,
};
