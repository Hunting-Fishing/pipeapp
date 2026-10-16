"use strict";

const crypto = require("node:crypto");
const {stripeSecretKey} = require("./stripe_marketplace_commands");
const {
  isStripeTransferId,
  stripeFinancialRequest,
} = require("./marketplace_stripe_financial_api");
const {
  marketplaceTransactionCurrency,
} = require("./marketplace_command_policy");

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

function uniqueSellerTransferIds(sale) {
  const values = [
    String(sale && sale.stripeSellerTransferId || ""),
    ...(Array.isArray(sale && sale.sellerPayoutTransferIds) ?
      sale.sellerPayoutTransferIds.map((value) => String(value || "")) : []),
  ];
  return [...new Set(values.filter(isStripeTransferId))];
}

function originalSellerProceedsMinor(sale) {
  const explicit = Number(sale && sale.originalSellerProceedsMinor);
  if (Number.isSafeInteger(explicit) && explicit >= 0) return explicit;
  const settled = Number(sale && sale.sellerProceedsMinor);
  if (Number.isSafeInteger(settled) && settled >= 0) return settled;
  const snapshot = Number(
      sale && sale.marketplaceFeeSnapshot &&
      sale.marketplaceFeeSnapshot.sellerProceedsBeforeTaxMinor,
  );
  return Number.isSafeInteger(snapshot) && snapshot >= 0 ? snapshot : 0;
}

function desiredSellerNetMinor({sale, customerExposureMinor}) {
  const sellerProceeds = originalSellerProceedsMinor(sale);
  const chargeAmount = Number(sale && sale.buyerChargedMinor || 0);
  if (!Number.isSafeInteger(chargeAmount) || chargeAmount <= 0) {
    throw new TypeError("The original buyer charge amount is unavailable.");
  }
  const recovery = proportionalRecoveryTarget({
    transferAmountMinor: sellerProceeds,
    originalChargeAmountMinor: chargeAmount,
    customerExposureMinor: Math.max(0, Number(customerExposureMinor || 0)),
  });
  return Math.max(0, sellerProceeds - recovery);
}

const DEFAULT_REBALANCE_LEASE_MILLIS = 5 * 60 * 1000;

