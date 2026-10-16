"use strict";

const crypto = require("node:crypto");
const {stripeSecretKey} = require("./stripe_marketplace_commands");
const {stripeFormRequest} = require("./stripe_checkout_commands");
const {
  marketplaceTransactionCurrency,
  paymentStatusAllowsCompletion,
} = require("./marketplace_command_policy");
const {financialEpoch} = require("./marketplace_financial_epoch");

const DEFAULT_SELLER_RELEASE_LEASE_MILLIS = 5 * 60 * 1000;

function transactionIdForAuction(listingId) {
  return `auction_${String(listingId || "").trim()}`;
}

function releaseFinanciallyEligible(sale = {}) {
  const completionReached = sale.status === "completed" ||
    sale.auctionSettlementStatus === "completed";
  return completionReached &&
    sale.paymentProvider === "stripe" &&
    sale.paymentProviderStatus === "paid" &&
    !sale.stripeSellerTransferId &&
    sale.financialHold !== true &&
    !new Set([
      "charged_back",
      "disputed",
      "partially_refunded",
      "refund_pending",
      "refund_processing",
      "refund_requested",
      "refunded",
    ]).has(String(sale.financialStatus || "")) &&
    !new Set(["lost", "open"]).has(String(sale.disputeStatus || "")) &&
    Number(sale.refundedMinor || 0) === 0;
}

function releaseEligible(sale = {}) {
  return releaseFinanciallyEligible(sale) &&
    !new Set([
      "release_invalidated_attempt_unknown",
      "release_invalidated_recovery_required",
      "release_dispatching",
      "release_outcome_unknown",
      "release_processing",
      "release_reserved",
      "released",
    ]).has(String(sale.sellerPayoutStatus || ""));
}

function sourceRevision(transactionData = {}) {
  const value = Number(transactionData.revision || 1);
  return Number.isSafeInteger(value) && value > 0 ? value : 1;
}

function auctionMirrorShouldApply(mirror, transactionData) {
  if (!mirror) return true;
  const current = Number(mirror.auctionSourceRevision || 0);
  return sourceRevision(transactionData) >
    (Number.isSafeInteger(current) && current >= 0 ? current : 0);
}

function releaseClaimMatches(sale, claim) {
  return Boolean(sale && claim) &&
    new Set([
      "release_processing",
      "release_reserved",
      "release_dispatching",
      "release_outcome_unknown",
    ]).has(String(sale.sellerPayoutStatus || "")) &&
    String(sale.sellerReleaseAttemptId || "") === claim.attemptId &&
    Number(sale.sellerReleaseFinancialEpoch) === claim.financialEpoch &&
    financialEpoch(sale) === claim.financialEpoch;
}

function marketplaceStatusForAuctionSync(mirror = {}, auctionStatusValue) {
  const auctionStatus = String(auctionStatusValue || "pending_completion");
  const terminalWithoutPayment = new Set([
    "cancelled", "disputed", "buyer_default_reported", "seller_default_reported",
  ]);
  if (terminalWithoutPayment.has(auctionStatus)) return auctionStatus;
  if (paymentStatusAllowsCompletion(
      mirror.paymentProviderStatus,
      mirror.marketplaceFeeStatus,
      mirror,
  )) return auctionStatus;
  return "pending_payment";
}

