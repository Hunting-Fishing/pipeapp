"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  DISPATCH_BILLING_PORTAL_PROVIDER_REVISION,
} = require("../dispatch_billing_portal_policy");
const {
  createDispatchSubscriptionPortalRuntimeGate,
  dispatchBillingPortalRuntimeDecision,
} = require("../dispatch_subscription_portal_runtime_gate");

function verifiedPortal(overrides = {}) {
  return {
    enabled: true,
    returnUrl: "https://pipebuyer.com/account",
    stripePortalConfigurationId: "bpc_live_dispatch",
    providerVerified: true,
    providerVerifiedConfigurationId: "bpc_live_dispatch",
    providerVerificationRevision: DISPATCH_BILLING_PORTAL_PROVIDER_REVISION,
    ...overrides,
  };
}

function fakeAdmin(portal) {
  return {
    firestore() {
      return {
        collection(name) {
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

test("runtime Portal decision requires provider proof bound to the exact bpc", () => {
  assert.equal(dispatchBillingPortalRuntimeDecision(verifiedPortal()).ready, true);
  assert.equal(dispatchBillingPortalRuntimeDecision(verifiedPortal({
    providerVerified: false,
  })).ready, false);
  assert.equal(dispatchBillingPortalRuntimeDecision(verifiedPortal({
    providerVerifiedConfigurationId: "bpc_other",
  })).ready, false);
  assert.equal(dispatchBillingPortalRuntimeDecision(verifiedPortal({
    providerVerificationRevision: "old-policy",
  })).ready, false);
});

test("runtime Portal decision rejects unsafe return URL", () => {
  const decision = dispatchBillingPortalRuntimeDecision(verifiedPortal({
    returnUrl: "https://evil.example/account",
  }));
  assert.equal(decision.ready, false);
  assert.equal(decision.reason, "return_url_invalid");
});

test("production gate blocks Checkout before invoking inner handler", async () => {
  let invoked = 0;
  const gate = createDispatchSubscriptionPortalRuntimeGate(
      fakeAdmin(verifiedPortal({providerVerified: false})),
      async () => {
        invoked += 1;
        return {ok: true};
      },
  );
  await assert.rejects(
      () => gate({data: {plan: "monthly"}}),
      /provider-verified Billing Portal configuration/i,
  );
  assert.equal(invoked, 0);
});

test("production gate delegates only after provider Portal proof passes", async () => {
  let invoked = 0;
  const gate = createDispatchSubscriptionPortalRuntimeGate(
      fakeAdmin(verifiedPortal()),
      async (request) => {
        invoked += 1;
        return {plan: request.data.plan};
      },
  );
  const result = await gate({data: {plan: "yearly"}});
  assert.equal(invoked, 1);
  assert.deepEqual(result, {plan: "yearly"});
});
