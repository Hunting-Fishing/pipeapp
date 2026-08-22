"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  validStripeReceiptUrl,
  verifiedReceiptAmount,
} = require("../external_settlement_receipt_commands");

test("receipt links must stay on HTTPS Stripe domains", () => {
  assert.equal(validStripeReceiptUrl(
      "https://pay.stripe.com/receipts/payment/abc"), true);
  assert.equal(validStripeReceiptUrl(
      "https://receipts.stripe.com/example"), true);
  assert.equal(validStripeReceiptUrl(
      "http://pay.stripe.com/receipts/payment/abc"), false);
  assert.equal(validStripeReceiptUrl(
      "https://stripe.com.evil.example/receipt"), false);
});

test("receipt charge must match stored fee total and currency", () => {
  const sale = {
    marketplaceFeeBuyerChargedMinor: 2875,
    marketplaceFeeSnapshot: {currency: "CAD"},
  };
  assert.equal(verifiedReceiptAmount(sale, {
    amount: 2875,
    currency: "cad",
  }), true);
  assert.equal(verifiedReceiptAmount(sale, {
    amount: 2800,
    currency: "cad",
  }), false);
  assert.equal(verifiedReceiptAmount(sale, {
    amount: 2875,
    currency: "usd",
  }), false);
});

test("receipt verification fails closed when ledger total is missing", () => {
  assert.equal(verifiedReceiptAmount({
    marketplaceFeeSnapshot: {currency: "CAD"},
  }, {
    amount: 2500,
    currency: "cad",
  }), false);
});