function createMarketplacePaymentLifecycle(admin, options = {}) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const now = typeof options.now === "function" ? options.now : () => Date.now();
  const releaseLeaseMillis = Number.isFinite(options.releaseLeaseMillis) ?
    Number(options.releaseLeaseMillis) : DEFAULT_SELLER_RELEASE_LEASE_MILLIS;
  const requestStripe = options.stripeRequest || stripeFormRequest;
  const readStripeSecret = options.stripeSecret || (() => stripeSecretKey.value());

  async function applyAuctionMirror({listingId, transactionData}) {
    const sale = transactionData || {};
    const buyerUid = String(sale.buyerUid || "").trim();
    const sellerUid = String(sale.sellerUid || "").trim();
    if (!listingId || !buyerUid || !sellerUid) return {created: false};
    const agreedQuantity = Math.max(1, Number(sale.agreedQuantity || 1));
    const agreedTotal = Number(sale.agreedTotal || sale.winningBidAmount || 0);
    if (!Number.isFinite(agreedTotal) || agreedTotal <= 0) return {created: false};
    const agreedUnitPrice = Number(
        sale.agreedUnitPrice || agreedTotal / agreedQuantity,
    );
    const mirrorId = transactionIdForAuction(listingId);
    const mirrorRef = db.collection("marketplace_transactions").doc(mirrorId);
    const listingRef = db.collection("public_listings").doc(listingId);
    const incomingRevision = sourceRevision(sale);
    return db.runTransaction(async (transaction) => {
      const mirrorSnapshot = await transaction.get(mirrorRef);
      const mirror = mirrorSnapshot.exists ? mirrorSnapshot.data() : null;
      if (!auctionMirrorShouldApply(mirror, sale)) {
        return {
          created: false,
          stale: true,
          transactionId: mirrorId,
          sourceRevision: incomingRevision,
        };
      }
      if (!mirrorSnapshot.exists) {
        const listingSnapshot = await transaction.get(listingRef);
        const listing = listingSnapshot.exists ? listingSnapshot.data() : {};
        const auctionStatus = String(sale.status || "pending_completion");
        transaction.create(mirrorRef, {
          listingId,
          listingTitle: String(
              listing.title || "Timed Buying purchase",
          ).slice(0, 240),
          buyerUid,
          sellerUid,
          source: "timed_buying_winner",
          paymentOrigin: "timed_buying",
          auctionTransactionId: listingId,
          status: marketplaceStatusForAuctionSync({}, auctionStatus),
          auctionSettlementStatus: auctionStatus,
          auctionSourceRevision: incomingRevision,
          buyerConfirmed: sale.buyerConfirmed === true,
          sellerConfirmed: sale.sellerConfirmed === true,
          agreedUnitPrice,
          agreedQuantity,
          agreedTotal,
          currency: marketplaceTransactionCurrency(
              sale.currency || listing.currency,
          ),
          priceBasis: String(
              sale.priceBasis || listing.priceBasis || "total",
          ),
          revision: 1,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        return {
          created: true,
          transactionId: mirrorId,
          sourceRevision: incomingRevision,
        };
      }
      const auctionStatus = String(sale.status || "pending_completion");
      transaction.set(mirrorRef, {
        status: marketplaceStatusForAuctionSync(mirror, auctionStatus),
        auctionSettlementStatus: auctionStatus,
        auctionSourceRevision: incomingRevision,
        buyerConfirmed: sale.buyerConfirmed === true,
        sellerConfirmed: sale.sellerConfirmed === true,
        ...(String(sale.reason || "").trim() ? {
          reason: String(sale.reason).slice(0, 2000),
        } : {}),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {
        created: false,
        synced: true,
        transactionId: mirrorId,
        sourceRevision: incomingRevision,
      };
    });
  }

  async function mirrorAuctionTransaction({listingId, transactionData}) {
    return applyAuctionMirror({listingId, transactionData});
  }

  async function syncAuctionTransaction({listingId, transactionData}) {
    return applyAuctionMirror({listingId, transactionData});
  }

  async function claimSellerRelease(transactionRef) {
    const proposedAttemptId = crypto.randomUUID();
    const proposedRecoveryLeaseId = crypto.randomUUID();
    return db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(transactionRef);
      if (!snapshot.exists) return {state: "missing"};
      const sale = snapshot.data();
      const payoutStatus = String(sale.sellerPayoutStatus || "");
      if (new Set([
        "release_invalidated_attempt_unknown",
        "release_invalidated_recovery_required",
        "release_invalidated_recovery_processing",
      ]).has(payoutStatus)) {
        const recoveryLeaseActive =
          payoutStatus === "release_invalidated_recovery_processing" &&
          Number(sale.sellerReleaseRecoveryLeaseExpiresAtMillis || 0) > now();
        const recoveryBackoffActive =
          Number(sale.sellerReleaseRecoveryNextAttemptAtMillis || 0) > now();
        if (recoveryLeaseActive || recoveryBackoffActive) {
          return {state: "in_progress"};
        }
        const attemptId = String(sale.sellerReleaseAttemptId || "");
        const transferId = String(
            sale.sellerReleaseInvalidatedTransferId || "",
        );
        const ambiguous = !transferId.startsWith("tr_") && attemptId &&
          String(sale.sellerReleaseRequestAttemptId || "") === attemptId;
        if (!transferId.startsWith("tr_") && !ambiguous) {
          return {state: "not_ready"};
        }
        transaction.set(transactionRef, {
          sellerPayoutStatus: "release_invalidated_recovery_processing",
          sellerReleaseRecoveryLeaseId: proposedRecoveryLeaseId,
          sellerReleaseRecoveryLeaseExpiresAtMillis:
            now() + releaseLeaseMillis,
          sellerReleaseRecoveryNextAttemptAtMillis: 0,
          sellerReleaseRecoveryAttemptCount: Math.max(
              0,
              Number(sale.sellerReleaseRecoveryAttemptCount || 0),
          ) + 1,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return {
          state: ambiguous ? "ambiguous_invalidated" : "recovery_required",
          sale,
          attemptId,
          recoveryLeaseId: proposedRecoveryLeaseId,
          transferId,
          amount: Math.max(0, Number(
              sale.sellerReleaseInvalidatedAmountMinor ||
              sale.sellerProceedsMinor || 0,
          )),
        };
      }
      const currentEpoch = financialEpoch(sale);
      const releaseActive = new Set([
        "release_processing",
        "release_reserved",
        "release_dispatching",
        "release_outcome_unknown",
      ]).has(payoutStatus);
      const leaseActive = releaseActive &&
        Number(sale.sellerReleaseLeaseExpiresAtMillis || 0) > now();
      if (leaseActive) return {state: "in_progress"};
      if (!releaseFinanciallyEligible(sale) ||
          (!releaseActive && !releaseEligible(sale))) {
        return {state: "not_ready"};
      }
      const reusableAttempt = releaseActive &&
        Number(sale.sellerReleaseFinancialEpoch) === currentEpoch &&
        String(sale.sellerReleaseAttemptId || "").trim();
      const attemptId = reusableAttempt ?
        String(sale.sellerReleaseAttemptId) : proposedAttemptId;
      const resumeDispatchUnknown = reusableAttempt && new Set([
        "release_dispatching",
        "release_outcome_unknown",
      ]).has(payoutStatus);
      const nextStatus = reusableAttempt ? payoutStatus : "release_processing";
      transaction.set(transactionRef, {
        sellerPayoutStatus: nextStatus,
        sellerReleaseAttemptId: attemptId,
        sellerReleaseFinancialEpoch: currentEpoch,
        sellerReleaseLeaseExpiresAtMillis: now() + releaseLeaseMillis,
        sellerReleaseAttemptCount:
          Math.max(0, Number(sale.sellerReleaseAttemptCount || 0)) + 1,
        sellerReleaseReservedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {
        state: "acquired",
        attemptId,
        financialEpoch: currentEpoch,
        resumeDispatchUnknown,
        sale,
      };
    });
  }

  async function markReleaseBlocked(transactionRef, claim, status) {
    await db.runTransaction(async (transaction) => {
      const current = await transaction.get(transactionRef);
      if (!current.exists || !releaseClaimMatches(current.data(), claim)) return;
      transaction.set(transactionRef, {
        sellerPayoutStatus: status,
        sellerReleaseLeaseExpiresAtMillis: 0,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    });
  }

  function storedReleaseRequest(sale, attemptId) {
    if (String(sale.sellerReleaseRequestAttemptId || "") !== attemptId) {
      return null;
    }
    const amount = Number(sale.sellerReleaseRequestAmountMinor || 0);
    const currency = String(sale.sellerReleaseRequestCurrency || "")
        .toLowerCase();
    const destination = String(sale.sellerReleaseRequestDestination || "");
    const chargeId = String(sale.sellerReleaseRequestChargeId || "");
    const transferGroup = String(
        sale.sellerReleaseRequestTransferGroup || "",
    );
    if (!Number.isSafeInteger(amount) || amount <= 0 ||
        !/^[a-z]{3}$/u.test(currency) ||
        !destination.startsWith("acct_") || !chargeId.startsWith("ch_") ||
        !transferGroup) {
      return null;
    }
    return {amount, currency, destination, chargeId, transferGroup};
  }

  async function reserveReleaseRequest({
    transactionRef,
    claim,
    amount,
    currency,
    destination,
    chargeId,
    transferGroup,
  }) {
    return db.runTransaction(async (transaction) => {
      const current = await transaction.get(transactionRef);
      if (!current.exists ||
          !releaseClaimMatches(current.data(), claim) ||
          !releaseFinanciallyEligible(current.data())) return null;
      const existing = storedReleaseRequest(current.data(), claim.attemptId);
      if (existing) {
        if (String(current.data().sellerPayoutStatus || "") ===
            "release_processing") {
          transaction.set(transactionRef, {
            sellerPayoutStatus: "release_reserved",
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
        }
        return existing;
      }
      const request = {
        amount,
        currency,
        destination,
        chargeId,
        transferGroup,
      };
      transaction.set(transactionRef, {
        sellerPayoutStatus: "release_reserved",
        sellerReleaseRequestAttemptId: claim.attemptId,
        sellerReleaseRequestAmountMinor: amount,
        sellerReleaseRequestCurrency: currency,
        sellerReleaseRequestDestination: destination,
        sellerReleaseRequestChargeId: chargeId,
        sellerReleaseRequestTransferGroup: transferGroup,
        sellerReleaseRequestReservedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return request;
    });
  }

  async function confirmReleaseDispatch({
    transactionRef,
    claim,
    request,
  }) {
    return db.runTransaction(async (transaction) => {
      const current = await transaction.get(transactionRef);
      if (!current.exists || !releaseClaimMatches(current.data(), claim) ||
          !releaseFinanciallyEligible(current.data())) return false;
      const sale = current.data();
      const expectedStatus = claim.resumeDispatchUnknown ?
        new Set(["release_dispatching", "release_outcome_unknown"]) :
        new Set(["release_reserved"]);
      if (!expectedStatus.has(String(sale.sellerPayoutStatus || ""))) {
        return false;
      }
      const stored = storedReleaseRequest(sale, claim.attemptId);
      if (!stored || stored.amount !== request.amount ||
          stored.currency !== request.currency ||
          stored.destination !== request.destination ||
          stored.chargeId !== request.chargeId ||
          stored.transferGroup !== request.transferGroup) return false;
      if (Number(sale.sellerProceedsMinor || 0) !== request.amount ||
          String(sale.stripeChargeId || "") !== request.chargeId ||
          marketplaceTransactionCurrency(sale.currency).toLowerCase() !==
            request.currency) return false;
      const providerRef = db.collection("payment_provider_accounts")
          .doc(String(sale.sellerUid || ""));
      const providerSnapshot = await transaction.get(providerRef);
      const provider = providerSnapshot.exists ? providerSnapshot.data() : {};
      if (!providerSnapshot.exists || provider.transferStatus !== "active" ||
          provider.sellerPayoutHold === true ||
          String(provider.stripeAccountId || "") !== request.destination) {
        return false;
      }
      transaction.set(transactionRef, {
        sellerPayoutStatus: "release_dispatching",
        sellerReleaseDispatchConfirmedAt: FieldValue.serverTimestamp(),
        sellerReleaseLeaseExpiresAtMillis: now() + releaseLeaseMillis,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return true;
    });
  }

  async function dispatchSellerTransfer({transactionId, attemptId, request}) {
    return requestStripe({
      secretKey: readStripeSecret(),
      path: "/v1/transfers",
      idempotencyKey:
        `pipebuyer-seller-release-${transactionId}-${attemptId}`,
      fields: {
        amount: request.amount,
        currency: request.currency,
        destination: request.destination,
        source_transaction: request.chargeId,
        transfer_group: request.transferGroup,
        "metadata[pipeBuyerTransactionId]": transactionId,
        "metadata[releaseAttemptId]": attemptId,
        "metadata[financialEpoch]": request.financialEpoch,
        "metadata[listingId]": request.listingId,
        "metadata[releaseReason]": "confirmed_physical_goods_completion",
      },
    });
  }

  async function recoverAmbiguousInvalidatedRelease({
    transactionId,
    transactionRef,
    claim,
  }) {
    const request = storedReleaseRequest(claim.sale, claim.attemptId);
    if (!request) {
      await markRecoveryFailed({
        transactionRef,
        claim,
        status: "release_invalidated_attempt_unknown",
        amount: 0,
        errorCode: "missing_release_request_snapshot",
      });
      return {recovered: false};
    }
    try {
      const transfer = await dispatchSellerTransfer({
        transactionId,
        attemptId: claim.attemptId,
        request: {
          ...request,
          financialEpoch: Number(claim.sale.sellerReleaseFinancialEpoch || 0),
          listingId: String(claim.sale.listingId || ""),
        },
      });
      const transferId = String(transfer.id || "");
      if (!transferId.startsWith("tr_")) {
        throw new Error("Stripe did not return a valid seller transfer.");
      }
      await db.runTransaction(async (transaction) => {
        const current = await transaction.get(transactionRef);
        if (!current.exists ||
            String(current.data().sellerReleaseAttemptId || "") !==
              claim.attemptId ||
            String(current.data().sellerReleaseRecoveryLeaseId || "") !==
              claim.recoveryLeaseId ||
            String(current.data().sellerPayoutStatus || "") !==
              "release_invalidated_recovery_processing") return;
        transaction.set(transactionRef, {
          sellerPayoutTransferIds: FieldValue.arrayUnion(transferId),
          sellerReleaseInvalidatedTransferId: transferId,
          sellerReleaseInvalidatedAmountMinor: request.amount,
          sellerReleaseInvalidatedAt: FieldValue.serverTimestamp(),
          sellerReleaseRecoveryOutstandingMinor: request.amount,
          financialHold: true,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      });
      return reverseInvalidatedRelease({
        transactionId,
        transactionRef,
        attemptId: claim.attemptId,
        recoveryLeaseId: claim.recoveryLeaseId,
        transferId,
        amount: request.amount,
      });
    } catch (error) {
      await markRecoveryFailed({
        transactionRef,
        claim,
        status: "release_invalidated_attempt_unknown",
        amount: request.amount,
        errorCode: error && error.stripeCode || error && error.code ||
          "provider_error",
      });
      return {recovered: false, error};
    }
  }

  async function markRecoveryFailed({
    transactionRef,
    claim,
    status,
    amount,
    errorCode,
  }) {
    await db.runTransaction(async (transaction) => {
      const current = await transaction.get(transactionRef);
      if (!current.exists ||
          String(current.data().sellerPayoutStatus || "") !==
            "release_invalidated_recovery_processing" ||
          String(current.data().sellerReleaseRecoveryLeaseId || "") !==
            claim.recoveryLeaseId) return;
      transaction.set(transactionRef, {
        sellerPayoutStatus: status,
        sellerReleaseRecoveryOutstandingMinor: Math.max(0, Number(amount || 0)),
        sellerReleaseRecoveryLeaseId: "",
        sellerReleaseRecoveryLeaseExpiresAtMillis: 0,
        sellerReleaseRecoveryNextAttemptAtMillis: now() + releaseLeaseMillis,
        financialHold: true,
        sellerReleaseRecoveryErrorCode:
          String(errorCode || "provider_error").slice(0, 120),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    });
  }

  async function reverseInvalidatedRelease({
    transactionId,
    transactionRef,
    attemptId,
    recoveryLeaseId,
    transferId,
    amount,
  }) {
    async function remainingTransferAmount() {
      const transfer = await requestStripe({
        secretKey: readStripeSecret(),
        path: `/v1/transfers/${encodeURIComponent(transferId)}`,
        method: "GET",
      });
      const original = Math.max(0, Number(transfer.amount || amount || 0));
      const reversed = Math.max(0, Number(transfer.amount_reversed || 0));
      return Math.max(0, original - reversed);
    }

    async function markRecovered(reversalId = "") {
      await db.runTransaction(async (transaction) => {
        const current = await transaction.get(transactionRef);
        if (!current.exists) return;
        const sale = current.data();
        if (String(sale.sellerReleaseInvalidatedTransferId || "") !==
            transferId ||
            String(sale.sellerPayoutStatus || "") !==
              "release_invalidated_recovery_processing" ||
            String(sale.sellerReleaseRecoveryLeaseId || "") !==
              recoveryLeaseId) return;
        transaction.set(transactionRef, {
          sellerPayoutStatus: sale.financialHold === true ?
            "blocked_financial_hold" : "pending_release",
          ...(reversalId ? {
            sellerReleaseInvalidationReversalIds:
              FieldValue.arrayUnion(reversalId),
          } : {}),
          sellerReleaseRecoveryOutstandingMinor: 0,
          sellerReleaseInvalidationRecoveredAt: FieldValue.serverTimestamp(),
          sellerReleaseRecoveryLeaseId: "",
          sellerReleaseRecoveryLeaseExpiresAtMillis: 0,
          sellerReleaseRecoveryNextAttemptAtMillis: 0,
          sellerReleaseLeaseExpiresAtMillis: 0,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      });
    }

    try {
      const remaining = await remainingTransferAmount();
      if (remaining === 0) {
        await markRecovered();
        return {recovered: true, reversalId: null, alreadyReversed: true};
      }
      const reversal = await requestStripe({
        secretKey: readStripeSecret(),
        path: `/v1/transfers/${encodeURIComponent(transferId)}/reversals`,
        idempotencyKey:
          `pipebuyer-seller-release-invalidation-${transactionId}-${attemptId}`,
        fields: {
          amount: remaining,
          "metadata[pipeBuyerTransactionId]": transactionId,
          "metadata[releaseAttemptId]": attemptId,
          "metadata[reason]": "financial_epoch_invalidated",
        },
      });
      const reversalId = String(reversal.id || "");
      if (!reversalId.startsWith("trr_")) {
        throw new Error("Stripe did not return a valid transfer reversal.");
      }
      await markRecovered(reversalId);
      return {recovered: true, reversalId};
    } catch (error) {
      try {
        if (await remainingTransferAmount() === 0) {
          await markRecovered();
          return {recovered: true, reversalId: null, alreadyReversed: true};
        }
      } catch (_) {
        // Preserve the original recovery error below. A retry will re-read the
        // transfer before attempting another idempotent reversal.
      }
      await markRecoveryFailed({
        transactionRef,
        claim: {recoveryLeaseId},
        status: "release_invalidated_recovery_required",
        amount,
        errorCode: error && error.stripeCode || error && error.code ||
          "provider_error",
      });
      return {recovered: false, error};
    }
  }

  async function releaseSellerFunds({transactionId}) {
    const transactionRef = db.collection("marketplace_transactions").doc(transactionId);
    const claim = await claimSellerRelease(transactionRef);
    if (claim.state === "missing") return {released: false, reason: "missing"};
    if (claim.state === "in_progress") {
      const error = new Error(
          "Seller release is already processing; retry after the lease expires.",
      );
      error.code = "seller_release_in_progress";
      throw error;
    }
    if (claim.state === "not_ready") {
      return {released: false, reason: "not_ready"};
    }
    if (claim.state === "ambiguous_invalidated") {
      const recovery = await recoverAmbiguousInvalidatedRelease({
        transactionId,
        transactionRef,
        claim,
      });
      return {
        released: false,
        reason: recovery.recovered ? "invalidated_release_reversed" :
          "invalidated_release_recovery_required",
      };
    }
    if (claim.state === "recovery_required") {
      const recovery = await reverseInvalidatedRelease({
        transactionId,
        transactionRef,
        attemptId: claim.attemptId,
        recoveryLeaseId: claim.recoveryLeaseId,
        transferId: claim.transferId,
        amount: claim.amount,
      });
      return {
        released: false,
        reason: recovery.recovered ? "invalidated_release_reversed" :
          "invalidated_release_recovery_required",
      };
    }
    const sale = claim.sale;
    const sellerProvider = await db.collection("payment_provider_accounts")
        .doc(String(sale.sellerUid || "")).get();
    if (!sellerProvider.exists || sellerProvider.data().transferStatus !== "active") {
      await markReleaseBlocked(
          transactionRef,
          claim,
          "blocked_seller_not_ready",
      );
      return {released: false, reason: "seller_not_ready"};
    }
    if (sellerProvider.data().sellerPayoutHold === true) {
      await markReleaseBlocked(
          transactionRef,
          claim,
          "blocked_financial_hold",
      );
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
      return db.runTransaction(async (transaction) => {
        const current = await transaction.get(transactionRef);
        if (!current.exists ||
            !releaseClaimMatches(current.data(), claim) ||
            !releaseFinanciallyEligible(current.data())) {
          return {released: false, reason: "financial_epoch_invalidated"};
        }
        transaction.set(transactionRef, {
          sellerPayoutStatus: "released",
          financialStatus: "settled",
          sellerReleaseLeaseExpiresAtMillis: 0,
          sellerReleasedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return {released: true, transferId: null};
      });
    }
    const transferGroup = String(
        sale.stripeTransferGroup || `PB_${transactionId}`,
    ).slice(0, 200);
    const releaseRequest = await reserveReleaseRequest({
      transactionRef,
      claim,
      amount,
      currency: marketplaceTransactionCurrency(sale.currency).toLowerCase(),
      destination,
      chargeId,
      transferGroup,
    });
    if (!releaseRequest) {
      return {released: false, reason: "financial_epoch_invalidated"};
    }
    if (typeof options.afterReleaseRequestReservation === "function") {
      await options.afterReleaseRequestReservation({
        transactionId,
        transactionRef,
        claim,
        request: releaseRequest,
      });
    }
    const dispatchConfirmed = await confirmReleaseDispatch({
      transactionRef,
      claim,
      request: releaseRequest,
    });
    if (!dispatchConfirmed) {
      return {released: false, reason: "financial_epoch_invalidated"};
    }
    const transfer = await dispatchSellerTransfer({
      transactionId,
      attemptId: claim.attemptId,
      request: {
        ...releaseRequest,
        financialEpoch: claim.financialEpoch,
        listingId: String(sale.listingId || ""),
      },
    });
    const transferId = String(transfer.id || "");
    if (!transferId.startsWith("tr_")) {
      throw new Error("Stripe did not return a valid seller transfer.");
    }
    const invalidationRecoveryLeaseId = crypto.randomUUID();
    const finalized = await db.runTransaction(async (transaction) => {
      const current = await transaction.get(transactionRef);
      if (current.exists &&
          String(current.data().stripeSellerTransferId || "") === transferId) {
        return true;
      }
      if (current.exists && releaseClaimMatches(current.data(), claim) &&
          releaseFinanciallyEligible(current.data())) {
        const currentSale = current.data();
        transaction.set(transactionRef, {
          stripeSellerTransferId: transferId,
          sellerPayoutTransferIds: FieldValue.arrayUnion(transferId),
          sellerPayoutStatus: "released",
          financialStatus: "settled",
          sellerReleaseLeaseExpiresAtMillis: 0,
          sellerReleasedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          ...(currentSale.paymentOrigin === "timed_buying" &&
              currentSale.auctionSettlementStatus === "completed" ?
            {status: "completed"} : {}),
        }, {merge: true});
        return true;
      }
      if (current.exists) {
        transaction.set(transactionRef, {
          sellerPayoutTransferIds: FieldValue.arrayUnion(transferId),
          sellerReleaseInvalidatedTransferId: transferId,
          sellerReleaseInvalidatedAmountMinor: amount,
          sellerReleaseInvalidatedAt: FieldValue.serverTimestamp(),
          sellerPayoutStatus: "release_invalidated_recovery_processing",
          sellerReleaseRecoveryLeaseId: invalidationRecoveryLeaseId,
          sellerReleaseRecoveryLeaseExpiresAtMillis:
            now() + releaseLeaseMillis,
          sellerReleaseRecoveryNextAttemptAtMillis: 0,
          sellerReleaseRecoveryOutstandingMinor: amount,
          financialHold: true,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
      return false;
    });
    if (finalized) return {released: true, transferId};
    const recovery = await reverseInvalidatedRelease({
      transactionId,
      transactionRef,
      attemptId: claim.attemptId,
      recoveryLeaseId: invalidationRecoveryLeaseId,
      transferId,
      amount,
    });
    return {
      released: false,
      transferId,
      reason: recovery.recovered ? "financial_epoch_invalidated_reversed" :
        "financial_epoch_invalidated_recovery_required",
    };
  }

  return {mirrorAuctionTransaction, syncAuctionTransaction, releaseSellerFunds};
}

module.exports = {
  DEFAULT_SELLER_RELEASE_LEASE_MILLIS,
  auctionMirrorShouldApply,
  createMarketplacePaymentLifecycle,
  financialEpoch,
  marketplaceStatusForAuctionSync,
  releaseClaimMatches,
  releaseEligible,
  releaseFinanciallyEligible,
  sourceRevision,
  transactionIdForAuction,
};
