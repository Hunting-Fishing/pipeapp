"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {stripeMarketplaceConfig} = require("../stripe_marketplace_config");
const {
  providerStateBlocksCheckout,
  requireVipSubscriptionReady,
  selectedVipPlan,
  vipCheckoutAttemptKey,
} = require("../vip_subscription_commands");
const {
  vipCheckoutIdentity,
  vipSubscriptionIdentity,
} = require("../vip_subscription_lifecycle");
const {
  vipSubscriptionContextFromInvoice,
} = require("../vip_subscription_monetization");
const {
  isVipCheckoutCompletedEvent,
} = require("../stripe_webhook_dispatch_lifecycle");

const ready = Object.freeze({
  stripeMode: "production",
  stripeSubscriptionsEnabled: true,
  stripeVipSubscriptionsEnabled: true,
  stripeWebhookVerified: true,
  stripeReconciliationReady: true,
  stripeTaxReady: false,
  stripeTaxRegistrationPending: true,
  stripeTaxPendingBillingApproved: true,
});

test("VIP launch catalog is exactly CAD 100 monthly", () => {
  const vip = stripeMarketplaceConfig.products.vipMonthlyCad;
  assert.equal(vip.productId, "prod_VA12LaMiaCMRqZ");
  assert.equal(vip.priceId, "price_1U9h0tDkO07WMXyRgdzAmm43");
  assert.equal(vip.currency, "CAD");
  assert.equal(vip.unitAmountMinor, 10000);
  assert.equal(vip.billingInterval, "month");
  assert.equal(vip.taxCode, "txcd_10103001");
});

test("VIP checkout accepts monthly only and has stable idempotency", () => {
  assert.equal(selectedVipPlan(), "monthly");
  assert.equal(selectedVipPlan("MONTHLY"), "monthly");
  assert.throws(() => selectedVipPlan("yearly"));
  assert.equal(
      vipCheckoutAttemptKey("buyer_123", 4),
      "pipebuyer-vip-buyer_123-attempt-4",
  );
});

test("VIP has a dedicated readiness switch beyond generic subscriptions", () => {
  assert.doesNotThrow(() => requireVipSubscriptionReady(ready));
  assert.throws(() => requireVipSubscriptionReady({
    ...ready,
    stripeVipSubscriptionsEnabled: false,
  }));
  assert.throws(() => requireVipSubscriptionReady({
    ...ready,
    stripeSubscriptionsEnabled: false,
  }));
});

test("provider state blocks duplicate VIP checkout before invoice access exists", () => {
  assert.equal(providerStateBlocksCheckout({
    ownerUid: "buyer_123",
    subscriptionId: "sub_live123",
    blocksNewCheckout: true,
  }, "buyer_123"), true);
  assert.equal(providerStateBlocksCheckout({
    ownerUid: "buyer_123",
    subscriptionId: "sub_live123",
    blocksNewCheckout: false,
  }, "buyer_123"), false);
});

test("VIP webhook identities require explicit vip_subscription metadata", () => {
  assert.deepEqual(vipCheckoutIdentity({
    metadata: {billingType: "vip_subscription", pipeBuyerUid: "buyer_123"},
    subscription: "sub_live123",
    customer: "cus_live123",
  }), {
    uid: "buyer_123",
    subscriptionId: "sub_live123",
    stripeCustomerId: "cus_live123",
  });
  assert.equal(vipCheckoutIdentity({
    metadata: {billingType: "dispatch_subscription", pipeBuyerUid: "buyer_123"},
    subscription: "sub_live123",
  }), null);
  assert.equal(vipSubscriptionIdentity({
    id: "sub_live123",
    metadata: {billingType: "dispatch_subscription", pipeBuyerUid: "buyer_123"},
  }), null);
});

test("verified webhook wrapper recognizes VIP Checkout without treating redirect as access", () => {
  assert.equal(isVipCheckoutCompletedEvent({
    type: "checkout.session.completed",
    data: {object: {metadata: {billingType: "vip_subscription"}}},
  }), true);
  assert.equal(isVipCheckoutCompletedEvent({
    type: "checkout.session.completed",
    data: {object: {metadata: {billingType: "dispatch_subscription"}}},
  }), false);
});

test("paid invoice context is VIP-only and server attributable", async () => {
  const invoice = {
    id: "in_live123",
    parent: {
      subscription_details: {
        subscription: "sub_live123",
        metadata: {
          billingType: "vip_subscription",
          pipeBuyerUid: "buyer_123",
          vipPlan: "monthly",
        },
      },
    },
  };
  const context = await vipSubscriptionContextFromInvoice({
    invoice,
    secretKey: "unused_with_embedded_metadata",
    stripeConfig: stripeMarketplaceConfig,
  });
  assert.equal(context.uid, "buyer_123");
  assert.equal(context.subscriptionId, "sub_live123");
  assert.equal(context.invoiceId, "in_live123");
});
