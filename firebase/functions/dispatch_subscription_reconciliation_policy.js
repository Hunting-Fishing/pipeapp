"use strict";

const {
  invoiceCommissionBaseMinor,
  sourceChargeFromInvoice,
  subscriptionIdentityFromInvoice,
} = require("./subscription_monetization");

function safeInteger(value) {
  const amount = Number(value);
  return Number.isSafeInteger(amount) ? amount : null;
}

function normalizedCurrency(value) {
  return String(value || "").trim().toLowerCase();
}

function objectId(value) {
  if (typeof value === "string") return value;
  return String(value && value.id || "");
}

function dispatchSubscriptionInvoiceReconciliationState({
  stored = {},
  invoice = {},
  charge = null,
  balanceTransaction = null,
} = {}) {
  const expectedAmountPaidMinor = safeInteger(stored.amountPaidMinor);
  const expectedCommissionBaseMinor = safeInteger(stored.commissionBaseMinor);
  const expectedTaxMinor = safeInteger(stored.taxMinor);
  const expectedCurrency = normalizedCurrency(stored.currency);
  const expectedInvoiceId = String(stored.invoiceId || "");
  const expectedSubscriptionId = String(stored.subscriptionId || "");
  const expectedUid = String(stored.uid || "");
  const expectedPlan = String(stored.plan || "");
  const expectedSourceChargeId = String(stored.sourceChargeId || "");

  const providerAmountPaidMinor = safeInteger(invoice.amount_paid);
  const providerTotalMinor = safeInteger(invoice.total);
  const providerCommissionBaseMinor = safeInteger(
      invoiceCommissionBaseMinor(invoice),
  );
  const providerTaxMinor = providerTotalMinor == null ||
      providerCommissionBaseMinor == null ? null :
      providerTotalMinor - providerCommissionBaseMinor;
  const providerCurrency = normalizedCurrency(invoice.currency);
  const identity = subscriptionIdentityFromInvoice(invoice);
  const metadata = identity.metadata || {};
  const providerSourceChargeId = sourceChargeFromInvoice(invoice);
  const zeroAmount = expectedAmountPaidMinor === 0;

  const chargeAmountMinor = safeInteger(charge && charge.amount);
  const chargeCurrency = normalizedCurrency(charge && charge.currency);
  const chargeBalanceTransactionId = objectId(charge && charge.balance_transaction);
  const balanceTransactionId = objectId(balanceTransaction);
  const providerGrossMinor = zeroAmount ? 0 :
    safeInteger(balanceTransaction && balanceTransaction.amount);
  const providerFeeMinor = zeroAmount ? 0 :
    safeInteger(balanceTransaction && balanceTransaction.fee);
  const providerNetMinor = zeroAmount ? 0 :
    safeInteger(balanceTransaction && balanceTransaction.net);

  const providerInvoiceChargeExpectation = zeroAmount ?
    !providerSourceChargeId : providerSourceChargeId.startsWith("ch_");
  const storedChargeExpectation = zeroAmount ?
    !expectedSourceChargeId : expectedSourceChargeId.startsWith("ch_");

  const checks = Object.freeze({
    storedPaid: String(stored.status || "") === "paid",
    invoiceIdMatches: String(invoice.id || "") === expectedInvoiceId,
    invoicePaid: String(invoice.status || "") === "paid",
    subscriptionIdMatches:
      String(identity.subscriptionId || "") === expectedSubscriptionId,
    billingTypeMatches:
      String(metadata.billingType || "") === "dispatch_subscription",
    uidMatches: !expectedUid || String(metadata.pipeBuyerUid || "") === expectedUid,
    planMatches:
      !expectedPlan || String(metadata.dispatchPlan || "") === expectedPlan,
    amountPaidValid:
      expectedAmountPaidMinor != null && expectedAmountPaidMinor >= 0,
    amountPaidMatches: providerAmountPaidMinor === expectedAmountPaidMinor,
    currencyValid: expectedCurrency.length === 3,
    currencyMatches: providerCurrency === expectedCurrency,
    commissionBaseValid:
      expectedCommissionBaseMinor != null && expectedCommissionBaseMinor >= 0,
    commissionBaseMatches:
      providerCommissionBaseMinor === expectedCommissionBaseMinor,
    taxValid: expectedTaxMinor != null && expectedTaxMinor >= 0,
    taxMatches: providerTaxMinor === expectedTaxMinor,
    invoiceArithmeticMatches:
      providerCommissionBaseMinor != null && providerTaxMinor != null &&
      providerTotalMinor != null &&
      providerCommissionBaseMinor + providerTaxMinor === providerTotalMinor,
    providerChargeExpectation: providerInvoiceChargeExpectation,
    storedChargeExpectation,
    sourceChargeMatches: providerSourceChargeId === expectedSourceChargeId,
    chargeIdMatches: zeroAmount ||
      String(charge && charge.id || "") === providerSourceChargeId,
    chargePaid: zeroAmount || charge && charge.paid === true,
    chargeAmountMatches: zeroAmount ||
      chargeAmountMinor === expectedAmountPaidMinor,
    chargeCurrencyMatches: zeroAmount || chargeCurrency === expectedCurrency,
    balanceTransactionLinked: zeroAmount ||
      chargeBalanceTransactionId.startsWith("txn_") &&
      chargeBalanceTransactionId === balanceTransactionId,
    balanceAmountMatches: zeroAmount ||
      providerGrossMinor === chargeAmountMinor,
    balanceCurrencyMatches: zeroAmount ||
      normalizedCurrency(balanceTransaction && balanceTransaction.currency) ===
        expectedCurrency,
    balanceArithmeticMatches: zeroAmount ||
      providerGrossMinor != null && providerFeeMinor != null &&
      providerNetMinor != null &&
      providerGrossMinor - providerFeeMinor === providerNetMinor,
  });

  const failedChecks = Object.entries(checks)
      .filter(([, passed]) => passed !== true)
      .map(([name]) => name);

  return Object.freeze({
    balanced: failedChecks.length === 0,
    failedChecks,
    currency: expectedCurrency.toUpperCase(),
    expectedAmountPaidMinor,
    expectedCommissionBaseMinor,
    expectedTaxMinor,
    providerInvoiceTotalMinor: providerTotalMinor,
    providerInvoiceAmountPaidMinor: providerAmountPaidMinor,
    providerGrossMinor,
    providerFeeMinor,
    providerNetMinor,
    stripeChargeId: providerSourceChargeId,
    stripeBalanceTransactionId: balanceTransactionId,
    invoiceDifferenceMinor:
      providerAmountPaidMinor == null || expectedAmountPaidMinor == null ? null :
        providerAmountPaidMinor - expectedAmountPaidMinor,
    providerDifferenceMinor:
      providerGrossMinor == null || providerFeeMinor == null ||
      providerNetMinor == null ? null :
        providerGrossMinor - providerFeeMinor - providerNetMinor,
    zeroAmount,
  });
}

module.exports = {
  dispatchSubscriptionInvoiceReconciliationState,
  normalizedCurrency,
  objectId,
  safeInteger,
};
