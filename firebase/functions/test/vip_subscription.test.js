"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {stripeMarketplaceConfig} = require("../stripe_marketplace_config");
const {membershipPlanCatalog} = require("../membership_plan_policy");
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

test("VIP checkout uses metadata before a subscription price exists", () => {
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
});

test("VIP subscription lifecycle uses the approved price, not billingType metadata", () => {
  const vipPlan = membershipPlanCatalog().vip_monthly;
  const dispatchPlan = membershipPlanCatalog().dispatch_monthly;
  const identity = vipSubscriptionIdentity({
    id: "sub_live123",
    metadata: {billingType: "dispatch_subscription", pipeBuyerUid: "buyer_123"},
    items: {data: [{id: "si_live123", price: {id: vipPlan.priceId}}]},
  });
  assert.equal(identity.uid, "buyer_123");
  assert.equal(identity.plan.id, "vip_monthly");
  assert.equal(vipSubscriptionIdentity({
    id: "sub_live123",
    metadata: {billingType: "vip_subscription", pipeBuyerUid: "buyer_123"},
    items: {data: [{id: "si_live123", price: {id: dispatchPlan.priceId}}]},
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

test("paid invoice context is VIP-only, price-authoritative, and attributable", async () => {
  const vipPlan = membershipPlanCatalog().vip_monthly;
  const invoice = {
    id: "in_live123",
    parent: {
      subscription_details: {
        subscription: "sub_live123",
        metadata: {
          // Stale metadata cannot override the billed VIP price.
          billingType: "dispatch_subscription",
          pipeBuyerUid: "buyer_123",
          vipPlan: "",
        },
      },
    },
    lines: {data: [{
      amount: 10000,
      pricing: {price_details: {price: vipPlan.priceId}},
    }]},
  };
  const context = await vipSubscriptionContextFromInvoice({
    invoice,
    secretKey: "unused_with_billed_price_and_embedded_metadata",
    stripeConfig: stripeMarketplaceConfig,
  });
  assert.equal(context.uid, "buyer_123");
  assert.equal(context.subscriptionId, "sub_live123");
  assert.equal(context.invoiceId, "in_live123");
  assert.equal(context.plan.id, "vip_monthly");
  assert.equal(context.metadata.billingType, "vip_subscription");
});
