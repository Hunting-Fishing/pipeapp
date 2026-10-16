"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {
  AdministratorAuthorizationError,
  requireAdministrator,
} = require("./administrator_authorization");
const {stripeSecretKey} = require("./stripe_marketplace_commands");
const {
  isStripeChargeId,
  isStripeDisputeId,
  stripeFinancialRequest,
} = require("./marketplace_stripe_financial_api");
const {
  createMarketplaceSellerFunds,
  proportionalRecoveryTarget,
} = require("./marketplace_seller_funds");
const {
  financialMutationValues,
  mutateMarketplaceFinancialState,
} = require("./marketplace_financial_epoch");
const {
  marketplaceTransactionCurrency,
} = require("./marketplace_command_policy");

const MAX_REASON_LENGTH = 1600;
const TERMINAL_DISPUTE_OUTCOMES = new Set(["won", "lost", "warning_closed"]);
const DEFAULT_REFUND_DISPATCH_LEASE_MILLIS = 5 * 60 * 1000;

function financialCurrency(...values) {
  let currency = null;
  for (const value of values) {
    if (!String(value || "").trim()) continue;
    const normalized = marketplaceTransactionCurrency(value);
    if (currency && normalized !== currency) {
      throw new TypeError("Marketplace financial currencies do not match.");
    }
    currency = normalized;
  }
  return marketplaceTransactionCurrency(currency);
}

function requireAuth(request) {
  return requireAuthenticatedIdentity(request, {requirePhone: false}).uid;
}

function cleanId(value, field) {
  const id = String(value || "").trim();
  if (!id || id.length > 180 || id.includes("/")) {
    throw new HttpsError("invalid-argument", `${field} is invalid.`);
  }
  return id;
}

function cleanReason(value) {
  const reason = String(value || "").trim();
  if (!reason || reason.length > MAX_REASON_LENGTH) {
    throw new HttpsError(
        "invalid-argument",
        "A concise refund or dispute reason is required.",
    );
  }
  return reason;
}

function positiveMinorAmount(value, field) {
  const amount = Number(value);
  if (!Number.isSafeInteger(amount) || amount <= 0) {
    throw new HttpsError("invalid-argument", `${field} must be a positive integer.`);
  }
  return amount;
}

function refundReasonCode(value) {
  const reason = String(value || "requested_by_customer").trim();
  return ["duplicate", "fraudulent", "requested_by_customer"].includes(reason) ?
    reason : "requested_by_customer";
}

function refundDispatchIdempotencyKey(caseId) {
  return `pipebuyer-refund-${caseId}`;
}

function storedRefundDispatchRequest(financialCase, caseId) {
  const state = String(financialCase && financialCase.refundRequestState || "");
  if (!["reserved", "dispatching", "outcome_unknown", "failed"].includes(state)) {
    return null;
  }
  const key = String(financialCase.refundRequestIdempotencyKey || "");
  const snapshot = financialCase.refundRequestSnapshot;
  const amount = Number(snapshot && snapshot.amountMinor || 0);
  const chargeAmount = Number(snapshot && snapshot.chargeAmountMinor || 0);
  const refundedBefore = Number(snapshot && snapshot.refundedBeforeMinor || 0);
  const chargeId = String(snapshot && snapshot.chargeId || "");
  const transactionId = String(snapshot && snapshot.transactionId || "");
  const approvedByUid = String(snapshot && snapshot.approvedByUid || "");
  const reason = refundReasonCode(snapshot && snapshot.reason);
  if (key !== refundDispatchIdempotencyKey(caseId) ||
      !isStripeChargeId(chargeId) || !transactionId || !approvedByUid ||
      !Number.isSafeInteger(amount) || amount <= 0 ||
      !Number.isSafeInteger(chargeAmount) || chargeAmount <= 0 ||
      !Number.isSafeInteger(refundedBefore) || refundedBefore < 0) return null;
  return {
    state,
    idempotencyKey: key,
    transactionId,
    chargeId,
    amount,
    chargeAmount,
    refundedBefore,
    reason,
    approvedByUid,
  };
}

function stripeFailureIsDefinitive(error) {
  const details = error && error.details && typeof error.details === "object" ?
    error.details : {};
  if (typeof details.stripeRequestDefinitiveFailure === "boolean") {
    return details.stripeRequestDefinitiveFailure;
  }
  const status = Number(error && error.stripeStatus ||
    details.stripeHttpStatus || 0);
  const code = String(error && error.stripeCode || details.stripeCode || "")
      .toLowerCase();
  return status >= 400 && status < 500 &&
    !new Set([408, 409, 424, 429]).has(status) &&
    !new Set(["idempotency_error", "idempotency_key_in_use"]).has(code);
}

function adjustedAffiliateCommission({
  commissionMinor,
  originalChargeAmountMinor,
  customerExposureMinor,
}) {
  const commission = Number(commissionMinor);
  const charge = Number(originalChargeAmountMinor);
  const exposure = Number(customerExposureMinor);
  if (!Number.isSafeInteger(commission) || commission < 0 ||
      !Number.isSafeInteger(charge) || charge <= 0 ||
      !Number.isSafeInteger(exposure) || exposure < 0) {
    throw new TypeError("Affiliate adjustment amounts must use valid minor units.");
  }
  const lost = exposure >= charge ?
    commission : Math.floor(commission * exposure / charge);
  return Math.max(0, commission - lost);
}

function disputeOutcome(status) {
  const value = String(status || "unknown");
  if (value === "won") return "won";
  if (value === "lost") return "lost";
  if (value === "warning_closed") return "warning_closed";
  return "open";
}

function resolvedDisputeOutcome(previousOutcome, incomingOutcome) {
  const previous = String(previousOutcome || "");
  if (TERMINAL_DISPUTE_OUTCOMES.has(previous)) return previous;
  return String(incomingOutcome || "open");
}

function refundStatusShouldApply({
  currentStatus,
  currentEventCreated,
  currentEventId,
  incomingStatus,
  incomingEventCreated,
  incomingEventId,
}) {
  const currentCreated = Math.max(0, Number(currentEventCreated || 0));
  const incomingCreated = Math.max(0, Number(incomingEventCreated || 0));
  if (currentEventId && incomingEventId &&
      String(currentEventId) === String(incomingEventId)) return false;
  if (currentCreated > 0 && incomingCreated > 0) {
    if (incomingCreated > currentCreated) return true;
    if (incomingCreated < currentCreated) return false;
    const statusRank = new Map([
      ["pending", 1],
      ["requires_action", 1],
      ["canceled", 2],
      ["failed", 3],
      ["succeeded", 4],
    ]);
    const currentRank = statusRank.get(String(currentStatus || "")) || 0;
    const incomingRank = statusRank.get(String(incomingStatus || "")) || 0;
    return incomingRank > currentRank;
  }
  if (String(currentStatus || "") === "succeeded" &&
      String(incomingStatus || "") !== "succeeded") return false;
  return true;
}

function financialChargeAmount(sale = {}, billingType = "marketplace_sale") {
  const value = billingType === "marketplace_fee_only" ?
    Number(
        sale.marketplaceFeeBuyerChargedMinor ||
        sale.platformMarketplaceFeeMinor ||
        sale.marketplaceFeeSnapshot &&
          sale.marketplaceFeeSnapshot.marketplaceFeeMinor ||
        0,
    ) : Number(sale.buyerChargedMinor || 0);
  return Number.isSafeInteger(value) && value > 0 ? value : 0;
}

function isParticipant(sale, uid) {
  return Boolean(sale) &&
    [String(sale.buyerUid || ""), String(sale.sellerUid || "")].includes(uid);
}

