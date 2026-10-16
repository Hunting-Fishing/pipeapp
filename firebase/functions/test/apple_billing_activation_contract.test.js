"use strict";

const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");

const functionsDirectory = path.resolve(__dirname, "..");

function source(fileName) {
  return fs.readFileSync(path.join(functionsDirectory, fileName), "utf8");
}

test("Apple billing bootstrap exposes only the iOS Sandbox cohort surface", () => {
  const bootstrap = source("production_bootstrap.js");
  assert.match(bootstrap, /exports\.getNativeMembershipBillingStatus\s*=/);
  assert.match(
      bootstrap,
      /createNativeMembershipBilling\(admin,\s*{\s*appleSandboxCohortOnly:\s*true/,
  );
  for (const callable of [
    "preflightNativeMembershipPurchase",
    "preflightNativeMembershipRestore",
    "resumeNativeMembershipPurchaseIntent",
    "markNativeMembershipPurchasePending",
    "releaseNativeMembershipPurchaseIntent",
  ]) {
    assert.match(
        bootstrap,
        new RegExp(
            `exports\\.${callable}\\s*=\\s*onCall\\(\\s*` +
            "protectedCallableOptions",
        ),
    );
  }
  assert.match(
      bootstrap,
      /exports\.verifyNativeMembershipPurchase\s*=\s*onCall\(\s*appleMembershipVerificationCallableOptions/,
  );
  const verificationOptions = bootstrap.slice(
      bootstrap.indexOf("const appleMembershipVerificationCallableOptions"),
      bootstrap.indexOf("const appleSandboxNotificationOptions"),
  );
  assert.match(verificationOptions, /secrets:\s*APPLE_IAP_SECRET_NAMES/);
  assert.doesNotMatch(verificationOptions, /GOOGLE_PLAY_SERVICE_ACCOUNT_JSON/);
  assert.match(
      bootstrap,
      /exports\.appStoreServerNotificationsSandbox\s*=\s*onRequest/,
  );
  assert.match(bootstrap, /cors:\s*false/);
  assert.match(bootstrap, /invoker:\s*"public"/);
  assert.match(bootstrap, /secrets:\s*APPLE_IAP_SECRET_NAMES/);
  assert.doesNotMatch(bootstrap, /loadMutationGate:\s*async\s*\(\)\s*=>\s*false/);
  assert.doesNotMatch(
      bootstrap,
      /exports\.reconcileNativeMembershipSubscriptions\s*=/,
  );
  assert.doesNotMatch(
      bootstrap,
      /exports\.appStoreServerNotifications\s*=/,
  );
});

test("Apple bootstrap imports only the Sandbox composition", () => {
  const bootstrap = source("production_bootstrap.js");
  assert.doesNotMatch(bootstrap, /apple_store_server_notifications/);
  assert.doesNotMatch(bootstrap, /apple_store_server_client/);
  const packageJson = JSON.parse(source("package.json"));
  assert.equal(
      packageJson.dependencies["@apple/app-store-server-library"],
      "3.1.0",
  );
  assert.match(bootstrap, /apple_native_billing_composition/);
  assert.match(bootstrap, /createAppleSandboxServerNotificationComposition/);
  assert.doesNotMatch(
      bootstrap,
      /createAppleProductionServerNotificationComposition/,
  );
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

test("purchase preflight rechecks cohort before account or intent writes", () => {
  const billing = source("native_membership_billing.js");
  const start = billing.indexOf("const preflightNativeMembershipPurchase");
  const end = billing.indexOf("const verifyNativeMembershipPurchase", start);
  const preflight = billing.slice(start, end);
  assert.ok(start >= 0 && end > start);
  assert.match(preflight, /currentPolicyAcceptanceStatus/);
  assert.match(preflight, /loadNativeBillingReadiness/);
  assert.match(preflight, /claimNativeMembershipPurchaseIntent/);
  assert.match(preflight, /ensureStoreAccountToken/);
  const cohort = preflight.indexOf("requireAppleSandboxCohortAccount({");
  const account = preflight.indexOf("ensureStoreAccountToken(", cohort);
  const claim = preflight.indexOf(
      "claimNativeMembershipPurchaseIntent({",
      account,
  );
  assert.ok(cohort >= 0);
  assert.ok(account > cohort);
  assert.ok(claim > account);
  assert.match(preflight, /requireSandboxAllowedAtClaim:\s*appleSandboxCohortOnly/);
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
  assert.match(
      verification,
      /requireSandboxAllowedAtClaim:\s*appleSandboxCohortOnly/,
  );
  const intent = verification.indexOf("requireNativeMembershipPurchaseIntent({");
  const freshClaim = verification.indexOf(
      "requireAppleSandboxCohortAccount({",
      intent,
  );
  const firstProof = verification.indexOf("appleCurrentEntitlement({", freshClaim);
  assert.ok(intent >= 0);
  assert.ok(freshClaim > intent);
  assert.ok(firstProof > freshClaim);
  assert.match(verification, /billingIntent:/);
  assert.match(verification, /finishBillingIntent/);
  assert.doesNotMatch(
      verification,
      /Mobile membership purchasing is not enabled yet/,
  );
});

test("cohort verification proves Sandbox before reconciliation writes", () => {
  const billing = source("native_membership_billing.js");
  const start = billing.indexOf("const verifyNativeMembershipPurchase");
  const end = billing.indexOf(
      "const reconcileNativeMembershipSubscriptions",
      start,
  );
  const verification = billing.slice(start, end);
  const sandboxOnly = verification.indexOf(
      "sandboxOnly: appleSandboxCohortOnly",
  );
  const initialSandboxGuard = verification.indexOf(
      "entitlement = requireAppleSandboxEntitlement(entitlement)",
      sandboxOnly,
  );
  const generation = verification.indexOf(
      "await beginNativeMembershipReconciliation({",
  );
  const refreshed = verification.indexOf(
      "entitlement = await appleReconciledEntitlement({",
      generation,
  );
  const refreshedSandboxGuard = verification.indexOf(
      "entitlement = requireAppleSandboxEntitlement(entitlement)",
      refreshed,
  );
  const apply = verification.indexOf(
      "await applyNativeEntitlement({",
      refreshedSandboxGuard,
  );
  assert.ok(sandboxOnly >= 0);
  assert.ok(initialSandboxGuard > sandboxOnly);
  assert.ok(generation > initialSandboxGuard);
  assert.ok(refreshed > generation);
  assert.ok(refreshedSandboxGuard > refreshed);
  assert.ok(apply > refreshedSandboxGuard);
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
