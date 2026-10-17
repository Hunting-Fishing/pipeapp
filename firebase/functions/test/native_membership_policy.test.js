"use strict";

const crypto = require("node:crypto");
const test = require("node:test");
const assert = require("node:assert/strict");
const {
  APPLE_BUNDLE_ID,
  APPLE_NATIVE_MEMBERSHIP_PRODUCT_IDS,
  GOOGLE_PACKAGE_NAME,
  appleTransactionEntitlement,
  appleNativeMembershipProduct,
  googleSubscriptionEntitlement,
  nativeMembershipProduct,
  normalizeNativePlatform,
} = require("../native_membership_policy");

const accountToken = "123e4567-e89b-42d3-a456-426614174000";

test("native membership catalog maps only approved store products", () => {
  assert.equal(nativeMembershipProduct("pipebuyer_dispatch_monthly").planId,
      "dispatch_monthly");
  assert.equal(nativeMembershipProduct("pipebuyer_dispatch_yearly").planId,
      "dispatch_yearly");
  assert.equal(nativeMembershipProduct("pipebuyer_vip_monthly").planId,
      "vip_monthly");
  assert.equal(appleNativeMembershipProduct("pipebuyer_vip_monthly"), null);
  assert.deepEqual(APPLE_NATIVE_MEMBERSHIP_PRODUCT_IDS, [
    "pipebuyer_dispatch_monthly",
    "pipebuyer_dispatch_yearly",
  ]);
  assert.equal(nativeMembershipProduct("unknown"), null);
  assert.equal(APPLE_BUNDLE_ID, "Pipe.Buyerapp");
  assert.equal(GOOGLE_PACKAGE_NAME, "Pipe.Buyerapp");
  assert.equal(normalizeNativePlatform("IOS"), "ios");
  assert.equal(normalizeNativePlatform("android"), "android");
  assert.equal(normalizeNativePlatform("web"), "");
});

test("Apple entitlement requires bundle, account binding, approved product and expiry", () => {
  const now = Date.UTC(2026, 7, 30);
  const payload = {
    bundleId: APPLE_BUNDLE_ID,
    appAccountToken: accountToken,
    productId: "pipebuyer_dispatch_monthly",
    transactionId: "200000000000001",
    originalTransactionId: "200000000000000",
    expiresDate: now + 3600000,
    environment: "Sandbox",
    inAppOwnershipType: "PURCHASED",
  };
  const entitlement = appleTransactionEntitlement(payload, accountToken, now);
  assert.equal(entitlement.planId, "dispatch_monthly");
  assert.equal(entitlement.provider, "app_store");
  assert.equal(appleTransactionEntitlement(
      {...payload, appAccountToken: crypto.randomUUID()}, accountToken, now), null);
  assert.equal(appleTransactionEntitlement(
      {...payload, bundleId: "not.pipebuyer"}, accountToken, now), null);
  assert.equal(appleTransactionEntitlement(
      {...payload, expiresDate: now - 1}, accountToken, now), null);
  assert.equal(appleTransactionEntitlement(
      {...payload, revocationDate: now}, accountToken, now), null);
  assert.equal(appleTransactionEntitlement(
      {...payload, productId: "pipebuyer_vip_monthly"}, accountToken, now), null);
  assert.equal(appleTransactionEntitlement(
      {...payload, inAppOwnershipType: undefined}, accountToken, now), null);
  assert.equal(appleTransactionEntitlement(
      {...payload, inAppOwnershipType: "FAMILY_SHARED"}, accountToken, now), null);
});

test("Google entitlement binds obfuscated account ID and preserves paid cancellation", () => {
  const now = Date.UTC(2026, 7, 30);
  const purchase = {
    subscriptionState: "SUBSCRIPTION_STATE_CANCELED",
    latestOrderId: "GPA.1234-5678-9012-34567",
    externalAccountIdentifiers: {
      obfuscatedExternalAccountId: accountToken,
    },
    lineItems: [{
      productId: "pipebuyer_dispatch_yearly",
      expiryTime: new Date(now + 86400000).toISOString(),
      latestSuccessfulOrderId: "GPA.1234-5678-9012-34567",
      autoRenewingPlan: {autoRenewEnabled: false},
      deferredItemReplacement: {productId: "pipebuyer_dispatch_monthly"},
    }],
  };
  const entitlement = googleSubscriptionEntitlement(purchase, accountToken, now);
  assert.equal(entitlement.planId, "dispatch_yearly");
  assert.equal(entitlement.status, "active_until_period_end");
  assert.equal(entitlement.pendingProductId, "pipebuyer_dispatch_monthly");
  assert.equal(entitlement.autoRenewEnabled, false);
  assert.equal(googleSubscriptionEntitlement(
      {
        ...purchase,
        externalAccountIdentifiers: {obfuscatedExternalAccountId: "other"},
      },
      accountToken,
      now,
  ), null);
});

test("Google on-hold or expired purchases do not grant membership", () => {
  const now = Date.UTC(2026, 7, 30);
  const base = {
    externalAccountIdentifiers: {obfuscatedExternalAccountId: accountToken},
    lineItems: [{
      productId: "pipebuyer_dispatch_monthly",
      expiryTime: new Date(now + 3600000).toISOString(),
      autoRenewingPlan: {autoRenewEnabled: true},
    }],
  };
  assert.equal(googleSubscriptionEntitlement({
    ...base,
    subscriptionState: "SUBSCRIPTION_STATE_ON_HOLD",
  }, accountToken, now), null);
  assert.equal(googleSubscriptionEntitlement({
    ...base,
    subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
    lineItems: [{
      ...base.lineItems[0],
      expiryTime: new Date(now - 1).toISOString(),
    }],
  }, accountToken, now), null);
});
