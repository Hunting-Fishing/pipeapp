"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  createDispatchSubscriptionCommands,
} = require("../dispatch_subscription_commands");
const {
  DISPATCH_BILLING_PORTAL_PROVIDER_REVISION,
  DISPATCH_PORTAL_CUSTOMER_UPDATES,
  DISPATCH_PORTAL_PRICE_IDS,
  DISPATCH_PORTAL_PRODUCT_ID,
} = require("../dispatch_billing_portal_policy");
const {stripeMarketplaceConfig} = require("../stripe_marketplace_config");

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
      return {doc(id) { return makeRef(`${name}/${id}`); }};
    },
    async runTransaction(callback) {
      const writes = [];
      const transaction = {
        async get(ref) {
          const value = docs.get(ref.path);
          return {exists: value != null, data: () => value};
        },
        set(ref, value, options) { writes.push({ref, value, options}); },
      };
      const result = await callback(transaction);
      for (const write of writes) {
        const current = docs.get(write.ref.path) || {};
        docs.set(write.ref.path, write.options && write.options.merge ?
          {...current, ...write.value} : write.value);
      }
      return result;
    },
  };
  function firestore() { return db; }
  firestore.FieldValue = FieldValue;
  return {admin: {firestore}, db};
}

function baseReadiness() {
  return {
    stripeSubscriptionsEnabled: true,
    stripeSubscriptionRecoveryVerified: true,
    stripeSubscriptionLifecycleWebhookVerified: true,
    checkoutSuccessUrl: "https://pipebuyer.com/payments/success",
    checkoutCancelUrl: "https://pipebuyer.com/payments/cancel",
    canadaGstHstSmallSupplier: false,
  };
}

function verifiedPortal(overrides = {}) {
  return {
    enabled: true,
    returnUrl: "https://pipebuyer.com/account/memberships",
    stripePortalConfigurationId: "bpc_dispatch_live",
    providerVerified: true,
    providerVerifiedConfigurationId: "bpc_dispatch_live",
    providerVerificationRevision: DISPATCH_BILLING_PORTAL_PROVIDER_REVISION,
    providerVerifiedFeatures: {
      paymentMethodUpdate: true,
      customerUpdate: true,
      customerUpdateAllowedUpdates: [...DISPATCH_PORTAL_CUSTOMER_UPDATES],
      invoiceHistory: true,
      subscriptionCancel: true,
      subscriptionCancelMode: "at_period_end",
      subscriptionCancelProration: "none",
      subscriptionUpdate: true,
      subscriptionUpdateAllowedUpdates: ["price"],
      subscriptionUpdateProration: "none",
      subscriptionUpdateTrialBehavior: "continue_trial",
      subscriptionUpdateScheduleAtPeriodEndConditions: [],
      subscriptionUpdateProductId: DISPATCH_PORTAL_PRODUCT_ID,
      subscriptionUpdatePriceIds: [...DISPATCH_PORTAL_PRICE_IDS],
    },
    ...overrides,
  };
}

function fixture({state, stripeRequest, portal = verifiedPortal(), nowMs}) {
  const initial = {
    "platform_configuration/payment_provider_readiness": baseReadiness(),
    "platform_configuration/dispatch_billing_portal": portal,
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
    ...(nowMs ? {nowMs} : {}),
  });
  return {commands, db};
}

function request(plan = "monthly", promotionCode = "") {
  return {data: {plan, ...(promotionCode ? {promotionCode} : {})}};
}

test("inner Checkout command rejects missing Portal provider proof before Stripe", async () => {
  let providerCalls = 0;
  const {commands} = fixture({
    portal: verifiedPortal({providerVerified: false}),
    stripeRequest: async () => { providerCalls += 1; return {}; },
  });
  await assert.rejects(() => commands.createDispatchSubscriptionCheckout(request()), /not enabled yet/i);
  assert.equal(providerCalls, 0);
});

test("first Dispatch Checkout uses stable attempt idempotency and lets Stripe create first Customer", async () => {
  const providerCalls = [];
  const {commands, db} = fixture({
    stripeRequest: async (call) => {
      providerCalls.push(call);
      assert.equal(call.idempotencyKey, "pipebuyer-dispatch-user-1-attempt-1");
      assert.equal(call.fields.customer, undefined);
      assert.equal(call.fields.allow_promotion_codes, "true");
      assert.equal(call.fields["subscription_data[trial_end]"], undefined);
      assert.equal(call.fields["line_items[0][price]"], stripeMarketplaceConfig.products.dispatchMonthlyCad.priceId);
      return {id: "cs_dispatch_first", url: "https://checkout.stripe.com/c/pay/dispatch-first"};
    },
  });
  const result = await commands.createDispatchSubscriptionCheckout(request());
  assert.equal(result.checkoutAttempt, 1);
  assert.equal(providerCalls.length, 1);
  assert.equal(db.docs.get("dispatch_subscriptions/user-1").status, "checkout_created");
});

