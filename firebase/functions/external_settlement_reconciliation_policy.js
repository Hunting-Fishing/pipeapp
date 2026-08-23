"use strict";

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

function externalFeeReconciliationState({
  sale = {},
  session = {},
  paymentIntent = {},
  charge = {},
  balanceTransaction = {},
} = {}) {
  const fee = sale.marketplaceFeeSnapshot || {};
  const expectedFeeMinor = safeInteger(fee.marketplaceFeeMinor);
  const expectedTaxMinor = safeInteger(sale.marketplaceFeeTaxCollectedMinor);
  const expectedTotalMinor = safeInteger(sale.marketplaceFeeBuyerChargedMinor);
  const expectedCurrency = normalizedCurrency(fee.currency || sale.currency);

  const sessionTaxMinor = safeInteger(
      session.total_details && session.total_details.amount_tax,
  );
  const sessionSubtotalMinor = safeInteger(session.amount_subtotal);
  const sessionTotalMinor = safeInteger(session.amount_total);
  const chargeAmountMinor = safeInteger(charge.amount);
  const balanceAmountMinor = safeInteger(balanceTransaction.amount);
  const providerFeeMinor = safeInteger(balanceTransaction.fee);
  const providerNetMinor = safeInteger(balanceTransaction.net);

  const storedSessionId = String(sale.stripeMarketplaceFeeSessionId || "");
  const storedPaymentIntentId = String(
      sale.stripeMarketplaceFeePaymentIntentId || "",
  );
  const storedChargeId = String(sale.stripeMarketplaceFeeChargeId || "");
  const providerBalanceTransactionId = objectId(charge.balance_transaction);
  const actualBalanceTransactionId = objectId(balanceTransaction);

  const checks = Object.freeze({
    feeSnapshotValid: expectedFeeMinor != null && expectedFeeMinor > 0,
    recordedTaxValid: expectedTaxMinor != null && expectedTaxMinor >= 0,
    recordedTotalValid: expectedTotalMinor != null && expectedTotalMinor > 0,
    currencyValid: expectedCurrency.length === 3,
    sessionIdMatches: String(session.id || "") === storedSessionId,
    sessionBillingTypeMatches:
      String(session.metadata && session.metadata.billingType || "") ===
        "marketplace_fee_only",
    sessionTransactionMatches:
      String(session.metadata && session.metadata.pipeBuyerTransactionId || "") ===
        String(sale.transactionId || sale.id || ""),
    sessionSubtotalMatches: sessionSubtotalMinor === expectedFeeMinor,
    sessionTaxMatches: sessionTaxMinor === expectedTaxMinor,
    sessionTotalMatches: sessionTotalMinor === expectedTotalMinor,
    sessionPaymentIntentMatches:
      objectId(session.payment_intent) === storedPaymentIntentId,
    paymentIntentIdMatches:
      String(paymentIntent.id || "") === storedPaymentIntentId,
    paymentIntentSucceeded: String(paymentIntent.status || "") === "succeeded",
    paymentIntentChargeMatches:
      objectId(paymentIntent.latest_charge) === storedChargeId,
    chargeIdMatches: String(charge.id || "") === storedChargeId,
    chargePaid: charge.paid === true,
    chargeAmountMatches: chargeAmountMinor === expectedTotalMinor,
    chargeCurrencyMatches:
      normalizedCurrency(charge.currency) === expectedCurrency,
    balanceTransactionLinked:
      providerBalanceTransactionId.length > 0 &&
      providerBalanceTransactionId === actualBalanceTransactionId,
    balanceAmountMatches: balanceAmountMinor === chargeAmountMinor,
    balanceCurrencyMatches:
      normalizedCurrency(balanceTransaction.currency) === expectedCurrency,
    balanceArithmeticMatches:
      balanceAmountMinor != null && providerFeeMinor != null &&
      providerNetMinor != null &&
      balanceAmountMinor - providerFeeMinor === providerNetMinor,
    firestoreArithmeticMatches:
      expectedFeeMinor != null && expectedTaxMinor != null &&
      expectedTotalMinor != null &&
      expectedFeeMinor + expectedTaxMinor === expectedTotalMinor,
  });

  const failedChecks = Object.entries(checks)
      .filter(([, passed]) => passed !== true)
      .map(([name]) => name);
  return Object.freeze({
    balanced: failedChecks.length === 0,
    failedChecks,
    expectedFeeMinor,
    expectedTaxMinor,
    expectedTotalMinor,
    currency: expectedCurrency.toUpperCase(),
    providerGrossMinor: balanceAmountMinor,
    providerFeeMinor,
    providerNetMinor,
    firestoreDifferenceMinor:
      expectedFeeMinor == null || expectedTaxMinor == null ||
      expectedTotalMinor == null ? null :
        expectedTotalMinor - expectedFeeMinor - expectedTaxMinor,
    providerDifferenceMinor:
      balanceAmountMinor == null || providerFeeMinor == null ||
      providerNetMinor == null ? null :
        balanceAmountMinor - providerFeeMinor - providerNetMinor,
    balanceTransactionId: actualBalanceTransactionId,
  });
}

module.exports = {
  externalFeeReconciliationState,
  normalizedCurrency,
  objectId,
  safeInteger,
};
