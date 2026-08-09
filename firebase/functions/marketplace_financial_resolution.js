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
const {stripeMarketplaceConfig} = require("./stripe_marketplace_config");
const {stripeSecretKey} = require("./stripe_marketplace_commands");

const MAX_REASON_LENGTH = 1600;
const OPEN_DISPUTE_STATUSES = new Set([
  "warning_needs_response",
  "warning_under_review",
  "needs_response",
  "under_review",
]);

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

function refundReasonCode(value) {
  const reason = String(value || "requested_by_customer").trim();
  return ["duplicate", "fraudulent", "requested_by_customer"].includes(reason) ?
    reason : "requested_by_customer";
}

function positiveMinorAmount(value, field) {
  const amount = Number(value);
  if (!Number.isSafeInteger(amount) || amount <= 0) {
    throw new HttpsError("invalid-argument", `${field} must be a positive integer.`);
  }
  return amount;
}

function proportionalRecoveryTarget({
  transferAmountMinor,
  originalChargeAmountMinor,
  customerExposureMinor,
}) {
  const transfer = Number(transferAmountMinor);
  const charge = Number(originalChargeAmountMinor);
  const exposure = Number(customerExposureMinor);
  if (!Number.isSafeInteger(transfer) || transfer < 0 ||
      !Number.isSafeInteger(charge) || charge <= 0 ||
      !Number.isSafeInteger(exposure) || exposure < 0) {
    throw new TypeError("Financial recovery amounts must use valid minor units.");
  }
  if (exposure >= charge) return transfer;
  return Math.floor(transfer * exposure / charge);
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

function isParticipant(sale, uid) {
  return Boolean(sale) &&
    (String(sale.buyerUid || "") === uid || String(sale.sellerUid || "") === uid);
}

function stripeChargeIdFromObject(value) {
  if (typeof value === "string") return value;
  return String(value && value.id || "");
}

async function stripeRequest({
  secretKey,
  path,
  fields,
  method = "POST",
  idempotencyKey,
}) {
  const url = new URL(`https://api.stripe.com${path}`);
  const form = new URLSearchParams();
  for (const [key, value] of Object.entries(fields || {})) {
    if (value == null) continue;
    if (method === "GET") {
      url.searchParams.append(key, String(value));
    } else if (Array.isArray(value)) {
      for (const item of value) form.append(`${key}[]`, String(item));
    } else {
      form.append(key, String(value));
    }
  }
  const response = await fetch(url, {
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
    const error = new Error("Stripe financial operation failed.");
    error.stripeStatus = response.status;
    error.stripeCode = String(
        payload && payload.error &&
        (payload.error.code || payload.error.type) || "provider_error",
    ).slice(0, 120);
    throw error;
  }
  return payload || {};
}

function createMarketplaceFinancialResolution(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;

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

  function requireFinancialResolutionReady(readiness) {
    if (!readiness.financialResolutionEnabled ||
        !readiness.webhookVerified ||
        !readiness.reconciliationReady ||
        !["sandbox", "production"].includes(readiness.stripeMode)) {
      throw new HttpsError(
          "failed-precondition",
          "Marketplace refund execution is not enabled yet.",
      );
    }
  }

  async function findTransactionForCharge(chargeId) {
    if (!String(chargeId || "").startsWith("ch_")) return null;
    const primary = await db.collection("marketplace_transactions")
        .where("stripeChargeId", "==", chargeId)
        .limit(2)
        .get();
    if (!primary.empty) {
      const document = primary.docs[0];
      return {
        id: document.id,
        ref: document.ref,
        sale: document.data(),
        billingType: "marketplace_sale",
      };
    }
    const feeOnly = await db.collection("marketplace_transactions")
        .where("stripeMarketplaceFeeChargeId", "==", chargeId)
        .limit(2)
        .get();
    if (feeOnly.empty) return null;
    const document = feeOnly.docs[0];
    return {
      id: document.id,
      ref: document.ref,
      sale: document.data(),
      billingType: "marketplace_fee_only",
    };
  }

  async function createFinancialEvent({
    transactionId,
    sale,
    caseId,
    type,
    values,
  }) {
    const eventRef = db.collection("marketplace_financial_events").doc();
    await eventRef.set({
      transactionId,
      caseId: caseId || null,
      buyerUid: String(sale.buyerUid || ""),
      sellerUid: String(sale.sellerUid || ""),
      type,
      ...(values || {}),
      createdAt: FieldValue.serverTimestamp(),
    });
    return eventRef.id;
  }

  async function setSellerRecoveryObligation({
    transactionId,
    sale,
    caseId,
    amountDueMinor,
    currency,
    reason,
  }) {
    const amount = Math.max(0, Number(amountDueMinor || 0));
    const obligationRef = db.collection("marketplace_seller_recovery_obligations")
        .doc(caseId);
    await obligationRef.set({
      transactionId,
      caseId,
      sellerUid: String(sale.sellerUid || ""),
      buyerUid: String(sale.buyerUid || ""),
      currency,
      amountDueMinor: amount,
      reason,
      status: amount > 0 ? "open" : "resolved",
      updatedAt: FieldValue.serverTimestamp(),
      ...(amount > 0 ? {} : {resolvedAt: FieldValue.serverTimestamp()}),
    }, {merge: true});
    if (sale.sellerUid) {
      await db.collection("payment_provider_accounts")
          .doc(String(sale.sellerUid)).set({
            sellerPayoutHold: amount > 0,
            sellerPayoutHoldReason: amount > 0 ? reason : null,
            sellerPayoutHoldUpdatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
    }
  }

  async function maybeClearSellerHold(sellerUid) {
    if (!sellerUid) return;
    const open = await db.collection("marketplace_seller_recovery_obligations")
        .where("sellerUid", "==", sellerUid)
        .where("status", "==", "open")
        .limit(1)
        .get();
    if (!open.empty) return;
    await db.collection("payment_provider_accounts").doc(sellerUid).set({
      sellerPayoutHold: false,
      sellerPayoutHoldReason: null,
      sellerPayoutHoldUpdatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  }

  async function syncAffiliateExposure({
    transactionId,
    sale,
    customerExposureMinor,
    caseId,
    reason,
  }) {
    const ledgerRef = db.collection("affiliate_commission_ledger")
        .doc(`marketplace_${transactionId}`);
    const ledgerSnapshot = await ledgerRef.get();
    if (!ledgerSnapshot.exists) return;
    const ledger = ledgerSnapshot.data();
    const commissionMinor = Number(ledger.commissionMinor || 0);
    const chargeAmountMinor = Number(sale.buyerChargedMinor || 0);
    if (!Number.isSafeInteger(commissionMinor) || commissionMinor <= 0 ||
        !Number.isSafeInteger(chargeAmountMinor) || chargeAmountMinor <= 0) {
      return;
    }
    const adjustedMinor = adjustedAffiliateCommission({
      commissionMinor,
      originalChargeAmountMinor: chargeAmountMinor,
      customerExposureMinor,
    });
    const lostMinor = commissionMinor - adjustedMinor;
    if (String(ledger.status || "") === "paid") {
      const obligationRef = db.collection("affiliate_recovery_obligations")
          .doc(`${caseId}_${ledgerRef.id}`);
      await obligationRef.set({
        caseId,
        transactionId,
        ledgerId: ledgerRef.id,
        referrerUid: String(ledger.referrerUid || ""),
        currency: String(ledger.currency || sale.currency || "CAD"),
        amountDueMinor: lostMinor,
        reason,
        status: lostMinor > 0 ? "open" : "resolved",
        updatedAt: FieldValue.serverTimestamp(),
        ...(lostMinor > 0 ? {} : {resolvedAt: FieldValue.serverTimestamp()}),
      }, {merge: true});
      if (ledger.referrerUid) {
        await db.collection("payment_provider_accounts")
            .doc(String(ledger.referrerUid)).set({
              affiliatePayoutHold: lostMinor > 0,
              affiliatePayoutHoldReason: lostMinor > 0 ? reason : null,
              affiliatePayoutHoldUpdatedAt: FieldValue.serverTimestamp(),
            }, {merge: true});
      }
      return;
    }
    const nextStatus = adjustedMinor === 0 ?
      "void_financial_event" : String(ledger.status || "pending_refund_window");
    await ledgerRef.set({
      adjustedCommissionMinor: adjustedMinor,
      financialExposureMinor: customerExposureMinor,
      financialAdjustmentReason: reason,
      status: nextStatus,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  }

  async function reverseSellerTransferToExposure({
    transactionId,
    sale,
    caseId,
    customerExposureMinor,
    reason,
  }) {
    const transferId = String(sale.stripeSellerTransferId || "");
    const chargeAmountMinor = Number(sale.buyerChargedMinor || 0);
    if (!transferId.startsWith("tr_") ||
        !Number.isSafeInteger(chargeAmountMinor) || chargeAmountMinor <= 0) {
      return {
        attempted: false,
        recoveredMinor: 0,
        outstandingMinor: 0,
        transferReversalId: null,
      };
    }
    const transfer = await stripeRequest({
      secretKey: stripeSecretKey.value(),
      path: `/v1/transfers/${encodeURIComponent(transferId)}`,
      method: "GET",
    });
    const transferAmount = Number(transfer.amount || 0);
    const alreadyReversed = Number(transfer.amount_reversed || 0);
    const target = proportionalRecoveryTarget({
      transferAmountMinor: transferAmount,
      originalChargeAmountMinor: chargeAmountMinor,
      customerExposureMinor,
    });
    const delta = Math.max(0, target - alreadyReversed);
    if (delta === 0) {
      await setSellerRecoveryObligation({
        transactionId,
        sale,
        caseId,
        amountDueMinor: 0,
        currency: String(sale.currency || "CAD").toUpperCase(),
        reason,
      });
      await maybeClearSellerHold(String(sale.sellerUid || ""));
      return {
        attempted: false,
        recoveredMinor: alreadyReversed,
        outstandingMinor: 0,
        transferReversalId: null,
      };
    }
    try {
      const reversal = await stripeRequest({
        secretKey: stripeSecretKey.value(),
        path: `/v1/transfers/${encodeURIComponent(transferId)}/reversals`,
        idempotencyKey: `pipebuyer-recovery-${caseId}-${target}`,
        fields: {
          amount: delta,
          "metadata[pipeBuyerTransactionId]": transactionId,
          "metadata[pipeBuyerFinancialCaseId]": caseId,
          "metadata[reason]": reason.slice(0, 200),
        },
      });
      await setSellerRecoveryObligation({
        transactionId,
        sale,
        caseId,
        amountDueMinor: 0,
        currency: String(sale.currency || "CAD").toUpperCase(),
        reason,
      });
      await maybeClearSellerHold(String(sale.sellerUid || ""));
      return {
        attempted: true,
        recoveredMinor: alreadyReversed + delta,
        outstandingMinor: 0,
        transferReversalId: String(reversal.id || ""),
      };
    } catch (error) {
      await setSellerRecoveryObligation({
        transactionId,
        sale,
        caseId,
        amountDueMinor: delta,
        currency: String(sale.currency || "CAD").toUpperCase(),
        reason,
      });
      return {
        attempted: true,
        recoveredMinor: alreadyReversed,
        outstandingMinor: delta,
        transferReversalId: null,
        stripeCode: String(error.stripeCode || "provider_error"),
      };
    }
  }

  async function requestMarketplaceRefund(request) {
    try {
      const uid = requireAuth(request);
      await enforceUserRateLimit({db, admin, request, scope: "offers"});
      const transactionId = cleanId(
          request.data && request.data.transactionId,
          "transactionId",
      );
      const requestId = cleanId(
          request.data && request.data.requestId,
          "requestId",
      );
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
            "Only this transaction's buyer or seller can request a refund.",
        );
      }
      if (!String(sale.stripeChargeId || "").startsWith("ch_")) {
        throw new HttpsError(
            "failed-precondition",
            "This transaction was not paid through Pipe Buyer Stripe Checkout.",
        );
      }
      if (OPEN_DISPUTE_STATUSES.has(String(sale.disputeStatus || ""))) {
        throw new HttpsError(
            "failed-precondition",
            "A Stripe dispute is already open for this transaction.",
        );
      }
      const charged = Number(sale.buyerChargedMinor || 0);
      const refunded = Number(sale.refundedMinor || 0);
      const remaining = Math.max(0, charged - refunded);
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
      const result = {
        caseId: requestId,
        transactionId,
        requestedRefundMinor: requestedAmount,
        currency: String(sale.currency || "CAD").toUpperCase(),
        status: "requested",
      };
      await db.runTransaction(async (transaction) => {
        const existing = await transaction.get(caseRef);
        if (existing.exists) {
          const data = existing.data();
          if (data.transactionId !== transactionId || data.requestedByUid !== uid) {
            throw new HttpsError("already-exists", "This request ID is already in use.");
          }
          return;
        }
        transaction.create(caseRef, {
          type: "refund_request",
          transactionId,
          listingId: String(sale.listingId || ""),
          buyerUid: String(sale.buyerUid || ""),
          sellerUid: String(sale.sellerUid || ""),
          requestedByUid: uid,
          requestedRefundMinor: requestedAmount,
          currency: result.currency,
          reason,
          status: "requested",
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.set(transactionRef, {
          financialStatus: "refund_requested",
          activeFinancialCaseId: requestId,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      });
      await createFinancialEvent({
        transactionId,
        sale,
        caseId: requestId,
        type: "refund_requested",
        values: {
          actorUid: uid,
          amountMinor: requestedAmount,
          currency: result.currency,
        },
      });
      return result;
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
      if (!snapshot.exists) {
        throw new HttpsError("not-found", "The refund request was not found.");
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
      await caseRef.update({
        status: "cancelled",
        cancelledByUid: uid,
        cancelledAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
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

  async function executeMarketplaceRefund(request) {
    let administratorUid;
    try {
      administratorUid = requireAdministrator(request);
      await enforceUserRateLimit({
        db,
        admin,
        request,
        scope: "administration",
      });
      const readiness = await loadReadiness();
      requireFinancialResolutionReady(readiness);
      const caseId = cleanId(request.data && request.data.caseId, "caseId");
      const allowPlatformFunding =
        request.data && request.data.allowPlatformFunding === true;
      if (allowPlatformFunding && !readiness.platformFundedRefundOverrideEnabled) {
        throw new HttpsError(
            "failed-precondition",
            "Platform-funded refund overrides are not enabled.",
        );
      }
      const caseRef = db.collection("marketplace_financial_cases").doc(caseId);
      const caseSnapshot = await caseRef.get();
      if (!caseSnapshot.exists) {
        throw new HttpsError("not-found", "The refund request was not found.");
      }
      const financialCase = caseSnapshot.data();
      if (financialCase.type !== "refund_request") {
        throw new HttpsError("failed-precondition", "This is not a refund request.");
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
      const transactionRef = db.collection("marketplace_transactions")
          .doc(transactionId);
      const saleSnapshot = await transactionRef.get();
      if (!saleSnapshot.exists) {
        throw new HttpsError("not-found", "The marketplace transaction was not found.");
      }
      const sale = saleSnapshot.data();
      if (OPEN_DISPUTE_STATUSES.has(String(sale.disputeStatus || ""))) {
        throw new HttpsError(
            "failed-precondition",
            "Do not refund while the cardholder dispute is open.",
        );
      }
      const chargeId = String(sale.stripeChargeId || "");
      if (!chargeId.startsWith("ch_")) {
        throw new HttpsError("failed-precondition", "The Stripe charge is unavailable.");
      }
      const charge = await stripeRequest({
        secretKey: stripeSecretKey.value(),
        path: `/v1/charges/${encodeURIComponent(chargeId)}`,
        method: "GET",
      });
      const chargeAmount = Number(charge.amount || 0);
      const amountRefunded = Number(charge.amount_refunded || 0);
      const remaining = Math.max(0, chargeAmount - amountRefunded);
      const requested = Number(financialCase.requestedRefundMinor || 0);
      if (!Number.isSafeInteger(requested) || requested <= 0 || requested > remaining) {
        throw new HttpsError(
            "failed-precondition",
            "The requested refund no longer matches Stripe's refundable balance.",
        );
      }
      const projectedRefunded = amountRefunded + requested;
      const recovery = await reverseSellerTransferToExposure({
        transactionId,
        sale,
        caseId,
        customerExposureMinor: projectedRefunded,
        reason: "approved_refund",
      });
      if (recovery.outstandingMinor > 0 && !allowPlatformFunding) {
        await caseRef.set({
          status: "blocked_seller_recovery",
          sellerRecoveryOutstandingMinor: recovery.outstandingMinor,
          sellerRecoveryStripeCode: recovery.stripeCode || null,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        throw new HttpsError(
            "failed-precondition",
            "Seller proceeds could not be recovered. The refund remains blocked for financial review.",
        );
      }
      let refund;
      try {
        refund = await stripeRequest({
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
          sellerRecoveryCompletedBeforeRefund: recovery.outstandingMinor === 0,
          sellerRecoveredMinor: recovery.recoveredMinor,
          refundProviderErrorCode: String(error.stripeCode || "provider_error"),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        throw error;
      }
      const refundStatus = String(refund.status || "pending");
      const effectiveRefunded = refundStatus === "failed" ?
        amountRefunded : projectedRefunded;
      const fullRefund = effectiveRefunded >= chargeAmount;
      await Promise.all([
        caseRef.set({
          status: refundStatus === "failed" ? "refund_retry_required" :
            refundStatus === "succeeded" ? "completed" : "refund_pending",
          refundStatus,
          stripeRefundId: String(refund.id || ""),
          approvedByUid: administratorUid,
          approvedAt: FieldValue.serverTimestamp(),
          sellerRecoveredMinor: recovery.recoveredMinor,
          sellerRecoveryOutstandingMinor: recovery.outstandingMinor,
          sellerTransferReversalId: recovery.transferReversalId,
          platformFundedOverrideUsed:
            allowPlatformFunding && recovery.outstandingMinor > 0,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true}),
        transactionRef.set({
          financialStatus: refundStatus === "succeeded" ?
            (fullRefund ? "refunded" : "partially_refunded") : "refund_pending",
          paymentProviderStatus: refundStatus === "succeeded" ?
            (fullRefund ? "refunded" : "partially_refunded") :
            String(sale.paymentProviderStatus || "paid"),
          refundedMinor: effectiveRefunded,
          sellerRecoveryOutstandingMinor: recovery.outstandingMinor,
          financialHold: recovery.outstandingMinor > 0,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true}),
      ]);
      await syncAffiliateExposure({
        transactionId,
        sale,
        customerExposureMinor: effectiveRefunded,
        caseId,
        reason: "refund",
      });
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
          sellerRecoveryOutstandingMinor: recovery.outstandingMinor,
        },
      });
      return {
        caseId,
        transactionId,
        refundId: String(refund.id || ""),
        status: refundStatus,
        sellerRecoveryOutstandingMinor: recovery.outstandingMinor,
        platformFundedOverrideUsed:
          allowPlatformFunding && recovery.outstandingMinor > 0,
        alreadyExecuted: false,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError ||
          error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Marketplace refund execution failed", {
        administratorUid: administratorUid || null,
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
    if (billingType === "marketplace_fee_only") {
      await transactionRef.set({
        marketplaceFeeStatus: charge.refunded ? "refunded" : "partially_refunded",
        marketplaceFeeRefundedMinor: Number(charge.amount_refunded || 0),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {transactionId, billingType};
    }
    const chargeAmount = Number(charge.amount || sale.buyerChargedMinor || 0);
    const refundedMinor = Number(charge.amount_refunded || 0);
    if (!Number.isSafeInteger(chargeAmount) || chargeAmount <= 0 ||
        !Number.isSafeInteger(refundedMinor) || refundedMinor <= 0) {
      return {transactionId, billingType};
    }
    const caseId = `stripe_refund_${chargeId}_${refundedMinor}`;
    const recovery = await reverseSellerTransferToExposure({
      transactionId,
      sale,
      caseId,
      customerExposureMinor: refundedMinor,
      reason: "stripe_refund_reconciliation",
    });
    const fullRefund = refundedMinor >= chargeAmount;
    await transactionRef.set({
      financialStatus: fullRefund ? "refunded" : "partially_refunded",
      paymentProviderStatus: fullRefund ? "refunded" : "partially_refunded",
      refundedMinor,
      sellerRecoveryOutstandingMinor: recovery.outstandingMinor,
      financialHold: recovery.outstandingMinor > 0,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    await db.collection("marketplace_financial_cases").doc(caseId).set({
      type: "stripe_refund_reconciliation",
      transactionId,
      listingId: String(sale.listingId || ""),
      buyerUid: String(sale.buyerUid || ""),
      sellerUid: String(sale.sellerUid || ""),
      currency: String(sale.currency || "CAD").toUpperCase(),
      status: recovery.outstandingMinor > 0 ?
        "seller_recovery_required" : "completed",
      refundedMinor,
      sellerRecoveredMinor: recovery.recoveredMinor,
      sellerRecoveryOutstandingMinor: recovery.outstandingMinor,
      sellerTransferReversalId: recovery.transferReversalId,
      updatedAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    await syncAffiliateExposure({
      transactionId,
      sale,
      customerExposureMinor: refundedMinor,
      caseId,
      reason: "refund",
    });
    return {transactionId, billingType, caseId};
  }

  async function handleRefundStatusEvent(refund, eventType) {
    const caseId = String(
        refund && refund.metadata && refund.metadata.pipeBuyerFinancialCaseId || "",
    );
    if (!caseId) return;
    const status = String(refund.status || "unknown");
    await db.collection("marketplace_financial_cases").doc(caseId).set({
      stripeRefundId: String(refund.id || ""),
      refundStatus: status,
      lastStripeRefundEvent: eventType,
      ...(status === "failed" ? {status: "refund_retry_required"} : {}),
      ...(status === "succeeded" ? {status: "completed"} : {}),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  }

  async function restoreSellerAfterWonDispute({
    transactionId,
    sale,
    caseId,
    disputeCase,
  }) {
    const restoreMinor = Number(disputeCase.sellerReversedForDisputeMinor || 0);
    if (!Number.isSafeInteger(restoreMinor) || restoreMinor <= 0) {
      return {restoredMinor: 0, transferId: null};
    }
    const provider = await db.collection("payment_provider_accounts")
        .doc(String(sale.sellerUid || "")).get();
    if (!provider.exists || provider.data().transferStatus !== "active") {
      return {restoredMinor: 0, transferId: null};
    }
    const destination = String(provider.data().stripeAccountId || "");
    if (!destination.startsWith("acct_")) {
      return {restoredMinor: 0, transferId: null};
    }
    try {
      const transfer = await stripeRequest({
        secretKey: stripeSecretKey.value(),
        path: "/v1/transfers",
        idempotencyKey: `pipebuyer-dispute-restore-${caseId}`,
        fields: {
          amount: restoreMinor,
          currency: String(sale.currency || "CAD").toLowerCase(),
          destination,
          transfer_group: String(sale.stripeTransferGroup || `PB_${transactionId}`),
          "metadata[pipeBuyerTransactionId]": transactionId,
          "metadata[pipeBuyerFinancialCaseId]": caseId,
          "metadata[type]": "dispute_won_restore",
        },
      });
      return {restoredMinor: restoreMinor, transferId: String(transfer.id || "")};
    } catch (error) {
      console.error("Seller dispute restoration transfer failed", {
        transactionId,
        caseId,
        stripeCode: error.stripeCode || null,
      });
      return {restoredMinor: 0, transferId: null};
    }
  }

  async function handleDisputeEvent(dispute, eventType) {
    const chargeId = stripeChargeIdFromObject(dispute && dispute.charge);
    const match = await findTransactionForCharge(chargeId);
    if (!match || match.billingType !== "marketplace_sale") return null;
    const {id: transactionId, ref: transactionRef, sale} = match;
    const disputeId = String(dispute.id || "");
    if (!disputeId.startsWith("dp_")) return null;
    const caseId = `dispute_${disputeId}`;
    const caseRef = db.collection("marketplace_financial_cases").doc(caseId);
    const previousSnapshot = await caseRef.get();
    const previous = previousSnapshot.exists ? previousSnapshot.data() : {};
    const status = String(dispute.status || "unknown");
    const disputeAmount = Math.max(0, Number(dispute.amount || 0));
    const refundedMinor = Math.max(0, Number(sale.refundedMinor || 0));
    const chargeAmount = Math.max(0, Number(sale.buyerChargedMinor || 0));
    const exposure = Math.min(chargeAmount, refundedMinor + disputeAmount);
    const readiness = await loadReadiness();
    let recovery = {
      recoveredMinor: Number(previous.sellerRecoveredMinor || 0),
      outstandingMinor: Number(previous.sellerRecoveryOutstandingMinor || 0),
      transferReversalId: previous.sellerTransferReversalId || null,
    };
    if ((eventType === "charge.dispute.created" ||
         eventType === "charge.dispute.funds_withdrawn") &&
        readiness.disputeAutomationEnabled) {
      const transferBefore = await stripeRequest({
        secretKey: stripeSecretKey.value(),
        path: `/v1/transfers/${encodeURIComponent(sale.stripeSellerTransferId || "")}`,
        method: "GET",
      }).catch(() => null);
      const reversedBefore = Number(transferBefore && transferBefore.amount_reversed || 0);
      recovery = await reverseSellerTransferToExposure({
        transactionId,
        sale,
        caseId,
        customerExposureMinor: exposure,
        reason: "stripe_dispute",
      });
      recovery.sellerReversedForDisputeMinor = Math.max(
          0,
          Number(recovery.recoveredMinor || 0) - reversedBefore,
      );
    }
    if ((eventType === "charge.dispute.created" ||
         eventType === "charge.dispute.funds_withdrawn") &&
        !readiness.disputeAutomationEnabled) {
      recovery.outstandingMinor = proportionalRecoveryTarget({
        transferAmountMinor: Math.max(0, Number(sale.sellerProceedsMinor || 0)),
        originalChargeAmountMinor: Math.max(1, chargeAmount),
        customerExposureMinor: exposure,
      });
      await setSellerRecoveryObligation({
        transactionId,
        sale,
        caseId,
        amountDueMinor: recovery.outstandingMinor,
        currency: String(sale.currency || "CAD").toUpperCase(),
        reason: "dispute_manual_recovery_required",
      });
    }

    let restoration = {restoredMinor: 0, transferId: null};
    if (eventType === "charge.dispute.closed" && status === "won") {
      restoration = await restoreSellerAfterWonDispute({
        transactionId,
        sale,
        caseId,
        disputeCase: previous,
      });
      await setSellerRecoveryObligation({
        transactionId,
        sale,
        caseId,
        amountDueMinor: 0,
        currency: String(sale.currency || "CAD").toUpperCase(),
        reason: "dispute_won",
      });
      await maybeClearSellerHold(String(sale.sellerUid || ""));
    }

    const evidenceDueBy = Number(
        dispute.evidence_details && dispute.evidence_details.due_by || 0,
    );
    const closed = eventType === "charge.dispute.closed";
    const lost = closed && ["lost", "warning_closed"].includes(status);
    const won = closed && status === "won";
    const financialStatus = won ? "dispute_won" :
      lost ? "charged_back" : "disputed";
    await caseRef.set({
      type: "stripe_dispute",
      transactionId,
      listingId: String(sale.listingId || ""),
      buyerUid: String(sale.buyerUid || ""),
      sellerUid: String(sale.sellerUid || ""),
      currency: String(dispute.currency || sale.currency || "CAD").toUpperCase(),
      stripeDisputeId: disputeId,
      stripeChargeId: chargeId,
      disputeAmountMinor: disputeAmount,
      disputeReason: String(dispute.reason || "unknown").slice(0, 240),
      disputeStatus: status,
      evidenceDueAt: evidenceDueBy > 0 ? Timestamp.fromMillis(evidenceDueBy * 1000) : null,
      sellerRecoveredMinor: recovery.recoveredMinor || 0,
      sellerRecoveryOutstandingMinor: won ? 0 : recovery.outstandingMinor || 0,
      sellerTransferReversalId: recovery.transferReversalId || null,
      sellerReversedForDisputeMinor:
        recovery.sellerReversedForDisputeMinor ||
        Number(previous.sellerReversedForDisputeMinor || 0),
      sellerRestoreTransferId: restoration.transferId,
      sellerRestoredAfterWinMinor: restoration.restoredMinor,
      status: won ? "won" : lost ? "lost" : "open",
      lastStripeEvent: eventType,
      taxReviewRequired: lost,
      updatedAt: FieldValue.serverTimestamp(),
      ...(previousSnapshot.exists ? {} : {
        createdAt: FieldValue.serverTimestamp(),
      }),
    }, {merge: true});
    await transactionRef.set({
      activeDisputeId: closed ? null : disputeId,
      disputeStatus: status,
      financialStatus,
      paymentProviderStatus: won ? "paid" : lost ? "charged_back" : "disputed",
      financialHold: !won,
      sellerRecoveryOutstandingMinor: won ? 0 : recovery.outstandingMinor || 0,
      taxReviewRequired: lost,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    const affiliateExposure = won ? refundedMinor : exposure;
    await syncAffiliateExposure({
      transactionId,
      sale,
      customerExposureMinor: affiliateExposure,
      caseId,
      reason: won ? "dispute_won" : "dispute",
    });
    await createFinancialEvent({
      transactionId,
      sale,
      caseId,
      type: eventType,
      values: {
        stripeDisputeId: disputeId,
        disputeStatus: status,
        amountMinor: disputeAmount,
        sellerRecoveryOutstandingMinor: won ? 0 : recovery.outstandingMinor || 0,
        taxReviewRequired: lost,
      },
    });
    return {transactionId, caseId, status};
  }

  async function retryMarketplaceSellerRecovery(request) {
    let administratorUid;
    try {
      administratorUid = requireAdministrator(request);
      await enforceUserRateLimit({
        db,
        admin,
        request,
        scope: "administration",
      });
      const readiness = await loadReadiness();
      requireFinancialResolutionReady(readiness);
      const caseId = cleanId(request.data && request.data.caseId, "caseId");
      const caseRef = db.collection("marketplace_financial_cases").doc(caseId);
      const caseSnapshot = await caseRef.get();
      if (!caseSnapshot.exists) {
        throw new HttpsError("not-found", "The financial case was not found.");
      }
      const financialCase = caseSnapshot.data();
      const transactionId = String(financialCase.transactionId || "");
      const transactionRef = db.collection("marketplace_transactions")
          .doc(transactionId);
      const saleSnapshot = await transactionRef.get();
      if (!saleSnapshot.exists) {
        throw new HttpsError("not-found", "The marketplace transaction was not found.");
      }
      const sale = saleSnapshot.data();
      const chargeAmount = Number(sale.buyerChargedMinor || 0);
      const refundExposure = Number(sale.refundedMinor || 0);
      const disputeExposure = OPEN_DISPUTE_STATUSES.has(
          String(sale.disputeStatus || ""),
      ) ? Number(financialCase.disputeAmountMinor || 0) : 0;
      const exposure = Math.min(
          chargeAmount,
          Math.max(0, refundExposure + disputeExposure),
      );
      const recovery = await reverseSellerTransferToExposure({
        transactionId,
        sale,
        caseId,
        customerExposureMinor: exposure,
        reason: "admin_recovery_retry",
      });
      await caseRef.set({
        sellerRecoveredMinor: recovery.recoveredMinor,
        sellerRecoveryOutstandingMinor: recovery.outstandingMinor,
        sellerTransferReversalId: recovery.transferReversalId ||
          financialCase.sellerTransferReversalId || null,
        recoveryRetriedByUid: administratorUid,
        recoveryRetriedAt: FieldValue.serverTimestamp(),
        ...(recovery.outstandingMinor === 0 ? {status: "recovery_completed"} : {}),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      await transactionRef.set({
        sellerRecoveryOutstandingMinor: recovery.outstandingMinor,
        financialHold: recovery.outstandingMinor > 0,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {
        caseId,
        transactionId,
        sellerRecoveryOutstandingMinor: recovery.outstandingMinor,
        recoveredMinor: recovery.recoveredMinor,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError ||
          error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Marketplace seller recovery retry failed", {
        administratorUid: administratorUid || null,
        error,
      });
      throw new HttpsError(
          "failed-precondition",
          "Seller recovery could not be completed. The financial hold remains active.",
      );
    }
  }

  return {
    cancelMarketplaceRefundRequest,
    executeMarketplaceRefund,
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
  OPEN_DISPUTE_STATUSES,
  adjustedAffiliateCommission,
  createMarketplaceFinancialResolution,
  proportionalRecoveryTarget,
  refundReasonCode,
  stripeRequest,
};
