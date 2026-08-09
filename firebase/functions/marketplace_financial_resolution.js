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

const MAX_REASON_LENGTH = 1600;
const TERMINAL_DISPUTE_OUTCOMES = new Set(["won", "lost", "warning_closed"]);

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

function isParticipant(sale, uid) {
  return Boolean(sale) &&
    [String(sale.buyerUid || ""), String(sale.sellerUid || "")].includes(uid);
}

function createMarketplaceFinancialResolution(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;
  const sellerFunds = createMarketplaceSellerFunds(admin);

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

  async function exposureSnapshot(transactionId, sale) {
    const chargeAmount = Math.max(0, Number(sale.buyerChargedMinor || 0));
    const refundedMinor = Math.max(0, Number(sale.refundedMinor || 0));
    const cases = await disputeCases(transactionId);
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

  async function updateAffiliateExposure({
    transactionId,
    sale,
    customerExposureMinor,
    reason,
  }) {
    const ledgerRef = db.collection("affiliate_commission_ledger")
        .doc(`marketplace_${transactionId}`);
    const ledgerSnapshot = await ledgerRef.get();
    if (!ledgerSnapshot.exists) return;
    const ledger = ledgerSnapshot.data();
    const originalCommission = Number(ledger.commissionMinor || 0);
    const chargeAmount = Number(sale.buyerChargedMinor || 0);
    if (!Number.isSafeInteger(originalCommission) || originalCommission <= 0 ||
        !Number.isSafeInteger(chargeAmount) || chargeAmount <= 0) return;
    const adjusted = adjustedAffiliateCommission({
      commissionMinor: originalCommission,
      originalChargeAmountMinor: chargeAmount,
      customerExposureMinor,
    });
    const lost = originalCommission - adjusted;
    const status = String(ledger.status || "");
    if (status === "paid") {
      const referrerUid = String(ledger.referrerUid || "");
      if (!referrerUid) return;
      const obligationRef = db.collection("affiliate_recovery_obligations")
          .doc(`marketplace_${transactionId}_${referrerUid}`);
      const existing = await obligationRef.get();
      const recovered = Math.max(0, Number(
          existing.exists ? existing.data().recoveredMinor || 0 : 0,
      ));
      const amountDue = Math.max(0, lost - recovered);
      await obligationRef.set({
        type: "marketplace_commission_recovery",
        transactionId,
        ledgerId: ledgerRef.id,
        referrerUid,
        currency: String(ledger.currency || sale.currency || "CAD").toUpperCase(),
        targetRecoveryMinor: lost,
        recoveredMinor: recovered,
        amountDueMinor: amountDue,
        reason,
        status: amountDue > 0 ? "open" : "resolved",
        updatedAt: FieldValue.serverTimestamp(),
        ...(amountDue === 0 ? {resolvedAt: FieldValue.serverTimestamp()} : {}),
      }, {merge: true});
      const open = await db.collection("affiliate_recovery_obligations")
          .where("referrerUid", "==", referrerUid)
          .where("status", "==", "open")
          .limit(1)
          .get();
      await db.collection("payment_provider_accounts").doc(referrerUid).set({
        affiliatePayoutHold: amountDue > 0 || !open.empty,
        affiliatePayoutHoldReason: amountDue > 0 || !open.empty ? reason : null,
        affiliatePayoutHoldUpdatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return;
    }

    let nextStatus = status;
    const changes = {
      adjustedCommissionMinor: adjusted,
      financialExposureMinor: customerExposureMinor,
      financialAdjustmentReason: reason,
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
    await ledgerRef.set(changes, {merge: true});
  }

  async function syncTransactionFinancialState({transactionId, sale, label}) {
    const exposure = await exposureSnapshot(transactionId, sale);
    const fullRefund = exposure.chargeAmount > 0 &&
      exposure.refundedMinor >= exposure.chargeAmount;
    const partialRefund = exposure.refundedMinor > 0 && !fullRefund;
    let financialStatus = label || "settled";
    if (exposure.lostDisputeIds.length > 0) financialStatus = "charged_back";
    else if (exposure.activeDisputeIds.length > 0) financialStatus = "disputed";
    else if (fullRefund) financialStatus = "refunded";
    else if (partialRefund) financialStatus = "partially_refunded";
    await db.collection("marketplace_transactions").doc(transactionId).set({
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
    await updateAffiliateExposure({
      transactionId,
      sale: {...sale, refundedMinor: exposure.refundedMinor},
      customerExposureMinor: exposure.customerExposureMinor,
      reason: financialStatus,
    });
    return exposure;
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
      await caseRef.create({
        type: "refund_request",
        transactionId,
        listingId: String(sale.listingId || ""),
        buyerUid: String(sale.buyerUid || ""),
        sellerUid: String(sale.sellerUid || ""),
        requestedByUid: uid,
        requestedRefundMinor: requestedAmount,
        currency: String(sale.currency || "CAD").toUpperCase(),
        reason,
        status: "requested",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      await transactionRef.set({
        financialStatus: "refund_requested",
        activeFinancialCaseId: requestId,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
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
      const snapshot = await caseRef.get();
      if (!snapshot.exists) throw new HttpsError("not-found", "Refund request not found.");
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
      await caseRef.update({
        status: "cancelled",
        cancelledByUid: uid,
        cancelledAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      const transactionId = String(financialCase.transactionId || "");
      if (transactionId) {
        await db.collection("marketplace_transactions").doc(transactionId).set({
          activeFinancialCaseId: null,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
      return {caseId, status: "cancelled"};
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      throw new HttpsError("internal", "The refund request could not be cancelled.");
    }
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
      if (!["requested", "blocked_seller_recovery", "refund_retry_required"]
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
      const chargeId = String(sale.stripeChargeId || "");
      const charge = await stripeFinancialRequest({
        secretKey: stripeSecretKey.value(),
        path: `/v1/charges/${encodeURIComponent(chargeId)}`,
        method: "GET",
      });
      const chargeAmount = Number(charge.amount || 0);
      const alreadyRefunded = Number(charge.amount_refunded || 0);
      const remaining = Math.max(0, chargeAmount - alreadyRefunded);
      const requested = Number(financialCase.requestedRefundMinor || 0);
      if (!Number.isSafeInteger(requested) || requested <= 0 || requested > remaining) {
        throw new HttpsError(
            "failed-precondition",
            "The requested refund no longer matches Stripe's refundable balance.",
        );
      }
      const projectedRefunded = alreadyRefunded + requested;
      const projectedExposure = Math.min(
          chargeAmount,
          projectedRefunded + currentExposure.disputeExposureMinor,
      );
      const recovery = await sellerFunds.rebalanceSellerFunds({
        transactionId,
        sale,
        caseId,
        customerExposureMinor: projectedExposure,
        reason: "approved_refund",
        allowRestoration: false,
      });
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
      let refund;
      try {
        refund = await stripeFinancialRequest({
          secretKey: stripeSecretKey.value(),
          path: "/v1/refunds",
          idempotencyKey: `pipebuyer-refund-${caseId}`,
          fields: {
            charge: chargeId,
            amount: requested,
            reason: refundReasonCode(
                request.data && request.data.refundReasonCode,
            ),
            "metadata[pipeBuyerTransactionId]": transactionId,
            "metadata[pipeBuyerFinancialCaseId]": caseId,
            "metadata[approvedByUid]": administratorUid,
          },
        });
      } catch (error) {
        await caseRef.set({
          status: "refund_retry_required",
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
        stripeRefundId: String(refund.id || ""),
        approvedByUid: administratorUid,
        approvedAt: FieldValue.serverTimestamp(),
        sellerRecoveryOutstandingMinor: recovery.outstandingRecoveryMinor,
        platformFundedOverrideUsed:
          allowPlatformFunding && recovery.outstandingRecoveryMinor > 0,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      if (refundStatus === "succeeded") {
        await transactionRef.set({
          refundedMinor: projectedRefunded,
          paymentProviderStatus: projectedRefunded >= chargeAmount ?
            "refunded" : "partially_refunded",
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        const updatedSale = {...sale, refundedMinor: projectedRefunded};
        await syncTransactionFinancialState({
          transactionId,
          sale: updatedSale,
        });
      } else {
        await transactionRef.set({
          financialStatus: "refund_pending",
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
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
    const refundedMinor = Math.max(0, Number(charge.amount_refunded || 0));
    if (billingType === "marketplace_fee_only") {
      await transactionRef.set({
        marketplaceFeeStatus: charge.refunded ? "refunded" : "partially_refunded",
        marketplaceFeeRefundedMinor: refundedMinor,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {transactionId, billingType};
    }
    const chargeAmount = Math.max(0, Number(charge.amount || sale.buyerChargedMinor || 0));
    if (chargeAmount <= 0 || refundedMinor <= 0) return {transactionId, billingType};
    await transactionRef.set({
      refundedMinor,
      paymentProviderStatus: refundedMinor >= chargeAmount ?
        "refunded" : "partially_refunded",
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    const updatedSale = {...sale, refundedMinor};
    const exposure = await exposureSnapshot(transactionId, updatedSale);
    const caseId = `stripe_refund_${chargeId}_${refundedMinor}`;
    const recovery = await sellerFunds.rebalanceSellerFunds({
      transactionId,
      sale: updatedSale,
      caseId,
      customerExposureMinor: exposure.customerExposureMinor,
      reason: "stripe_refund_reconciliation",
      allowRestoration: false,
    });
    await db.collection("marketplace_financial_cases").doc(caseId).set({
      type: "stripe_refund_reconciliation",
      transactionId,
      listingId: String(sale.listingId || ""),
      buyerUid: String(sale.buyerUid || ""),
      sellerUid: String(sale.sellerUid || ""),
      currency: String(sale.currency || "CAD").toUpperCase(),
      refundedMinor,
      status: recovery.outstandingRecoveryMinor > 0 ?
        "seller_recovery_required" : "completed",
      sellerRecoveryOutstandingMinor: recovery.outstandingRecoveryMinor,
      updatedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    await syncTransactionFinancialState({transactionId, sale: updatedSale});
    return {transactionId, billingType, caseId};
  }

  async function handleRefundStatusEvent(refund, eventType) {
    const caseId = String(
        refund && refund.metadata && refund.metadata.pipeBuyerFinancialCaseId || "",
    );
    if (!caseId) return null;
    const caseRef = db.collection("marketplace_financial_cases").doc(caseId);
    const caseSnapshot = await caseRef.get();
    if (!caseSnapshot.exists) return null;
    const financialCase = caseSnapshot.data();
    const transactionId = String(financialCase.transactionId || "");
    const status = String(refund.status || "unknown");
    await caseRef.set({
      stripeRefundId: String(refund.id || ""),
      refundStatus: status,
      lastStripeRefundEvent: eventType,
      ...(status === "failed" ? {status: "refund_retry_required"} : {}),
      ...(status === "succeeded" ? {status: "completed"} : {}),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    if (status === "failed" && transactionId) {
      const transactionRef = db.collection("marketplace_transactions").doc(transactionId);
      const saleSnapshot = await transactionRef.get();
      if (saleSnapshot.exists) {
        const sale = saleSnapshot.data();
        const exposure = await exposureSnapshot(transactionId, sale);
        await sellerFunds.rebalanceSellerFunds({
          transactionId,
          sale,
          caseId,
          customerExposureMinor: exposure.customerExposureMinor,
          reason: "failed_refund_restoration",
          allowRestoration: true,
        });
        await syncTransactionFinancialState({transactionId, sale});
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
    if (!match || match.billingType !== "marketplace_sale") return null;
    const {id: transactionId, ref: transactionRef, sale} = match;
    const outcome = disputeOutcome(dispute.status);
    const caseId = `dispute_${disputeId}`;
    const caseRef = db.collection("marketplace_financial_cases").doc(caseId);
    const previous = await caseRef.get();
    const evidenceDueBy = Number(
        dispute.evidence_details && dispute.evidence_details.due_by || 0,
    );
    const current = previous.exists ? previous.data() : {};
    const fundsWithdrawn = current.fundsWithdrawn === true ||
      eventType === "charge.dispute.funds_withdrawn";
    const fundsReinstated = current.fundsReinstated === true ||
      eventType === "charge.dispute.funds_reinstated";
    await caseRef.set({
      type: "stripe_dispute",
      transactionId,
      listingId: String(sale.listingId || ""),
      buyerUid: String(sale.buyerUid || ""),
      sellerUid: String(sale.sellerUid || ""),
      currency: String(dispute.currency || sale.currency || "CAD").toUpperCase(),
      stripeDisputeId: disputeId,
      stripeChargeId: chargeId,
      disputeAmountMinor: Math.max(0, Number(dispute.amount || 0)),
      disputeReason: String(dispute.reason || "unknown").slice(0, 240),
      stripeDisputeStatus: String(dispute.status || "unknown"),
      outcome,
      status: TERMINAL_DISPUTE_OUTCOMES.has(outcome) ? "closed" : "open",
      evidenceDueAt: evidenceDueBy > 0 ?
        Timestamp.fromMillis(evidenceDueBy * 1000) : null,
      evidenceSubmissionCount: Math.max(0, Number(
          dispute.evidence_details && dispute.evidence_details.submission_count || 0,
      )),
      fundsWithdrawn,
      fundsReinstated,
      lastStripeEvent: eventType,
      taxReviewRequired: outcome === "lost",
      updatedAt: FieldValue.serverTimestamp(),
      ...(previous.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),
    }, {merge: true});

    const exposure = await exposureSnapshot(transactionId, sale);
    const readiness = await loadReadiness();
    let rebalance = {
      outstandingRecoveryMinor: Number(sale.sellerRecoveryOutstandingMinor || 0),
      outstandingRestorationMinor: Number(sale.sellerRestorationOutstandingMinor || 0),
    };
    if (readiness.disputeAutomationEnabled) {
      rebalance = await sellerFunds.rebalanceSellerFunds({
        transactionId,
        sale,
        caseId,
        customerExposureMinor: exposure.customerExposureMinor,
        reason: outcome === "won" || outcome === "warning_closed" ?
          "dispute_closed_restoration" : "stripe_dispute",
        allowRestoration: outcome === "won" || outcome === "warning_closed",
      });
    } else if (outcome === "open" || outcome === "lost") {
      const originalSeller = Number(sale.originalSellerProceedsMinor ||
        sale.sellerProceedsMinor || 0);
      const targetRecovery = proportionalRecoveryTarget({
        transferAmountMinor: Math.max(0, originalSeller),
        originalChargeAmountMinor: Math.max(1, Number(sale.buyerChargedMinor || 1)),
        customerExposureMinor: exposure.customerExposureMinor,
      });
      const actualRecovery = Math.max(
          0,
          originalSeller - Number(sale.sellerNetTransferredMinor || originalSeller),
      );
      const outstanding = Math.max(0, targetRecovery - actualRecovery);
      await db.collection("marketplace_seller_recovery_obligations").doc(caseId).set({
        transactionId,
        caseId,
        sellerUid: String(sale.sellerUid || ""),
        buyerUid: String(sale.buyerUid || ""),
        currency: String(sale.currency || "CAD").toUpperCase(),
        amountDueMinor: outstanding,
        reason: "dispute_manual_recovery_required",
        status: outstanding > 0 ? "open" : "resolved",
        updatedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      if (sale.sellerUid) {
        await db.collection("payment_provider_accounts").doc(String(sale.sellerUid)).set({
          sellerPayoutHold: outstanding > 0,
          sellerPayoutHoldReason: outstanding > 0 ?
            "dispute_manual_recovery_required" : null,
          sellerPayoutHoldUpdatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
      rebalance.outstandingRecoveryMinor = outstanding;
    }

    const label = outcome === "lost" ? "charged_back" :
      outcome === "won" ? "dispute_won" :
      outcome === "warning_closed" ? "dispute_warning_closed" : "disputed";
    const latestSale = (await transactionRef.get()).data() || sale;
    const finalExposure = await syncTransactionFinancialState({
      transactionId,
      sale: latestSale,
      label,
    });
    await transactionRef.set({
      financialHold: rebalance.outstandingRecoveryMinor > 0 ||
        finalExposure.activeDisputeIds.length > 0,
      sellerRecoveryOutstandingMinor:
        Math.max(0, Number(rebalance.outstandingRecoveryMinor || 0)),
      sellerRestorationOutstandingMinor:
        Math.max(0, Number(rebalance.outstandingRestorationMinor || 0)),
      taxReviewRequired: finalExposure.lostDisputeIds.length > 0,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
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
  proportionalRecoveryTarget,
  refundReasonCode,
};
