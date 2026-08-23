"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  MAX_RETIRED_SUBSCRIPTION_IDS,
  dispatchCheckoutIdempotencyKey,
  dispatchPostProviderPersistenceDecision,
  dispatchRetiredSubscriptionIds,
  dispatchSubscriptionCheckoutState,
  existingDispatchCheckoutDecision,
  isDispatchRetiredSubscriptionId,
  nextDispatchCheckoutAttempt,
  nextDispatchRetiredSubscriptionIds,
} = require("../dispatch_subscription_checkout_policy");

test("existing Stripe subscription blocks a second subscription Checkout", () => {
  for (const status of ["active", "trialing", "past_due", "unpaid", "paused"] ) {
    assert.equal(dispatchSubscriptionCheckoutState({
      status,
      stripeSubscriptionId: "sub_existing",
    }), "existing_subscription");
  }
});

test("active Checkout requires a valid stored Session", () => {
  assert.equal(dispatchSubscriptionCheckoutState({
    status: "checkout_created",
    stripeCheckoutSessionId: "cs_open",
  }), "active_checkout");
  assert.equal(dispatchSubscriptionCheckoutState({
    status: "checkout_created",
  }), "inconsistent");
});

test("canceled or expired subscription state may start a new Checkout", () => {
  assert.equal(dispatchSubscriptionCheckoutState({
    status: "canceled",
    stripeSubscriptionId: "sub_old",
  }), "create");
  assert.equal(dispatchSubscriptionCheckoutState({
    status: "incomplete_expired",
    stripeSubscriptionId: "sub_old",
  }), "create");
});

test("retired subscription ids are normalized, deduplicated and bounded", () => {
  const many = Array.from(
      {length: MAX_RETIRED_SUBSCRIPTION_IDS + 3},
      (_, index) => `sub_${index}`,
  );
  const normalized = dispatchRetiredSubscriptionIds({
    retiredStripeSubscriptionIds: ["bad", many[0], many[0], ...many],
  });
  assert.equal(normalized.length, MAX_RETIRED_SUBSCRIPTION_IDS);
  assert.equal(normalized.at(-1), many.at(-1));
  assert.equal(normalized.includes("bad"), false);
});

test("restart moves current subscription into retired ledger exactly once", () => {
  const next = nextDispatchRetiredSubscriptionIds({
    stripeSubscriptionId: "sub_current",
    retiredStripeSubscriptionIds: ["sub_older", "sub_current"],
  });
  assert.deepEqual(next, ["sub_older", "sub_current"]);
  assert.equal(
      isDispatchRetiredSubscriptionId(
          {retiredStripeSubscriptionIds: next},
          "sub_current",
      ),
      true,
  );
  assert.equal(
      isDispatchRetiredSubscriptionId(
          {retiredStripeSubscriptionIds: next},
          "sub_unknown",
      ),
      false,
  );
});

test("Dispatch idempotency is stable per server-owned logical attempt", () => {
  assert.equal(nextDispatchCheckoutAttempt({checkoutAttempt: 1}), 2);
  assert.equal(
      dispatchCheckoutIdempotencyKey("user-1", 2),
      "pipebuyer-dispatch-user-1-attempt-2",
  );
  assert.equal(
      dispatchCheckoutIdempotencyKey("user-1", 2),
      dispatchCheckoutIdempotencyKey("user-1", 2),
  );
  assert.throws(
      () => dispatchCheckoutIdempotencyKey("", 1),
      /Invalid Dispatch Checkout/i,
  );
});

test("open provider Checkout is reused and expired Checkout may advance", () => {
  assert.equal(existingDispatchCheckoutDecision({
    providerStatus: "open",
    checkoutUrlValid: true,
  }).action, "reuse");
  assert.equal(existingDispatchCheckoutDecision({
    providerStatus: "open",
    checkoutUrlValid: false,
  }).action, "invalid_url");
  assert.equal(existingDispatchCheckoutDecision({
    providerStatus: "expired",
  }).action, "create_new");
});

test("complete or paid provider Checkout is processing-locked", () => {
  assert.equal(existingDispatchCheckoutDecision({
    providerStatus: "complete",
  }).action, "processing");
  assert.equal(existingDispatchCheckoutDecision({
    paymentStatus: "paid",
  }).action, "processing");
});

test("post-provider write cannot overwrite subscription or newer processing state", () => {
  assert.equal(dispatchPostProviderPersistenceDecision({
    currentStatus: "active",
    currentSubscriptionId: "sub_active",
    currentAttempt: 2,
    createdAttempt: 2,
    createdSessionId: "cs_2",
  }), "existing_subscription");
  assert.equal(dispatchPostProviderPersistenceDecision({
    currentStatus: "processing",
    currentSessionId: "cs_2",
    currentAttempt: 2,
    createdSessionId: "cs_2",
    createdAttempt: 2,
  }), "processing");
  assert.equal(dispatchPostProviderPersistenceDecision({
    currentStatus: "checkout_created",
    currentSessionId: "cs_3",
    currentAttempt: 3,
    createdSessionId: "cs_2",
    createdAttempt: 2,
  }), "superseded");
});
