"use strict";

const crypto = require("node:crypto");
const assert = require("node:assert/strict");
const test = require("node:test");
const {
  createStripeWebhookEventStore,
} = require("../stripe_webhook_event_store");
const {
  createStripeWebhookDispatchLifecycleWrapper,
} = require("../stripe_webhook_dispatch_lifecycle");
const {createMemoryAdmin} = require("./memory_firestore");

test("Stripe webhook event lease admits only one concurrent worker", async () => {
  const memory = createMemoryAdmin();
  let clock = 1000;
  const store = createStripeWebhookEventStore({
    db: memory.db,
    admin: memory.admin,
    now: () => clock,
    leaseMillis: 5000,
  });
  const [first, second] = await Promise.all([
    store.begin({eventId: "evt_concurrent", type: "charge.refunded"}),
    store.begin({eventId: "evt_concurrent", type: "charge.refunded"}),
  ]);
  assert.deepEqual(
      [first.state, second.state].sort(),
      ["acquired", "in_progress"],
  );
  const acquired = first.state === "acquired" ? first : second;
  await store.complete("evt_concurrent", acquired);
  assert.equal((await store.begin({eventId: "evt_concurrent"})).state, "duplicate");
  assert.equal(
      memory.read("stripe_webhook_events/evt_concurrent").attemptCount,
      1,
  );
});

test("failed and expired Stripe webhook leases retry with lease CAS", async () => {
  const memory = createMemoryAdmin();
  let clock = 1000;
  const store = createStripeWebhookEventStore({
    db: memory.db,
    admin: memory.admin,
    now: () => clock,
    leaseMillis: 5000,
  });
  const first = await store.begin({eventId: "evt_retry", type: "invoice.paid"});
  await store.fail("evt_retry", new Error("temporary"), first);
  const retry = await store.begin({eventId: "evt_retry", type: "invoice.paid"});
  assert.equal(retry.state, "acquired");
  clock = 7000;
  const takeover = await store.begin({eventId: "evt_retry", type: "invoice.paid"});
  assert.equal(takeover.state, "acquired");
  await assert.rejects(
      store.complete("evt_retry", retry),
      (error) => error.code === "stripe_webhook_lease_lost",
  );
  await store.complete("evt_retry", takeover);
  assert.equal(memory.read("stripe_webhook_events/evt_retry").attemptCount, 3);
});

test("subscription wrapper claims before provider-state side effects", async () => {
  const memory = createMemoryAdmin();
  const store = createStripeWebhookEventStore({
    db: memory.db,
    admin: memory.admin,
  });
  const secret = "whsec_test";
  const event = {
    id: "evt_subscription_concurrent",
    livemode: false,
    type: "checkout.session.completed",
    data: {object: {
      id: "cs_subscription",
      metadata: {billingType: "dispatch_subscription"},
    }},
  };
  const rawBody = Buffer.from(JSON.stringify(event));
  const timestamp = Math.floor(Date.now() / 1000);
  const signature = crypto.createHmac("sha256", secret)
      .update(`${timestamp}.${rawBody.toString("utf8")}`)
      .digest("hex");
  let enterLifecycle;
  const lifecycleEntered = new Promise((resolve) => {
    enterLifecycle = resolve;
  });
  let finishLifecycle;
  const lifecycleFinished = new Promise((resolve) => {
    finishLifecycle = resolve;
  });
  let lifecycleCalls = 0;
  const baseHandler = async (_request, response, context) => {
    assert.equal(context.claim.state, "acquired");
    await store.complete(event.id, context.claim);
    response.status(200).send("OK");
  };
  baseHandler.webhookEventStore = store;
  baseHandler.verifyRequest = async () => ({
    ok: true,
    event,
    stripeMode: "production",
  });
  const wrapper = createStripeWebhookDispatchLifecycleWrapper({
    baseHandler,
    dispatchSubscriptionLifecycle: {
      async handleDispatchCheckoutCompleted() {
        lifecycleCalls += 1;
        enterLifecycle();
        await lifecycleFinished;
      },
    },
    vipSubscriptionLifecycle: {},
  });
  const request = {
    rawBody,
    get: () => `t=${timestamp},v1=${signature}`,
  };
  const response = () => {
    const result = {statusCode: null, body: null};
    return {
      result,
      status(code) {
        result.statusCode = code;
        return this;
      },
      send(body) {
        result.body = body;
        return this;
      },
    };
  };
  const firstResponse = response();
  const first = wrapper(request, firstResponse);
  await lifecycleEntered;
  const secondResponse = response();
  await wrapper(request, secondResponse);
  assert.equal(secondResponse.result.statusCode, 409);
  assert.equal(lifecycleCalls, 1);
  finishLifecycle();
  await first;
  assert.equal(firstResponse.result.statusCode, 200);
});

test("subscription wrapper rejects sandbox membership mutations", async () => {
  let lifecycleCalls = 0;
  const baseHandler = async () => {
    throw new Error("Sandbox subscription events must not reach the base handler.");
  };
  baseHandler.webhookEventStore = {begin: async () => ({state: "acquired"})};
  baseHandler.verifyRequest = async () => ({
    ok: true,
    stripeMode: "sandbox",
    event: {
      id: "evt_sandbox_subscription",
      type: "checkout.session.completed",
      data: {object: {
        metadata: {billingType: "dispatch_subscription"},
      }},
    },
  });
  const wrapper = createStripeWebhookDispatchLifecycleWrapper({
    baseHandler,
    dispatchSubscriptionLifecycle: {
      async handleDispatchCheckoutCompleted() {
        lifecycleCalls += 1;
      },
    },
    vipSubscriptionLifecycle: {},
  });
  const result = {statusCode: null, body: null};
  await wrapper({}, {
    status(code) {
      result.statusCode = code;
      return this;
    },
    send(body) {
      result.body = body;
      return this;
    },
  });
  assert.equal(result.statusCode, 409);
  assert.match(result.body, /production environment/u);
  assert.equal(lifecycleCalls, 0);
});

test("subscription wrapper rejects sandbox invoice monetization", async () => {
  let baseCalls = 0;
  const baseHandler = async () => {
    baseCalls += 1;
  };
  baseHandler.webhookEventStore = {begin: async () => ({state: "acquired"})};
  baseHandler.verifyRequest = async () => ({
    ok: true,
    stripeMode: "sandbox",
    event: {
      id: "evt_sandbox_invoice",
      type: "invoice.paid",
      data: {object: {id: "in_sandbox"}},
    },
  });
  const wrapper = createStripeWebhookDispatchLifecycleWrapper({
    baseHandler,
    dispatchSubscriptionLifecycle: {},
    vipSubscriptionLifecycle: {},
  });
  const result = {statusCode: null};
  await wrapper({}, {
    status(code) {
      result.statusCode = code;
      return this;
    },
    send() {
      return this;
    },
  });
  assert.equal(result.statusCode, 409);
  assert.equal(baseCalls, 0);
});
