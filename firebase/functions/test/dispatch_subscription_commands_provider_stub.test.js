"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  createDispatchSubscriptionCommands,
} = require("../dispatch_subscription_commands");

const FieldValue = {serverTimestamp: () => "server-time"};

function fakeAdmin(initial = {}) {
  const docs = new Map(Object.entries(initial));
  function makeRef(path) {
    return {
      path,
      async get() {
        const value = docs.get(path);
        return {exists: value != null, data: () => value};
      },
    };
  }
  const db = {
    docs,
    collection(name) {
      return {
        doc(id) {
          return makeRef(`${name}/${id}`);
        },
      };
    },
    async runTransaction(callback) {
      const writes = [];
      const transaction = {
        async get(ref) {
          const value = docs.get(ref.path);
          return {exists: value != null, data: () => value};
        },
        set(ref, value, options) {
          writes.push({ref, value, options});
        },
      };
      const result = await callback(transaction);
      for (const write of writes) {
        const current = docs.get(write.ref.path) || {};
        docs.set(
            write.ref.path,
            write.options && write.options.merge ?
              {...current, ...write.value} : write.value,
        );
      }
      return result;
    },
  };
  function firestore() {
    return db;
  }
  firestore.FieldValue = FieldValue;
  return {admin: {firestore}, db};
}

function baseReadiness() {
  return {
    stripeSubscriptionsEnabled: true,
    checkoutSuccessUrl: "https://pipebuyer.com/payments/success",
    checkoutCancelUrl: "https://pipebuyer.com/payments/cancel",
    canadaGstHstSmallSupplier: false,
  };
}

function fixture({state, stripeRequest}) {
  const initial = {
    "platform_configuration/payment_provider_readiness": baseReadiness(),
  };
  if (state) initial["dispatch_subscriptions/user-1"] = state;
  const {admin, db} = fakeAdmin(initial);
  const commands = createDispatchSubscriptionCommands(admin, {
    authUid: () => "user-1",
    rateLimit: async () => {},
    loadFeatureFlags: async () => ({dispatch: true, paidFeatures: true}),
    requireFeature: () => {},
    loadProviderReadiness: async () => ({
      stripeMode: "production",
      stripeWebhookVerified: true,
      stripeTaxReady: true,
      stripeReconciliationReady: true,
      canadaGstHstSmallSupplier: false,
    }),
    runtimeTaxEvidence: async () => ({applicable: false, authorized: true}),
    secretProvider: () => "sk_test_dispatch_stub",
    stripeRequest,
  });
  return {commands, db};
}

function request(plan = "monthly") {
  return {data: {plan}};
}

test("first Dispatch Checkout uses stable attempt idempotency and persists singleton state", async () => {
  const providerCalls = [];
  const {commands, db} = fixture({
    stripeRequest: async (call) => {
      providerCalls.push(call);
      assert.equal(call.idempotencyKey, "pipebuyer-dispatch-user-1-attempt-1");
      assert.equal(call.fields.mode, "subscription");
      assert.equal(call.fields["metadata[checkoutAttempt]"], 1);
      assert.equal(call.fields["metadata[billingType]"], "dispatch_subscription");
      return {
        id: "cs_dispatch_first",
        url: "https://checkout.stripe.com/c/pay/dispatch-first",
      };
    },
  });
  const result = await commands.createDispatchSubscriptionCheckout(request());
  assert.equal(result.checkoutAttempt, 1);
  assert.equal(result.alreadyCreated, false);
  assert.equal(providerCalls.length, 1);
  const state = db.docs.get("dispatch_subscriptions/user-1");
  assert.equal(state.status, "checkout_created");
  assert.equal(state.checkoutAttempt, 1);
  assert.equal(state.stripeCheckoutSessionId, "cs_dispatch_first");
  assert.equal(state.stripeSubscriptionId, null);
  const session = db.docs.get("subscription_checkout_sessions/cs_dispatch_first");
  assert.equal(session.checkoutAttempt, 1);
  assert.equal(session.plan, "monthly");
});

