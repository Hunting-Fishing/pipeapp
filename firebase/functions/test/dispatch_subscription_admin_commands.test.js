"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  dispatchInvoiceAdminSummary,
} = require("../dispatch_subscription_admin_commands");

test("admin summary exposes accounting evidence without provider customer or subscription ids", () => {
  const summary = dispatchInvoiceAdminSummary({
    invoiceId: "in_123",
    uid: "user-1",
    plan: "monthly",
    currency: "cad",
    amountPaidMinor: 2500,
    commissionBaseMinor: 2500,
    taxMinor: 0,
    status: "paid",
    reconciliationStatus: "balanced",
    reconciliationFailedChecks: [],
    providerGrossMinor: 2500,
    providerFeeMinor: 103,
    providerNetMinor: 2397,
    stripeBalanceTransactionId: "txn_123",
    stripeCustomerId: "cus_secret",
    stripeSubscriptionId: "sub_secret",
    sourceChargeId: "ch_secret",
    paidAt: {toMillis: () => 1234567890},
  });

  assert.equal(summary.invoiceId, "in_123");
  assert.equal(summary.currency, "CAD");
  assert.equal(summary.providerFeeMinor, 103);
  assert.equal(summary.paidAtMillis, 1234567890);
  assert.equal("stripeCustomerId" in summary, false);
  assert.equal("stripeSubscriptionId" in summary, false);
  assert.equal("sourceChargeId" in summary, false);
});

test("admin summary bounds failed checks and normalizes missing amounts", () => {
  const summary = dispatchInvoiceAdminSummary({
    reconciliationFailedChecks: Array.from({length: 60}, (_, index) => `check_${index}`),
  }, "in_fallback");
  assert.equal(summary.invoiceId, "in_fallback");
  assert.equal(summary.amountPaidMinor, 0);
  assert.equal(summary.reconciliationFailedChecks.length, 40);
});
