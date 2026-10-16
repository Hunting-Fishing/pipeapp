"use strict";

const crypto = require("node:crypto");
const {stripeSecretKey} = require("./stripe_marketplace_commands");
const {stripeFormRequest} = require("./stripe_checkout_commands");
const {
  marketplaceTransactionCurrency,
} = require("./marketplace_command_policy");

const PAYOUT_RETRY_DELAY_MILLIS = 24 * 60 * 60 * 1000;
const PAYOUT_DISPATCH_LEASE_MILLIS = 10 * 60 * 1000;

function affiliatePayoutIdempotencyKey(ledgerId, attemptId) {
  return `pipebuyer-affiliate-${ledgerId}-${attemptId}`;
}

function affiliateTransferFailureIsDefinitive(error) {
  const details = error && error.details && typeof error.details === "object" ?
    error.details : {};
  if (typeof details.stripeRequestDefinitiveFailure === "boolean") {
    return details.stripeRequestDefinitiveFailure;
  }
  if (typeof error?.stripeRequestDefinitiveFailure === "boolean") {
    return error.stripeRequestDefinitiveFailure;
  }
  const status = Number(error && error.stripeStatus ||
    details.stripeHttpStatus || 0);
  const code = String(error && error.stripeCode || details.stripeCode || "")
      .toLowerCase();
  return status >= 400 && status < 500 &&
    !new Set([408, 409, 424, 429]).has(status) &&
    !new Set(["idempotency_error", "idempotency_key_in_use"]).has(code);
}

function storedPayoutRequest(data, ledgerId) {
  const attemptId = String(data && data.payoutAttemptId || "").trim();
  const idempotencyKey = String(
      data && data.payoutRequestIdempotencyKey || "",
  ).trim();
  const snapshot = data && data.payoutRequestSnapshot;
  const amount = Number(snapshot && snapshot.amountMinor || 0);
  const currency = String(snapshot && snapshot.currency || "").toLowerCase();
  const destination = String(snapshot && snapshot.destination || "").trim();
  const referrerUid = String(snapshot && snapshot.referrerUid || "").trim();
  const commissionType = String(
      snapshot && snapshot.commissionType || "affiliate_commission",
  );
  if (!attemptId ||
      idempotencyKey !== affiliatePayoutIdempotencyKey(ledgerId, attemptId) ||
      !Number.isSafeInteger(amount) || amount <= 0 ||
      !/^[a-z]{3}$/.test(currency) ||
      !destination.startsWith("acct_") || !referrerUid) return null;
  return {
    attemptId,
    idempotencyKey,
    amount,
    currency,
    destination,
    referrerUid,
    commissionType,
  };
}

function isContingentDisputeTransaction(data) {
  if (!data || typeof data !== "object") return false;
  return data.financialStatus === "disputed" ||
    (Array.isArray(data.activeDisputeIds) && data.activeDisputeIds.length > 0);
}

