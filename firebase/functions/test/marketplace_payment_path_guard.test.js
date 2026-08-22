"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  externalSettlementFullyConfirmed,
  hasStartedExternalSettlement,
  hasStartedStripeMarketplaceCheckout,
} = require("../marketplace_payment_path_guard");

test("Stripe marketplace checkout is treated as started from the first provider state", () => {
  assert.equal(hasStartedStripeMarketplaceCheckout({
    stripeCheckoutSessionId: "cs_live_123",
  }), true);
  assert.equal(hasStartedStripeMarketplaceCheckout({
    paymentProviderStatus: "checkout_created",
  }), true);
  assert.equal(hasStartedStripeMarketplaceCheckout({
    paymentMethod: "stripe_checkout",
  }), true);
  assert.equal(hasStartedStripeMarketplaceCheckout({
    stripePaymentIntentId: "pi_123",
  }), true);
  assert.equal(hasStartedStripeMarketplaceCheckout({}), false);
});

test("external settlement is treated as started when either party confirms", () => {
  assert.equal(hasStartedExternalSettlement({
    externalSettlementBuyerConfirmed: true,
  }), true);
  assert.equal(hasStartedExternalSettlement({
    externalSettlementSellerConfirmed: true,
  }), true);
  assert.equal(hasStartedExternalSettlement({
    marketplaceFeeStatus: "pending_collection",
  }), true);
  assert.equal(hasStartedExternalSettlement({
    stripeMarketplaceFeeSessionId: "cs_fee_123",
  }), true);
  assert.equal(hasStartedExternalSettlement({}), false);
});

test("external fee checkout requires both confirmations and the external payment path", () => {
  assert.equal(externalSettlementFullyConfirmed({
    paymentMethod: "external_settlement",
    externalSettlementBuyerConfirmed: true,
    externalSettlementSellerConfirmed: true,
  }), true);
  assert.equal(externalSettlementFullyConfirmed({
    paymentMethod: "external_settlement",
    externalSettlementBuyerConfirmed: true,
    externalSettlementSellerConfirmed: false,
  }), false);
  assert.equal(externalSettlementFullyConfirmed({
    paymentMethod: "stripe_checkout",
    externalSettlementBuyerConfirmed: true,
    externalSettlementSellerConfirmed: true,
  }), false);
});