test("double tap reuses open Dispatch Checkout and never creates another Session", async () => {
  let calls = 0;
  const {commands} = fixture({
    state: {
      uid: "user-1",
      plan: "monthly",
      status: "checkout_created",
      checkoutAttempt: 1,
      stripeCheckoutSessionId: "cs_dispatch_open",
    },
    stripeRequest: async (call) => {
      calls += 1;
      assert.equal(call.method, "GET");
      assert.match(call.path, /cs_dispatch_open$/u);
      return {
        status: "open",
        payment_status: "unpaid",
        url: "https://checkout.stripe.com/c/pay/dispatch-open",
      };
    },
  });
  const result = await commands.createDispatchSubscriptionCheckout(request());
  assert.equal(result.alreadyCreated, true);
  assert.equal(result.processing, false);
  assert.equal(result.checkoutSessionId, "cs_dispatch_open");
  assert.equal(calls, 1);
});

test("existing active subscription blocks a second Stripe Checkout without leaking provider id", async () => {
  let calls = 0;
  const {commands} = fixture({
    state: {
      uid: "user-1",
      plan: "monthly",
      status: "active",
      stripeSubscriptionId: "sub_dispatch_active",
    },
    stripeRequest: async () => {
      calls += 1;
      throw new Error("Stripe should not be called");
    },
  });
  const result = await commands.createDispatchSubscriptionCheckout(request("yearly"));
  assert.equal(result.alreadySubscribed, true);
  assert.equal(result.subscriptionStatus, "active");
  assert.equal("stripeSubscriptionId" in result, false);
  assert.equal(calls, 0);
});

test("different plan cannot create a second Session while Checkout is open", async () => {
  let calls = 0;
  const {commands} = fixture({
    state: {
      uid: "user-1",
      plan: "monthly",
      status: "checkout_created",
      checkoutAttempt: 1,
      stripeCheckoutSessionId: "cs_monthly_open",
    },
    stripeRequest: async () => {
      calls += 1;
      return {};
    },
  });
  await assert.rejects(
      () => commands.createDispatchSubscriptionCheckout(request("yearly")),
      /monthly Dispatch Checkout is already open/i,
  );
  assert.equal(calls, 0);
});

test("provider response cannot overwrite subscription created by faster webhook", async () => {
  let db;
  const built = fixture({
    stripeRequest: async () => {
      db.docs.set("dispatch_subscriptions/user-1", {
        uid: "user-1",
        plan: "monthly",
        status: "active",
        checkoutAttempt: 1,
        stripeCheckoutSessionId: "cs_dispatch_race",
        stripeSubscriptionId: "sub_dispatch_race",
      });
      return {
        id: "cs_dispatch_race",
        url: "https://checkout.stripe.com/c/pay/dispatch-race",
      };
    },
  });
  db = built.db;
  const result = await built.commands.createDispatchSubscriptionCheckout(request());
  assert.equal(result.alreadySubscribed, true);
  assert.equal("stripeSubscriptionId" in result, false);
  const state = db.docs.get("dispatch_subscriptions/user-1");
  assert.equal(state.status, "active");
  assert.equal(state.stripeSubscriptionId, "sub_dispatch_race");
});

test("canceled subscription can start a clean replacement Checkout without stale subscription id", async () => {
  const {commands, db} = fixture({
    state: {
      uid: "user-1",
      plan: "monthly",
      status: "canceled",
      entitlementActive: false,
      checkoutAttempt: 1,
      stripeSubscriptionId: "sub_dispatch_retired",
      stripeCustomerId: "cus_dispatch_existing",
    },
    stripeRequest: async (call) => {
      assert.equal(call.idempotencyKey, "pipebuyer-dispatch-user-1-attempt-2");
      return {
        id: "cs_dispatch_replacement",
        url: "https://checkout.stripe.com/c/pay/dispatch-replacement",
      };
    },
  });
  const result = await commands.createDispatchSubscriptionCheckout(request("yearly"));
  assert.equal(result.checkoutAttempt, 2);
  const state = db.docs.get("dispatch_subscriptions/user-1");
  assert.equal(state.status, "checkout_created");
  assert.equal(state.plan, "yearly");
  assert.equal(state.stripeSubscriptionId, null);
  assert.equal(state.stripeCustomerId, "cus_dispatch_existing");
});

test("Dispatch Checkout URL is restricted to checkout.stripe.com", async () => {
  const {commands} = fixture({
    stripeRequest: async () => ({
      id: "cs_bad_host",
      url: "https://evil.example/checkout",
    }),
  });
  await assert.rejects(
      () => commands.createDispatchSubscriptionCheckout(request()),
      /valid subscription Checkout/i,
  );
});