function createMarketplaceFinancialResolution(admin, options = {}) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;
  const sellerFunds = options.sellerFunds || createMarketplaceSellerFunds(
      admin,
      options.sellerFundsOptions,
  );
  const requestStripe = options.stripeRequest || stripeFinancialRequest;
  const readStripeSecret = options.stripeSecret || (() => stripeSecretKey.value());
  const now = typeof options.now === "function" ? options.now : () => Date.now();
  const refundDispatchLeaseMillis =
    Number.isFinite(options.refundDispatchLeaseMillis) ?
      Number(options.refundDispatchLeaseMillis) :
      DEFAULT_REFUND_DISPATCH_LEASE_MILLIS;

  async function loadReadiness() {
    const snapshot = await db.collection("platform_configuration")
        .doc("payment_provider_readiness").get();
    const data = snapshot.exists ? snapshot.data() : {};
    return {
      stripeMode: String(data.stripeMode || "disabled"),
      webhookVerified: data.stripeWebhookVerified === true,
      reconciliationReady: data.stripeReconciliationReady === true,
      financialResolutionEnabled:
        data.marketplaceFinancialResolutionEnabled === true,
      disputeAutomationEnabled:
        data.marketplaceDisputeAutomationEnabled === true,
      platformFundedRefundOverrideEnabled:
        data.platformFundedRefundOverrideEnabled === true,
    };
  }

  function requireResolutionReady(readiness) {
    if (!readiness.financialResolutionEnabled ||
        !readiness.webhookVerified ||
        !readiness.reconciliationReady ||
        !["sandbox", "production"].includes(readiness.stripeMode)) {
      throw new HttpsError(
          "failed-precondition",
          "Marketplace financial resolution is not enabled yet.",
      );
    }
  }

  async function findTransactionForCharge(chargeId) {
    if (!isStripeChargeId(chargeId)) return null;
    const saleQuery = await db.collection("marketplace_transactions")
        .where("stripeChargeId", "==", chargeId)
        .limit(2)
        .get();
    if (!saleQuery.empty) {
      const document = saleQuery.docs[0];
      return {
        id: document.id,
        ref: document.ref,
        sale: document.data(),
        billingType: "marketplace_sale",
      };
    }
    const feeQuery = await db.collection("marketplace_transactions")
        .where("stripeMarketplaceFeeChargeId", "==", chargeId)
        .limit(2)
        .get();
    if (feeQuery.empty) return null;
    const document = feeQuery.docs[0];
    return {
      id: document.id,
      ref: document.ref,
      sale: document.data(),
      billingType: "marketplace_fee_only",
    };
  }

  async function disputeCases(transactionId) {
    const snapshot = await db.collection("marketplace_financial_cases")
        .where("transactionId", "==", transactionId)
        .limit(100)
        .get();
    return snapshot.docs
        .map((document) => ({id: document.id, ...document.data()}))
        .filter((item) => item.type === "stripe_dispute");
  }

  async function exposureSnapshot(
      transactionId,
      sale,
      billingType = "marketplace_sale",
  ) {
    const chargeAmount = financialChargeAmount(sale, billingType);
    const refundedMinor = Math.max(0, Number(
        billingType === "marketplace_fee_only" ?
          sale.marketplaceFeeRefundedMinor || 0 : sale.refundedMinor || 0,
    ));
    const cases = (await disputeCases(transactionId)).filter((item) =>
      String(item.billingType || "marketplace_sale") === billingType,
    );
    const open = cases.filter((item) => item.outcome === "open");
    const lost = cases.filter((item) => item.outcome === "lost");
    const disputeExposure = [...open, ...lost].reduce(
        (total, item) => total + Math.max(0, Number(item.disputeAmountMinor || 0)),
        0,
    );
    const customerExposureMinor = Math.min(
        chargeAmount,
        refundedMinor + disputeExposure,
    );
    return {
      chargeAmount,
      refundedMinor,
      disputeExposureMinor: disputeExposure,
      customerExposureMinor,
      activeDisputeIds: open.map((item) => String(item.stripeDisputeId || ""))
          .filter(Boolean),
      lostDisputeIds: lost.map((item) => String(item.stripeDisputeId || ""))
          .filter(Boolean),
      cases,
    };
  }

  async function createFinancialEvent({transactionId, sale, caseId, type, values}) {
    await db.collection("marketplace_financial_events").doc().set({
      transactionId,
      caseId: caseId || null,
      buyerUid: String(sale.buyerUid || ""),
      sellerUid: String(sale.sellerUid || ""),
      type,
      ...(values || {}),
      createdAt: FieldValue.serverTimestamp(),
    });
  }

  async function updateAffiliateExposureAtEpoch({
    transactionId,
    customerExposureMinor,
    reason,
    expectedFinancialEpoch,
    billingType = "marketplace_sale",
  }) {
    const transactionRef = db.collection("marketplace_transactions")
        .doc(transactionId);
    const ledgerRef = db.collection("affiliate_commission_ledger")
        .doc(`marketplace_${transactionId}`);
    return db.runTransaction(async (transaction) => {
      const saleSnapshot = await transaction.get(transactionRef);
      const ledgerSnapshot = await transaction.get(ledgerRef);
      if (!saleSnapshot.exists ||
          Number(saleSnapshot.data().financialEpoch || 0) !==
            expectedFinancialEpoch) return false;
      if (!ledgerSnapshot.exists) return true;
      const sale = saleSnapshot.data();
      const ledger = ledgerSnapshot.data();
      const originalCommission = Number(ledger.commissionMinor || 0);
      const chargeAmount = financialChargeAmount(sale, billingType);
      if (!Number.isSafeInteger(originalCommission) || originalCommission <= 0 ||
          !Number.isSafeInteger(chargeAmount) || chargeAmount <= 0) return true;
      const adjusted = adjustedAffiliateCommission({
        commissionMinor: originalCommission,
        originalChargeAmountMinor: chargeAmount,
        customerExposureMinor,
      });
      const lost = originalCommission - adjusted;
      const status = String(ledger.status || "");
      const possiblyEscaped = [
        "paid",
        "payout_dispatching",
        "payout_outcome_unknown",
      ].includes(status) || status === "payout_retry" &&
        ledger.payoutFailureDefinitive !== true;
      if (possiblyEscaped) {
        const referrerUid = String(ledger.referrerUid || "");
        if (!referrerUid) return true;
        const obligationRef = db.collection("affiliate_recovery_obligations")
            .doc(`marketplace_${transactionId}_${referrerUid}`);
        const obligationSnapshot = await transaction.get(obligationRef);
        const openObligations = await transaction.get(
            db.collection("affiliate_recovery_obligations")
                .where("referrerUid", "==", referrerUid)
                .where("status", "==", "open")
                .limit(100),
        );
        const recovered = Math.max(0, Number(
            obligationSnapshot.exists ?
              obligationSnapshot.data().recoveredMinor || 0 : 0,
        ));
        const amountDue = Math.max(0, lost - recovered);
        const hasOtherOpen = openObligations.docs.some((document) =>
          document.id !== obligationRef.id,
        );
        transaction.set(obligationRef, {
          type: "marketplace_commission_recovery",
          transactionId,
          ledgerId: ledgerRef.id,
          referrerUid,
          currency: financialCurrency(ledger.currency, sale.currency),
          targetRecoveryMinor: lost,
          recoveredMinor: recovered,
          amountDueMinor: amountDue,
          reason,
          status: amountDue > 0 ? "open" : "resolved",
          financialExposureEpoch: expectedFinancialEpoch,
          updatedAt: FieldValue.serverTimestamp(),
          ...(amountDue === 0 ? {
            resolvedAt: FieldValue.serverTimestamp(),
          } : {}),
        }, {merge: true});
        transaction.set(ledgerRef, {
          adjustedCommissionMinor: adjusted,
          financialExposureMinor: customerExposureMinor,
          financialRecoveryTargetMinor: lost,
          financialAdjustmentReason: reason,
          financialExposureEpoch: expectedFinancialEpoch,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        transaction.set(
            db.collection("payment_provider_accounts").doc(referrerUid),
            {
              affiliatePayoutHold: amountDue > 0 || hasOtherOpen,
              affiliatePayoutHoldReason: amountDue > 0 || hasOtherOpen ?
                reason : null,
              affiliatePayoutHoldUpdatedAt: FieldValue.serverTimestamp(),
            },
            {merge: true},
        );
        return true;
      }

      let nextStatus = status;
      const changes = {
        adjustedCommissionMinor: adjusted,
        financialExposureMinor: customerExposureMinor,
        financialRecoveryTargetMinor: lost,
        financialAdjustmentReason: reason,
        financialExposureEpoch: expectedFinancialEpoch,
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (adjusted === 0 && status !== "void_financial_event") {
        changes.statusBeforeFinancialAdjustment = status;
        nextStatus = "void_financial_event";
      } else if (adjusted > 0 && status === "void_financial_event") {
        nextStatus = String(
            ledger.statusBeforeFinancialAdjustment || "pending_refund_window",
        );
      }
      changes.status = nextStatus;
      transaction.set(ledgerRef, changes, {merge: true});
      return true;
    });
  }

  async function syncTransactionFinancialState({
    transactionId,
    sale,
    label,
    expectedFinancialEpoch = null,
  }) {
    const exposure = await exposureSnapshot(transactionId, sale);
    const fullRefund = exposure.chargeAmount > 0 &&
      exposure.refundedMinor >= exposure.chargeAmount;
    const partialRefund = exposure.refundedMinor > 0 && !fullRefund;
    let financialStatus = label || "settled";
    if (exposure.lostDisputeIds.length > 0) financialStatus = "charged_back";
    else if (exposure.activeDisputeIds.length > 0) financialStatus = "disputed";
    else if (fullRefund) financialStatus = "refunded";
    else if (partialRefund) financialStatus = "partially_refunded";
    const transactionRef = db.collection("marketplace_transactions")
        .doc(transactionId);
    const appliedEpoch = await db.runTransaction(async (transaction) => {
      const current = await transaction.get(transactionRef);
      if (!current.exists || expectedFinancialEpoch !== null &&
          Number(current.data().financialEpoch || 0) !==
            expectedFinancialEpoch) return false;
      transaction.set(transactionRef, {
        refundedMinor: exposure.refundedMinor,
        financialStatus,
        activeDisputeIds: exposure.activeDisputeIds,
        lostDisputeIds: exposure.lostDisputeIds,
        activeDisputeId: exposure.activeDisputeIds[0] || null,
        disputeStatus: exposure.activeDisputeIds.length > 0 ? "open" :
          exposure.lostDisputeIds.length > 0 ? "lost" : null,
        taxReviewRequired: exposure.lostDisputeIds.length > 0,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return Number(current.data().financialEpoch || 0);
    });
    let affiliateApplied = false;
    if (appliedEpoch !== false) {
      affiliateApplied = await updateAffiliateExposureAtEpoch({
        transactionId,
        customerExposureMinor: exposure.customerExposureMinor,
        reason: financialStatus,
        expectedFinancialEpoch: appliedEpoch,
        billingType: "marketplace_sale",
      });
    }
    return {
      ...exposure,
      applied: appliedEpoch !== false && affiliateApplied,
      appliedFinancialEpoch: appliedEpoch === false ? null : appliedEpoch,
    };
  }

  async function applyMonotonicChargeRefund({
    transactionRef,
    billingType,
    incomingRefundedMinor,
    providerChargeAmountMinor,
  }) {
    return db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(transactionRef);
      if (!snapshot.exists) return null;
      const current = snapshot.data();
      const storedRefundedMinor = Math.max(0, Number(
          billingType === "marketplace_fee_only" ?
            current.marketplaceFeeRefundedMinor : current.refundedMinor,
      ) || 0);
      const effectiveRefundedMinor = Math.max(
          storedRefundedMinor,
          incomingRefundedMinor,
      );
      const chargeAmountMinor = Math.max(
          0,
          Number(providerChargeAmountMinor || 0),
          financialChargeAmount(current, billingType),
      );
      const fullRefund = chargeAmountMinor > 0 &&
        effectiveRefundedMinor >= chargeAmountMinor;
      const expectedStatus = fullRefund ? "refunded" : "partially_refunded";
      const currentStatus = String(
          billingType === "marketplace_fee_only" ?
            current.marketplaceFeeStatus : current.paymentProviderStatus,
      );
      if (effectiveRefundedMinor === storedRefundedMinor &&
          currentStatus === expectedStatus && current.financialHold === true) {
        return {
          sale: current,
          protectedSale: current,
          expectedFinancialEpoch: Number(current.financialEpoch || 0),
          effectiveRefundedMinor,
          chargeAmountMinor,
          fullRefund,
          changed: false,
        };
      }
      const values = billingType === "marketplace_fee_only" ? {
        marketplaceFeeStatus: expectedStatus,
        marketplaceFeeRefundedMinor: effectiveRefundedMinor,
      } : {
        refundedMinor: effectiveRefundedMinor,
        paymentProviderStatus: expectedStatus,
      };
      const patch = {
        ...financialMutationValues(current, values),
        updatedAt: FieldValue.serverTimestamp(),
      };
      transaction.set(transactionRef, patch, {merge: true});
      return {
        sale: current,
        protectedSale: {...current, ...patch},
        expectedFinancialEpoch: Number(patch.financialEpoch || 0),
        effectiveRefundedMinor,
        chargeAmountMinor,
        fullRefund,
        changed: true,
      };
    });
  }

  async function requestMarketplaceRefund(request) {
    try {
      const uid = requireAuth(request);
      await enforceUserRateLimit({db, admin, request, scope: "offers"});
      const transactionId = cleanId(
          request.data && request.data.transactionId,
          "transactionId",
      );
      const requestId = cleanId(request.data && request.data.requestId, "requestId");
      const reason = cleanReason(request.data && request.data.reason);
      const transactionRef = db.collection("marketplace_transactions")
          .doc(transactionId);
      const saleSnapshot = await transactionRef.get();
      if (!saleSnapshot.exists) {
        throw new HttpsError("not-found", "The marketplace transaction was not found.");
      }
      const sale = saleSnapshot.data();
      if (!isParticipant(sale, uid)) {
        throw new HttpsError(
            "permission-denied",
            "Only the buyer or seller can request a refund for this transaction.",
        );
      }
      if (!isStripeChargeId(sale.stripeChargeId)) {
        throw new HttpsError(
            "failed-precondition",
            "This transaction was not paid through Pipe Buyer Stripe Checkout.",
        );
      }
      const exposure = await exposureSnapshot(transactionId, sale);
      if (exposure.activeDisputeIds.length > 0) {
        throw new HttpsError(
            "failed-precondition",
            "A cardholder dispute is already open for this payment.",
        );
      }
      const remaining = Math.max(0,
          Number(sale.buyerChargedMinor || 0) - Number(sale.refundedMinor || 0));
      if (!Number.isSafeInteger(remaining) || remaining <= 0) {
        throw new HttpsError("failed-precondition", "This payment is already refunded.");
      }
      const requestedAmount = request.data && request.data.amountMinor == null ?
        remaining : positiveMinorAmount(request.data.amountMinor, "amountMinor");
      if (requestedAmount > remaining) {
        throw new HttpsError(
            "invalid-argument",
            "The requested refund exceeds the remaining paid amount.",
        );
      }
      const caseRef = db.collection("marketplace_financial_cases").doc(requestId);
      const existing = await caseRef.get();
      if (existing.exists) {
        const data = existing.data();
        if (data.transactionId !== transactionId || data.requestedByUid !== uid) {
          throw new HttpsError("already-exists", "This request ID is already in use.");
        }
        return {
          caseId: requestId,
          transactionId,
          requestedRefundMinor: Number(data.requestedRefundMinor || 0),
          status: String(data.status || "requested"),
          alreadyCreated: true,
        };
      }
      const creation = await db.runTransaction(async (transaction) => {
        const currentSaleSnapshot = await transaction.get(transactionRef);
        const currentCase = await transaction.get(caseRef);
        if (currentCase.exists) {
          const data = currentCase.data();
          if (data.transactionId !== transactionId || data.requestedByUid !== uid) {
            throw new HttpsError(
                "already-exists",
                "This request ID is already in use.",
            );
          }
          return {alreadyCreated: true, data};
        }
        if (!currentSaleSnapshot.exists) {
          throw new HttpsError(
              "not-found",
              "The marketplace transaction was not found.",
          );
        }
        const currentSale = currentSaleSnapshot.data();
        if (!isParticipant(currentSale, uid) ||
            !isStripeChargeId(currentSale.stripeChargeId) ||
            String(currentSale.disputeStatus || "") === "open") {
          throw new HttpsError(
              "failed-precondition",
              "This payment is no longer eligible for a refund request.",
          );
        }
        const currentRemaining = Math.max(
            0,
            Number(currentSale.buyerChargedMinor || 0) -
              Number(currentSale.refundedMinor || 0),
        );
        if (requestedAmount > currentRemaining) {
          throw new HttpsError(
              "failed-precondition",
              "The available refundable amount changed.",
          );
        }
        transaction.create(caseRef, {
          type: "refund_request",
          transactionId,
          listingId: String(currentSale.listingId || ""),
          buyerUid: String(currentSale.buyerUid || ""),
          sellerUid: String(currentSale.sellerUid || ""),
          requestedByUid: uid,
          requestedRefundMinor: requestedAmount,
          currency: financialCurrency(currentSale.currency),
          reason,
          status: "requested",
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.set(transactionRef, {
          ...financialMutationValues(currentSale, {
            financialStatusBeforeRefundRequest:
              String(currentSale.financialStatus || "paid_pending_fulfillment"),
            financialStatus: "refund_requested",
            activeFinancialCaseId: requestId,
          }),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return {alreadyCreated: false};
      });
      if (creation.alreadyCreated) {
        return {
          caseId: requestId,
          transactionId,
          requestedRefundMinor:
            Number(creation.data.requestedRefundMinor || 0),
          status: String(creation.data.status || "requested"),
          alreadyCreated: true,
        };
      }
      await createFinancialEvent({
        transactionId,
        sale,
        caseId: requestId,
        type: "refund_requested",
        values: {actorUid: uid, amountMinor: requestedAmount},
      });
      return {
        caseId: requestId,
        transactionId,
        requestedRefundMinor: requestedAmount,
        status: "requested",
        alreadyCreated: false,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Marketplace refund request failed", error);
      throw new HttpsError("internal", "The refund request could not be recorded.");
    }
  }

  async function cancelMarketplaceRefundRequest(request) {
    try {
      const uid = requireAuth(request);
      const caseId = cleanId(request.data && request.data.caseId, "caseId");
      const caseRef = db.collection("marketplace_financial_cases").doc(caseId);
      const initial = await caseRef.get();
      if (!initial.exists) {
        throw new HttpsError("not-found", "Refund request not found.");
      }
      const transactionId = String(initial.data().transactionId || "");
      const transactionRef = db.collection("marketplace_transactions")
          .doc(transactionId || "missing");
      await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(caseRef);
        const saleSnapshot = await transaction.get(transactionRef);
        if (!snapshot.exists) {
          throw new HttpsError("not-found", "Refund request not found.");
        }
        const financialCase = snapshot.data();
        if (financialCase.requestedByUid !== uid) {
          throw new HttpsError(
              "permission-denied",
              "Only the requester can cancel this refund request.",
          );
        }
        if (financialCase.status !== "requested") {
          throw new HttpsError(
              "failed-precondition",
              "This refund request has already entered financial processing.",
          );
        }
        transaction.update(caseRef, {
          status: "cancelled",
          cancelledByUid: uid,
          cancelledAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        if (!saleSnapshot.exists) return;
        const currentSale = saleSnapshot.data();
        if (String(currentSale.activeFinancialCaseId || "") !== caseId) return;
        const hasOtherFinancialHold =
          String(currentSale.disputeStatus || "") === "open" ||
          Number(currentSale.refundedMinor || 0) > 0;
        transaction.set(transactionRef, {
          ...financialMutationValues(currentSale, {
            activeFinancialCaseId: null,
            financialStatus: hasOtherFinancialHold ?
              String(currentSale.financialStatus || "disputed") :
              String(
                  currentSale.financialStatusBeforeRefundRequest ||
                  "paid_pending_fulfillment",
              ),
          }, {hold: hasOtherFinancialHold}),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      });
      return {caseId, status: "cancelled"};
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      throw new HttpsError("internal", "The refund request could not be cancelled.");
    }
  }

  async function reserveRefundDispatch({
    caseId,
    caseRef,
    transactionId,
    transactionRef,
    expectedFinancialEpoch,
    chargeId,
    amount,
    chargeAmount,
    refundedBefore,
    reason,
    approvedByUid,
  }) {
    return db.runTransaction(async (transaction) => {
      const saleSnapshot = await transaction.get(transactionRef);
      const caseSnapshot = await transaction.get(caseRef);
      if (!saleSnapshot.exists || !caseSnapshot.exists) return null;
      const sale = saleSnapshot.data();
      const financialCase = caseSnapshot.data();
      if (Number(sale.financialEpoch || 0) !== expectedFinancialEpoch ||
          String(sale.activeFinancialCaseId || "") !== caseId ||
          String(sale.disputeStatus || "") === "open" ||
          String(financialCase.transactionId || "") !== transactionId) {
        return null;
      }
      const existing = storedRefundDispatchRequest(financialCase, caseId);
      if (existing) {
        if (existing.transactionId !== transactionId ||
            existing.chargeId !== chargeId || existing.amount !== amount) {
          throw new HttpsError(
              "failed-precondition",
              "The immutable refund provider request does not match this case.",
          );
        }
        transaction.set(caseRef, {
          refundDispatchFinancialEpoch: expectedFinancialEpoch,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return existing;
      }
      const providerRequest = {
        state: "reserved",
        idempotencyKey: refundDispatchIdempotencyKey(caseId),
        transactionId,
        chargeId,
        amount,
        chargeAmount,
        refundedBefore,
        reason,
        approvedByUid,
      };
      transaction.set(caseRef, {
        refundRequestState: "reserved",
        refundRequestIdempotencyKey: providerRequest.idempotencyKey,
        refundRequestSnapshot: {
          transactionId,
          chargeId,
          amountMinor: amount,
          chargeAmountMinor: chargeAmount,
          refundedBeforeMinor: refundedBefore,
          reason,
          approvedByUid,
        },
        refundDispatchFinancialEpoch: expectedFinancialEpoch,
        refundRequestReservedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return providerRequest;
    });
  }

  async function confirmRefundDispatch({
    caseId,
    caseRef,
    transactionRef,
    expectedFinancialEpoch,
    providerRequest,
  }) {
    return db.runTransaction(async (transaction) => {
      const saleSnapshot = await transaction.get(transactionRef);
      const caseSnapshot = await transaction.get(caseRef);
      if (!saleSnapshot.exists || !caseSnapshot.exists) return false;
      const sale = saleSnapshot.data();
      const financialCase = caseSnapshot.data();
      const stored = storedRefundDispatchRequest(financialCase, caseId);
      const activeDisputes = Array.isArray(sale.activeDisputeIds) ?
        sale.activeDisputeIds : [];
      if (!stored || stored.idempotencyKey !== providerRequest.idempotencyKey ||
          stored.transactionId !== providerRequest.transactionId ||
          stored.chargeId !== providerRequest.chargeId ||
          stored.amount !== providerRequest.amount ||
          Number(sale.financialEpoch || 0) !== expectedFinancialEpoch ||
          Number(financialCase.refundDispatchFinancialEpoch || 0) !==
            expectedFinancialEpoch ||
          String(sale.activeFinancialCaseId || "") !== caseId ||
          String(sale.disputeStatus || "") === "open" ||
          activeDisputes.length > 0) return false;
      transaction.set(caseRef, {
        status: "refund_dispatching",
        refundRequestState: "dispatching",
        refundDispatchLeaseExpiresAtMillis:
          now() + refundDispatchLeaseMillis,
        refundRequestDispatchConfirmedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return true;
    });
  }

  async function executeMarketplaceRefund(request) {
    let administratorUid = null;
    try {
      administratorUid = requireAdministrator(request);
      await enforceUserRateLimit({db, admin, request, scope: "administration"});
      const readiness = await loadReadiness();
      requireResolutionReady(readiness);
      const caseId = cleanId(request.data && request.data.caseId, "caseId");
      const allowPlatformFunding =
        request.data && request.data.allowPlatformFunding === true;
      if (allowPlatformFunding && !readiness.platformFundedRefundOverrideEnabled) {
        throw new HttpsError(
            "failed-precondition",
            "Platform-funded refund overrides are disabled.",
        );
      }
      const caseRef = db.collection("marketplace_financial_cases").doc(caseId);
      const caseSnapshot = await caseRef.get();
      if (!caseSnapshot.exists) throw new HttpsError("not-found", "Refund request not found.");
      const financialCase = caseSnapshot.data();
      if (financialCase.type !== "refund_request") {
        throw new HttpsError("failed-precondition", "This case is not a refund request.");
      }
      if (["succeeded", "pending"].includes(String(financialCase.refundStatus || ""))) {
        return {
          caseId,
          transactionId: financialCase.transactionId,
          refundId: financialCase.stripeRefundId || null,
          status: financialCase.refundStatus,
          alreadyExecuted: true,
        };
      }
      const existingProviderRequest = storedRefundDispatchRequest(
          financialCase,
          caseId,
      );
      if (existingProviderRequest &&
          existingProviderRequest.state === "dispatching" &&
          Number(financialCase.refundDispatchLeaseExpiresAtMillis || 0) > now()) {
        return {
          caseId,
          transactionId: financialCase.transactionId,
          refundId: financialCase.stripeRefundId || null,
          status: "processing",
          alreadyExecuted: true,
        };
      }
      if (![
        "requested",
        "blocked_seller_recovery",
        "refund_dispatching",
        "refund_retry_required",
      ]
          .includes(String(financialCase.status || ""))) {
        throw new HttpsError(
            "failed-precondition",
            "This refund request is not eligible for execution.",
        );
      }
      const transactionId = String(financialCase.transactionId || "");
      const transactionRef = db.collection("marketplace_transactions").doc(transactionId);
      const saleSnapshot = await transactionRef.get();
      if (!saleSnapshot.exists) throw new HttpsError("not-found", "Transaction not found.");
      const sale = saleSnapshot.data();
      const currentExposure = await exposureSnapshot(transactionId, sale);
      if (currentExposure.activeDisputeIds.length > 0) {
        throw new HttpsError(
            "failed-precondition",
            "Do not issue a refund while a cardholder dispute is open.",
        );
      }
      const mutation = await mutateMarketplaceFinancialState({
        db,
        transactionRef,
        FieldValue,
        values: {
          financialStatus: "refund_processing",
          activeFinancialCaseId: caseId,
        },
      });
      if (!mutation) {
        throw new HttpsError("not-found", "Transaction not found.");
      }
      const expectedFinancialEpoch = Number(
          mutation.patch.financialEpoch || 0,
      );
      const protectedSaleSnapshot = await transactionRef.get();
      if (!protectedSaleSnapshot.exists) {
        throw new HttpsError("not-found", "Transaction not found.");
      }
      const protectedSale = protectedSaleSnapshot.data();
      const chargeId = String(protectedSale.stripeChargeId || "");
      const charge = await requestStripe({
        secretKey: readStripeSecret(),
        path: `/v1/charges/${encodeURIComponent(chargeId)}`,
        method: "GET",
      });
      financialCurrency(protectedSale.currency, charge.currency);
      const chargeAmount = Number(charge.amount || 0);
      const alreadyRefunded = Number(charge.amount_refunded || 0);
      const remaining = Math.max(0, chargeAmount - alreadyRefunded);
      const requested = existingProviderRequest ?
        existingProviderRequest.amount :
        Number(financialCase.requestedRefundMinor || 0);
      const requestMayHaveEscaped = existingProviderRequest &&
        new Set(["dispatching", "outcome_unknown"]).has(
            existingProviderRequest.state,
        );
      if (!Number.isSafeInteger(requested) || requested <= 0 ||
          requested > remaining && !requestMayHaveEscaped) {
        throw new HttpsError(
            "failed-precondition",
            "The requested refund no longer matches Stripe's refundable balance.",
        );
      }
      const projectedRefunded = requestMayHaveEscaped ?
        Math.max(
            alreadyRefunded,
            existingProviderRequest.refundedBefore + requested,
        ) : alreadyRefunded + requested;
      const projectedExposure = Math.min(
          chargeAmount,
          projectedRefunded + currentExposure.disputeExposureMinor,
      );
      const recovery = await sellerFunds.rebalanceSellerFunds({
        transactionId,
        sale: protectedSale,
        caseId,
        customerExposureMinor: projectedExposure,
        reason: "approved_refund",
        allowRestoration: false,
        expectedFinancialEpoch,
      });
      if (recovery.stale || recovery.inProgress) {
        throw new HttpsError(
            "aborted",
            "The transaction changed during refund recovery. Retry with fresh state.",
        );
      }
      if (recovery.outstandingRecoveryMinor > 0 && !allowPlatformFunding) {
        await caseRef.set({
          status: "blocked_seller_recovery",
          sellerRecoveryOutstandingMinor: recovery.outstandingRecoveryMinor,
          sellerRecoveryFailures: recovery.failures.slice(0, 10),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        throw new HttpsError(
            "failed-precondition",
            "Seller proceeds could not be recovered. The refund remains blocked for financial review.",
        );
      }
      const providerRequest = await reserveRefundDispatch({
        caseId,
        caseRef,
        transactionId,
        transactionRef,
        expectedFinancialEpoch,
        chargeId,
        amount: requested,
        chargeAmount,
        refundedBefore: alreadyRefunded,
        reason: existingProviderRequest ?
          existingProviderRequest.reason :
          refundReasonCode(request.data && request.data.refundReasonCode),
        approvedByUid: existingProviderRequest ?
          existingProviderRequest.approvedByUid : administratorUid,
      });
      if (!providerRequest) {
        throw new HttpsError(
            "aborted",
            "The transaction changed before the refund was reserved.",
        );
      }
      if (typeof options.afterRefundRequestReservation === "function") {
        await options.afterRefundRequestReservation({
          caseId,
          transactionId,
          expectedFinancialEpoch,
          providerRequest,
        });
      }
      let refund;
      let providerDispatched = false;
      try {
        const dispatchCurrent = await confirmRefundDispatch({
          caseId,
          caseRef,
          transactionRef,
          expectedFinancialEpoch,
          providerRequest,
        });
        if (!dispatchCurrent) {
          throw new HttpsError(
              "aborted",
              "The transaction changed before the refund was sent.",
          );
        }
        providerDispatched = true;
        refund = await requestStripe({
          secretKey: readStripeSecret(),
          path: "/v1/refunds",
          idempotencyKey: providerRequest.idempotencyKey,
          fields: {
            charge: providerRequest.chargeId,
            amount: providerRequest.amount,
            reason: providerRequest.reason,
            "metadata[pipeBuyerTransactionId]":
              providerRequest.transactionId,
            "metadata[pipeBuyerFinancialCaseId]": caseId,
            "metadata[approvedByUid]": providerRequest.approvedByUid,
          },
        });
      } catch (error) {
        const definitive = providerDispatched &&
          stripeFailureIsDefinitive(error);
        await caseRef.set({
          status: "refund_retry_required",
          refundRequestState: providerDispatched ?
            definitive ? "failed" : "outcome_unknown" : "reserved",
          refundDispatchLeaseExpiresAtMillis: 0,
          sellerRecoveryCompletedBeforeRefund:
            recovery.outstandingRecoveryMinor === 0,
          refundProviderErrorCode: String(error.stripeCode || "provider_error"),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        throw error;
      }
      const refundStatus = String(refund.status || "pending");
      await caseRef.set({
        status: refundStatus === "succeeded" ? "completed" :
          refundStatus === "failed" ? "refund_retry_required" : "refund_pending",
        refundStatus,
        refundRequestState: refundStatus === "failed" ? "failed" :
          refundStatus === "succeeded" ? "succeeded" : "pending",
        refundDispatchLeaseExpiresAtMillis: 0,
        stripeRefundId: String(refund.id || ""),
        approvedByUid: administratorUid,
        approvedAt: FieldValue.serverTimestamp(),
        sellerRecoveryOutstandingMinor: recovery.outstandingRecoveryMinor,
        platformFundedOverrideUsed:
          allowPlatformFunding && recovery.outstandingRecoveryMinor > 0,
        financialEpoch: expectedFinancialEpoch,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      if (refundStatus === "succeeded") {
        const saleApplied = await db.runTransaction(async (transaction) => {
          const current = await transaction.get(transactionRef);
          if (!current.exists ||
              Number(current.data().financialEpoch || 0) !==
                expectedFinancialEpoch) return false;
          transaction.set(transactionRef, {
            refundedMinor: projectedRefunded,
            paymentProviderStatus: projectedRefunded >= chargeAmount ?
              "refunded" : "partially_refunded",
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
          return true;
        });
        if (saleApplied) {
          const updatedSale = {...protectedSale, refundedMinor: projectedRefunded};
          await syncTransactionFinancialState({
            transactionId,
            sale: updatedSale,
            expectedFinancialEpoch,
          });
        } else {
          await caseRef.set({
            status: "refund_reconciliation_required",
            financialStateStaleAfterRefund: true,
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
        }
      } else {
        await db.runTransaction(async (transaction) => {
          const current = await transaction.get(transactionRef);
          if (!current.exists ||
              Number(current.data().financialEpoch || 0) !==
                expectedFinancialEpoch) return;
          transaction.set(transactionRef, {
            financialStatus: "refund_pending",
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
        });
      }
      await createFinancialEvent({
        transactionId,
        sale,
        caseId,
        type: "refund_executed",
        values: {
          actorUid: administratorUid,
          amountMinor: requested,
          stripeRefundId: String(refund.id || ""),
          refundStatus,
          sellerRecoveryOutstandingMinor: recovery.outstandingRecoveryMinor,
        },
      });
      return {
        caseId,
        transactionId,
        refundId: String(refund.id || ""),
        status: refundStatus,
        sellerRecoveryOutstandingMinor: recovery.outstandingRecoveryMinor,
        platformFundedOverrideUsed:
          allowPlatformFunding && recovery.outstandingRecoveryMinor > 0,
        alreadyExecuted: false,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError ||
          error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Marketplace refund execution failed", {
        administratorUid,
        stripeCode: error && error.stripeCode || null,
        error,
      });
      throw new HttpsError(
          "failed-precondition",
          "The refund could not be completed safely. Review the financial case before retrying.",
      );
    }
  }

  async function reconcileChargeRefund(charge) {
    const chargeId = String(charge && charge.id || "");
    const match = await findTransactionForCharge(chargeId);
    if (!match) return null;
    const {id: transactionId, ref: transactionRef, sale, billingType} = match;
    const incomingRefundedMinor = Math.max(
        0,
        Number(charge.amount_refunded || 0),
    );
    if (billingType === "marketplace_fee_only") {
      const mutation = await applyMonotonicChargeRefund({
        transactionRef,
        billingType,
        incomingRefundedMinor,
        providerChargeAmountMinor: Number(charge.amount || 0),
      });
      if (!mutation) return null;
      const exposure = await exposureSnapshot(
          transactionId,
          mutation.protectedSale,
          billingType,
      );
      const affiliateApplied = await updateAffiliateExposureAtEpoch({
        transactionId,
        customerExposureMinor: exposure.customerExposureMinor,
        reason: mutation.fullRefund ?
          "marketplace_fee_refunded" : "marketplace_fee_partially_refunded",
        expectedFinancialEpoch: mutation.expectedFinancialEpoch,
        billingType,
      });
      if (!affiliateApplied) {
        throw new Error(
            "Marketplace fee refund changed during affiliate reconciliation.",
        );
      }
      return {transactionId, billingType};
    }
    const chargeAmount = Math.max(
        0,
        Number(charge.amount || sale.buyerChargedMinor || 0),
    );
    if (chargeAmount <= 0 || incomingRefundedMinor <= 0) {
      return {transactionId, billingType};
    }
    const mutation = await applyMonotonicChargeRefund({
      transactionRef,
      billingType,
      incomingRefundedMinor,
      providerChargeAmountMinor: chargeAmount,
    });
    if (!mutation) return null;
    const expectedFinancialEpoch = mutation.expectedFinancialEpoch;
    const updatedSale = mutation.protectedSale;
    const exposure = await exposureSnapshot(transactionId, updatedSale);
    const caseId =
      `stripe_refund_${chargeId}_${mutation.effectiveRefundedMinor}`;
    const recovery = await sellerFunds.rebalanceSellerFunds({
      transactionId,
      sale: updatedSale,
      caseId,
      customerExposureMinor: exposure.customerExposureMinor,
      reason: "stripe_refund_reconciliation",
      allowRestoration: false,
      expectedFinancialEpoch,
    });
    if (recovery.stale || recovery.inProgress) {
      throw new Error(
          "Marketplace seller refund recovery changed during reconciliation.",
      );
    }
    const synced = await syncTransactionFinancialState({
      transactionId,
      sale: updatedSale,
      expectedFinancialEpoch,
    });
    if (!synced.applied) {
      throw new Error(
          "Marketplace refund exposure changed during reconciliation.",
      );
    }
    const caseRef = db.collection("marketplace_financial_cases").doc(caseId);
    const caseApplied = await db.runTransaction(async (transaction) => {
      const current = await transaction.get(transactionRef);
      if (!current.exists ||
          Number(current.data().financialEpoch || 0) !==
            expectedFinancialEpoch) return false;
      transaction.set(caseRef, {
        type: "stripe_refund_reconciliation",
        transactionId,
        listingId: String(updatedSale.listingId || ""),
        buyerUid: String(updatedSale.buyerUid || ""),
        sellerUid: String(updatedSale.sellerUid || ""),
        currency: financialCurrency(updatedSale.currency),
        refundedMinor: mutation.effectiveRefundedMinor,
        status: recovery.outstandingRecoveryMinor > 0 ?
          "seller_recovery_required" : "completed",
        sellerRecoveryOutstandingMinor: recovery.outstandingRecoveryMinor,
        financialEpoch: expectedFinancialEpoch,
        updatedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return true;
    });
    if (!caseApplied) {
      throw new Error(
          "Marketplace refund case changed during reconciliation.",
      );
    }
    return {transactionId, billingType, caseId};
  }

  async function handleRefundStatusEvent(
      refund,
      eventType,
      eventCreated = 0,
      eventId = "",
  ) {
    const caseId = String(
        refund && refund.metadata && refund.metadata.pipeBuyerFinancialCaseId || "",
    );
    if (!caseId) return null;
    const caseRef = db.collection("marketplace_financial_cases").doc(caseId);
    const incomingStatus = String(refund.status || "unknown");
    const transition = await db.runTransaction(async (transaction) => {
      const caseSnapshot = await transaction.get(caseRef);
      if (!caseSnapshot.exists) return null;
      const financialCase = caseSnapshot.data();
      const applies = refundStatusShouldApply({
        currentStatus: financialCase.refundStatus,
        currentEventCreated: financialCase.lastStripeRefundEventCreated,
        currentEventId: financialCase.lastStripeRefundEventId,
        incomingStatus,
        incomingEventCreated: eventCreated,
        incomingEventId: eventId,
      });
      if (!applies) {
        return {
          applied: false,
          needsFailedRestoration:
            String(financialCase.refundStatus || "") === "failed" &&
            String(financialCase.status || "") ===
              "refund_restoration_reconciliation_required",
          status: String(financialCase.refundStatus || "unknown"),
          transactionId: String(financialCase.transactionId || ""),
        };
      }
      transaction.set(caseRef, {
        stripeRefundId: String(refund.id || ""),
        refundStatus: incomingStatus,
        lastStripeRefundEvent: eventType,
        lastStripeRefundEventCreated: Math.max(0, Number(eventCreated || 0)),
        lastStripeRefundEventId: String(eventId || ""),
        ...(incomingStatus === "failed" ? {
          status: "refund_retry_required",
        } : {}),
        ...(incomingStatus === "succeeded" ? {status: "completed"} : {}),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {
        applied: true,
        status: incomingStatus,
        transactionId: String(financialCase.transactionId || ""),
      };
    });
    if (!transition) return null;
    const {transactionId, status} = transition;
    if ((transition.applied || transition.needsFailedRestoration) &&
        status === "failed" && transactionId) {
      const transactionRef = db.collection("marketplace_transactions").doc(transactionId);
      const mutation = await mutateMarketplaceFinancialState({
        db,
        transactionRef,
        FieldValue,
        values: {
          financialStatus: "refund_failed_restoration_processing",
          activeFinancialCaseId: caseId,
        },
      });
      if (mutation) {
        const expectedFinancialEpoch = Number(
            mutation.patch.financialEpoch || 0,
        );
        const sale = {...mutation.sale, ...mutation.patch};
        const exposure = await exposureSnapshot(transactionId, sale);
        const restoration = await sellerFunds.rebalanceSellerFunds({
          transactionId,
          sale,
          caseId,
          customerExposureMinor: exposure.customerExposureMinor,
          reason: "failed_refund_restoration",
          allowRestoration: true,
          expectedFinancialEpoch,
        });
        if (restoration.stale || restoration.inProgress) {
          await caseRef.set({
            status: "refund_restoration_reconciliation_required",
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
          throw new Error(
              "Failed refund restoration changed during reconciliation.",
          );
        }
        const synced = await syncTransactionFinancialState({
          transactionId,
          sale,
          expectedFinancialEpoch,
        });
        if (!synced.applied) {
          await caseRef.set({
            status: "refund_restoration_reconciliation_required",
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
          throw new Error(
              "Failed refund exposure changed during reconciliation.",
          );
        }
        await caseRef.set({
          status: "refund_retry_required",
          sellerRestorationOutstandingMinor: Math.max(
              0,
              Number(restoration.outstandingRestorationMinor || 0),
          ),
          sellerRecoveryOutstandingMinor: Math.max(
              0,
              Number(restoration.outstandingRecoveryMinor || 0),
          ),
          restorationFinancialEpoch: expectedFinancialEpoch,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
    }
    return {caseId, transactionId, status};
  }

  async function handleDisputeEvent(dispute, eventType) {
    const disputeId = String(dispute && dispute.id || "");
    if (!isStripeDisputeId(disputeId)) return null;
    const chargeId = typeof dispute.charge === "string" ?
      dispute.charge : String(dispute.charge && dispute.charge.id || "");
    const match = await findTransactionForCharge(chargeId);
    if (!match) return null;
    const {id: transactionId, ref: transactionRef, sale, billingType} = match;
    const incomingOutcome = disputeOutcome(dispute.status);
    const caseId = `dispute_${disputeId}`;
    const caseRef = db.collection("marketplace_financial_cases").doc(caseId);
    const evidenceDueBy = Number(
        dispute.evidence_details && dispute.evidence_details.due_by || 0,
    );
    const disputeState = await db.runTransaction(async (transaction) => {
      const previous = await transaction.get(caseRef);
      const current = previous.exists ? previous.data() : {};
      const outcome = resolvedDisputeOutcome(
          current.outcome,
          incomingOutcome,
      );
      const fundsWithdrawn = current.fundsWithdrawn === true ||
        eventType === "charge.dispute.funds_withdrawn";
      const fundsReinstated = current.fundsReinstated === true ||
        eventType === "charge.dispute.funds_reinstated";
      transaction.set(caseRef, {
        type: "stripe_dispute",
        transactionId,
        listingId: String(sale.listingId || ""),
        buyerUid: String(sale.buyerUid || ""),
        sellerUid: String(sale.sellerUid || ""),
        currency: financialCurrency(dispute.currency, sale.currency),
        stripeDisputeId: disputeId,
        stripeChargeId: chargeId,
        billingType,
        disputeAmountMinor: Math.max(0, Number(dispute.amount || 0)),
        disputeReason: String(dispute.reason || "unknown").slice(0, 240),
        stripeDisputeStatus: String(dispute.status || "unknown"),
        outcome,
        status: TERMINAL_DISPUTE_OUTCOMES.has(outcome) ? "closed" : "open",
        evidenceDueAt: evidenceDueBy > 0 ?
          Timestamp.fromMillis(evidenceDueBy * 1000) : null,
        evidenceSubmissionCount: Math.max(0, Number(
            dispute.evidence_details &&
            dispute.evidence_details.submission_count || 0,
        )),
        fundsWithdrawn,
        fundsReinstated,
        lastStripeEvent: eventType,
        taxReviewRequired: outcome === "lost",
        updatedAt: FieldValue.serverTimestamp(),
        ...(previous.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),
      }, {merge: true});
      return {outcome};
    });
    const financialState = await db.runTransaction(async (transaction) => {
      const currentCase = await transaction.get(caseRef);
      const currentSale = await transaction.get(transactionRef);
      if (!currentSale.exists) return null;
      const latestOutcome = resolvedDisputeOutcome(
          currentCase.exists ? currentCase.data().outcome : disputeState.outcome,
          disputeState.outcome,
      );
      const currentSaleData = currentSale.data();
      const activeFinancialCaseId = String(
          currentSaleData.activeFinancialCaseId || "",
      );
      let activeFinancialCase = null;
      if (billingType !== "marketplace_fee_only" &&
          activeFinancialCaseId && activeFinancialCaseId !== caseId) {
        const activeCaseSnapshot = await transaction.get(
            db.collection("marketplace_financial_cases")
                .doc(activeFinancialCaseId),
        );
        activeFinancialCase = activeCaseSnapshot.exists ?
          activeCaseSnapshot.data() : null;
      }
      const previousDisputeHold = billingType === "marketplace_fee_only" ?
        Array.isArray(currentSaleData.activeMarketplaceFeeDisputeIds) &&
          currentSaleData.activeMarketplaceFeeDisputeIds.length > 0 ||
        Array.isArray(currentSaleData.lostMarketplaceFeeDisputeIds) &&
          currentSaleData.lostMarketplaceFeeDisputeIds.length > 0 ||
        ["open", "lost"].includes(
            String(currentSaleData.marketplaceFeeDisputeStatus || ""),
        ) :
        Array.isArray(currentSaleData.activeDisputeIds) &&
          currentSaleData.activeDisputeIds.length > 0 ||
        Array.isArray(currentSaleData.lostDisputeIds) &&
          currentSaleData.lostDisputeIds.length > 0 ||
        ["open", "lost"].includes(
            String(currentSaleData.disputeStatus || ""),
        );
      const pendingRefundCase = activeFinancialCase &&
        activeFinancialCase.type === "refund_request" &&
        (new Set([
          "requested",
          "blocked_seller_recovery",
          "refund_dispatching",
          "refund_pending",
          "refund_reconciliation_required",
          "refund_retry_required",
        ]).has(String(activeFinancialCase.status || "")) ||
        new Set([
          "reserved",
          "dispatching",
          "outcome_unknown",
          "pending",
        ]).has(String(activeFinancialCase.refundRequestState || "")));
      const refundHold = billingType === "marketplace_fee_only" ?
        Number(currentSaleData.marketplaceFeeRefundedMinor || 0) > 0 :
        Number(currentSaleData.refundedMinor || 0) > 0 ||
          pendingRefundCase ||
          new Set([
            "refund_pending",
            "refund_processing",
            "refund_requested",
          ]).has(String(currentSaleData.financialStatus || ""));
      const otherFinancialHold = currentSaleData.financialHold === true &&
        !previousDisputeHold && !refundHold;
      const disputeHold = latestOutcome === "open" || latestOutcome === "lost";
      const patch = financialMutationValues(
          currentSaleData,
          billingType === "marketplace_fee_only" ? {
            marketplaceFeeDisputeBillingType: billingType,
            marketplaceFeeDisputeStatus: latestOutcome,
          } : {
            disputeStatus: latestOutcome === "open" ? "open" : latestOutcome,
          },
          {hold: disputeHold || refundHold || otherFinancialHold},
      );
      transaction.set(transactionRef, {
        ...patch,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {
        outcome: latestOutcome,
        financialEpoch: Number(patch.financialEpoch || 0),
        otherFinancialHold,
        refundHold,
        refundFinancialStatus: refundHold ?
          String(currentSaleData.financialStatus || "refund_processing") : null,
      };
    });
    if (!financialState) return null;
    const outcome = financialState.outcome;

    if (billingType === "marketplace_fee_only") {
      const latest = (await transactionRef.get()).data() || sale;
      const exposure = await exposureSnapshot(
          transactionId,
          latest,
          billingType,
      );
      const fullRefund = exposure.chargeAmount > 0 &&
        exposure.refundedMinor >= exposure.chargeAmount;
      const partialRefund = exposure.refundedMinor > 0 && !fullRefund;
      const feeStatus = exposure.lostDisputeIds.length > 0 ? "charged_back" :
        exposure.activeDisputeIds.length > 0 ? "disputed" :
          fullRefund ? "refunded" : partialRefund ?
            "partially_refunded" : "collected";
      const financialLabel = exposure.lostDisputeIds.length > 0 ?
        "charged_back" : exposure.activeDisputeIds.length > 0 ?
          "disputed" : fullRefund ? "refunded" : partialRefund ?
            "partially_refunded" : "settled";
      if (typeof options.beforeFeeDisputeFinalization === "function") {
        await options.beforeFeeDisputeFinalization({
          disputeId,
          outcome,
          financialEpoch: financialState.financialEpoch,
          exposure,
        });
      }
      const applied = await db.runTransaction(async (transaction) => {
        const current = await transaction.get(transactionRef);
        if (!current.exists ||
            Number(current.data().financialEpoch || 0) !==
              financialState.financialEpoch) return false;
        transaction.set(transactionRef, {
          marketplaceFeeStatus: feeStatus,
          marketplaceFeeFinancialStatus: financialLabel,
          marketplaceFeeDisputeStatus:
            exposure.activeDisputeIds.length > 0 ? "open" :
              exposure.lostDisputeIds.length > 0 ? "lost" : outcome,
          activeMarketplaceFeeDisputeIds: exposure.activeDisputeIds,
          lostMarketplaceFeeDisputeIds: exposure.lostDisputeIds,
          activeDisputeIds: exposure.activeDisputeIds,
          lostDisputeIds: exposure.lostDisputeIds,
          activeDisputeId: exposure.activeDisputeIds[0] || null,
          financialHold: financialState.otherFinancialHold ||
            exposure.refundedMinor > 0 ||
            exposure.activeDisputeIds.length > 0 ||
            exposure.lostDisputeIds.length > 0,
          taxReviewRequired: exposure.lostDisputeIds.length > 0,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return true;
      });
      if (applied) {
        await updateAffiliateExposureAtEpoch({
          transactionId,
          customerExposureMinor: exposure.customerExposureMinor,
          reason: `marketplace_fee_${financialLabel}`,
          expectedFinancialEpoch: financialState.financialEpoch,
          billingType: "marketplace_fee_only",
        });
      }
      await createFinancialEvent({
        transactionId,
        sale,
        caseId,
        type: eventType,
        values: {
          billingType,
          stripeDisputeId: disputeId,
          disputeStatus: String(dispute.status || "unknown"),
          outcome,
          amountMinor: Math.max(0, Number(dispute.amount || 0)),
        },
      });
      return {transactionId, caseId, outcome, billingType};
    }

    const protectedSaleSnapshot = await transactionRef.get();
    const protectedSale = protectedSaleSnapshot.exists ?
      protectedSaleSnapshot.data() : sale;
    const exposure = await exposureSnapshot(transactionId, protectedSale);
    const readiness = await loadReadiness();
    let rebalance = {
      outstandingRecoveryMinor:
        Number(protectedSale.sellerRecoveryOutstandingMinor || 0),
      outstandingRestorationMinor:
        Number(protectedSale.sellerRestorationOutstandingMinor || 0),
    };
    if (readiness.disputeAutomationEnabled) {
      rebalance = await sellerFunds.rebalanceSellerFunds({
        transactionId,
        sale: protectedSale,
        caseId,
        customerExposureMinor: exposure.customerExposureMinor,
        reason: outcome === "won" || outcome === "warning_closed" ?
          "dispute_closed_restoration" : "stripe_dispute",
        allowRestoration: !financialState.refundHold &&
          (outcome === "won" || outcome === "warning_closed"),
        expectedFinancialEpoch: financialState.financialEpoch,
      });
    } else if (outcome === "open" || outcome === "lost") {
      const originalSeller = Number(protectedSale.originalSellerProceedsMinor ||
        protectedSale.sellerProceedsMinor || 0);
      const targetRecovery = proportionalRecoveryTarget({
        transferAmountMinor: Math.max(0, originalSeller),
        originalChargeAmountMinor:
          Math.max(1, Number(protectedSale.buyerChargedMinor || 1)),
        customerExposureMinor: exposure.customerExposureMinor,
      });
      const actualRecovery = Math.max(
          0,
          originalSeller - Number(
              protectedSale.sellerNetTransferredMinor || originalSeller,
          ),
      );
      const outstanding = Math.max(0, targetRecovery - actualRecovery);
      await db.collection("marketplace_seller_recovery_obligations").doc(caseId).set({
        transactionId,
        caseId,
        sellerUid: String(protectedSale.sellerUid || ""),
        buyerUid: String(protectedSale.buyerUid || ""),
        currency: financialCurrency(protectedSale.currency),
        amountDueMinor: outstanding,
        reason: "dispute_manual_recovery_required",
        status: outstanding > 0 ? "open" : "resolved",
        updatedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      if (protectedSale.sellerUid) {
        await db.collection("payment_provider_accounts")
            .doc(String(protectedSale.sellerUid)).set({
          sellerPayoutHold: outstanding > 0,
          sellerPayoutHoldReason: outstanding > 0 ?
            "dispute_manual_recovery_required" : null,
          sellerPayoutHoldUpdatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
      rebalance.outstandingRecoveryMinor = outstanding;
    }

    const label = financialState.refundHold ?
      financialState.refundFinancialStatus : outcome === "lost" ?
        "charged_back" : outcome === "won" ? "dispute_won" :
          outcome === "warning_closed" ?
            "dispute_warning_closed" : "disputed";
    if (typeof options.beforeSaleDisputeFinalization === "function") {
      await options.beforeSaleDisputeFinalization({
        disputeId,
        outcome,
        financialEpoch: financialState.financialEpoch,
      });
    }
    const latestSale = (await transactionRef.get()).data() || sale;
    const finalExposure = await syncTransactionFinancialState({
      transactionId,
      sale: latestSale,
      label,
      expectedFinancialEpoch: financialState.financialEpoch,
    });
    if (finalExposure.applied) {
      await db.runTransaction(async (transaction) => {
        const current = await transaction.get(transactionRef);
        if (!current.exists ||
            Number(current.data().financialEpoch || 0) !==
              financialState.financialEpoch) return;
        transaction.set(transactionRef, {
          financialHold: rebalance.outstandingRecoveryMinor > 0 ||
            finalExposure.activeDisputeIds.length > 0 ||
            financialState.refundHold,
          sellerRecoveryOutstandingMinor:
            Math.max(0, Number(rebalance.outstandingRecoveryMinor || 0)),
          sellerRestorationOutstandingMinor:
            Math.max(0, Number(rebalance.outstandingRestorationMinor || 0)),
          taxReviewRequired: finalExposure.lostDisputeIds.length > 0,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      });
    }
    await createFinancialEvent({
      transactionId,
      sale,
      caseId,
      type: eventType,
      values: {
        stripeDisputeId: disputeId,
        disputeStatus: String(dispute.status || "unknown"),
        outcome,
        amountMinor: Math.max(0, Number(dispute.amount || 0)),
        sellerRecoveryOutstandingMinor:
          Math.max(0, Number(rebalance.outstandingRecoveryMinor || 0)),
        sellerRestorationOutstandingMinor:
          Math.max(0, Number(rebalance.outstandingRestorationMinor || 0)),
      },
    });
    return {transactionId, caseId, outcome};
  }

  async function retryMarketplaceSellerRecovery(request) {
    let administratorUid = null;
    try {
      administratorUid = requireAdministrator(request);
      await enforceUserRateLimit({db, admin, request, scope: "administration"});
      const readiness = await loadReadiness();
      requireResolutionReady(readiness);
      const caseId = cleanId(request.data && request.data.caseId, "caseId");
      const caseSnapshot = await db.collection("marketplace_financial_cases")
          .doc(caseId).get();
      if (!caseSnapshot.exists) throw new HttpsError("not-found", "Financial case not found.");
      const transactionId = String(caseSnapshot.data().transactionId || "");
      const transactionRef = db.collection("marketplace_transactions").doc(transactionId);
      const saleSnapshot = await transactionRef.get();
      if (!saleSnapshot.exists) throw new HttpsError("not-found", "Transaction not found.");
      const sale = saleSnapshot.data();
      const exposure = await exposureSnapshot(transactionId, sale);
      const rebalance = await sellerFunds.rebalanceSellerFunds({
        transactionId,
        sale,
        caseId,
        customerExposureMinor: exposure.customerExposureMinor,
        reason: "administrator_financial_rebalance",
        allowRestoration: true,
        expectedFinancialEpoch: Number(sale.financialEpoch || 0),
      });
      await db.collection("marketplace_financial_cases").doc(caseId).set({
        sellerRecoveryOutstandingMinor: rebalance.outstandingRecoveryMinor,
        sellerRestorationOutstandingMinor: rebalance.outstandingRestorationMinor,
        rebalancedByUid: administratorUid,
        rebalancedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {
        caseId,
        transactionId,
        sellerRecoveryOutstandingMinor: rebalance.outstandingRecoveryMinor,
        sellerRestorationOutstandingMinor: rebalance.outstandingRestorationMinor,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError ||
          error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Marketplace seller recovery retry failed", {
        administratorUid,
        error,
      });
      throw new HttpsError(
          "failed-precondition",
          "The seller financial balance could not be reconciled.",
      );
    }
  }

  return {
    cancelMarketplaceRefundRequest,
    executeMarketplaceRefund,
    exposureSnapshot,
    findTransactionForCharge,
    handleDisputeEvent,
    handleRefundStatusEvent,
    reconcileChargeRefund,
    requestMarketplaceRefund,
    retryMarketplaceSellerRecovery,
  };
}

module.exports = {
  MAX_REASON_LENGTH,
  TERMINAL_DISPUTE_OUTCOMES,
  adjustedAffiliateCommission,
  createMarketplaceFinancialResolution,
  disputeOutcome,
  financialChargeAmount,
  proportionalRecoveryTarget,
  refundStatusShouldApply,
  refundReasonCode,
  resolvedDisputeOutcome,
};
