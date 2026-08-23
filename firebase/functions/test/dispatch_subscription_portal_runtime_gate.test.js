"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  DISPATCH_BILLING_PORTAL_PROVIDER_REVISION,
  DISPATCH_PORTAL_CUSTOMER_UPDATES,
  DISPATCH_PORTAL_PRICE_IDS,
  DISPATCH_PORTAL_PRODUCT_ID,
} = require("../dispatch_billing_portal_policy");
const {
  createDispatchSubscriptionPortalRuntimeGate,
  dispatchBillingPortalRuntimeDecision,
} = require("../dispatch_subscription_portal_runtime_gate");

function storedProviderFeatures(overrides = {}) {
  return {
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
    subscriptionUpdateProductId: DISPATCH_PORTAL_PRODUCT_ID,
    subscriptionUpdatePriceIds: [...DISPATCH_PORTAL_PRICE_IDS],
    ...overrides,
  };
}

function verifiedPortal(overrides = {}) {
  return {
    enabled: true,
    returnUrl: "https://pipebuyer.com/account",
    stripePortalConfigurationId: "bpc_live_dispatch",
    providerVerified: true,
    providerVerifiedConfigurationId: "bpc_live_dispatch",
    providerVerificationRevision: DISPATCH_BILLING_PORTAL_PROVIDER_REVISION,
    providerVerifiedFeatures: storedProviderFeatures(),
    ...overrides,
  };
}

function liveProviderPortal(overrides = {}) {
  return {
    id: "bpc_live_dispatch",
    active: true,
    livemode: true,
    features: {
      payment_method_update: {enabled: true},
      customer_update: {
        enabled: true,
        allowed_updates: [...DISPATCH_PORTAL_CUSTOMER_UPDATES],
      },
      invoice_history: {enabled: true},
      subscription_cancel: {
        enabled: true,
        mode: "at_period_end",
        proration_behavior: "none",
      },
      subscription_update: {
        enabled: true,
        default_allowed_updates: ["price"],
        proration_behavior: "none",
        products: [{
          product: DISPATCH_PORTAL_PRODUCT_ID,
          prices: [...DISPATCH_PORTAL_PRICE_IDS],
        }],
      },
    },
    ...overrides,
  };
}

function authenticatedRequest(data = {}) {
  return {
    auth: {uid: "user-1", token: {}},
    data,
  };
}

function fakeAdmin(portal, counters = null) {
  return {
    firestore() {
      return {
        collection(name) {
          if (counters) counters.firestoreReads += 1;
          assert.equal(name, "platform_configuration");
          return {
            doc(id) {
              assert.equal(id, "dispatch_billing_portal");
              return {
                async get() {
                  return {
                    exists: portal != null,
                    data: () => portal,
                  };
                },
              };
            },
          };
        },
      };
    },
  };
}

test("runtime Portal decision requires complete stored proof bound to the exact bpc", () => {
  const ready = dispatchBillingPortalRuntimeDecision(verifiedPortal());
  assert.equal(ready.ready, true);
  assert.equal(ready.configurationId, "bpc_live_dispatch");
  assert.equal(dispatchBillingPortalRuntimeDecision(verifiedPortal({
    providerVerified: false,
  })).ready, false);
  assert.equal(dispatchBillingPortalRuntimeDecision(verifiedPortal({
    providerVerifiedConfigurationId: "bpc_other",
  })).ready, false);
  assert.equal(dispatchBillingPortalRuntimeDecision(verifiedPortal({
    providerVerificationRevision: "old-policy",
  })).ready, false);
  assert.equal(dispatchBillingPortalRuntimeDecision(verifiedPortal({
    providerVerifiedFeatures: storedProviderFeatures({
      subscriptionUpdateAllowedUpdates: ["price", "quantity"],
    }),
  })).ready, false);
  assert.equal(dispatchBillingPortalRuntimeDecision(verifiedPortal({
    providerVerifiedFeatures: {},
  })).ready, false);
});

