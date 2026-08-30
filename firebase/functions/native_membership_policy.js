"use strict";

const APPLE_BUNDLE_ID = "Pipe.Buyerapp";
const GOOGLE_PACKAGE_NAME = "Pipe.Buyerapp";

const NATIVE_MEMBERSHIP_PRODUCTS = Object.freeze({
  pipebuyer_dispatch_monthly: Object.freeze({
    productId: "pipebuyer_dispatch_monthly",
    planId: "dispatch_monthly",
    tier: "dispatch",
  }),
  pipebuyer_dispatch_yearly: Object.freeze({
    productId: "pipebuyer_dispatch_yearly",
    planId: "dispatch_yearly",
    tier: "dispatch",
  }),
  pipebuyer_vip_monthly: Object.freeze({
    productId: "pipebuyer_vip_monthly",
    planId: "vip_monthly",
    tier: "vip",
  }),
});

const GOOGLE_ENTITLED_STATES = new Set([
  "SUBSCRIPTION_STATE_ACTIVE",
  "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
  // Google reports a user-cancelled subscription as CANCELED until its paid
  // expiry. Access must continue through that already-paid period.
  "SUBSCRIPTION_STATE_CANCELED",
]);

const APPLE_ENTITLED_STATUSES = new Set([1, 4]); // ACTIVE, BILLING_GRACE_PERIOD

function nativeMembershipProduct(value) {
  const productId = String(value || "").trim();
  return NATIVE_MEMBERSHIP_PRODUCTS[productId] || null;
}

function normalizeNativePlatform(value) {
  const platform = String(value || "").trim().toLowerCase();
  return new Set(["ios", "android"]).has(platform) ? platform : "";
}

function decodeBase64UrlJson(value) {
  try {
    const text = Buffer.from(String(value || ""), "base64url").toString("utf8");
    const decoded = JSON.parse(text);
    return decoded && typeof decoded === "object" ? decoded : null;
  } catch (_) {
    return null;
  }
}

function decodeJwsPayload(jws) {
  const parts = String(jws || "").split(".");
  return parts.length === 3 ? decodeBase64UrlJson(parts[1]) : null;
}

function appleTransactionEntitlement(payload, expectedAccountToken, nowMillis = Date.now()) {
  if (!payload || typeof payload !== "object") return null;
  if (String(payload.bundleId || "") !== APPLE_BUNDLE_ID) return null;
  if (String(payload.appAccountToken || "").toLowerCase() !==
      String(expectedAccountToken || "").toLowerCase()) return null;
  const product = nativeMembershipProduct(payload.productId);
  if (!product) return null;
  const expiresAtMillis = Number(payload.expiresDate || 0);
  if (!Number.isFinite(expiresAtMillis) || expiresAtMillis <= nowMillis) return null;
  if (Number(payload.revocationDate || 0) > 0 || payload.isUpgraded === true) return null;
  const ownership = String(payload.inAppOwnershipType || "PURCHASED");
  if (ownership && ownership !== "PURCHASED") return null;
  const transactionId = String(payload.transactionId || "").trim();
  const originalTransactionId = String(payload.originalTransactionId || "").trim();
  if (!transactionId || !originalTransactionId) return null;
  return {
    provider: "app_store",
    platform: "ios",
    productId: product.productId,
    planId: product.planId,
    tier: product.tier,
    transactionId,
    originalTransactionId,
    expiresAtMillis,
    environment: String(payload.environment || ""),
  };
}

function appleStatusEntitlement(statusResponse, expectedAccountToken, nowMillis = Date.now()) {
  if (!statusResponse || String(statusResponse.bundleId || "") !== APPLE_BUNDLE_ID) {
    return null;
  }
  let selected = null;
  for (const group of Array.isArray(statusResponse.data) ? statusResponse.data : []) {
    for (const item of Array.isArray(group && group.lastTransactions) ?
      group.lastTransactions : []) {
      const status = Number(item && item.status || 0);
      if (!APPLE_ENTITLED_STATUSES.has(status)) continue;
      const payload = decodeJwsPayload(item && item.signedTransactionInfo);
      const entitlement = appleTransactionEntitlement(
          payload,
          expectedAccountToken,
          nowMillis,
      );
      if (!entitlement) continue;
      const renewal = decodeJwsPayload(item && item.signedRenewalInfo) || {};
      const candidate = {
        ...entitlement,
        status: status === 4 ? "grace_period" : "active",
        autoRenewEnabled: Number(renewal.autoRenewStatus || 0) === 1,
        pendingProductId: nativeMembershipProduct(renewal.autoRenewProductId) ?
          String(renewal.autoRenewProductId) : "",
      };
      if (!selected || candidate.expiresAtMillis > selected.expiresAtMillis) {
        selected = candidate;
      }
    }
  }
  return selected;
}

function googleSubscriptionEntitlement(purchase, expectedAccountToken, nowMillis = Date.now()) {
  if (!purchase || typeof purchase !== "object") return null;
  const account = purchase.externalAccountIdentifiers || {};
  if (String(account.obfuscatedExternalAccountId || "") !==
      String(expectedAccountToken || "")) return null;
  const state = String(purchase.subscriptionState || "");
  if (!GOOGLE_ENTITLED_STATES.has(state)) return null;
  let selected = null;
  for (const item of Array.isArray(purchase.lineItems) ? purchase.lineItems : []) {
    const product = nativeMembershipProduct(item && item.productId);
    if (!product) continue;
    const expiresAtMillis = Date.parse(String(item.expiryTime || ""));
    if (!Number.isFinite(expiresAtMillis) || expiresAtMillis <= nowMillis) continue;
    const replacement = item.deferredItemReplacement || {};
    const candidate = {
      provider: "google_play",
      platform: "android",
      productId: product.productId,
      planId: product.planId,
      tier: product.tier,
      expiresAtMillis,
      status: state === "SUBSCRIPTION_STATE_IN_GRACE_PERIOD" ?
        "grace_period" : state === "SUBSCRIPTION_STATE_CANCELED" ?
          "active_until_period_end" : "active",
      autoRenewEnabled: Boolean(
          item.autoRenewingPlan && item.autoRenewingPlan.autoRenewEnabled === true,
      ),
      latestOrderId: String(
          item.latestSuccessfulOrderId || purchase.latestOrderId || "",
      ),
      pendingProductId: nativeMembershipProduct(replacement.productId) ?
        String(replacement.productId) : "",
    };
    if (!selected || candidate.expiresAtMillis > selected.expiresAtMillis) {
      selected = candidate;
    }
  }
  return selected;
}

module.exports = {
  APPLE_BUNDLE_ID,
  APPLE_ENTITLED_STATUSES,
  GOOGLE_ENTITLED_STATES,
  GOOGLE_PACKAGE_NAME,
  NATIVE_MEMBERSHIP_PRODUCTS,
  appleStatusEntitlement,
  appleTransactionEntitlement,
  decodeJwsPayload,
  googleSubscriptionEntitlement,
  nativeMembershipProduct,
  normalizeNativePlatform,
};
