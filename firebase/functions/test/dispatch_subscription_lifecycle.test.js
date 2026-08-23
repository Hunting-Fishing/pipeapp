"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  dispatchCheckoutIdentity,
  dispatchSubscriptionIdentity,
  lifecycleStatePatch,
  providerSubscriptionState,
} = require("../dispatch_subscription_lifecycle");
const {
  isDispatchCheckoutCompletedEvent,
  isDispatchSubscriptionLifecycleEvent,
  stripeEventFromRawBody,
} = require("../stripe_webhook_dispatch_lifecycle");

test("Dispatch subscription identity accepts only owned Dispatch metadata", () => {
  assert.deepEqual(dispatchSubscriptionIdentity({
    id: "sub_123",
    metadata: {
      billingType: "dispatch_subscription",
      pipeBuyerUid: "carrier_1",
    },
  }), {
    subscriptionId: "sub_123",
    uid: "carrier_1",
    metadata: {
      billingType: "dispatch_subscription",
      pipeBuyerUid: "carrier_1",
    },
  });
  assert.equal(dispatchSubscriptionIdentity({
    id: "sub_123",
    metadata: {billingType: "other", pipeBuyerUid: "carrier_1"},
  }), null);
});

test("completed Dispatch Checkout identifies provider state without granting access", () => {
  const session = {
    subscription: "sub_123",
    customer: "cus_123",
    client_reference_id: "carrier_1",
    metadata: {
      billingType: "dispatch_subscription",
      pipeBuyerUid: "carrier_1",
    },
  };
  assert.deepEqual(dispatchCheckoutIdentity(session), {
    uid: "carrier_1",
    subscriptionId: "sub_123",
    stripeCustomerId: "cus_123",
  });
  assert.equal(isDispatchCheckoutCompletedEvent({
    type: "checkout.session.completed",
    data: {object: session},
  }), true);
});

test("provider state blocks duplicate checkout before entitlement exists", () => {
  assert.deepEqual(providerSubscriptionState({
    status: "incomplete",
    customer: "cus_123",
    current_period_end: 1200,
  }), {
    providerStatus: "incomplete",
    blocksNewCheckout: true,
    cancelAtPeriodEnd: false,
    providerPeriodEndMillis: 1_200_000,
    stripeCustomerId: "cus_123",
  });
  assert.equal(providerSubscriptionState({status: "canceled"}).blocksNewCheckout, false);
});

test("cancel-at-period-end keeps already-paid access only until paid-through", () => {
  const now = 1_000_000;
  const patch = lifecycleStatePatch({
    subscription: {
      status: "active",
      cancel_at_period_end: true,
      cancel_at: 1100,
      current_period_end: 1100,
    },
    existingMembership: {
      status: "active",
      currentPeriodEnd: {toMillis: () => 1_100_000},
    },
    nowMillis: now,
  });
  assert.equal(patch.active, true);
  assert.equal(patch.status, "active_until_period_end");
  assert.equal(patch.renewalStatus, "cancel_at_period_end");
  assert.equal(patch.cancelAtPeriodEnd, true);
  assert.equal(patch.cancellationEffectiveMillis, 1_100_000);
});

test("deleted subscription cannot keep access after paid-through expires", () => {
  const now = 1_200_000;
  const patch = lifecycleStatePatch({
    subscription: {
      status: "canceled",
      current_period_end: 1100,
    },
    existingMembership: {
      status: "active",
      currentPeriodEnd: {toMillis: () => 1_100_000},
    },
    deleted: true,
    nowMillis: now,
  });
  assert.equal(patch.active, false);
  assert.equal(patch.status, "canceled");
  assert.equal(patch.renewalStatus, "canceled");
});

test("past-due lifecycle flags payment issue without extending paid period", () => {
  const now = 1_000_000;
  const patch = lifecycleStatePatch({
    subscription: {status: "past_due", current_period_end: 1200},
    existingMembership: {
      status: "active",
      currentPeriodEnd: {toMillis: () => 1_100_000},
    },
    nowMillis: now,
  });
  assert.equal(patch.active, true);
  assert.equal(patch.paymentIssue, true);
  assert.equal(patch.renewalStatus, "past_due");
});

test("paused lifecycle flags payment issue without inventing new paid time", () => {
  const now = 1_000_000;
  const patch = lifecycleStatePatch({
    subscription: {status: "paused", current_period_end: 1200},
    existingMembership: {
      status: "active",
      currentPeriodEnd: {toMillis: () => 1_100_000},
    },
    nowMillis: now,
  });
  assert.equal(patch.active, true);
  assert.equal(patch.paymentIssue, true);
  assert.equal(patch.renewalStatus, "paused");
});

test("webhook lifecycle detector selects subscription create/update/delete/pause/resume", () => {
  for (const type of [
    "customer.subscription.created",
    "customer.subscription.updated",
    "customer.subscription.deleted",
    "customer.subscription.paused",
    "customer.subscription.resumed",
  ]) {
    const event = stripeEventFromRawBody(Buffer.from(JSON.stringify({
      id: "evt_123",
      type,
      data: {object: {id: "sub_123"}},
    })));
    assert.equal(isDispatchSubscriptionLifecycleEvent(event), true, type);
  }
  assert.equal(isDispatchSubscriptionLifecycleEvent({
    type: "invoice.paid",
    data: {object: {id: "in_123"}},
  }), false);
  assert.equal(stripeEventFromRawBody(Buffer.from("not json")), null);
});