test("Founding500 Checkout claims one slot and sets exact six-month trial without Stripe discount stacking", async () => {
  const fixedNow = Date.UTC(2026, 7, 23, 15, 30, 0);
  const {commands, db} = fixture({
    nowMs: () => fixedNow,
    stripeRequest: async (call) => {
      assert.equal(call.fields.allow_promotion_codes, "false");
      assert.equal(call.fields["discounts[0][coupon]"], undefined);
      assert.equal(call.fields["subscription_data[trial_end]"], 1803396600);
      assert.equal(call.fields["metadata[launchPromotionCode]"], "FOUNDING500");
      return {id: "cs_founding_1", url: "https://checkout.stripe.com/c/pay/founding-1"};
    },
  });
  const result = await commands.createDispatchSubscriptionCheckout(
      request("yearly", "founding500"),
  );
  assert.equal(result.promotionApplied, true);
  assert.equal(result.launchPromotionCode, "FOUNDING500");
  const program = db.docs.get("dispatch_promotion_programs/dispatch_founding500_2026");
  assert.equal(program.claimedCount, 1);
  assert.equal(program.maxClaims, 500);
  const claim = db.docs.get("dispatch_promotion_claims/user-1");
  assert.equal(claim.claimNumber, 1);
  assert.equal(claim.status, "checkout_created");
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
      return {status: "open", payment_status: "unpaid", url: "https://checkout.stripe.com/c/pay/dispatch-open"};
    },
  });
  const result = await commands.createDispatchSubscriptionCheckout(request());
  assert.equal(result.alreadyCreated, true);
  assert.equal(result.checkoutSessionId, "cs_dispatch_open");
  assert.equal(calls, 1);
});

test("existing active subscription blocks a second Stripe Checkout", async () => {
  let calls = 0;
  const {commands} = fixture({
    state: {uid: "user-1", plan: "monthly", status: "active", stripeSubscriptionId: "sub_dispatch_active"},
    stripeRequest: async () => { calls += 1; return {}; },
  });
  const result = await commands.createDispatchSubscriptionCheckout(request("yearly"));
  assert.equal(result.alreadySubscribed, true);
  assert.equal(calls, 0);
});

test("canceled subscriber cannot receive Founding500 as a second free period", async () => {
  let calls = 0;
  const {commands} = fixture({
    state: {
      uid: "user-1",
      plan: "monthly",
      status: "canceled",
      stripeSubscriptionId: "sub_dispatch_retired",
      stripeCustomerId: "cus_dispatch_existing",
    },
    stripeRequest: async () => { calls += 1; return {}; },
  });
  await assert.rejects(
      () => commands.createDispatchSubscriptionCheckout(request("monthly", "FOUNDING500")),
      /first Dispatch subscription/i,
  );
  assert.equal(calls, 0);
});

test("canceled subscription reuses existing Stripe Customer and unified yearly price", async () => {
  const {commands, db} = fixture({
    state: {
      uid: "user-1",
      plan: "monthly",
      status: "canceled",
      entitlementActive: false,
      checkoutAttempt: 1,
      stripeSubscriptionId: "sub_dispatch_retired",
      stripeCustomerId: "cus_dispatch_existing",
      retiredStripeSubscriptionIds: ["sub_dispatch_older"],
    },
    stripeRequest: async (call) => {
      assert.equal(call.fields.customer, "cus_dispatch_existing");
      assert.equal(call.fields["line_items[0][price]"], stripeMarketplaceConfig.products.dispatchYearlyCad.priceId);
      return {id: "cs_dispatch_replacement", url: "https://checkout.stripe.com/c/pay/dispatch-replacement"};
    },
  });
  const result = await commands.createDispatchSubscriptionCheckout(request("yearly"));
  assert.equal(result.checkoutAttempt, 2);
  const state = db.docs.get("dispatch_subscriptions/user-1");
  assert.equal(state.stripeCustomerId, "cus_dispatch_existing");
  assert.deepEqual(state.retiredStripeSubscriptionIds, ["sub_dispatch_older", "sub_dispatch_retired"]);
});

test("malformed stored Stripe Customer identity fails closed before provider creation", async () => {
  let calls = 0;
  const {commands} = fixture({
    state: {
      uid: "user-1",
      plan: "monthly",
      status: "canceled",
      stripeSubscriptionId: "sub_dispatch_retired",
      stripeCustomerId: "not-a-customer",
    },
    stripeRequest: async () => { calls += 1; return {}; },
  });
  await assert.rejects(() => commands.createDispatchSubscriptionCheckout(request("yearly")), /billing customer identity needs review/i);
  assert.equal(calls, 0);
});
