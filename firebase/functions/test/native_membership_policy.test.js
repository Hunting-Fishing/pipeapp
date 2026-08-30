"use strict";

const crypto = require("node:crypto");
const test = require("node:test");
const assert = require("node:assert/strict");
const {
  APPLE_BUNDLE_ID,
  GOOGLE_PACKAGE_NAME,
  appleStatusEntitlement,
  appleTransactionEntitlement,
  decodeJwsPayload,
  googleSubscriptionEntitlement,
  nativeMembershipProduct,
  normalizeNativePlatform,
} = require("../native_membership_policy");

const accountToken = "123e4567-e89b-42d3-a456-426614174000";

function fakeJws(payload) {
  const header = Buffer.from(JSON.stringify({alg: "ES256"})).toString("base64url");
  const body = Buffer.from(JSON.stringify(payload)).toString("base64url");
  return `${header}.${body}.signature`;
}

test("native membership catalog maps only approved store products", () => {
  assert.equal(nativeMembershipProduct("pipebuyer_dispatch_monthly").planId,
      "dispatch_monthly");
  assert.equal(nativeMembershipProduct("pipebuyer_dispatch_yearly").planId,
      "dispatch_yearly");
  assert.equal(nativeMembershipProduct("pipebuyer_vip_monthly").planId,
      "vip_monthly");
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
    productId: "pipebuyer_vip_monthly",
    transactionId: "200000000000001",
    originalTransactionId: "200000000000000",
    expiresDate: now + 3600000,
    environment: "Sandbox",
    inAppOwnershipType: "PURCHASED",
  };
  const entitlement = appleTransactionEntitlement(payload, accountToken, now);
  assert.equal(entitlement.planId, "vip_monthly");
  assert.equal(entitlement.provider, "app_store");
  assert.equal(appleTransactionEntitlement(
      {...payload, appAccountToken: crypto.randomUUID()}, accountToken, now), null);
  assert.equal(appleTransactionEntitlement(
      {...payload, bundleId: "not.pipebuyer"}, accountToken, now), null);
  assert.equal(appleTransactionEntitlement(
      {...payload, expiresDate: now - 1}, accountToken, now), null);
  assert.equal(appleTransactionEntitlement(
      {...payload, revocationDate: now}, accountToken, now), null);
});

test("Apple status uses the latest entitled transaction and renewal target", () => {
  const now = Date.UTC(2026, 7, 30);
  const transaction = {
    bundleId: APPLE_BUNDLE_ID,
    appAccountToken: accountToken,
    productId: "pipebuyer_vip_monthly",
    transactionId: "200000000000002",
    originalTransactionId: "200000000000000",
    expiresDate: now + 7200000,
    environment: "Production",
  };
  const response = {
    bundleId: APPLE_BUNDLE_ID,
    data: [{
      lastTransactions: [{
        status: 1,
        signedTransactionInfo: fakeJws(transaction),
        signedRenewalInfo: fakeJws({
          autoRenewStatus: 1,
          autoRenewProductId: "pipebuyer_dispatch_monthly",
        }),
      }],
    }],
  };
  const entitlement = appleStatusEntitlement(response, accountToken, now);
  assert.equal(entitlement.planId, "vip_monthly");
  assert.equal(entitlement.pendingProductId, "pipebuyer_dispatch_monthly");
  assert.equal(entitlement.autoRenewEnabled, true);
  assert.equal(decodeJwsPayload(fakeJws(transaction)).transactionId,
      transaction.transactionId);
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
