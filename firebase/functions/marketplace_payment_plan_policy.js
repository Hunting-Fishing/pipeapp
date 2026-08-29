"use strict";

const MIN_PAYMENT_PART_MINOR = 100;
const CLOSED_TRANSACTION_STATUSES = new Set([
  "completed",
  "cancelled",
  "disputed",
  "buyer_default_reported",
  "seller_default_reported",
]);
const PAYMENT_STARTED_STATUSES = new Set([
  "checkout_created",
  "processing",
  "partially_paid",
  "paid",
]);

class PaymentPlanPolicyError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "PaymentPlanPolicyError";
    this.code = code;
  }
}

function safeMinor(value, field) {
  const amount = Number(value);
  if (!Number.isSafeInteger(amount) || amount <= 0) {
    throw new PaymentPlanPolicyError(
        "invalid-argument",
        `${field} must be a positive amount in minor currency units.`,
    );
  }
  return amount;
}

function splitPaymentAmounts(agreedTotalMinor, depositAmountMinor) {
  const total = safeMinor(agreedTotalMinor, "agreedTotalMinor");
  const deposit = safeMinor(depositAmountMinor, "depositAmountMinor");
  const balance = total - deposit;
  if (deposit < MIN_PAYMENT_PART_MINOR || balance < MIN_PAYMENT_PART_MINOR) {
    throw new PaymentPlanPolicyError(
        "invalid-argument",
        "Deposit and remaining balance must each be at least 1.00 in the transaction currency.",
    );
  }
  return {
    paymentRequiredMinor: total,
    depositAmountMinor: deposit,
    balanceAmountMinor: balance,
  };
}

function participantRole(sale, actorUid) {
  const uid = String(actorUid || "");
  if (!sale || !uid) return null;
  if (String(sale.buyerUid || "") === uid) return "buyer";
  if (String(sale.sellerUid || "") === uid) return "seller";
  return null;
}

function paymentHasStarted(sale = {}) {
  return Number(sale.amountPaidMinor || 0) > 0 ||
    PAYMENT_STARTED_STATUSES.has(String(sale.paymentProviderStatus || "")) ||
    String(sale.stripeCheckoutSessionId || "").startsWith("cs_") ||
    String(sale.stripePaymentIntentId || "").startsWith("pi_") ||
    String(sale.stripeChargeId || "").startsWith("ch_");
}

function agreedTotalFromSale(sale) {
  const fee = sale && sale.marketplaceFeeSnapshot || {};
  return safeMinor(fee.agreedTotalMinor, "marketplaceFeeSnapshot.agreedTotalMinor");
}

function requireMutablePaymentPlan(sale, actorUid) {
  if (!sale) {
    throw new PaymentPlanPolicyError("not-found", "The marketplace transaction is unavailable.");
  }
  const role = participantRole(sale, actorUid);
  if (!role) {
    throw new PaymentPlanPolicyError(
        "permission-denied",
        "Only the buyer or seller can change payment terms.",
    );
  }
  if (CLOSED_TRANSACTION_STATUSES.has(String(sale.status || ""))) {
    throw new PaymentPlanPolicyError(
        "failed-precondition",
        "Payment terms cannot be changed after the transaction is closed.",
    );
  }
  if (paymentHasStarted(sale)) {
    throw new PaymentPlanPolicyError(
        "failed-precondition",
        "Payment terms are locked after a Stripe payment has started.",
    );
  }
  if (sale.paymentPlanStatus === "active") {
    throw new PaymentPlanPolicyError(
        "failed-precondition",
        "The approved payment plan is already locked.",
    );
  }
  if (sale.paymentOrigin === "timed_buying") {
    throw new PaymentPlanPolicyError(
        "failed-precondition",
        "Timed Buying deposit terms must be disclosed before bidding starts and cannot be negotiated after the winner is selected.",
    );
  }
  return role;
}

function validateDepositProposal({sale, actorUid, depositAmountMinor}) {
  const actorRole = requireMutablePaymentPlan(sale, actorUid);
  const amounts = splitPaymentAmounts(
      agreedTotalFromSale(sale),
      depositAmountMinor,
  );
  const currentRevision = Math.max(0, Number(sale.paymentPlanProposalRevision || 0));
  return {
    actorRole,
    proposalRevision: currentRevision + 1,
    paymentPlan: "deposit_balance",
    ...amounts,
    buyerApproved: actorRole === "buyer",
    sellerApproved: actorRole === "seller",
    status: "pending_counterparty",
  };
}

function currentProposal(sale, expectedRevision) {
  if (!sale) {
    throw new PaymentPlanPolicyError("not-found", "The marketplace transaction is unavailable.");
  }
  const proposal = sale.paymentPlanProposal;
  if (!proposal || proposal.status !== "pending_counterparty") {
    throw new PaymentPlanPolicyError(
        "failed-precondition",
        "There is no pending deposit proposal to approve.",
    );
  }
  const revision = Number(sale.paymentPlanProposalRevision || 0);
  if (!Number.isSafeInteger(Number(expectedRevision)) ||
      Number(expectedRevision) !== revision) {
    throw new PaymentPlanPolicyError(
        "aborted",
        "The deposit proposal changed. Review the latest terms before approving.",
    );
  }
  return {proposal, revision};
}

function validateDepositApproval({sale, actorUid, expectedRevision}) {
  const actorRole = requireMutablePaymentPlan(sale, actorUid);
  const {proposal, revision} = currentProposal(sale, expectedRevision);
  const buyerApproved = proposal.buyerApproved === true || actorRole === "buyer";
  const sellerApproved = proposal.sellerApproved === true || actorRole === "seller";
  return {
    actorRole,
    proposalRevision: revision,
    buyerApproved,
    sellerApproved,
    activate: buyerApproved && sellerApproved,
    paymentPlan: "deposit_balance",
    paymentRequiredMinor: safeMinor(proposal.paymentRequiredMinor, "paymentRequiredMinor"),
    depositAmountMinor: safeMinor(proposal.depositAmountMinor, "depositAmountMinor"),
    balanceAmountMinor: safeMinor(proposal.balanceAmountMinor, "balanceAmountMinor"),
  };
}

function validateDepositDecline({sale, actorUid, expectedRevision}) {
  const actorRole = requireMutablePaymentPlan(sale, actorUid);
  const {proposal, revision} = currentProposal(sale, expectedRevision);
  const alreadyApproved = actorRole === "buyer" ?
    proposal.buyerApproved === true : proposal.sellerApproved === true;
  if (alreadyApproved && proposal.buyerApproved === true && proposal.sellerApproved === true) {
    throw new PaymentPlanPolicyError(
        "failed-precondition",
        "The fully approved deposit plan is already locked.",
    );
  }
  return {actorRole, proposalRevision: revision, status: "declined"};
}

module.exports = {
  MIN_PAYMENT_PART_MINOR,
  PaymentPlanPolicyError,
  participantRole,
  paymentHasStarted,
  splitPaymentAmounts,
  validateDepositApproval,
  validateDepositDecline,
  validateDepositProposal,
};