function createAffiliatePayouts(admin, options = {}) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;
  const requestStripe = options.stripeRequest || stripeFormRequest;
  const readStripeSecret = options.stripeSecret || (() => stripeSecretKey.value());

  async function payoutReadiness() {
    const snapshot = await db.collection("platform_configuration")
        .doc("payment_provider_readiness").get();
    const data = snapshot.exists ? snapshot.data() : {};
    return {
      enabled: data.affiliatePayoutsEnabled === true,
      economicsReady: data.affiliatePayoutEconomicsReady === true,
      stripeMode: String(data.stripeMode || "disabled"),
    };
  }

  async function claimLedger(document) {
    const payoutAttemptId = crypto.randomUUID();
    return db.runTransaction(async (transaction) => {
      const current = await transaction.get(document.ref);
      if (!current.exists) return null;
      const data = current.data();
      const status = String(data.status || "");
      const nowMillis = Date.now();
      const dispatchLeaseExpiresAtMillis = Math.max(
          0,
          Number(data.payoutDispatchLeaseExpiresAtMillis || 0),
      );
      const resumesUnknownOutcome = status === "payout_outcome_unknown" ||
        status === "payout_dispatching" &&
          dispatchLeaseExpiresAtMillis > 0 &&
          dispatchLeaseExpiresAtMillis <= nowMillis;
      const resumesReservedRequest = status === "payout_reserved" &&
        dispatchLeaseExpiresAtMillis > 0 &&
        dispatchLeaseExpiresAtMillis <= nowMillis;
      if (resumesUnknownOutcome || resumesReservedRequest) {
        const nextRetryAt = data.nextRetryAt;
        const retryMillis = nextRetryAt &&
          typeof nextRetryAt.toMillis === "function" ?
          nextRetryAt.toMillis() : 0;
        if (retryMillis > nowMillis) return null;
        const request = storedPayoutRequest(data, document.id);
        if (!request) {
          transaction.update(document.ref, {
            status: "eligible_financial_review_required",
            payoutErrorCode: "missing_immutable_request_snapshot",
            updatedAt: FieldValue.serverTimestamp(),
          });
          return null;
        }
        transaction.update(document.ref, {
          status: resumesUnknownOutcome ?
            "payout_dispatching" : "payout_reserved",
          payoutDispatchLeaseExpiresAtMillis:
            nowMillis + PAYOUT_DISPATCH_LEASE_MILLIS,
          payoutOutcomeResolutionAttempts: FieldValue.increment(1),
          payoutAttemptedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        return {
          ...data,
          ledgerId: document.id,
          payoutAttemptId: request.attemptId,
          payoutRequest: request,
          resumeAmbiguous: resumesUnknownOutcome,
          resumeReserved: resumesReservedRequest,
        };
      }
      const eligibleAfter = data.eligibleAfter;
      const eligibleMillis = eligibleAfter &&
        typeof eligibleAfter.toMillis === "function" ?
        eligibleAfter.toMillis() : Number.POSITIVE_INFINITY;
      if (![
        "pending_refund_window",
        "payout_retry",
        "eligible_payout_setup_required",
      ].includes(status) || eligibleMillis > Date.now()) {
        return null;
      }
      if (status === "payout_retry") {
        const nextRetryAt = data.nextRetryAt;
        const retryMillis = nextRetryAt &&
          typeof nextRetryAt.toMillis === "function" ?
          nextRetryAt.toMillis() : 0;
        if (retryMillis > Date.now()) return null;
      }
      transaction.update(document.ref, {
        status: "paying",
        payoutAttemptId,
        payoutDispatchLeaseExpiresAtMillis: 0,
        payoutAttemptedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return {...data, ledgerId: document.id, payoutAttemptId};
    });
  }

  async function authorizePayout({
    document,
    ledger,
    referrerUid,
    amount,
    currency,
  }) {
    const providerRef = db.collection("payment_provider_accounts")
        .doc(referrerUid);
    return db.runTransaction(async (transaction) => {
      const current = await transaction.get(document.ref);
      const provider = await transaction.get(providerRef);
      if (!current.exists ||
          String(current.data().status || "") !== "paying" ||
          String(current.data().payoutAttemptId || "") !==
            ledger.payoutAttemptId) {
        return {authorized: false, reason: "stale_claim"};
      }
      const currentLedger = current.data();
      if (Number(currentLedger.financialExposureMinor || 0) > 0 ||
          currentLedger.contingentDisputeHold === true ||
          provider.exists && provider.data().affiliatePayoutHold === true) {
        transaction.update(document.ref, {
          status: "eligible_financial_review_required",
          contingentDisputeHold: true,
          updatedAt: FieldValue.serverTimestamp(),
        });
        return {authorized: false, reason: "financial_hold"};
      }
      const providerData = provider.exists ? provider.data() : {};
      const destination = String(providerData.stripeAccountId || "");
      if (providerData.transferStatus !== "active" ||
          !destination.startsWith("acct_")) {
        transaction.update(document.ref, {
          status: "eligible_payout_setup_required",
          updatedAt: FieldValue.serverTimestamp(),
        });
        return {authorized: false, reason: "needs_onboarding"};
      }
      const request = {
        attemptId: ledger.payoutAttemptId,
        idempotencyKey: affiliatePayoutIdempotencyKey(
            document.id,
            ledger.payoutAttemptId,
        ),
        amount,
        currency: currency.toLowerCase(),
        destination,
        referrerUid,
        commissionType: String(ledger.type || "affiliate_commission"),
      };
      transaction.update(document.ref, {
        status: "payout_reserved",
        payoutDispatchAmountMinor: amount,
        payoutRequestIdempotencyKey: request.idempotencyKey,
        payoutRequestSnapshot: {
          amountMinor: request.amount,
          currency: request.currency,
          destination: request.destination,
          referrerUid: request.referrerUid,
          commissionType: request.commissionType,
        },
        payoutRequestReservedAt: FieldValue.serverTimestamp(),
        payoutDispatchLeaseExpiresAtMillis:
          Date.now() + PAYOUT_DISPATCH_LEASE_MILLIS,
        updatedAt: FieldValue.serverTimestamp(),
      });
      return {authorized: true, request};
    });
  }

  async function confirmPayoutDispatch({document, attemptId, resolveUnknown}) {
    return db.runTransaction(async (transaction) => {
      const current = await transaction.get(document.ref);
      const expectedStatus = resolveUnknown ?
        "payout_dispatching" : "payout_reserved";
      if (!current.exists ||
          String(current.data().status || "") !== expectedStatus ||
          String(current.data().payoutAttemptId || "") !== attemptId) {
        return {authorized: false, reason: "stale_claim"};
      }
      const data = current.data();
      const request = storedPayoutRequest(data, document.id);
      if (!request) {
        transaction.update(document.ref, {
          status: "eligible_financial_review_required",
          payoutErrorCode: "missing_immutable_request_snapshot",
          payoutDispatchLeaseExpiresAtMillis: 0,
          updatedAt: FieldValue.serverTimestamp(),
        });
        return {authorized: false, reason: "financial_hold"};
      }
      if (!resolveUnknown &&
          (Number(data.financialExposureMinor || 0) > 0 ||
           data.contingentDisputeHold === true)) {
        transaction.update(document.ref, {
          status: "eligible_financial_review_required",
          contingentDisputeHold: true,
          payoutDispatchLeaseExpiresAtMillis: 0,
          updatedAt: FieldValue.serverTimestamp(),
        });
        return {authorized: false, reason: "financial_hold"};
      }
      transaction.update(document.ref, {
        status: "payout_dispatching",
        payoutDispatchCheckedAt: FieldValue.serverTimestamp(),
        payoutDispatchStartedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return {authorized: true, request};
    });
  }

  async function finalizePayout({
    document,
    attemptId,
    transfer,
    request,
    grossAmount,
    recoveryAppliedMinor,
  }) {
    return db.runTransaction(async (transaction) => {
      const current = await transaction.get(document.ref);
      if (!current.exists ||
          String(current.data().payoutAttemptId || "") !== attemptId) {
        return false;
      }
      const data = current.data();
      const storedRequest = storedPayoutRequest(data, document.id);
      if (!storedRequest ||
          storedRequest.idempotencyKey !== request.idempotencyKey) return false;
      const staleState = String(data.status || "") !== "payout_dispatching";
      const originalCommission = Math.max(
          0,
          Number(data.commissionMinor || grossAmount || 0),
      );
      const adjustedCommission = Number.isSafeInteger(
          Number(data.adjustedCommissionMinor),
      ) ? Math.max(0, Number(data.adjustedCommissionMinor)) :
        originalCommission;
      const exposureRecovery = Math.max(
          0,
          Number(data.financialRecoveryTargetMinor ||
            originalCommission - adjustedCommission),
      );
      const targetRecovery = exposureRecovery > 0 ? exposureRecovery :
        staleState ? request.amount : 0;
      let amountDue = 0;
      if (targetRecovery > 0 && request.referrerUid) {
        const transactionId = String(data.transactionId || "").trim();
        const obligationRef = db.collection("affiliate_recovery_obligations")
            .doc(`marketplace_${transactionId}_${request.referrerUid}`);
        const obligation = await transaction.get(obligationRef);
        const recovered = Math.max(0, Number(
            obligation.exists ? obligation.data().recoveredMinor || 0 : 0,
        ));
        amountDue = Math.max(0, targetRecovery - recovered);
        transaction.set(obligationRef, {
          type: "marketplace_commission_recovery",
          transactionId,
          ledgerId: document.id,
          referrerUid: request.referrerUid,
          currency: request.currency.toUpperCase(),
          targetRecoveryMinor: targetRecovery,
          recoveredMinor: recovered,
          amountDueMinor: amountDue,
          reason: String(
              data.financialAdjustmentReason ||
              "affiliate_payout_state_changed_during_dispatch",
          ),
          status: amountDue > 0 ? "open" : "resolved",
          updatedAt: FieldValue.serverTimestamp(),
          ...(amountDue === 0 ? {
            resolvedAt: FieldValue.serverTimestamp(),
          } : {}),
        }, {merge: true});
        if (amountDue > 0) {
          transaction.set(
              db.collection("payment_provider_accounts")
                  .doc(request.referrerUid),
              {
                affiliatePayoutHold: true,
                affiliatePayoutHoldReason:
                  "affiliate_financial_recovery_required",
                affiliatePayoutHoldUpdatedAt: FieldValue.serverTimestamp(),
              },
              {merge: true},
          );
        }
      }
      transaction.set(document.ref, {
        status: "paid",
        contingentDisputeHold: amountDue > 0 ||
          Number(data.financialExposureMinor || 0) > 0,
        grossEligibleCommissionMinor: grossAmount,
        recoveryOffsetMinor: recoveryAppliedMinor,
        paidCommissionMinor: request.amount,
        stripeTransferId: String(transfer.id || ""),
        payoutDispatchLeaseExpiresAtMillis: 0,
        payoutOutcomeResolvedAt: FieldValue.serverTimestamp(),
        paidAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return true;
    });
  }

  async function recordPayoutFailure({document, attemptId, error}) {
    const definitive = affiliateTransferFailureIsDefinitive(error);
    await db.runTransaction(async (transaction) => {
      const current = await transaction.get(document.ref);
      if (!current.exists ||
          String(current.data().payoutAttemptId || "") !== attemptId) return;
      const data = current.data();
      const financialHold =
        Number(data.financialExposureMinor || 0) > 0 ||
        data.contingentDisputeHold === true;
      let hasOtherOpen = false;
      if (definitive && financialHold) {
        const referrerUid = String(data.referrerUid || "").trim();
        const transactionId = String(data.transactionId || "").trim();
        if (referrerUid && transactionId) {
          const obligationRef = db.collection("affiliate_recovery_obligations")
              .doc(`marketplace_${transactionId}_${referrerUid}`);
          const openObligations = await transaction.get(
              db.collection("affiliate_recovery_obligations")
                  .where("referrerUid", "==", referrerUid)
                  .where("status", "==", "open")
                  .limit(100),
          );
          hasOtherOpen = openObligations.docs.some((item) =>
            item.id !== obligationRef.id,
          );
          transaction.set(obligationRef, {
            amountDueMinor: 0,
            status: "resolved",
            reason: "affiliate_transfer_definitively_failed",
            resolvedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
          transaction.set(
              db.collection("payment_provider_accounts").doc(referrerUid),
              {
                affiliatePayoutHold: hasOtherOpen,
                affiliatePayoutHoldReason: hasOtherOpen ?
                  "affiliate_recovery_obligation" : null,
                affiliatePayoutHoldUpdatedAt: FieldValue.serverTimestamp(),
              },
              {merge: true},
          );
        }
      }
      transaction.set(document.ref, {
        status: definitive ? financialHold ?
          "eligible_financial_review_required" : "payout_retry" :
          "payout_outcome_unknown",
        payoutFailureDefinitive: definitive,
        payoutErrorCode:
          String(error && error.stripeCode ||
            error && error.details && error.details.stripeCode ||
            "provider_error").slice(0, 120),
        payoutDispatchLeaseExpiresAtMillis: 0,
        nextRetryAt: Timestamp.fromMillis(
            Date.now() + PAYOUT_RETRY_DELAY_MILLIS,
        ),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    });
    return definitive;
  }

  async function obligationIsContingent(data) {
    const transactionId = String(data && data.transactionId || "").trim();
    if (!transactionId) return false;
    const transactionSnapshot = await db.collection("marketplace_transactions")
        .doc(transactionId)
        .get();
    if (!transactionSnapshot.exists) return false;
    return isContingentDisputeTransaction(transactionSnapshot.data());
  }

  async function applyRecoveryObligations(referrerUid, availableMinor, currency) {
    let remaining = Math.max(0, Number(availableMinor || 0));
    let applied = 0;
    let contingentDispute = false;
    const obligations = await db.collection("affiliate_recovery_obligations")
        .where("referrerUid", "==", referrerUid)
        .where("status", "==", "open")
        .limit(100)
        .get();
    for (const document of obligations.docs) {
      if (remaining <= 0) break;
      const obligation = document.data();
      if (await obligationIsContingent(obligation)) {
        contingentDispute = true;
        continue;
      }
      const result = await db.runTransaction(async (transaction) => {
        const current = await transaction.get(document.ref);
        if (!current.exists || current.data().status !== "open") return 0;
        const data = current.data();
        if (String(data.currency || currency).toUpperCase() !== currency.toUpperCase()) {
          return 0;
        }
        const due = Math.max(0, Number(data.amountDueMinor || 0));
        if (!Number.isSafeInteger(due) || due <= 0) {
          transaction.update(document.ref, {
            status: "resolved",
            resolvedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          });
          return 0;
        }
        const offset = Math.min(remaining, due);
        const nextDue = due - offset;
        transaction.update(document.ref, {
          recoveredMinor: FieldValue.increment(offset),
          amountDueMinor: nextDue,
          status: nextDue === 0 ? "resolved" : "open",
          lastRecoverySource: "future_affiliate_commission",
          updatedAt: FieldValue.serverTimestamp(),
          ...(nextDue === 0 ? {resolvedAt: FieldValue.serverTimestamp()} : {}),
        });
        return offset;
      });
      if (result > 0) {
        remaining -= result;
        applied += result;
      }
    }

    const stillOpen = await db.collection("affiliate_recovery_obligations")
        .where("referrerUid", "==", referrerUid)
        .where("status", "==", "open")
        .limit(100)
        .get();
    let finalizedDebtOpen = false;
    let contingentDebtOpen = contingentDispute;
    for (const document of stillOpen.docs) {
      if (await obligationIsContingent(document.data())) {
        contingentDebtOpen = true;
      } else {
        finalizedDebtOpen = true;
      }
    }
    const anyHold = finalizedDebtOpen || contingentDebtOpen;
    await db.collection("payment_provider_accounts").doc(referrerUid).set({
      affiliatePayoutHold: anyHold,
      affiliatePayoutHoldReason: contingentDebtOpen ?
        "open_dispute_contingent_exposure" :
        finalizedDebtOpen ? "affiliate_recovery_obligation" : null,
      affiliatePayoutHoldUpdatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return {
      appliedMinor: applied,
      payableMinor: remaining,
      unresolved: finalizedDebtOpen,
      contingentDispute: contingentDebtOpen,
    };
  }

  async function processLedger(document) {
    const ledger = await claimLedger(document);
    if (!ledger) return "skipped";
    const referrerUid = String(
        ledger.resumeAmbiguous || ledger.resumeReserved ?
          ledger.payoutRequest && ledger.payoutRequest.referrerUid :
          ledger.referrerUid,
    ).trim();
    const adjusted = Number(ledger.adjustedCommissionMinor);
    const grossAmount = ledger.resumeAmbiguous || ledger.resumeReserved ? Math.max(
        Number(ledger.commissionMinor || 0),
        Number(ledger.payoutRequest && ledger.payoutRequest.amount || 0),
    ) : Number.isSafeInteger(adjusted) ?
      adjusted : Number(ledger.commissionMinor || 0);
    let currency;
    try {
      currency = marketplaceTransactionCurrency(
          ledger.resumeAmbiguous || ledger.resumeReserved ?
            ledger.payoutRequest && ledger.payoutRequest.currency :
            ledger.currency,
      );
    } catch (_) {
      await document.ref.set({
        status: "invalid",
        payoutErrorCode: "missing_or_unsupported_currency",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return "invalid";
    }
    if (!referrerUid || !Number.isSafeInteger(grossAmount)) {
      await document.ref.set({
        status: "invalid",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return "invalid";
    }
    if (!ledger.resumeAmbiguous && !ledger.resumeReserved && grossAmount <= 0) {
      await document.ref.set({
        status: "void_financial_event",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return "voided";
    }

    if (ledger.resumeAmbiguous || ledger.resumeReserved) {
      const dispatch = await confirmPayoutDispatch({
        document,
        attemptId: ledger.payoutAttemptId,
        resolveUnknown: ledger.resumeAmbiguous,
      });
      if (!dispatch.authorized) return "financial_hold";
      if (typeof options.afterPayoutDispatchCheck === "function") {
        await options.afterPayoutDispatchCheck({
          document,
          ledger,
          request: dispatch.request,
          resolvingUnknown: ledger.resumeAmbiguous,
        });
      }
      try {
        const transfer = await requestStripe({
          secretKey: readStripeSecret(),
          path: "/v1/transfers",
          idempotencyKey: dispatch.request.idempotencyKey,
          fields: {
            amount: dispatch.request.amount,
            currency: dispatch.request.currency,
            destination: dispatch.request.destination,
            "metadata[pipeBuyerAffiliateLedgerId]": document.id,
            "metadata[referrerUid]": dispatch.request.referrerUid,
            "metadata[commissionType]": dispatch.request.commissionType,
          },
        });
        if (!String(transfer && transfer.id || "").startsWith("tr_")) {
          const error = new Error(
              "Stripe returned an ambiguous affiliate transfer response.",
          );
          error.stripeCode = "invalid_transfer_response";
          throw error;
        }
        const finalized = await finalizePayout({
          document,
          attemptId: ledger.payoutAttemptId,
          transfer,
          request: dispatch.request,
          grossAmount,
          recoveryAppliedMinor: Math.max(
              0,
              Number(ledger.recoveryOffsetMinor || 0),
          ),
        });
        if (!finalized) {
          const error = new Error(
              "Affiliate transfer succeeded but local state became stale.",
          );
          error.stripeCode = "stale_payout_finalization";
          throw error;
        }
        return "paid";
      } catch (error) {
        console.error("Affiliate transfer outcome remains unresolved", {
          ledgerId: document.id,
          stripeStatus: error.stripeStatus || null,
          stripeCode: error.stripeCode || null,
        });
        await recordPayoutFailure({
          document,
          attemptId: ledger.payoutAttemptId,
          error,
        });
        return "retry";
      }
    }

    const recovery = await applyRecoveryObligations(
        referrerUid,
        grossAmount,
        currency,
    );
    if (recovery.appliedMinor > 0) {
      await document.ref.set({
        recoveryOffsetMinor: recovery.appliedMinor,
        postRecoveryPayableMinor: recovery.payableMinor,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    if (recovery.contingentDispute) {
      await document.ref.set({
        status: "eligible_financial_review_required",
        contingentDisputeHold: true,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return "financial_hold";
    }
    if (recovery.payableMinor <= 0) {
      await document.ref.set({
        status: "applied_to_financial_recovery",
        paidCommissionMinor: 0,
        recoveredCommissionMinor: recovery.appliedMinor,
        settledAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return "recovered";
    }
    if (recovery.unresolved) {
      await document.ref.set({
        status: "eligible_financial_review_required",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return "financial_hold";
    }

    if (typeof options.beforePayoutAuthorization === "function") {
      await options.beforePayoutAuthorization({document, ledger});
    }
    const amount = recovery.payableMinor;
    const authorization = await authorizePayout({
      document,
      ledger,
      referrerUid,
      amount,
      currency,
    });
    if (!authorization.authorized) {
      return authorization.reason === "needs_onboarding" ?
        "needs_onboarding" : "financial_hold";
    }
    if (typeof options.afterPayoutAuthorization === "function") {
      await options.afterPayoutAuthorization({document, ledger, amount});
    }
    const dispatch = await confirmPayoutDispatch({
      document,
      attemptId: ledger.payoutAttemptId,
      resolveUnknown: false,
    });
    if (!dispatch.authorized) return "financial_hold";
    if (typeof options.afterPayoutDispatchCheck === "function") {
      await options.afterPayoutDispatchCheck({
        document,
        ledger,
        request: dispatch.request,
        resolvingUnknown: false,
      });
    }
    try {
      const transfer = await requestStripe({
        secretKey: readStripeSecret(),
        path: "/v1/transfers",
        idempotencyKey: dispatch.request.idempotencyKey,
        fields: {
          amount: dispatch.request.amount,
          currency: dispatch.request.currency,
          destination: dispatch.request.destination,
          "metadata[pipeBuyerAffiliateLedgerId]": document.id,
          "metadata[referrerUid]": dispatch.request.referrerUid,
          "metadata[commissionType]": dispatch.request.commissionType,
        },
      });
      if (!String(transfer && transfer.id || "").startsWith("tr_")) {
        const error = new Error(
            "Stripe returned an ambiguous affiliate transfer response.",
        );
        error.stripeCode = "invalid_transfer_response";
        throw error;
      }
      const finalized = await finalizePayout({
        document,
        attemptId: ledger.payoutAttemptId,
        transfer,
        request: dispatch.request,
        grossAmount,
        recoveryAppliedMinor: recovery.appliedMinor,
      });
      if (!finalized) {
        const error = new Error(
            "Affiliate transfer succeeded but local state became stale.",
        );
        error.stripeCode = "stale_payout_finalization";
        throw error;
      }
      return "paid";
    } catch (error) {
      console.error("Affiliate transfer failed", {
        ledgerId: document.id,
        stripeStatus: error.stripeStatus || null,
        stripeCode: error.stripeCode || null,
      });
      await recordPayoutFailure({
        document,
        attemptId: ledger.payoutAttemptId,
        error,
      });
      return "retry";
    }
  }

  async function processEligibleAffiliatePayouts() {
    const readiness = await payoutReadiness();
    if (!readiness.enabled ||
        !readiness.economicsReady ||
        !["sandbox", "production"].includes(readiness.stripeMode)) {
      return {
        enabled: false,
        economicsReady: readiness.economicsReady,
        processed: 0,
      };
    }
    const snapshot = await db.collection("affiliate_commission_ledger")
        .where("eligibleAfter", "<=", Timestamp.now())
        .limit(100)
        .get();
    const counts = {
      paid: 0,
      recovered: 0,
      retry: 0,
      needs_onboarding: 0,
      financial_hold: 0,
      voided: 0,
      skipped: 0,
      invalid: 0,
    };
    for (const document of snapshot.docs) {
      const result = await processLedger(document);
      counts[result] = Number(counts[result] || 0) + 1;
    }
    return {
      enabled: true,
      economicsReady: true,
      processed: snapshot.size,
      counts,
    };
  }

  return {
    applyRecoveryObligations,
    payoutReadiness,
    processLedger,
    processEligibleAffiliatePayouts,
  };
}

module.exports = {
  affiliateTransferFailureIsDefinitive,
  createAffiliatePayouts,
  isContingentDisputeTransaction,
};
