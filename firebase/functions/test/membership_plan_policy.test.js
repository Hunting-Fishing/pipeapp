"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  effectiveMembershipPlan,
  invoiceLinePriceId,
  invoiceMembershipPlan,
  invoiceMembershipPlanResolution,
  membershipPlanCatalog,
  membershipPlanChangeKind,
  membershipPlanForPriceId,
  membershipPlanMetadata,
  subscriptionMembershipPlan,
} = require("../membership_plan_policy");
const {
  activeNativeProvider,
  planStatusPayload,
  providerSubscriptionId,
  subscriptionPeriodBounds,
  uniqueBlockingSubscriptionId,
} = require("../membership_plan_management");

function timestamp(millis) {
  return {toMillis: () => millis};
}

test("membership ladder is Free -> Dispatch -> VIP", () => {
  const plans = membershipPlanCatalog();
  assert.equal(plans.free.rank, 0);
  assert.equal(plans.dispatch_monthly.rank, 1);
  assert.equal(plans.dispatch_yearly.rank, 1);
  assert.equal(plans.vip_monthly.rank, 2);
  assert.equal(
      membershipPlanChangeKind(plans.vip_monthly, plans.dispatch_monthly),
      "change_at_period_end",
  );
  assert.equal(
      membershipPlanChangeKind(plans.dispatch_monthly, plans.vip_monthly),
      "upgrade_now",
  );
  assert.equal(
      membershipPlanChangeKind(plans.dispatch_monthly, plans.free),
      "cancel",
  );
});

test("approved Stripe prices map to one Pipe Buyer plan", () => {
  const plans = membershipPlanCatalog();
  for (const id of ["dispatch_monthly", "dispatch_yearly", "vip_monthly"]) {
    assert.ok(plans[id].priceId.startsWith("price_"));
    assert.equal(membershipPlanForPriceId(plans[id].priceId).id, id);
  }
  assert.equal(membershipPlanForPriceId("price_unknown"), null);
});

test("subscription plan is derived from the actual single Stripe item price", () => {
  const plan = membershipPlanCatalog().vip_monthly;
  assert.equal(subscriptionMembershipPlan({
    items: {data: [{id: "si_123", price: {id: plan.priceId}}]},
  }).id, "vip_monthly");
  assert.equal(subscriptionMembershipPlan({items: {data: []}}), null);
  assert.equal(subscriptionMembershipPlan({
    items: {data: [
      {id: "si_1", price: {id: plan.priceId}},
      {id: "si_2", price: {id: plan.priceId}},
    ]},
  }), null);
});

test("invoice membership plan supports legacy and current Stripe line price shapes", () => {
  const plans = membershipPlanCatalog();
  assert.equal(
      invoiceLinePriceId({price: {id: plans.dispatch_monthly.priceId}}),
      plans.dispatch_monthly.priceId,
  );
  assert.equal(invoiceLinePriceId({
    pricing: {price_details: {price: plans.vip_monthly.priceId}},
  }), plans.vip_monthly.priceId);
  assert.equal(invoiceMembershipPlan({
    lines: {data: [{
      amount: 2500,
      pricing: {price_details: {price: plans.dispatch_monthly.priceId}},
    }]},
  }).id, "dispatch_monthly");
});

test("upgrade proration invoice resolves to the positive target plan price", () => {
  const plans = membershipPlanCatalog();
  const resolution = invoiceMembershipPlanResolution({
    lines: {data: [
      {amount: -1200, price: {id: plans.dispatch_monthly.priceId}},
      {amount: 5000, price: {id: plans.vip_monthly.priceId}},
    ]},
  });
  assert.equal(resolution.plan.id, "vip_monthly");
  assert.equal(resolution.hasApprovedPrice, true);
  assert.equal(resolution.ambiguous, false);
});

test("ambiguous positive membership prices fail closed", () => {
  const plans = membershipPlanCatalog();
  const resolution = invoiceMembershipPlanResolution({
    lines: {data: [
      {amount: 2500, price: {id: plans.dispatch_monthly.priceId}},
      {amount: 10000, price: {id: plans.vip_monthly.priceId}},
    ]},
  });
  assert.equal(resolution.plan, null);
  assert.equal(resolution.hasApprovedPrice, true);
  assert.equal(resolution.ambiguous, true);
});