test("runtime Portal decision rejects unsafe return URL", () => {
  const decision = dispatchBillingPortalRuntimeDecision(verifiedPortal({
    returnUrl: "https://evil.example/account",
  }));
  assert.equal(decision.ready, false);
  assert.equal(decision.reason, "return_url_invalid");
});

test("unauthenticated request cannot trigger Firestore or Stripe provider reads", async () => {
  const counters = {firestoreReads: 0, providerCalls: 0, invoked: 0};
  const gate = createDispatchSubscriptionPortalRuntimeGate(
      fakeAdmin(verifiedPortal(), counters),
      async () => {
        counters.invoked += 1;
        return {ok: true};
      },
      {
        secretProvider: () => "sk_live_stub",
        stripeRequest: async () => {
          counters.providerCalls += 1;
          return liveProviderPortal();
        },
      },
  );
  await assert.rejects(
      () => gate({data: {plan: "monthly"}}),
      /sign in before using Dispatch billing/i,
  );
  assert.deepEqual(counters, {
    firestoreReads: 0,
    providerCalls: 0,
    invoked: 0,
  });
});

test("production gate blocks before provider request when stored proof is invalid", async () => {
  let invoked = 0;
  let providerCalls = 0;
  const gate = createDispatchSubscriptionPortalRuntimeGate(
      fakeAdmin(verifiedPortal({providerVerified: false})),
      async () => {
        invoked += 1;
        return {ok: true};
      },
      {
        secretProvider: () => "sk_live_stub",
        stripeRequest: async () => {
          providerCalls += 1;
          return liveProviderPortal();
        },
      },
  );
  await assert.rejects(
      () => gate(authenticatedRequest({plan: "monthly"})),
      /provider-verified Billing Portal configuration/i,
  );
  assert.equal(providerCalls, 0);
  assert.equal(invoked, 0);
});

test("production gate re-reads exact live bpc before delegating", async () => {
  let invoked = 0;
  const providerCalls = [];
  const gate = createDispatchSubscriptionPortalRuntimeGate(
      fakeAdmin(verifiedPortal()),
      async (request) => {
        invoked += 1;
        return {plan: request.data.plan};
      },
      {
        secretProvider: () => "sk_live_stub",
        stripeRequest: async (call) => {
          providerCalls.push(call);
          return liveProviderPortal();
        },
      },
  );
  const result = await gate(authenticatedRequest({plan: "yearly"}));
  assert.equal(invoked, 1);
  assert.equal(providerCalls.length, 1);
  assert.equal(providerCalls[0].method, "GET");
  assert.match(providerCalls[0].path, /bpc_live_dispatch$/u);
  assert.deepEqual(result, {plan: "yearly"});
});

test("provider-side Portal drift blocks quantity changes even when stored proof is green", async () => {
  let invoked = 0;
  const gate = createDispatchSubscriptionPortalRuntimeGate(
      fakeAdmin(verifiedPortal()),
      async () => {
        invoked += 1;
        return {ok: true};
      },
      {
        secretProvider: () => "sk_live_stub",
        stripeRequest: async () => liveProviderPortal({
          features: {
            payment_method_update: {enabled: true},
            customer_update: {
              enabled: true,
              allowed_updates: [...DISPATCH_PORTAL_CUSTOMER_UPDATES],
            },
            invoice_history: {enabled: true},
            subscription_cancel: {
              enabled: true,
              mode: "at_period_end",
              proration_behavior: "none",
            },
            subscription_update: {
              enabled: true,
              default_allowed_updates: ["price", "quantity"],
              proration_behavior: "none",
              products: [{
                product: DISPATCH_PORTAL_PRODUCT_ID,
                prices: [...DISPATCH_PORTAL_PRICE_IDS],
              }],
            },
          },
        }),
      },
  );
  await assert.rejects(
      () => gate(authenticatedRequest({plan: "monthly"})),
      /no longer matches the approved launch policy/i,
  );
  assert.equal(invoked, 0);
});
