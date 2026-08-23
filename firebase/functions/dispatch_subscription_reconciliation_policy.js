"use strict";

const {
  invoiceCommissionBaseMinor,
  subscriptionIdentityFromInvoice,
} = require("./subscription_monetization");
const {
  invoicePaymentIntentId,
  objectId,
} = require("./dispatch_subscription_invoice_payment_policy");

function safeInteger(value) {
  const amount = Number(value);
  return Number.isSafeInteger(amount) ? amount : null;
}

function normalizedCurrency(value) {
  return String(value || "").trim().toLowerCase();
}

function dispatchSubscriptionInvoiceReconciliationState({
  stored = {},
  invoice = {},
  invoicePayment = null,
  paymentIntent = null,
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
  const expectedPaymentIntentId = String(stored.stripePaymentIntentId || "");
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

  const invoicePaymentId = objectId(invoicePayment);
  const invoicePaymentInvoiceId = objectId(invoicePayment && invoicePayment.invoice);
  const invoicePaymentAmountPaidMinor = safeInteger(
      invoicePayment && invoicePayment.amount_paid,
  );
  const invoicePaymentCurrency = normalizedCurrency(
      invoicePayment && invoicePayment.currency,
  );
  const providerPaymentIntentId = invoicePaymentIntentId(invoicePayment);
  const paymentIntentAmountReceivedMinor = safeInteger(
      paymentIntent && paymentIntent.amount_received,
  );
  const providerSourceChargeId = objectId(paymentIntent && paymentIntent.latest_charge);

  const expectedZero = expectedAmountPaidMinor === 0;
  const providerZero = providerAmountPaidMinor === 0;
  const zeroAmount = expectedZero && providerZero;
  const paymentEvidenceRequired =
    (expectedAmountPaidMinor != null && expectedAmountPaidMinor > 0) ||
    (providerAmountPaidMinor != null && providerAmountPaidMinor > 0);

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
    zeroAmountProviderPaymentAbsent:
      !zeroAmount || !invoicePayment && !paymentIntent && !charge && !balanceTransaction,
    invoicePaymentPresent: !paymentEvidenceRequired || invoicePaymentId.startsWith("inpay_"),
    invoicePaymentPaid:
      !paymentEvidenceRequired || String(invoicePayment && invoicePayment.status || "") === "paid",
    invoicePaymentInvoiceMatches:
      !paymentEvidenceRequired || invoicePaymentInvoiceId === expectedInvoiceId,
    invoicePaymentAmountMatches:
      !paymentEvidenceRequired || invoicePaymentAmountPaidMinor === providerAmountPaidMinor,
    invoicePaymentCurrencyMatches:
      !paymentEvidenceRequired || invoicePaymentCurrency === expectedCurrency,
    invoicePaymentTypeSupported:
      !paymentEvidenceRequired || providerPaymentIntentId.startsWith("pi_"),
    storedPaymentIntentConsistent:
      !expectedPaymentIntentId || expectedPaymentIntentId === providerPaymentIntentId,
    paymentIntentIdMatches:
      !paymentEvidenceRequired || String(paymentIntent && paymentIntent.id || "") ===
        providerPaymentIntentId,
    paymentIntentSucceeded:
      !paymentEvidenceRequired || String(paymentIntent && paymentIntent.status || "") ===
        "succeeded",
    paymentIntentAmountMatches:
      !paymentEvidenceRequired || paymentIntentAmountReceivedMinor ===
        providerAmountPaidMinor,
    paymentIntentChargePresent:
      !paymentEvidenceRequired || providerSourceChargeId.startsWith("ch_"),
    storedChargeConsistent:
      !expectedSourceChargeId || expectedSourceChargeId === providerSourceChargeId,
    chargeIdMatches: !paymentEvidenceRequired ||
      String(charge && charge.id || "") === providerSourceChargeId,
    chargePaid: !paymentEvidenceRequired || charge && charge.paid === true,
    chargeAmountMatches: !paymentEvidenceRequired ||
      chargeAmountMinor === providerAmountPaidMinor,
    chargeCurrencyMatches: !paymentEvidenceRequired ||
      chargeCurrency === expectedCurrency,
    balanceTransactionLinked: !paymentEvidenceRequired ||
      chargeBalanceTransactionId.startsWith("txn_") &&
      chargeBalanceTransactionId === balanceTransactionId,
    balanceAmountMatches: !paymentEvidenceRequired ||
      providerGrossMinor === chargeAmountMinor,
    balanceCurrencyMatches: !paymentEvidenceRequired ||
      normalizedCurrency(balanceTransaction && balanceTransaction.currency) ===
        expectedCurrency,
    balanceArithmeticMatches: !paymentEvidenceRequired ||
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
    stripeInvoicePaymentId: invoicePaymentId,
    stripePaymentIntentId: providerPaymentIntentId,
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
  safeInteger,
};