test("zero-net single-plan invoice can still resolve its approved plan", () => {
  const plans = membershipPlanCatalog();
  const resolution = invoiceMembershipPlanResolution({
    lines: {data: [{
      amount: 0,
      pricing: {price_details: {price: plans.dispatch_monthly.priceId}},
    }]},
  });
  assert.equal(resolution.plan.id, "dispatch_monthly");
  assert.equal(resolution.hasApprovedPrice, true);
});

test("VIP paid access wins over Dispatch in effective tier", () => {
  const now = 1_000_000;
  const plan = effectiveMembershipPlan({
    nowMillis: now,
    vipMembership: {
      active: true,
      currentPeriodEnd: timestamp(now + 5000),
    },
    dispatchMembership: {
      active: true,
      plan: "monthly",
      currentPeriodEnd: timestamp(now + 5000),
    },
  });
  assert.equal(plan.id, "vip_monthly");
});

test("expired paid memberships resolve to Free", () => {
  const now = 1_000_000;
  const plan = effectiveMembershipPlan({
    nowMillis: now,
    vipMembership: {
      active: true,
      currentPeriodEnd: timestamp(now - 1),
    },
    dispatchMembership: {
      active: true,
      plan: "monthly",
      currentPeriodEnd: timestamp(now - 1),
    },
  });
  assert.equal(plan.id, "free");
});

test("plan metadata switches billing surface without changing ownership", () => {
  const dispatch = membershipPlanMetadata(
      membershipPlanCatalog().dispatch_monthly,
      "uid-1",
  );
  assert.equal(dispatch.billingType, "dispatch_subscription");
  assert.equal(dispatch.dispatchPlan, "monthly");
  assert.equal(dispatch.vipPlan, "");
  assert.equal(dispatch.pipeBuyerUid, "uid-1");
  const vip = membershipPlanMetadata(
      membershipPlanCatalog().vip_monthly,
      "uid-1",
  );
  assert.equal(vip.billingType, "vip_subscription");
  assert.equal(vip.vipPlan, "monthly");
  assert.equal(vip.dispatchPlan, "");
});

test("provider selection refuses two distinct paid subscriptions", () => {
  assert.throws(() => uniqueBlockingSubscriptionId({
    uid: "uid-1",
    dispatchProvider: {
      ownerUid: "uid-1",
      subscriptionId: "sub_dispatch",
      providerStatus: "active",
    },
    vipProvider: {
      ownerUid: "uid-1",
      subscriptionId: "sub_vip",
      providerStatus: "active",
    },
  }));
  assert.equal(uniqueBlockingSubscriptionId({
    uid: "uid-1",
    dispatchProvider: {
      ownerUid: "uid-1",
      subscriptionId: "sub_same",
      providerStatus: "active",
    },
    vipProvider: {
      ownerUid: "uid-1",
      subscriptionId: "sub_same",
      providerStatus: "active",
    },
  }), "sub_same");
  assert.equal(providerSubscriptionId({
    ownerUid: "uid-1",
    subscriptionId: "sub_done",
    providerStatus: "canceled",
  }, "uid-1"), "");
});

test("active mobile billing provider owns plan management", () => {
  const now = 10_000;
  const nativeProvider = {
    ownerUid: "uid-1",
    active: true,
    provider: "app_store",
    expiresAtMillis: now + 5_000,
  };
  assert.equal(
      activeNativeProvider(nativeProvider, "uid-1", now),
      "app_store",
  );
  assert.equal(
      activeNativeProvider(nativeProvider, "other-user", now),
      "",
  );
  assert.equal(
      activeNativeProvider({...nativeProvider, expiresAtMillis: now - 1},
          "uid-1", now),
      "",
  );
  const status = planStatusPayload({
    uid: "uid-1",
    currentPlan: membershipPlanCatalog().vip_monthly,
    nativeProvider,
    transition: null,
  });
  assert.equal(status.currentProvider, "app_store");
  assert.equal(status.manageInStore, true);
});

test("period bounds prefer subscription item period", () => {
  assert.deepEqual(subscriptionPeriodBounds({
    items: {data: [{
      id: "si_1",
      price: {id: membershipPlanCatalog().dispatch_monthly.priceId},
      current_period_start: 100,
      current_period_end: 200,
    }]},
    current_period_start: 10,
    current_period_end: 20,
  }), {start: 100, end: 200});
});
