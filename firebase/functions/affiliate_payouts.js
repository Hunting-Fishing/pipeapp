"use strict";

const {stripeSecretKey} = require("./stripe_marketplace_commands");
const {stripeFormRequest} = require("./stripe_checkout_commands");

function isContingentDisputeTransaction(data) {
  if (!data || typeof data !== "object") return false;
  return data.financialStatus === "disputed" ||
    (Array.isArray(data.activeDisputeIds) && data.activeDisputeIds.length > 0);
}

function createAffiliatePayouts(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;

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
    return db.runTransaction(async (transaction) => {
      const current = await transaction.get(document.ref);
      if (!current.exists) return null;
      const data = current.data();
      const status = String(data.status || "");
      const eligibleAfter = data.eligibleAfter;
      const eligibleMillis = eligibleAfter &&
        typeof eligibleAfter.toMillis === "function" ?
        eligibleAfter.toMillis() : Number.POSITIVE_INFINITY;
      if (![
        "pending_refund_window",
        "payout_retry",
        "eligible_payout_setup_required",
        "eligible_financial_review_required",
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
        payoutAttemptedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return {...data, ledgerId: document.id};
    });
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
    const referrerUid = String(ledger.referrerUid || "").trim();
    const adjusted = Number(ledger.adjustedCommissionMinor);
    const grossAmount = Number.isSafeInteger(adjusted) ?
      adjusted : Number(ledger.commissionMinor || 0);
    const currency = String(ledger.currency || "CAD").toUpperCase();
    if (!referrerUid || !Number.isSafeInteger(grossAmount)) {
      await document.ref.set({
        status: "invalid",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return "invalid";
    }
    if (grossAmount <= 0) {
      await document.ref.set({
        status: "void_financial_event",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return "voided";
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

    const provider = await db.collection("payment_provider_accounts")
        .doc(referrerUid).get();
    if (!provider.exists || provider.data().transferStatus !== "active" ||
        !String(provider.data().stripeAccountId || "").startsWith("acct_")) {
      await document.ref.set({
        status: "eligible_payout_setup_required",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return "needs_onboarding";
    }
    try {
      const amount = recovery.payableMinor;
      const transfer = await stripeFormRequest({
        secretKey: stripeSecretKey.value(),
        path: "/v1/transfers",
        idempotencyKey: `pipebuyer-affiliate-${document.id}-${amount}`,
        fields: {
          amount,
          currency: currency.toLowerCase(),
          destination: String(provider.data().stripeAccountId),
          "metadata[pipeBuyerAffiliateLedgerId]": document.id,
          "metadata[referrerUid]": referrerUid,
          "metadata[commissionType]":
            String(ledger.type || "affiliate_commission"),
        },
      });
      await document.ref.set({
        status: "paid",
        contingentDisputeHold: false,
        grossEligibleCommissionMinor: grossAmount,
        recoveryOffsetMinor: recovery.appliedMinor,
        paidCommissionMinor: amount,
        stripeTransferId: String(transfer.id || ""),
        paidAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return "paid";
    } catch (error) {
      console.error("Affiliate transfer failed", {
        ledgerId: document.id,
        stripeStatus: error.stripeStatus || null,
        stripeCode: error.stripeCode || null,
      });
      await document.ref.set({
        status: "payout_retry",
        payoutErrorCode:
          String(error.stripeCode || "provider_error").slice(0, 120),
        nextRetryAt: Timestamp.fromMillis(Date.now() + 24 * 60 * 60 * 1000),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
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
    processEligibleAffiliatePayouts,
  };
}

module.exports = {
  createAffiliatePayouts,
  isContingentDisputeTransaction,
};
