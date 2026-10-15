"use strict";

const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");

const functionsDirectory = path.resolve(__dirname, "..");

function source(fileName) {
  return fs.readFileSync(path.join(functionsDirectory, fileName), "utf8");
}

test("Apple billing production bootstrap remains fail-closed", () => {
  const bootstrap = source("production_bootstrap.js");
  assert.match(bootstrap, /exports\.getNativeMembershipBillingStatus\s*=/);
  assert.doesNotMatch(bootstrap, /exports\.preflightNativeMembershipPurchase\s*=/);
  assert.doesNotMatch(bootstrap, /exports\.preflightNativeMembershipRestore\s*=/);
  assert.doesNotMatch(
      bootstrap,
      /exports\.releaseNativeMembershipPurchaseIntent\s*=/,
  );
  assert.doesNotMatch(
      bootstrap,
      /exports\.resumeNativeMembershipPurchaseIntent\s*=/,
  );
  assert.doesNotMatch(
      bootstrap,
      /exports\.markNativeMembershipPurchasePending\s*=/,
  );
  assert.doesNotMatch(bootstrap, /exports\.verifyNativeMembershipPurchase\s*=/);
  assert.doesNotMatch(
      bootstrap,
      /exports\.reconcileNativeMembershipSubscriptions\s*=/,
  );
  assert.doesNotMatch(bootstrap, /exports\.appStoreServerNotifications/);
  assert.doesNotMatch(bootstrap, /exports\.appStoreServerNotificationsSandbox/);
});

test("Apple helper is present but cannot be activated by importing bootstrap", () => {
  const bootstrap = source("production_bootstrap.js");
  assert.doesNotMatch(bootstrap, /apple_store_server_notifications/);
  assert.doesNotMatch(bootstrap, /apple_store_server_client/);
  const packageJson = JSON.parse(source("package.json"));
  assert.equal(
      packageJson.dependencies["@apple/app-store-server-library"],
      "3.1.0",
  );
  assert.doesNotMatch(bootstrap, /apple_native_billing_composition/);
  assert.doesNotMatch(bootstrap, /native_membership_reconciliation_runner/);
  assert.doesNotMatch(bootstrap, /native_membership_account_backfill/);
});

test("Apple allowlist omits unconfigured VIP while shared Google catalog remains", () => {
  const policy = require("../native_membership_policy");
  assert.deepEqual(policy.APPLE_NATIVE_MEMBERSHIP_PRODUCT_IDS, [
    "pipebuyer_dispatch_monthly",
    "pipebuyer_dispatch_yearly",
  ]);
  assert.equal(policy.appleNativeMembershipProduct("pipebuyer_vip_monthly"), null);
  assert.equal(
      policy.nativeMembershipProduct("pipebuyer_vip_monthly").planId,
      "vip_monthly",
  );
  assert.equal(policy.decodeJwsPayload, undefined);
  assert.equal(policy.appleStatusEntitlement, undefined);
});

test("client verification claims freshness only after proof and then re-fetches", () => {
  const billing = source("native_membership_billing.js");
  const callable = billing.indexOf("const verifyNativeMembershipPurchase");
  const firstProof = billing.indexOf("appleCurrentEntitlement({", callable);
  const generation = billing.indexOf(
      "await beginNativeMembershipReconciliation({",
      firstProof,
  );
  const trustedRefresh = billing.indexOf(
      "entitlement = await appleReconciledEntitlement({",
      generation,
  );
  const apply = billing.indexOf("await applyNativeEntitlement({", trustedRefresh);
  assert.ok(callable >= 0);
  assert.ok(firstProof > callable);
  assert.ok(generation > firstProof);
  assert.ok(trustedRefresh > generation);
  assert.ok(apply > trustedRefresh);
});

test("purchase preflight rechecks policy, readiness, and provider ownership", () => {
  const billing = source("native_membership_billing.js");
  const start = billing.indexOf("const preflightNativeMembershipPurchase");
  const end = billing.indexOf("const verifyNativeMembershipPurchase", start);
  const preflight = billing.slice(start, end);
  assert.ok(start >= 0 && end > start);
  assert.match(preflight, /currentPolicyAcceptanceStatus/);
  assert.match(preflight, /loadNativeBillingReadiness/);
  assert.match(preflight, /claimNativeMembershipPurchaseIntent/);
  assert.match(preflight, /ensureStoreAccountToken/);
  assert.match(preflight, /purchaseIntentToken/);
  assert.match(preflight, /ready: true/);
});

test("purchase verification requires the preflight intent token", () => {
  const billing = source("native_membership_billing.js");
  const start = billing.indexOf("const verifyNativeMembershipPurchase");
  const end = billing.indexOf(
      "const reconcileNativeMembershipSubscriptions",
      start,
  );
  const verification = billing.slice(start, end);
  assert.match(verification, /validIntentToken\(purchaseIntentToken\)/);
  assert.match(verification, /requireNativeMembershipPurchaseIntent/);
  assert.match(verification, /billingIntent:/);
  assert.match(verification, /finishBillingIntent/);
  assert.doesNotMatch(
      verification,
      /Mobile membership purchasing is not enabled yet/,
  );
});

test("scheduled reconciliation accepts a one-page durable checkpoint bound", () => {
  const billing = source("native_membership_billing.js");
  const start = billing.indexOf("const reconcileNativeMembershipSubscriptions");
  const end = billing.indexOf("getNativeMembershipBillingStatus,", start);
  const reconciliation = billing.slice(start, end);
  assert.match(reconciliation, /maxPages/);
  assert.match(reconciliation, /reconcileNativeMembershipPages/);
});

test("both Stripe subscription checkout commands claim the shared intent", () => {
  for (const fileName of [
    "dispatch_subscription_commands.js",
    "vip_subscription_commands.js",
  ]) {
    const checkout = source(fileName);
    assert.match(checkout, /MEMBERSHIP_BILLING_INTENT_COLLECTION/);
    assert.match(checkout, /nativeBillingIntentCoordinationEnabled/);
    assert.match(checkout, /claimBillingIntentInTransaction/);
    assert.match(checkout, /failStripeCheckoutReservation/);
    assert.match(checkout, /makeStripeCheckoutReservationRetryable/);
    assert.match(checkout, /checkoutRequestFields/);
    assert.match(checkout, /fields: reservation\.checkoutRequestFields/);
    assert.match(checkout, /channel: "stripe"/);
    assert.match(checkout, /nativeProviderStateBlocksNewCheckout/);
  }
});
