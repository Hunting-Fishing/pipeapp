"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  createDispatchSubscriptionStatusCommands,
  dispatchSubscriptionPublicBillingReady,
  dispatchSubscriptionPublicTaxReady,
} = require("../dispatch_subscription_status_commands");
const {
  DISPATCH_BILLING_PORTAL_PROVIDER_REVISION,
} = require("../dispatch_billing_portal_policy");

function storedPortalFeatures(overrides = {}) {
  return {
    paymentMethodUpdate: true,
    invoiceHistory: true,
    subscriptionCancel: true,
    subscriptionCancelMode: "at_period_end",
    subscriptionCancelProration: "none",
    subscriptionUpdate: false,
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
    providerVerifiedFeatures: storedPortalFeatures(),
    ...overrides,
  };
}

function readyBilling(overrides = {}) {
  return {
    stripeMode: "production",
    stripeSubscriptionsEnabled: true,
    stripeWebhookVerified: true,
    stripeSubscriptionLifecycleWebhookVerified: true,
    stripeSubscriptionRecoveryVerified: true,
    stripeReconciliationReady: true,
    stripeTaxReady: true,
    ...overrides,
  };
}

function validSmallSupplierAssessment(overrides = {}) {
  return {
    worldwideAndAssociatedIncluded: true,
    singleQuarterCadMinor: 1000000,
    rollingFourQuarterCadMinor: 2000000,
    thresholdCadMinor: 3000000,
    exceeded: false,
    requiresRegistrationReview: false,
    revision: 7,
    ...overrides,
  };
}

function smallSupplierBilling(overrides = {}) {
  return readyBilling({
    stripeTaxReady: false,
    canadaGstHstSmallSupplier: true,
    canadaGstHstSmallSupplierAssessmentRevision: 7,
    ...overrides,
  });
}

function fakeAdmin({
  subscription = null,
  portal = verifiedPortal(),
  readiness = readyBilling(),
  assessment = null,
} = {}) {
  const docs = new Map([
    ["dispatch_subscriptions/user-1", subscription],
    ["platform_configuration/dispatch_billing_portal", portal],
    ["platform_configuration/payment_provider_readiness", readiness],
    ["tax_threshold_assessments/canada_gst_hst_current", assessment],
  ]);
  const db = {
    collection(name) {
      return {
        doc(id) {
          return {
            async get() {
              const data = docs.get(`${name}/${id}`);
              return {
                exists: data != null,
                data: () => data,
              };
            },
          };
        },
      };
    },
  };
  return {
    firestore() {
      return db;
    },
  };
}

const catalog = () => ({
  monthly: {currency: "CAD", unitAmountMinor: 2500, interval: "month"},
  yearly: {currency: "CAD", unitAmountMinor: 30000, interval: "year"},
});

test("public billing readiness requires every Dispatch launch prerequisite", () => {
  assert.equal(
      dispatchSubscriptionPublicBillingReady(readyBilling(), verifiedPortal()),
      true,
  );
  assert.equal(
      dispatchSubscriptionPublicBillingReady(
          readyBilling({stripeSubscriptionsEnabled: false}),
          verifiedPortal(),
      ),
      false,
  );
  assert.equal(
      dispatchSubscriptionPublicBillingReady(
          readyBilling({stripeSubscriptionRecoveryVerified: false}),
          verifiedPortal(),
      ),
      false,
  );
  assert.equal(
      dispatchSubscriptionPublicBillingReady(
          readyBilling(),
          verifiedPortal({providerVerified: false}),
      ),
      false,
  );
  assert.equal(
      dispatchSubscriptionPublicBillingReady(
          readyBilling(),
          verifiedPortal({
            providerVerifiedFeatures: storedPortalFeatures({subscriptionUpdate: true}),
          }),
      ),
      false,
  );
});

test("small-supplier presentation readiness requires exact audited assessment binding", () => {
  const readiness = smallSupplierBilling();
  const assessment = validSmallSupplierAssessment();
  assert.equal(
      dispatchSubscriptionPublicTaxReady(readiness, assessment),
      true,
  );
  assert.equal(
      dispatchSubscriptionPublicTaxReady(readiness, null),
      false,
  );
  assert.equal(
      dispatchSubscriptionPublicTaxReady(
          readiness,
          validSmallSupplierAssessment({revision: 8}),
      ),
      false,
  );
  assert.equal(
      dispatchSubscriptionPublicTaxReady(
          readiness,
          validSmallSupplierAssessment({rollingFourQuarterCadMinor: 3000001}),
      ),
      false,
  );
});

test("status disables purchase before public billing readiness is enabled", async () => {
  const commands = createDispatchSubscriptionStatusCommands(
      fakeAdmin({
        readiness: readyBilling({stripeSubscriptionsEnabled: false}),
      }),
      {
        authUid: () => "user-1",
        rateLimit: async () => {},
        catalog,
      },
  );
  const result = await commands.getDispatchSubscriptionStatus({auth: {uid: "user-1"}});
  assert.equal(result.billingAvailable, false);
  assert.equal(result.canStartCheckout, false);
  assert.equal(result.alreadySubscribed, false);
});

test("status enables purchase only when user state and billing readiness both allow it", async () => {
  const commands = createDispatchSubscriptionStatusCommands(
      fakeAdmin(),
      {
        authUid: () => "user-1",
        rateLimit: async () => {},
        catalog,
      },
  );
  const result = await commands.getDispatchSubscriptionStatus({auth: {uid: "user-1"}});
  assert.equal(result.billingAvailable, true);
  assert.equal(result.canStartCheckout, true);
});

test("status fails closed when small-supplier assessment is missing or stale", async () => {
  const missingAssessmentCommands = createDispatchSubscriptionStatusCommands(
      fakeAdmin({readiness: smallSupplierBilling()}),
      {
        authUid: () => "user-1",
        rateLimit: async () => {},
        catalog,
      },
  );
  const missing = await missingAssessmentCommands.getDispatchSubscriptionStatus({
    auth: {uid: "user-1"},
  });
  assert.equal(missing.billingAvailable, false);
  assert.equal(missing.canStartCheckout, false);

  const validCommands = createDispatchSubscriptionStatusCommands(
      fakeAdmin({
        readiness: smallSupplierBilling(),
        assessment: validSmallSupplierAssessment(),
      }),
      {
        authUid: () => "user-1",
        rateLimit: async () => {},
        catalog,
      },
  );
  const valid = await validCommands.getDispatchSubscriptionStatus({
    auth: {uid: "user-1"},
  });
  assert.equal(valid.billingAvailable, true);
  assert.equal(valid.canStartCheckout, true);
});

test("active subscriber remains active even when new purchases are disabled", async () => {
  const commands = createDispatchSubscriptionStatusCommands(
      fakeAdmin({
        subscription: {
          plan: "monthly",
          status: "active",
          billingStatus: "paid",
          entitlementActive: true,
          stripeCustomerId: "cus_live_user",
          stripeSubscriptionId: "sub_live_user",
        },
        readiness: readyBilling({stripeSubscriptionsEnabled: false}),
      }),
      {
        authUid: () => "user-1",
        rateLimit: async () => {},
        catalog,
      },
  );
  const result = await commands.getDispatchSubscriptionStatus({auth: {uid: "user-1"}});
  assert.equal(result.billingAvailable, false);
  assert.equal(result.entitlementActive, true);
  assert.equal(result.alreadySubscribed, true);
  assert.equal(result.canStartCheckout, false);
  assert.equal(result.canManageBilling, true);
});