function restorationIdempotencyKey(transactionId, attemptId) {
  return `pipebuyer-seller-restoration-${transactionId}-${attemptId}`;
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

function storedRestorationRequest(sale, transactionId) {
  const state = String(sale && sale.sellerRestorationRequestState || "");
  if (!["reserved", "dispatching", "outcome_unknown"].includes(state)) {
    return null;
  }
  const attemptId = String(
      sale && sale.sellerRestorationRequestAttemptId || "",
  ).trim();
  const idempotencyKey = String(
      sale && sale.sellerRestorationRequestIdempotencyKey || "",
  ).trim();
  const snapshot = sale && sale.sellerRestorationRequestSnapshot;
  const amount = Number(snapshot && snapshot.amountMinor || 0);
  const destination = String(snapshot && snapshot.destination || "").trim();
  let currency;
  try {
    currency = marketplaceTransactionCurrency(
        snapshot && snapshot.currency,
    ).toLowerCase();
  } catch (_) {
    return null;
  }
  if (!attemptId ||
      idempotencyKey !== restorationIdempotencyKey(transactionId, attemptId) ||
      !Number.isSafeInteger(amount) || amount <= 0 ||
      !destination.startsWith("acct_")) return null;
  return {
    attemptId,
    idempotencyKey,
    state,
    amount,
    currency,
    destination,
    transferGroup: String(snapshot.transferGroup || "").slice(0, 200),
    caseId: String(snapshot.caseId || ""),
    operationId: String(snapshot.operationId || ""),
    desiredNetMinor: Number(snapshot.desiredNetMinor || 0),
    financialEpoch: Number(snapshot.financialEpoch || 0),
  };
}

function createMarketplaceSellerFunds(admin, options = {}) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const requestStripe = options.stripeRequest || stripeFinancialRequest;
  const readStripeSecret = options.stripeSecret || (() => stripeSecretKey.value());
  const now = typeof options.now === "function" ? options.now : () => Date.now();
  const leaseMillis = Number.isFinite(options.leaseMillis) ?
    Number(options.leaseMillis) : DEFAULT_REBALANCE_LEASE_MILLIS;

  async function retrieveTransfers(sale) {
    const ids = uniqueSellerTransferIds(sale);
    const transfers = [];
    for (const id of ids) {
      const transfer = await requestStripe({
        secretKey: readStripeSecret(),
        path: `/v1/transfers/${encodeURIComponent(id)}`,
        method: "GET",
      });
      transfers.push({
        id,
        amountMinor: Math.max(0, Number(transfer.amount || 0)),
        reversedMinor: Math.max(0, Number(transfer.amount_reversed || 0)),
        raw: transfer,
      });
    }
    return transfers;
  }

  function netSellerTransferredMinor(transfers) {
    return transfers.reduce((total, transfer) =>
      total + Math.max(0, transfer.amountMinor - transfer.reversedMinor), 0);
  }

  async function sellerDestination(sale) {
    const sellerUid = String(sale && sale.sellerUid || "").trim();
    if (!sellerUid) return null;
    const snapshot = await db.collection("payment_provider_accounts")
        .doc(sellerUid).get();
    if (!snapshot.exists) return null;
    const data = snapshot.data();
    const accountId = String(data.stripeAccountId || "");
    if (data.transferStatus !== "active" || !accountId.startsWith("acct_")) {
      return null;
    }
    return {sellerUid, accountId, providerRef: snapshot.ref, provider: data};
  }

  async function claimRebalance(transactionId, expectedFinancialEpoch) {
    if (expectedFinancialEpoch == null) return {guarded: false};
    const transactionRef = db.collection("marketplace_transactions")
        .doc(transactionId);
    const operationId = crypto.randomUUID();
    return db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(transactionRef);
      if (!snapshot.exists ||
          Number(snapshot.data().financialEpoch || 0) !==
            expectedFinancialEpoch) return {guarded: true, stale: true};
      const data = snapshot.data();
      if (String(data.sellerFundsRebalanceOperationId || "") &&
          Number(data.sellerFundsRebalanceLeaseExpiresAtMillis || 0) > now()) {
        return {guarded: true, inProgress: true};
      }
      transaction.set(transactionRef, {
        sellerFundsRebalanceOperationId: operationId,
        sellerFundsRebalanceFinancialEpoch: expectedFinancialEpoch,
        sellerFundsRebalanceLeaseExpiresAtMillis: now() + leaseMillis,
        sellerFundsRebalanceStartedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {
        guarded: true,
        operationId,
        expectedFinancialEpoch,
        transactionRef,
      };
    });
  }

  async function rebalanceOperationCurrent(claim) {
    if (!claim.guarded) return true;
    const snapshot = await claim.transactionRef.get();
    return snapshot.exists &&
      Number(snapshot.data().financialEpoch || 0) ===
        claim.expectedFinancialEpoch &&
      String(snapshot.data().sellerFundsRebalanceOperationId || "") ===
        claim.operationId;
  }

  async function reserveRestorationRequest({
    transactionId,
    claim,
    caseId,
    desiredNetMinor,
    amount,
    destination,
    sale,
  }) {
    const transactionRef = claim.transactionRef ||
      db.collection("marketplace_transactions").doc(transactionId);
    const transferGroup = String(
        sale.stripeTransferGroup || `PB_${transactionId}`,
    ).slice(0, 200);
    return db.runTransaction(async (transaction) => {
      const current = await transaction.get(transactionRef);
      if (!current.exists) return null;
      const existing = storedRestorationRequest(current.data(), transactionId);
      if (existing) return null;
      if (claim.guarded &&
          (Number(current.data().financialEpoch || 0) !==
            claim.expectedFinancialEpoch ||
           String(current.data().sellerFundsRebalanceOperationId || "") !==
            claim.operationId)) return null;
      const currency = marketplaceTransactionCurrency(
          current.data().currency,
      ).toLowerCase();
      if (marketplaceTransactionCurrency(sale.currency).toLowerCase() !==
          currency) return null;
      const attemptId = crypto.randomUUID();
      const request = {
        attemptId,
        idempotencyKey: restorationIdempotencyKey(transactionId, attemptId),
        state: "reserved",
        amount,
        currency,
        destination,
        transferGroup,
        caseId,
        operationId: String(claim.operationId || ""),
        desiredNetMinor,
        financialEpoch: Number(current.data().financialEpoch || 0),
      };
      transaction.set(transactionRef, {
        sellerRestorationRequestState: "reserved",
        sellerRestorationRequestAttemptId: attemptId,
        sellerRestorationRequestIdempotencyKey: request.idempotencyKey,
        sellerRestorationRequestSnapshot: {
          amountMinor: amount,
          currency,
          destination,
          transferGroup,
          caseId,
          operationId: request.operationId,
          desiredNetMinor,
          financialEpoch: request.financialEpoch,
        },
        sellerRestorationRequestReservedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return request;
    });
  }

  async function confirmRestorationDispatch({
    transactionId,
    claim,
    request,
  }) {
    if (!claim.guarded) return false;
    const transactionRef = claim.transactionRef ||
      db.collection("marketplace_transactions").doc(transactionId);
    return db.runTransaction(async (transaction) => {
      const current = await transaction.get(transactionRef);
      if (!current.exists) return false;
      const sale = current.data();
      const stored = storedRestorationRequest(sale, transactionId);
      const activeCaseId = String(sale.activeFinancialCaseId || "");
      if (!stored || stored.state !== "reserved" ||
          stored.attemptId !== request.attemptId ||
          stored.idempotencyKey !== request.idempotencyKey ||
          stored.operationId !== claim.operationId ||
          stored.caseId !== request.caseId ||
          stored.financialEpoch !== claim.expectedFinancialEpoch ||
          Number(sale.financialEpoch || 0) !== claim.expectedFinancialEpoch ||
          String(sale.sellerFundsRebalanceOperationId || "") !==
            claim.operationId ||
          Number(sale.sellerFundsRebalanceFinancialEpoch || 0) !==
            claim.expectedFinancialEpoch ||
          activeCaseId && activeCaseId !== request.caseId ||
          marketplaceTransactionCurrency(sale.currency).toLowerCase() !==
            request.currency) return false;
      const providerRef = db.collection("payment_provider_accounts")
          .doc(String(sale.sellerUid || ""));
      const providerSnapshot = await transaction.get(providerRef);
      const provider = providerSnapshot.exists ? providerSnapshot.data() : {};
      if (!providerSnapshot.exists || provider.transferStatus !== "active" ||
          String(provider.stripeAccountId || "") !== request.destination) {
        return false;
      }
      transaction.set(transactionRef, {
        sellerRestorationRequestState: "dispatching",
        sellerRestorationRequestDispatchConfirmedAt:
          FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return true;
    });
  }

  async function abandonReservedRestoration(transactionId, request) {
    const transactionRef = db.collection("marketplace_transactions")
        .doc(transactionId);
    return db.runTransaction(async (transaction) => {
      const current = await transaction.get(transactionRef);
      if (!current.exists ||
          String(current.data().sellerRestorationRequestState || "") !==
            "reserved" ||
          String(current.data().sellerRestorationRequestAttemptId || "") !==
            request.attemptId) return false;
      transaction.set(transactionRef, {
        sellerRestorationRequestState: "abandoned",
        sellerRestorationRequestAbandonedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return true;
    });
  }

  async function dispatchRestorationRequest(transactionId, request) {
    return requestStripe({
      secretKey: readStripeSecret(),
      path: "/v1/transfers",
      idempotencyKey: request.idempotencyKey,
      fields: {
        amount: request.amount,
        currency: request.currency,
        destination: request.destination,
        transfer_group: request.transferGroup,
        "metadata[pipeBuyerTransactionId]": transactionId,
        "metadata[pipeBuyerFinancialCaseId]": request.caseId,
        "metadata[type]": "seller_financial_restoration",
        "metadata[restorationAttemptId]": request.attemptId,
      },
    });
  }

  async function recordRestorationResult({
    transactionId,
    request,
    state,
    transferId = "",
    error = null,
  }) {
    const transactionRef = db.collection("marketplace_transactions")
        .doc(transactionId);
    return db.runTransaction(async (transaction) => {
      const current = await transaction.get(transactionRef);
      if (!current.exists ||
          String(current.data().sellerRestorationRequestAttemptId || "") !==
            request.attemptId) return false;
      transaction.set(transactionRef, {
        sellerRestorationRequestState: state,
        ...(transferId ? {
          sellerRestorationRequestTransferId: transferId,
          sellerPayoutTransferIds: FieldValue.arrayUnion(transferId),
          sellerRestorationRequestResolvedAt: FieldValue.serverTimestamp(),
        } : {}),
        ...(error ? {
          sellerRestorationRequestErrorCode:
            String(error.stripeCode || error.code || "provider_error")
                .slice(0, 120),
        } : {}),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return true;
    });
  }

  async function resolvePendingRestoration({transactionId, claim, caseId}) {
    const transactionRef = claim.transactionRef ||
      db.collection("marketplace_transactions").doc(transactionId);
    const snapshot = await transactionRef.get();
    if (!snapshot.exists) return null;
    const request = storedRestorationRequest(snapshot.data(), transactionId);
    if (!request) return null;
    if (request.state === "reserved") {
      await abandonReservedRestoration(transactionId, request);
      return {abandoned: true, request};
    }
    try {
      const transfer = await dispatchRestorationRequest(transactionId, request);
      const transferId = String(transfer && transfer.id || "");
      if (!isStripeTransferId(transferId)) {
        const error = new Error(
            "Stripe returned an ambiguous seller restoration response.",
        );
        error.stripeCode = "invalid_transfer_response";
        throw error;
      }
      await recordRestorationResult({
        transactionId,
        request,
        state: "succeeded",
        transferId,
      });
      const currentForCase = request.caseId === caseId &&
        (!claim.guarded || request.financialEpoch ===
          claim.expectedFinancialEpoch && await rebalanceOperationCurrent(claim));
      if (currentForCase) {
        return {transferId, amount: request.amount, request};
      }
      const compensation = await compensateStaleRestoration({
        transactionId,
        caseId: request.caseId,
        claim: {
          ...claim,
          operationId: request.attemptId,
          transactionRef,
        },
        transferId,
        amount: request.amount,
      });
      await recordRestorationResult({
        transactionId,
        request,
        state: compensation.compensated ?
          "compensated" : "compensation_required",
        transferId,
      });
      return {compensated: compensation.compensated, request};
    } catch (error) {
      const definitive = stripeFailureIsDefinitive(error);
      await recordRestorationResult({
        transactionId,
        request,
        state: definitive ? "failed" : "outcome_unknown",
        error,
      });
      return {
        blocked: !definitive,
        definitive,
        request,
        failure: {
          transferId: null,
          amountMinor: request.amount,
          operation: "restoration",
          ambiguous: !definitive,
          stripeCode: String(error.stripeCode || "provider_error"),
        },
      };
    }
  }

  async function compensateStaleRestoration({
    transactionId,
    caseId,
    claim,
    transferId,
    amount,
  }) {
    if (!transferId || amount <= 0) return {compensated: true};
    try {
      const reversal = await requestStripe({
        secretKey: readStripeSecret(),
        path: `/v1/transfers/${encodeURIComponent(transferId)}/reversals`,
        idempotencyKey:
          `pipebuyer-stale-restoration-${caseId}-${claim.operationId}`,
        fields: {
          amount,
          "metadata[pipeBuyerTransactionId]": transactionId,
          "metadata[pipeBuyerFinancialCaseId]": caseId,
          "metadata[reason]": "financial_epoch_invalidated",
        },
      });
      await claim.transactionRef.set({
        sellerPayoutTransferIds: FieldValue.arrayUnion(transferId),
        sellerRebalanceInvalidatedTransferIds: FieldValue.arrayUnion(transferId),
        sellerRebalanceCompensationReversalIds:
          FieldValue.arrayUnion(String(reversal.id || "")),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {compensated: true};
    } catch (error) {
      await claim.transactionRef.set({
        sellerPayoutTransferIds: FieldValue.arrayUnion(transferId),
        sellerRebalanceInvalidatedTransferIds: FieldValue.arrayUnion(transferId),
        sellerRebalanceCompensationRequired: true,
        sellerRebalanceCompensationAmountMinor: amount,
        sellerRebalanceCompensationErrorCode:
          String(error && error.stripeCode || error && error.code ||
            "provider_error").slice(0, 120),
        financialHold: true,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {compensated: false, error};
    }
  }

  async function setSellerRecoveryState({
    transactionId,
    sale,
    caseId,
    outstandingRecoveryMinor,
    outstandingRestorationMinor,
    desiredNetMinor,
    actualNetMinor,
    reason,
  }) {
    const sellerUid = String(sale && sale.sellerUid || "");
    const obligationRef = db.collection("marketplace_seller_recovery_obligations")
        .doc(caseId);
    const recoveryDue = Math.max(0, Number(outstandingRecoveryMinor || 0));
    const restorationDue = Math.max(0, Number(outstandingRestorationMinor || 0));
    await obligationRef.set({
      transactionId,
      caseId,
      sellerUid,
      buyerUid: String(sale && sale.buyerUid || ""),
      currency: marketplaceTransactionCurrency(sale && sale.currency),
      desiredSellerNetMinor: desiredNetMinor,
      actualSellerNetMinor: actualNetMinor,
      amountDueMinor: recoveryDue,
      restorationDueMinor: restorationDue,
      reason,
      status: recoveryDue > 0 ? "open" :
        restorationDue > 0 ? "seller_restoration_pending" : "resolved",
      updatedAt: FieldValue.serverTimestamp(),
      ...(recoveryDue === 0 && restorationDue === 0 ? {
        resolvedAt: FieldValue.serverTimestamp(),
      } : {}),
    }, {merge: true});
    if (sellerUid) {
      const openOther = await db.collection("marketplace_seller_recovery_obligations")
          .where("sellerUid", "==", sellerUid)
          .where("status", "==", "open")
          .limit(2)
          .get();
      const hasOpenRecovery = recoveryDue > 0 || restorationDue > 0 ||
        openOther.docs.some(
          (document) => document.id !== caseId,
        );
      await db.collection("payment_provider_accounts").doc(sellerUid).set({
        sellerPayoutHold: hasOpenRecovery,
        sellerPayoutHoldReason: hasOpenRecovery ? reason : null,
        sellerPayoutHoldUpdatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
  }

  async function finalizeGuardedRebalance({
    claim,
    transactionId,
    sale,
    caseId,
    outstandingRecoveryMinor,
    outstandingRestorationMinor,
    desiredNetMinor,
    actualNetMinor,
    reason,
    originalProceeds,
    restorationTransferId,
  }) {
    const sellerUid = String(sale && sale.sellerUid || "");
    const obligationRef = db.collection("marketplace_seller_recovery_obligations")
        .doc(caseId);
    const providerRef = sellerUid ?
      db.collection("payment_provider_accounts").doc(sellerUid) : null;
    const recoveryDue = Math.max(0, Number(outstandingRecoveryMinor || 0));
    const restorationDue = Math.max(0, Number(outstandingRestorationMinor || 0));
    return db.runTransaction(async (transaction) => {
      const current = await transaction.get(claim.transactionRef);
      const openOther = sellerUid ? await transaction.get(
          db.collection("marketplace_seller_recovery_obligations")
              .where("sellerUid", "==", sellerUid)
              .where("status", "==", "open")
              .limit(100),
      ) : null;
      if (!current.exists ||
          Number(current.data().financialEpoch || 0) !==
            claim.expectedFinancialEpoch ||
          String(current.data().sellerFundsRebalanceOperationId || "") !==
            claim.operationId) return false;
      const hasOpenRecovery = recoveryDue > 0 || restorationDue > 0 ||
        Boolean(openOther) &&
        openOther.docs.some((document) => document.id !== caseId);
      transaction.set(obligationRef, {
        transactionId,
        caseId,
        sellerUid,
        buyerUid: String(sale && sale.buyerUid || ""),
        currency: marketplaceTransactionCurrency(sale && sale.currency),
        desiredSellerNetMinor: desiredNetMinor,
        actualSellerNetMinor: actualNetMinor,
        amountDueMinor: recoveryDue,
        restorationDueMinor: restorationDue,
        reason,
        status: recoveryDue > 0 ? "open" :
          restorationDue > 0 ? "seller_restoration_pending" : "resolved",
        financialEpoch: claim.expectedFinancialEpoch,
        updatedAt: FieldValue.serverTimestamp(),
        ...(recoveryDue === 0 && restorationDue === 0 ? {
          resolvedAt: FieldValue.serverTimestamp(),
        } : {}),
      }, {merge: true});
      if (providerRef) {
        transaction.set(providerRef, {
          sellerPayoutHold: hasOpenRecovery,
          sellerPayoutHoldReason: hasOpenRecovery ? reason : null,
          sellerPayoutHoldUpdatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
      transaction.set(claim.transactionRef, {
        originalSellerProceedsMinor: originalProceeds,
        sellerNetTransferredMinor: actualNetMinor,
        sellerDesiredNetMinor: desiredNetMinor,
        sellerRecoveryOutstandingMinor: recoveryDue,
        sellerRestorationOutstandingMinor: restorationDue,
        financialHold: recoveryDue > 0 || restorationDue > 0,
        ...(restorationTransferId ? {
          sellerPayoutTransferIds:
            FieldValue.arrayUnion(restorationTransferId),
        } : {}),
        sellerFundsRebalanceOperationId: "",
        sellerFundsRebalanceLeaseExpiresAtMillis: 0,
        sellerFundsRebalancedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return true;
    });
  }

  async function rebalanceSellerFunds({
    transactionId,
    sale,
    caseId,
    customerExposureMinor,
    reason,
    allowRestoration = false,
    expectedFinancialEpoch = null,
  }) {
    const claim = await claimRebalance(transactionId, expectedFinancialEpoch);
    if (claim.stale || claim.inProgress) {
      return {
        stale: claim.stale === true,
        inProgress: claim.inProgress === true,
        outstandingRecoveryMinor:
          Math.max(0, Number(sale.sellerRecoveryOutstandingMinor || 0)),
        outstandingRestorationMinor:
          Math.max(0, Number(sale.sellerRestorationOutstandingMinor || 0)),
        reversalIds: [],
        restorationTransferId: null,
        restorationMinor: 0,
        failures: [],
      };
    }
    const transactionRef = claim.transactionRef ||
      db.collection("marketplace_transactions").doc(transactionId);
    const latestSnapshot = await transactionRef.get();
    let workingSale = latestSnapshot.exists ?
      {...sale, ...latestSnapshot.data()} : sale;
    const pendingResolution = await resolvePendingRestoration({
      transactionId,
      claim,
      caseId,
    });
    let pendingRestorationBlocked = false;
    const failures = [];
    if (pendingResolution && pendingResolution.transferId) {
      workingSale = {
        ...workingSale,
        sellerPayoutTransferIds: [
          ...(Array.isArray(workingSale.sellerPayoutTransferIds) ?
            workingSale.sellerPayoutTransferIds : []),
          pendingResolution.transferId,
        ],
      };
    } else if (pendingResolution && pendingResolution.failure) {
      failures.push(pendingResolution.failure);
      pendingRestorationBlocked = pendingResolution.blocked === true;
    }
    const originalProceeds = originalSellerProceedsMinor(workingSale);
    const desiredNet = desiredSellerNetMinor({
      sale: workingSale,
      customerExposureMinor,
    });
    const transfers = await retrieveTransfers(workingSale);
    let actualNet = netSellerTransferredMinor(transfers);
    const reversalIds = [];

    if (actualNet > desiredNet) {
      let remaining = actualNet - desiredNet;
      const candidates = [...transfers].reverse();
      for (const transfer of candidates) {
        if (remaining <= 0) break;
        if (!await rebalanceOperationCurrent(claim)) break;
        const reversible = Math.max(
            0,
            transfer.amountMinor - transfer.reversedMinor,
        );
        if (reversible <= 0) continue;
        const amount = Math.min(remaining, reversible);
        try {
          const reversal = await requestStripe({
            secretKey: readStripeSecret(),
            path: `/v1/transfers/${encodeURIComponent(transfer.id)}/reversals`,
            idempotencyKey:
              `pipebuyer-seller-recovery-${caseId}-${transfer.id}-${desiredNet}`,
            fields: {
              amount,
              "metadata[pipeBuyerTransactionId]": transactionId,
              "metadata[pipeBuyerFinancialCaseId]": caseId,
              "metadata[reason]": String(reason || "financial_recovery").slice(0, 200),
            },
          });
          reversalIds.push(String(reversal.id || ""));
          remaining -= amount;
          actualNet -= amount;
        } catch (error) {
          failures.push({
            transferId: transfer.id,
            amountMinor: amount,
            stripeCode: String(error.stripeCode || "provider_error"),
          });
        }
      }
    }

    let restorationTransferId = null;
    let restorationMinor = 0;
    if (!pendingRestorationBlocked && allowRestoration && actualNet < desiredNet &&
        await rebalanceOperationCurrent(claim)) {
      const destination = await sellerDestination(workingSale);
      const amount = desiredNet - actualNet;
      if (destination && amount > 0) {
        const restorationRequest = await reserveRestorationRequest({
          transactionId,
          claim,
          caseId,
          desiredNetMinor: desiredNet,
          amount,
          destination: destination.accountId,
          sale: workingSale,
        });
        if (!restorationRequest) {
          failures.push({
            transferId: null,
            amountMinor: amount,
            operation: "restoration",
            stripeCode: "stale_restoration_reservation",
          });
        } else {
        if (typeof options.afterRestorationRequestReservation === "function") {
          await options.afterRestorationRequestReservation({
            transactionId,
            claim,
            request: restorationRequest,
          });
        }
        const dispatchConfirmed = await confirmRestorationDispatch({
          transactionId,
          claim,
          request: restorationRequest,
        });
        if (!dispatchConfirmed) {
          await abandonReservedRestoration(transactionId, restorationRequest);
          failures.push({
            transferId: null,
            amountMinor: amount,
            operation: "restoration",
            stripeCode: "stale_restoration_dispatch",
          });
        } else {
        try {
          const transfer = await dispatchRestorationRequest(
              transactionId,
              restorationRequest,
          );
          restorationTransferId = String(transfer.id || "");
          if (!isStripeTransferId(restorationTransferId)) {
            const error = new Error(
                "Stripe returned an ambiguous seller restoration response.",
            );
            error.stripeCode = "invalid_transfer_response";
            throw error;
          }
          restorationMinor = amount;
          actualNet += amount;
          await recordRestorationResult({
            transactionId,
            request: restorationRequest,
            state: "succeeded",
            transferId: restorationTransferId,
          });
        } catch (error) {
          const definitive = stripeFailureIsDefinitive(error);
          await recordRestorationResult({
            transactionId,
            request: restorationRequest,
            state: definitive ? "failed" : "outcome_unknown",
            error,
          });
          failures.push({
            transferId: null,
            amountMinor: amount,
            operation: "restoration",
            ambiguous: !definitive,
            stripeCode: String(error.stripeCode || "provider_error"),
          });
        }
        }
        }
      }
    }

    const outstandingRecovery = Math.max(0, actualNet - desiredNet);
    const outstandingRestoration = Math.max(0, desiredNet - actualNet);
    let stale = false;
    let compensation = null;
    if (claim.guarded) {
      const finalized = await finalizeGuardedRebalance({
        claim,
        transactionId,
        sale: workingSale,
        caseId,
        outstandingRecoveryMinor: outstandingRecovery,
        outstandingRestorationMinor: outstandingRestoration,
        desiredNetMinor: desiredNet,
        actualNetMinor: actualNet,
        reason,
        originalProceeds,
        restorationTransferId,
      });
      stale = !finalized;
      if (stale && restorationTransferId) {
        compensation = await compensateStaleRestoration({
          transactionId,
          caseId,
          claim,
          transferId: restorationTransferId,
          amount: restorationMinor,
        });
        const request = storedRestorationRequest(
            (await transactionRef.get()).data() || {},
            transactionId,
        );
        if (request) {
          await recordRestorationResult({
            transactionId,
            request,
            state: compensation.compensated ?
              "compensated" : "compensation_required",
            transferId: restorationTransferId,
          });
        }
      }
    } else {
      await setSellerRecoveryState({
        transactionId,
        sale: workingSale,
        caseId,
        outstandingRecoveryMinor: outstandingRecovery,
        outstandingRestorationMinor: outstandingRestoration,
        desiredNetMinor: desiredNet,
        actualNetMinor: actualNet,
        reason,
      });
      await db.collection("marketplace_transactions").doc(transactionId).set({
        originalSellerProceedsMinor: originalProceeds,
        sellerNetTransferredMinor: actualNet,
        sellerDesiredNetMinor: desiredNet,
        sellerRecoveryOutstandingMinor: outstandingRecovery,
        sellerRestorationOutstandingMinor: outstandingRestoration,
        financialHold: outstandingRecovery > 0 || outstandingRestoration > 0,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }

    return {
      stale,
      compensation,
      desiredNetMinor: desiredNet,
      actualNetMinor: actualNet,
      outstandingRecoveryMinor: outstandingRecovery,
      outstandingRestorationMinor: outstandingRestoration,
      reversalIds,
      restorationTransferId,
      restorationMinor,
      failures,
    };
  }

  return {
    rebalanceSellerFunds,
    retrieveTransfers,
    sellerDestination,
  };
}

module.exports = {
  createMarketplaceSellerFunds,
  desiredSellerNetMinor,
  netSellerTransferredMinor: (transfers) => transfers.reduce((total, transfer) =>
    total + Math.max(0,
        Number(transfer.amountMinor || 0) - Number(transfer.reversedMinor || 0)), 0),
  originalSellerProceedsMinor,
  proportionalRecoveryTarget,
  uniqueSellerTransferIds,
};
