"use strict";

const {stripeSecretKey} = require("./stripe_marketplace_commands");
const {stripeFormRequest} = require("./stripe_checkout_commands");

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
      const eligibleMillis = eligibleAfter && typeof eligibleAfter.toMillis === "function" ?
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
        const retryMillis = nextRetryAt && typeof nextRetryAt.toMillis === "function" ?
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

  async function processLedger(document) {
    const ledger = await claimLedger(document);
    if (!ledger) return "skipped";
    const referrerUid = String(ledger.referrerUid || "").trim();
    const amount = Number(ledger.commissionMinor || 0);
    const currency = String(ledger.currency || "CAD").toLowerCase();
    if (!referrerUid || !Number.isSafeInteger(amount) || amount <= 0) {
      await document.ref.set({
        status: "invalid",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return "invalid";
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
      const transfer = await stripeFormRequest({
        secretKey: stripeSecretKey.value(),
        path: "/v1/transfers",
        idempotencyKey: `pipebuyer-affiliate-${document.id}`,
        fields: {
          amount,
          currency,
          destination: String(provider.data().stripeAccountId),
          "metadata[pipeBuyerAffiliateLedgerId]": document.id,
          "metadata[referrerUid]": referrerUid,
          "metadata[commissionType]": String(ledger.type || "affiliate_commission"),
        },
      });
      await document.ref.set({
        status: "paid",
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
        payoutErrorCode: String(error.stripeCode || "provider_error").slice(0, 120),
        nextRetryAt: Timestamp.fromMillis(Date.now() + 24 * 60 * 60 * 1000),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return "retry";
    }
  }

  async function processEligibleAffiliatePayouts() {
    const readiness = await payoutReadiness();
    if (!readiness.enabled ||
        !["sandbox", "production"].includes(readiness.stripeMode)) {
      return {enabled: false, processed: 0};
    }
    const snapshot = await db.collection("affiliate_commission_ledger")
        .where("eligibleAfter", "<=", Timestamp.now())
        .limit(100)
        .get();
    const counts = {paid: 0, retry: 0, needs_onboarding: 0, skipped: 0, invalid: 0};
    for (const document of snapshot.docs) {
      const result = await processLedger(document);
      counts[result] = Number(counts[result] || 0) + 1;
    }
    return {
      enabled: true,
      processed: snapshot.size,
      counts,
    };
  }

  return {processEligibleAffiliatePayouts};
}

module.exports = {createAffiliatePayouts};
