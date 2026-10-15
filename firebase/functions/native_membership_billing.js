"use strict";

const crypto = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {
  effectiveMembershipPlan,
} = require("./membership_plan_policy");
const {
  APPLE_BUNDLE_ID,
  APPLE_NATIVE_MEMBERSHIP_PRODUCT_IDS,
  GOOGLE_PACKAGE_NAME,
  NATIVE_MEMBERSHIP_PRODUCTS,
  appleNativeMembershipProduct,
  googleSubscriptionEntitlement,
  nativeMembershipProduct,
  normalizeNativePlatform,
} = require("./native_membership_policy");
const {
  createAppleStoreServerEnvironment,
  fetchVerifiedAppleCurrentEntitlement,
  fetchVerifiedAppleSubscriptionEntitlement,
  isAppleTransactionNotFound,
} = require("./apple_store_server_client");
const {
  accountTokenDocumentId,
} = require("./apple_store_server_notifications");
const {
  reconcileNativeMembershipPages,
} = require("./native_membership_reconciliation");
const {
  MEMBERSHIP_BILLING_INTENT_COLLECTION,
  NATIVE_PURCHASE_INTENT_TTL_MS,
  NATIVE_RESTORE_INTENT_TTL_MS,
  billingIntentMatchesForVerification,
  claimBillingIntentInTransaction,
  finishBillingIntent,
  markBillingIntentPendingInTransaction,
  markBillingIntentVerifyingInTransaction,
  nativeBillingIntentCoordinationEnabled,
  requireBillingIntentForVerification,
  stripeCheckoutStateOpen,
  timestampMillis,
  validIntentToken,
} = require("./membership_billing_intent");
const {
  currentPolicyAcceptanceStatus,
} = require("./policy_acceptance_status");

const GOOGLE_ANDROID_PUBLISHER_SCOPE =
  "https://www.googleapis.com/auth/androidpublisher";
const NATIVE_RECONCILIATION_LIMIT = 200;
const NATIVE_RECONCILIATION_LEASE_COLLECTION =
  "native_membership_reconciliation_leases";
const TERMINAL_STRIPE_PROVIDER_STATUSES = new Set([
  "canceled",
  "incomplete_expired",
]);

function secretBinding(name, unavailableMessage) {
  return Object.freeze({
    name,
    value() {
      const value = String(process.env[name] || "").trim();
      if (!value) {
        throw new HttpsError("failed-precondition", unavailableMessage);
      }
      return value;
    },
  });
}

const appleIapPrivateKey = secretBinding(
    "APPLE_IAP_PRIVATE_KEY",
    "Apple subscription verification credentials are unavailable.",
);
const appleIapKeyId = secretBinding(
    "APPLE_IAP_KEY_ID",
    "Apple subscription verification credentials are unavailable.",
);
const appleIapIssuerId = secretBinding(
    "APPLE_IAP_ISSUER_ID",
    "Apple subscription verification credentials are unavailable.",
);
const googlePlayServiceAccountJson = secretBinding(
    "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON",
    "Google Play subscription verification credentials are unavailable.",
);

const nativeMembershipSecretNames = Object.freeze([
  appleIapPrivateKey.name,
  appleIapKeyId.name,
  appleIapIssuerId.name,
  googlePlayServiceAccountJson.name,
]);

function base64UrlJson(value) {
  return Buffer.from(JSON.stringify(value), "utf8").toString("base64url");
}

function normalizePrivateKey(value) {
  return String(value || "").replace(/\\n/g, "\n").trim();
}

function googleServiceAccount() {
  let account;
  try {
    account = JSON.parse(googlePlayServiceAccountJson.value());
  } catch (_) {
    throw new HttpsError(
        "failed-precondition",
        "Google Play verification credentials are invalid.",
    );
  }
  const clientEmail = String(account && account.client_email || "").trim();
  const privateKey = normalizePrivateKey(account && account.private_key);
  const tokenUri = String(
      account && account.token_uri || "https://oauth2.googleapis.com/token",
  ).trim();
  if (!clientEmail || !privateKey ||
      tokenUri !== "https://oauth2.googleapis.com/token") {
    throw new HttpsError(
        "failed-precondition",
        "Google Play verification credentials are invalid.",
    );
  }
  return {clientEmail, privateKey, tokenUri};
}

async function googleAccessToken() {
  const account = googleServiceAccount();
  const now = Math.floor(Date.now() / 1000);
  const signingInput = `${base64UrlJson({alg: "RS256", typ: "JWT"})}.` +
    base64UrlJson({
      iss: account.clientEmail,
      scope: GOOGLE_ANDROID_PUBLISHER_SCOPE,
      aud: account.tokenUri,
      iat: now,
      exp: now + (45 * 60),
    });
  const signature = crypto.sign(
      "RSA-SHA256",
      Buffer.from(signingInput, "utf8"),
      account.privateKey,
  );
  const assertion = `${signingInput}.${signature.toString("base64url")}`;
  const form = new URLSearchParams({
    grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
    assertion,
  });
  const response = await fetch(account.tokenUri, {
    method: "POST",
    headers: {"Content-Type": "application/x-www-form-urlencoded"},
    body: form.toString(),
  });
  const payload = await response.json().catch(() => ({}));
  const token = String(payload && payload.access_token || "");
  if (!response.ok || !token) {
    throw new HttpsError(
        "failed-precondition",
        "Google Play could not authorize subscription verification.",
    );
  }
  return token;
}

async function fetchJson(url, options = {}) {
  const response = await fetch(url, options);
  const payload = await response.json().catch(() => ({}));
  return {ok: response.ok, status: response.status, payload};
}

function appleServerEnvironment(environment) {
  return createAppleStoreServerEnvironment({
    environment,
    privateKey: normalizePrivateKey(appleIapPrivateKey.value()),
    keyId: appleIapKeyId.value(),
    issuerId: appleIapIssuerId.value(),
  });
}

async function appleCurrentEntitlement({
  transactionId,
  accountToken,
  allowSandbox = false,
  createServerEnvironment = appleServerEnvironment,
  fetchCurrentEntitlement = fetchVerifiedAppleCurrentEntitlement,
  transactionNotFound = isAppleTransactionNotFound,
}) {
  const production = createServerEnvironment("Production");
  try {
    const entitlement = await fetchCurrentEntitlement({
      ...production,
      transactionId,
      expectedAccountToken: accountToken,
      expectedEnvironment: production.environment,
    });
    if (!entitlement) {
      throw new HttpsError(
          "failed-precondition",
          "The App Store subscription is not currently entitled.",
      );
    }
    return entitlement;
  } catch (error) {
    if (!transactionNotFound(error)) throw error;
    if (!allowSandbox) {
      throw new HttpsError(
          "failed-precondition",
          "This App Store transaction is not available in Production.",
      );
    }
  }

  const sandbox = createServerEnvironment("Sandbox");
  const entitlement = await fetchCurrentEntitlement({
    ...sandbox,
    transactionId,
    expectedAccountToken: accountToken,
    expectedEnvironment: sandbox.environment,
  });
  if (!entitlement) {
    throw new HttpsError(
        "failed-precondition",
        "The App Store subscription is not currently entitled.",
    );
  }
  return entitlement;
}

async function appleReconciledEntitlement({
  originalTransactionId,
  accountToken,
  environment,
}) {
  const server = appleServerEnvironment(environment);
  return fetchVerifiedAppleSubscriptionEntitlement({
    ...server,
    originalTransactionId,
    expectedAccountToken: accountToken,
    expectedEnvironment: server.environment,
  });
}

async function googleSubscriptionPurchase(purchaseToken) {
  const token = await googleAccessToken();
  const url = "https://androidpublisher.googleapis.com/androidpublisher/v3/" +
    `applications/${encodeURIComponent(GOOGLE_PACKAGE_NAME)}/` +
    `purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;
  const response = await fetchJson(url, {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/json",
    },
  });
  if (!response.ok) {
    throw new HttpsError(
        "failed-precondition",
        "Google Play could not verify this subscription.",
    );
  }
  return response.payload;
}

async function googleCurrentEntitlement({purchaseToken, accountToken}) {
  const purchase = await googleSubscriptionPurchase(purchaseToken);
  const entitlement = googleSubscriptionEntitlement(purchase, accountToken);
  if (!entitlement) {
    throw new HttpsError(
        "failed-precondition",
        "This Google Play subscription is not currently entitled to this Pipe Buyer account.",
    );
  }
  return entitlement;
}

function stripeProviderBlocksNativePurchase(state, uid) {
  if (!state || state.ownerUid !== uid) return false;
  const subscriptionId = String(state.subscriptionId || "");
  if (!subscriptionId.startsWith("sub_")) return false;
  return !TERMINAL_STRIPE_PROVIDER_STATUSES.has(
      String(state.providerStatus || "unknown"),
  );
}

function stripeMembershipBlocksNativePurchase(
    membership,
    uid,
    nowMillis = Date.now(),
) {
  return Boolean(membership && membership.ownerUid === uid &&
    membership.active === true && membership.billingProvider === "stripe" &&
    timestampMillis(membership.currentPeriodEnd) > nowMillis);
}

function nativeProviderCurrent(state, uid, nowMillis = Date.now()) {
  if (!state || state.ownerUid !== uid || state.active !== true) return false;
  const expiresAtMillis = Number(state.expiresAtMillis || 0);
  return Number.isFinite(expiresAtMillis) && expiresAtMillis > nowMillis;
}

function nativeBillingReadiness(data) {
  const config = data || {};
  return {
    enabled: config.enabled === true,
    appleEnabled: config.enabled === true && config.appleEnabled === true,
    appleSandboxEnabled: config.enabled === true &&
      config.appleEnabled === true && config.appleSandboxEnabled === true,
    googleEnabled: config.enabled === true && config.googleEnabled === true,
  };
}

function appleSandboxAllowedForRequest(readiness, request) {
  return Boolean(readiness.appleSandboxEnabled === true &&
    request && request.auth && request.auth.token &&
    request.auth.token.appleSandboxTester === true);
}

async function appleSandboxAccountAllowed(admin, uid) {
  const user = await admin.auth().getUser(uid);
  return Boolean(user && user.customClaims &&
    user.customClaims.appleSandboxTester === true);
}

async function appleSandboxAllowedForCurrentAccount(admin, readiness, request, uid) {
  if (!appleSandboxAllowedForRequest(readiness, request)) return false;
  return appleSandboxAccountAllowed(admin, uid);
}

async function loadNativeBillingReadiness(db) {
  const snapshot = await db.collection("platform_configuration")
      .doc("native_membership_billing").get();
  return nativeBillingReadiness(snapshot.exists ? snapshot.data() : {});
}

async function ensureStoreAccountToken(db, admin, uid) {
  const ref = db.collection("native_membership_accounts").doc(uid);
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const existing = snapshot.exists ?
      String(snapshot.data().storeAccountToken || "").trim() : "";
    const token =
      /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
          .test(existing) ? existing.toLowerCase() : crypto.randomUUID().toLowerCase();
    const tokenRef = db.collection("native_membership_account_tokens")
        .doc(accountTokenDocumentId(token));
    const tokenSnapshot = await transaction.get(tokenRef);
    const indexedOwner = tokenSnapshot.exists ?
      String(tokenSnapshot.data().ownerUid || "") : "";
    if (indexedOwner && indexedOwner !== uid) {
      throw new Error("native_membership_account_token_conflict");
    }
    if (token !== existing.toLowerCase()) {
      transaction.set(ref, {
        ownerUid: uid,
        storeAccountToken: token,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    transaction.set(tokenRef, {
      ownerUid: uid,
      storeAccountToken: token,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(tokenSnapshot.exists ? {} : {
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }),
    }, {merge: true});
    return token;
  });
}

async function stripeProviderState(db, uid) {
  const [dispatch, vip] = await Promise.all([
    db.collection("dispatch_subscription_provider_state").doc(uid).get(),
    db.collection("vip_subscription_provider_state").doc(uid).get(),
  ]);
  return {
    dispatch: dispatch.exists ? dispatch.data() : null,
    vip: vip.exists ? vip.data() : null,
  };
}

async function currentMembershipState(db, uid) {
  const [dispatch, vip, native] = await Promise.all([
    db.collection("dispatch_memberships").doc(uid).get(),
    db.collection("vip_memberships").doc(uid).get(),
    db.collection("native_membership_provider_state").doc(uid).get(),
  ]);
  const dispatchMembership = dispatch.exists ? dispatch.data() : null;
  const vipMembership = vip.exists ? vip.data() : null;
  return {
    dispatchMembership,
    vipMembership,
    nativeProvider: native.exists ? native.data() : null,
    currentPlan: effectiveMembershipPlan({dispatchMembership, vipMembership}),
  };
}

async function claimNativeMembershipPurchaseIntent({
  db,
  admin,
  uid,
  platform,
  product,
  restore = false,
  sandboxAllowed = false,
  nowMillis = Date.now(),
}) {
  const intentRef = db.collection(MEMBERSHIP_BILLING_INTENT_COLLECTION).doc(uid);
  const readinessRef = db.collection("platform_configuration")
      .doc("native_membership_billing");
  const stripeDispatchRef = db.collection("dispatch_subscription_provider_state")
      .doc(uid);
  const stripeVipRef = db.collection("vip_subscription_provider_state").doc(uid);
  const nativeRef = db.collection("native_membership_provider_state").doc(uid);
  const dispatchMembershipRef = db.collection("dispatch_memberships").doc(uid);
  const vipMembershipRef = db.collection("vip_memberships").doc(uid);
  const dispatchCheckoutRef = db.collection("dispatch_subscription_checkout_state")
      .doc(uid);
  const vipCheckoutRef = db.collection("vip_subscription_checkout_state").doc(uid);
  return db.runTransaction(async (transaction) => {
    const [
      intentSnapshot,
      readinessSnapshot,
      stripeDispatchSnapshot,
      stripeVipSnapshot,
      nativeSnapshot,
      dispatchMembershipSnapshot,
      vipMembershipSnapshot,
      dispatchCheckoutSnapshot,
      vipCheckoutSnapshot,
    ] = await Promise.all([
      transaction.get(intentRef),
      transaction.get(readinessRef),
      transaction.get(stripeDispatchRef),
      transaction.get(stripeVipRef),
      transaction.get(nativeRef),
      transaction.get(dispatchMembershipRef),
      transaction.get(vipMembershipRef),
      transaction.get(dispatchCheckoutRef),
      transaction.get(vipCheckoutRef),
    ]);
    const readiness = readinessSnapshot.exists ? readinessSnapshot.data() : {};
    const storeReady = platform === "ios" ?
      readiness.appleEnabled === true : readiness.googleEnabled === true;
    if (!nativeBillingIntentCoordinationEnabled(readiness) || !storeReady) {
      throw new HttpsError(
          "failed-precondition",
          "Mobile membership purchasing is not enabled yet.",
      );
    }
    const stripeDispatch = stripeDispatchSnapshot.exists ?
      stripeDispatchSnapshot.data() : null;
    const stripeVip = stripeVipSnapshot.exists ? stripeVipSnapshot.data() : null;
    const dispatchMembership = dispatchMembershipSnapshot.exists ?
      dispatchMembershipSnapshot.data() : null;
    const vipMembership = vipMembershipSnapshot.exists ?
      vipMembershipSnapshot.data() : null;
    if (stripeProviderBlocksNativePurchase(stripeDispatch, uid) ||
        stripeProviderBlocksNativePurchase(stripeVip, uid) ||
        stripeMembershipBlocksNativePurchase(dispatchMembership, uid, nowMillis) ||
        stripeMembershipBlocksNativePurchase(vipMembership, uid, nowMillis) ||
        stripeCheckoutStateOpen(
            dispatchCheckoutSnapshot.exists ? dispatchCheckoutSnapshot.data() : null,
            uid,
            nowMillis,
        ) ||
        stripeCheckoutStateOpen(
            vipCheckoutSnapshot.exists ? vipCheckoutSnapshot.data() : null,
            uid,
            nowMillis,
        )) {
      throw new HttpsError(
          "failed-precondition",
          "A Stripe membership or checkout is already in progress.",
      );
    }
    const existingNative = nativeSnapshot.exists ? nativeSnapshot.data() : null;
    const requestedProvider = platform === "ios" ? "app_store" : "google_play";
    if (nativeProviderCurrent(existingNative, uid) &&
        existingNative.provider !== requestedProvider) {
      throw new HttpsError(
          "failed-precondition",
          "Another mobile store already owns this membership.",
      );
    }
    if (!restore && nativeProviderCurrent(existingNative, uid) &&
        existingNative.provider === requestedProvider &&
        existingNative.productId === product.productId &&
        !existingNative.pendingProductId) {
      throw new HttpsError(
          "already-exists",
          "This mobile membership plan is already active.",
      );
    }
    const claim = claimBillingIntentInTransaction({
      transaction,
      intentRef,
      intentSnapshot,
      admin,
      uid,
      channel: requestedProvider,
      platform,
      productId: restore ? "*" : product.productId,
      planId: restore ? "restore" : product.planId,
      nowMillis,
      ttlMillis: restore ?
        NATIVE_RESTORE_INTENT_TTL_MS : NATIVE_PURCHASE_INTENT_TTL_MS,
      sandboxAllowed,
    });
    return {
      ...claim,
      currentPlan: nativeProviderCurrent(existingNative, uid) ?
        String(existingNative.planId || "free") : "free",
      currentProvider: nativeProviderCurrent(existingNative, uid) ?
        String(existingNative.provider || "") : "free",
    };
  });
}

async function requireNativeMembershipPurchaseIntent({
  db,
  uid,
  platform,
  product,
  intentToken,
  restore = false,
}) {
  const snapshot = await db.collection(MEMBERSHIP_BILLING_INTENT_COLLECTION)
      .doc(uid).get();
  const intent = snapshot.exists ? snapshot.data() : null;
  return requireBillingIntentForVerification(intent, {
    uid,
    channel: platform === "ios" ? "app_store" : "google_play",
    platform,
    productId: restore ? "*" : product.productId,
    planId: restore ? "restore" : product.planId,
    intentToken,
  });
}

function resumableNativeMembershipIntent(intent, {
  uid,
  platform,
  product,
  allowRestore = false,
  nowMillis = Date.now(),
}) {
  if (!intent || !validIntentToken(intent.intentToken)) return null;
  const channel = platform === "ios" ? "app_store" : "google_play";
  const exactExpected = {
    uid,
    channel,
    platform,
    productId: product.productId,
    planId: product.planId,
    intentToken: intent.intentToken,
  };
  let restore = false;
  if (!billingIntentMatchesForVerification(intent, exactExpected, nowMillis)) {
    const restoreExpected = {
      uid,
      channel,
      platform,
      productId: "*",
      planId: "restore",
      intentToken: intent.intentToken,
    };
    if (!allowRestore ||
        !billingIntentMatchesForVerification(
            intent,
            restoreExpected,
            nowMillis,
        )) {
      return null;
    }
    restore = true;
  }
  return {
    intentToken: intent.intentToken,
    ownerUid: uid,
    platform,
    productId: restore ? "*" : product.productId,
    restore,
    expiresAtMillis: Math.max(
        timestampMillis(intent.expiresAtMillis || intent.expiresAt),
        timestampMillis(intent.replayUntilMillis || intent.replayUntil),
    ),
  };
}

async function beginNativeMembershipReconciliation({
  db,
  admin,
  uid,
  billingIntent = null,
}) {
  const ref = db.collection(NATIVE_RECONCILIATION_LEASE_COLLECTION).doc(uid);
  const intentRef = db.collection(MEMBERSHIP_BILLING_INTENT_COLLECTION).doc(uid);
  return db.runTransaction(async (transaction) => {
    const [snapshot, intentSnapshot] = await Promise.all([
      transaction.get(ref),
      transaction.get(intentRef),
    ]);
    if (billingIntent) {
      markBillingIntentVerifyingInTransaction({
        transaction,
        intentRef,
        intentSnapshot,
        admin,
        expected: {uid, ...billingIntent},
        allowCompletedReplay: true,
      });
    }
    const previous = snapshot.exists ? Number(snapshot.data().generation || 0) : 0;
    if (!Number.isSafeInteger(previous) || previous < 0 ||
        previous >= Number.MAX_SAFE_INTEGER) {
      throw new Error("native_membership_reconciliation_generation_invalid");
    }
    const generation = previous + 1;
    transaction.set(ref, {
      ownerUid: uid,
      generation,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(snapshot.exists ? {} : {
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }),
    }, {merge: true});
    return generation;
  });
}

function providerSubscriptionKey(entitlement, purchaseToken) {
  if (entitlement.provider === "app_store") {
    return `app_store:${entitlement.originalTransactionId}`;
  }
  return `google_play:${crypto.createHash("sha256")
      .update(String(purchaseToken || ""), "utf8")
      .digest("hex")}`;
}

async function applyNativeEntitlement({
  db,
  admin,
  uid,
  accountToken,
  entitlement,
  purchaseToken = "",
  reconciliationGeneration,
}) {
  const providerRef = db.collection("native_membership_provider_state").doc(uid);
  const dispatchRef = db.collection("dispatch_memberships").doc(uid);
  const vipRef = db.collection("vip_memberships").doc(uid);
  const userRef = db.collection("users").doc(uid);
  const transitionRef = db.collection("membership_plan_transitions").doc(uid);
  const stripeDispatchRef = db.collection("dispatch_subscription_provider_state")
      .doc(uid);
  const stripeVipRef = db.collection("vip_subscription_provider_state").doc(uid);
  const stripeDispatchCheckoutRef = db
      .collection("dispatch_subscription_checkout_state").doc(uid);
  const stripeVipCheckoutRef = db.collection("vip_subscription_checkout_state")
      .doc(uid);
  const reconciliationLeaseRef = db
      .collection(NATIVE_RECONCILIATION_LEASE_COLLECTION).doc(uid);
  const Timestamp = admin.firestore.Timestamp;
  const FieldValue = admin.firestore.FieldValue;
  const end = Timestamp.fromMillis(entitlement.expiresAtMillis);
  const subscriptionKey = providerSubscriptionKey(entitlement, purchaseToken);

  return db.runTransaction(async (transaction) => {
    const [
      dispatchSnapshot,
      vipSnapshot,
      providerSnapshot,
      stripeDispatchSnapshot,
      stripeVipSnapshot,
      stripeDispatchCheckoutSnapshot,
      stripeVipCheckoutSnapshot,
      reconciliationLeaseSnapshot,
    ] = await Promise.all([
      transaction.get(dispatchRef),
      transaction.get(vipRef),
      transaction.get(providerRef),
      transaction.get(stripeDispatchRef),
      transaction.get(stripeVipRef),
      transaction.get(stripeDispatchCheckoutRef),
      transaction.get(stripeVipCheckoutRef),
      transaction.get(reconciliationLeaseRef),
    ]);
    const currentGeneration = reconciliationLeaseSnapshot.exists ?
      Number(reconciliationLeaseSnapshot.data().generation || 0) : 0;
    if (!Number.isSafeInteger(reconciliationGeneration) ||
        reconciliationGeneration < 1 ||
        currentGeneration !== reconciliationGeneration) {
      throw new HttpsError(
          "aborted",
          "A newer mobile membership status check replaced this result.",
      );
    }
    const stripeDispatch = stripeDispatchSnapshot.exists ?
      stripeDispatchSnapshot.data() : null;
    const stripeVip = stripeVipSnapshot.exists ? stripeVipSnapshot.data() : null;
    if (stripeProviderBlocksNativePurchase(stripeDispatch, uid) ||
        stripeProviderBlocksNativePurchase(stripeVip, uid) ||
        stripeMembershipBlocksNativePurchase(
            dispatchSnapshot.exists ? dispatchSnapshot.data() : null,
            uid,
        ) ||
        stripeMembershipBlocksNativePurchase(
            vipSnapshot.exists ? vipSnapshot.data() : null,
            uid,
        ) ||
        stripeCheckoutStateOpen(
            stripeDispatchCheckoutSnapshot.exists ?
              stripeDispatchCheckoutSnapshot.data() : null,
            uid,
        ) ||
        stripeCheckoutStateOpen(
            stripeVipCheckoutSnapshot.exists ?
              stripeVipCheckoutSnapshot.data() : null,
            uid,
        )) {
      throw new HttpsError(
          "failed-precondition",
          "This membership is currently being billed by Stripe.",
      );
    }
    const previousProvider = providerSnapshot.exists ? providerSnapshot.data() : null;
    if (nativeProviderCurrent(previousProvider, uid) &&
        previousProvider.provider !== entitlement.provider) {
      throw new HttpsError(
          "failed-precondition",
          "Another mobile store already owns this active membership.",
      );
    }

    transaction.set(providerRef, {
      ownerUid: uid,
      provider: entitlement.provider,
      platform: entitlement.platform,
      active: true,
      status: entitlement.status || "active",
      productId: entitlement.productId,
      planId: entitlement.planId,
      tier: entitlement.tier,
      providerSubscriptionKey: subscriptionKey,
      storeAccountToken: accountToken,
      expiresAtMillis: entitlement.expiresAtMillis,
      expiresAt: end,
      autoRenewEnabled: entitlement.autoRenewEnabled === true,
      pendingProductId: entitlement.pendingProductId || null,
      pendingPlanId: nativeMembershipProduct(entitlement.pendingProductId)?.planId || null,
      originalTransactionId: entitlement.originalTransactionId || null,
      latestTransactionId: entitlement.transactionId || null,
      latestOrderId: entitlement.latestOrderId || null,
      environment: entitlement.environment || null,
      ...(purchaseToken ? {purchaseToken} : {}),
      lastVerifiedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      ...(providerSnapshot.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),
    }, {merge: true});

    if (entitlement.tier === "vip") {
      transaction.set(vipRef, {
        ownerUid: uid,
        active: true,
        status: entitlement.status || "active",
        renewalStatus: entitlement.autoRenewEnabled ? "paid" : "cancel_at_period_end",
        paymentIssue: entitlement.status === "grace_period",
        plan: "monthly",
        subscriptionId: subscriptionKey,
        billingProvider: entitlement.provider,
        currentPeriodEnd: end,
        updatedAt: FieldValue.serverTimestamp(),
        ...(vipSnapshot.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),
      }, {merge: true});
      if (dispatchSnapshot.exists &&
          new Set(["app_store", "google_play"])
              .has(String(dispatchSnapshot.data().billingProvider || ""))) {
        transaction.set(dispatchRef, {
          active: false,
          status: "upgraded_to_vip",
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
      transaction.set(userRef, {
        vipActive: true,
        vipStatus: entitlement.status || "active",
        vipExpiresAt: end,
        vipSubscriptionId: subscriptionKey,
        vipUpdatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    } else {
      const dispatchPlan = entitlement.planId === "dispatch_yearly" ?
        "yearly" : "monthly";
      transaction.set(dispatchRef, {
        ownerUid: uid,
        active: true,
        status: entitlement.status || "active",
        renewalStatus: entitlement.autoRenewEnabled ? "paid" : "cancel_at_period_end",
        paymentIssue: entitlement.status === "grace_period",
        plan: dispatchPlan,
        subscriptionId: subscriptionKey,
        billingProvider: entitlement.provider,
        currentPeriodEnd: end,
        updatedAt: FieldValue.serverTimestamp(),
        ...(dispatchSnapshot.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),
      }, {merge: true});
      if (vipSnapshot.exists &&
          new Set(["app_store", "google_play"])
              .has(String(vipSnapshot.data().billingProvider || ""))) {
        transaction.set(vipRef, {
          active: false,
          status: "downgraded_to_dispatch",
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        transaction.set(userRef, {
          vipActive: false,
          vipStatus: "downgraded_to_dispatch",
          vipExpiresAt: FieldValue.delete(),
          vipSubscriptionId: FieldValue.delete(),
          vipUpdatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
    }

    transaction.set(transitionRef, {
      ownerUid: uid,
      targetPlan: entitlement.planId,
      status: "completed",
      completedByProvider: entitlement.provider,
      completedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    return true;
  });
}

async function clearExpiredNativeEntitlement({
  db,
  admin,
  uid,
  providerState,
  terminalStatus = "expired",
  reconciliationGeneration,
}) {
  const provider = String(providerState && providerState.provider || "");
  const planId = String(providerState && providerState.planId || "");
  const providerSubscriptionKey = String(
      providerState && providerState.providerSubscriptionKey || "",
  );
  const originalTransactionId = String(
      providerState && providerState.originalTransactionId || "",
  );
  const expectedProductId = String(providerState && providerState.productId || "");
  const expectedPlanId = String(providerState && providerState.planId || "");
  const expectedExpiresAtMillis = Number(
      providerState && providerState.expiresAtMillis || 0,
  );
  const expectedLatestTransactionId = String(
      providerState && providerState.latestTransactionId || "",
  );
  const expectedLatestOrderId = String(
      providerState && providerState.latestOrderId || "",
  );
  const status = new Set(["expired", "refunded", "revoked", "inactive"])
      .has(String(terminalStatus)) ? String(terminalStatus) : "expired";
  const providerRef = db.collection("native_membership_provider_state").doc(uid);
  const dispatchRef = db.collection("dispatch_memberships").doc(uid);
  const vipRef = db.collection("vip_memberships").doc(uid);
  const userRef = db.collection("users").doc(uid);
  const reconciliationLeaseRef = db
      .collection(NATIVE_RECONCILIATION_LEASE_COLLECTION).doc(uid);
  const FieldValue = admin.firestore.FieldValue;
  return db.runTransaction(async (transaction) => {
    const [
      providerSnapshot,
      dispatchSnapshot,
      vipSnapshot,
      reconciliationLeaseSnapshot,
    ] = await Promise.all([
      transaction.get(providerRef),
      transaction.get(dispatchRef),
      transaction.get(vipRef),
      transaction.get(reconciliationLeaseRef),
    ]);
    const currentGeneration = reconciliationLeaseSnapshot.exists ?
      Number(reconciliationLeaseSnapshot.data().generation || 0) : 0;
    if (!Number.isSafeInteger(reconciliationGeneration) ||
        reconciliationGeneration < 1 ||
        currentGeneration !== reconciliationGeneration) {
      return false;
    }
    const currentProvider = providerSnapshot.exists ? providerSnapshot.data() : null;
    const providerMatches = currentProvider && currentProvider.active === true &&
      currentProvider.ownerUid === uid && currentProvider.provider === provider &&
      providerSubscriptionKey &&
      String(currentProvider.providerSubscriptionKey || "") ===
        providerSubscriptionKey &&
      expectedProductId && currentProvider.productId === expectedProductId &&
      expectedPlanId && currentProvider.planId === expectedPlanId &&
      Number.isFinite(expectedExpiresAtMillis) && expectedExpiresAtMillis > 0 &&
      Number(currentProvider.expiresAtMillis || 0) === expectedExpiresAtMillis &&
      (provider !== "app_store" ||
       (originalTransactionId &&
        String(currentProvider.originalTransactionId || "") ===
          originalTransactionId &&
        expectedLatestTransactionId &&
        String(currentProvider.latestTransactionId || "") ===
          expectedLatestTransactionId)) &&
      (provider !== "google_play" ||
       (expectedLatestOrderId &&
        String(currentProvider.latestOrderId || "") === expectedLatestOrderId));
    if (!providerMatches) return false;
    transaction.set(providerRef, {
      active: false,
      status,
      lastVerifiedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    if (planId.startsWith("dispatch_") && dispatchSnapshot.exists &&
        dispatchSnapshot.data().billingProvider === provider &&
        dispatchSnapshot.data().subscriptionId === providerSubscriptionKey) {
      transaction.set(dispatchRef, {
        active: false,
        status,
        renewalStatus: status,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    if (planId === "vip_monthly" && vipSnapshot.exists &&
        vipSnapshot.data().billingProvider === provider &&
        vipSnapshot.data().subscriptionId === providerSubscriptionKey) {
      transaction.set(vipRef, {
        active: false,
        status,
        renewalStatus: status,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      transaction.set(userRef, {
        vipActive: false,
        vipStatus: status,
        vipUpdatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    return true;
  });
}

function createNativeMembershipBilling(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  const getNativeMembershipBillingStatus = async (request) => {
    try {
      const identity = requireAuthenticatedIdentity(request, {requirePhone: false});
      await enforceUserRateLimit({db, admin, request, scope: "account"});
      const requestedPlatform = normalizeNativePlatform(
          request.data && request.data.platform,
      );
      const googleProductIds = Object.keys(NATIVE_MEMBERSHIP_PRODUCTS);
      const appleProductIds = [...APPLE_NATIVE_MEMBERSHIP_PRODUCT_IDS];
      const [readiness, accountToken, state, stripeState] = await Promise.all([
        loadNativeBillingReadiness(db),
        ensureStoreAccountToken(db, admin, identity.uid),
        currentMembershipState(db, identity.uid),
        stripeProviderState(db, identity.uid),
      ]);
      const stripeManaged =
        stripeProviderBlocksNativePurchase(stripeState.dispatch, identity.uid) ||
        stripeProviderBlocksNativePurchase(stripeState.vip, identity.uid);
      const nativeCurrent = nativeProviderCurrent(
          state.nativeProvider,
          identity.uid,
      );
      return {
        available: readiness.enabled,
        appleEnabled: readiness.appleEnabled,
        appleSandboxEnabled: appleSandboxAllowedForRequest(readiness, request),
        googleEnabled: readiness.googleEnabled,
        bundleId: APPLE_BUNDLE_ID,
        packageName: GOOGLE_PACKAGE_NAME,
        // productIds remains the platform-selected compatibility field. The
        // explicit lists prevent an Apple activation from changing Google.
        productIds: requestedPlatform === "ios" ?
          appleProductIds : googleProductIds,
        appleProductIds,
        googleProductIds,
        storeAccountToken: accountToken,
        currentPlan: state.currentPlan.id,
        currentProvider: stripeManaged ? "stripe" :
          nativeCurrent ? String(state.nativeProvider.provider || "") : "free",
        nativeActive: nativeCurrent,
        purchaseBlockedByStripe: stripeManaged,
        pendingPlan: nativeCurrent ?
          String(state.nativeProvider.pendingPlanId || "") : "",
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Native membership billing status failed");
      throw new HttpsError(
          "internal",
          "Mobile membership billing status could not be loaded.",
      );
    }
  };

  const preflightNativeMembershipPurchase = async (request) => {
    try {
      const identity = requireAuthenticatedIdentity(request, {requirePhone: false});
      await enforceUserRateLimit({db, admin, request, scope: "account"});
      const platform = normalizeNativePlatform(request.data && request.data.platform);
      const product = nativeMembershipProduct(request.data && request.data.productId);
      const appleProductAllowed = platform !== "ios" ||
        appleNativeMembershipProduct(product && product.productId);
      if (!platform || !product || !appleProductAllowed) {
        throw new HttpsError(
            "invalid-argument",
            "The mobile membership purchase is invalid.",
        );
      }
      const [readiness, policyStatus] = await Promise.all([
        loadNativeBillingReadiness(db),
        currentPolicyAcceptanceStatus(db, identity.uid),
      ]);
      if (!readiness.enabled ||
          (platform === "ios" && !readiness.appleEnabled) ||
          (platform === "android" && !readiness.googleEnabled)) {
        throw new HttpsError(
            "failed-precondition",
            "Mobile membership purchasing is not enabled yet.",
        );
      }
      if (!policyStatus.current) {
        throw new HttpsError(
            "failed-precondition",
            "Review and accept the current policies before purchasing.",
        );
      }
      const [accountToken, sandboxAllowed] = await Promise.all([
        ensureStoreAccountToken(db, admin, identity.uid),
        platform === "ios" ?
          appleSandboxAllowedForCurrentAccount(
              admin,
              readiness,
              request,
              identity.uid,
          ) : false,
      ]);
      const intent = await claimNativeMembershipPurchaseIntent({
        db,
        admin,
        uid: identity.uid,
        platform,
        product,
        sandboxAllowed,
      });
      return {
        ready: true,
        platform,
        productId: product.productId,
        intentOwnerUid: identity.uid,
        storeAccountToken: accountToken,
        purchaseIntentToken: intent.intentToken,
        purchaseIntentExpiresAtMillis: intent.expiresAtMillis,
        purchaseIntentReused: intent.reused,
        currentPlan: intent.currentPlan,
        currentProvider: intent.currentProvider,
        appleSandboxEnabled: sandboxAllowed,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Native membership purchase preflight failed", {
        code: String(error && error.code || "").slice(0, 80),
      });
      throw new HttpsError(
          "internal",
          "Mobile membership purchasing could not be prepared safely.",
      );
    }
  };

  const preflightNativeMembershipRestore = async (request) => {
    try {
      const identity = requireAuthenticatedIdentity(request, {requirePhone: false});
      await enforceUserRateLimit({db, admin, request, scope: "account"});
      const platform = normalizeNativePlatform(request.data && request.data.platform);
      if (!platform) {
        throw new HttpsError(
            "invalid-argument",
            "The mobile membership restore platform is invalid.",
        );
      }
      const [readiness, policyStatus] = await Promise.all([
        loadNativeBillingReadiness(db),
        currentPolicyAcceptanceStatus(db, identity.uid),
      ]);
      if (!readiness.enabled ||
          (platform === "ios" && !readiness.appleEnabled) ||
          (platform === "android" && !readiness.googleEnabled)) {
        throw new HttpsError(
            "failed-precondition",
            "Mobile membership restoration is not enabled yet.",
        );
      }
      if (!policyStatus.current) {
        throw new HttpsError(
            "failed-precondition",
            "Review and accept the current policies before restoring.",
        );
      }
      const [accountToken, sandboxAllowed] = await Promise.all([
        ensureStoreAccountToken(db, admin, identity.uid),
        platform === "ios" ?
          appleSandboxAllowedForCurrentAccount(
              admin,
              readiness,
              request,
              identity.uid,
          ) : false,
      ]);
      const intent = await claimNativeMembershipPurchaseIntent({
        db,
        admin,
        uid: identity.uid,
        platform,
        product: null,
        restore: true,
        sandboxAllowed,
      });
      return {
        ready: true,
        platform,
        intentOwnerUid: identity.uid,
        storeAccountToken: accountToken,
        purchaseIntentToken: intent.intentToken,
        purchaseIntentExpiresAtMillis: intent.expiresAtMillis,
        purchaseIntentReused: intent.reused,
        appleSandboxEnabled: sandboxAllowed,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Native membership restore preflight failed", {
        code: String(error && error.code || "").slice(0, 80),
      });
      throw new HttpsError(
          "internal",
          "Mobile membership restoration could not be prepared safely.",
      );
    }
  };

  const resumeNativeMembershipPurchaseIntent = async (request) => {
    try {
      const identity = requireAuthenticatedIdentity(request, {requirePhone: false});
      await enforceUserRateLimit({db, admin, request, scope: "account"});
      const platform = normalizeNativePlatform(request.data && request.data.platform);
      const product = nativeMembershipProduct(request.data && request.data.productId);
      const appleProductAllowed = platform !== "ios" ||
        appleNativeMembershipProduct(product && product.productId);
      if (!platform || !product || !appleProductAllowed) {
        throw new HttpsError(
            "invalid-argument",
            "The mobile membership recovery request is invalid.",
        );
      }
      const snapshot = await db.collection(MEMBERSHIP_BILLING_INTENT_COLLECTION)
          .doc(identity.uid).get();
      const resumed = resumableNativeMembershipIntent(
          snapshot.exists ? snapshot.data() : null,
          {
            uid: identity.uid,
            platform,
            product,
            allowRestore: request.data && request.data.restore === true,
          },
      );
      if (!resumed) return {found: false};
      return {
        found: true,
        purchaseIntentToken: resumed.intentToken,
        purchaseIntentExpiresAtMillis: resumed.expiresAtMillis,
        intentOwnerUid: resumed.ownerUid,
        platform: resumed.platform,
        productId: resumed.productId,
        restore: resumed.restore,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Native membership purchase intent recovery failed");
      throw new HttpsError(
          "internal",
          "The store purchase authorization could not be recovered safely.",
      );
    }
  };

  const releaseNativeMembershipPurchaseIntent = async (request) => {
    try {
      const identity = requireAuthenticatedIdentity(request, {requirePhone: false});
      await enforceUserRateLimit({db, admin, request, scope: "account"});
      const intentToken = String(
          request.data && request.data.purchaseIntentToken || "",
      ).trim();
      if (!validIntentToken(intentToken)) {
        throw new HttpsError(
            "invalid-argument",
            "The membership purchase attempt is invalid.",
        );
      }
      const released = await finishBillingIntent({
        db,
        admin,
        uid: identity.uid,
        intentToken,
        status: "released",
      });
      return {released};
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Native membership purchase intent release failed");
      throw new HttpsError(
          "internal",
          "The membership purchase attempt could not be released safely.",
      );
    }
  };

  const markNativeMembershipPurchasePending = async (request) => {
    try {
      const identity = requireAuthenticatedIdentity(request, {requirePhone: false});
      await enforceUserRateLimit({db, admin, request, scope: "account"});
      const platform = normalizeNativePlatform(request.data && request.data.platform);
      const product = nativeMembershipProduct(request.data && request.data.productId);
      const appleProductAllowed = platform !== "ios" ||
        appleNativeMembershipProduct(product && product.productId);
      const intentToken = String(
          request.data && request.data.purchaseIntentToken || "",
      ).trim();
      if (!platform || !product || !appleProductAllowed ||
          !validIntentToken(intentToken)) {
        throw new HttpsError(
            "invalid-argument",
            "The pending mobile membership purchase is invalid.",
        );
      }
      const intentRef = db.collection(MEMBERSHIP_BILLING_INTENT_COLLECTION)
          .doc(identity.uid);
      const pending = await db.runTransaction(async (transaction) => {
        const intentSnapshot = await transaction.get(intentRef);
        return markBillingIntentPendingInTransaction({
          transaction,
          intentRef,
          intentSnapshot,
          admin,
          expected: {
            uid: identity.uid,
            channel: platform === "ios" ? "app_store" : "google_play",
            platform,
            productId: product.productId,
            planId: product.planId,
            intentToken,
          },
        });
      });
      return {
        pending: true,
        purchaseIntentExpiresAtMillis: pending.expiresAtMillis,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Native membership pending intent update failed");
      throw new HttpsError(
          "internal",
          "The pending store purchase could not be recorded safely.",
      );
    }
  };

  const verifyNativeMembershipPurchase = async (request) => {
    try {
      const identity = requireAuthenticatedIdentity(request, {requirePhone: false});
      await enforceUserRateLimit({db, admin, request, scope: "account"});
      const platform = normalizeNativePlatform(request.data && request.data.platform);
      const product = nativeMembershipProduct(request.data && request.data.productId);
      const appleProductAllowed = platform !== "ios" ||
        appleNativeMembershipProduct(product && product.productId);
      if (!platform || !product || !appleProductAllowed) {
        throw new HttpsError("invalid-argument", "The mobile membership purchase is invalid.");
      }
      const restore = request.data && request.data.restore === true;
      const purchaseIntentToken = String(
          request.data && request.data.purchaseIntentToken || "",
      ).trim();
      if (!validIntentToken(purchaseIntentToken)) {
        throw new HttpsError(
            "failed-precondition",
            "Start this membership purchase again before verifying it.",
        );
      }
      // Entry readiness and current policy acceptance are enforced before this
      // opaque intent is issued. Verification deliberately trusts that exact,
      // still-live intent so a rollback or policy revision cannot strand an
      // already accepted App Store / Play transaction.
      const purchaseIntent = await requireNativeMembershipPurchaseIntent({
        db,
        uid: identity.uid,
        platform,
        product,
        intentToken: purchaseIntentToken,
        restore,
      });
      const [accountToken, stripeState, nativeSnapshot] = await Promise.all([
        ensureStoreAccountToken(db, admin, identity.uid),
        stripeProviderState(db, identity.uid),
        db.collection("native_membership_provider_state").doc(identity.uid).get(),
      ]);
      if (stripeProviderBlocksNativePurchase(stripeState.dispatch, identity.uid) ||
          stripeProviderBlocksNativePurchase(stripeState.vip, identity.uid)) {
        throw new HttpsError(
            "failed-precondition",
            "This membership is currently billed by Stripe. Manage or finish that subscription before starting store billing.",
        );
      }
      const existingNative = nativeSnapshot.exists ? nativeSnapshot.data() : null;
      const requestedProvider = platform === "ios" ? "app_store" : "google_play";
      if (nativeProviderCurrent(existingNative, identity.uid) &&
          existingNative.provider !== requestedProvider) {
        throw new HttpsError(
            "failed-precondition",
            "Another mobile store already owns this membership.",
        );
      }

      let entitlement;
      let purchaseToken = "";
      if (platform === "ios") {
        const purchaseId = String(request.data && request.data.purchaseId || "").trim();
        if (!/^[0-9]{6,40}$/.test(purchaseId)) {
          throw new HttpsError(
              "invalid-argument",
              "The App Store transaction identifier is invalid.",
          );
        }
        const allowSandbox = purchaseIntent.sandboxAllowedAtClaim === true &&
          await appleSandboxAccountAllowed(admin, identity.uid);
        entitlement = await appleCurrentEntitlement({
          transactionId: purchaseId,
          accountToken,
          allowSandbox,
        });
      } else {
        purchaseToken = String(
            request.data && request.data.serverVerificationData || "",
        ).trim();
        if (purchaseToken.length < 20 || purchaseToken.length > 4096) {
          throw new HttpsError(
              "invalid-argument",
              "The Google Play purchase token is invalid.",
          );
        }
        entitlement = await googleCurrentEntitlement({
          purchaseToken,
          accountToken,
        });
      }

      const initialProductMatches = entitlement.productId === product.productId ||
        entitlement.pendingProductId === product.productId;
      if (!initialProductMatches) {
        throw new HttpsError(
            "failed-precondition",
            "The verified store product does not match the requested membership plan.",
        );
      }
      // Only verified store proof may supersede another reconciliation. Re-fetch
      // after acquiring the generation so an older response cannot win a race.
      const reconciliationGeneration =
        await beginNativeMembershipReconciliation({
          db,
          admin,
          uid: identity.uid,
          billingIntent: {
            channel: platform === "ios" ? "app_store" : "google_play",
            platform,
            productId: restore ? "*" : product.productId,
            planId: restore ? "restore" : product.planId,
            intentToken: purchaseIntentToken,
          },
        });
      if (platform === "ios") {
        entitlement = await appleReconciledEntitlement({
          originalTransactionId: entitlement.originalTransactionId,
          accountToken,
          environment: entitlement.environment,
        });
      } else {
        entitlement = await googleCurrentEntitlement({purchaseToken, accountToken});
      }
      const requestedProductMatches = entitlement &&
        (entitlement.productId === product.productId ||
         entitlement.pendingProductId === product.productId);
      if (!requestedProductMatches) {
        throw new HttpsError(
            "failed-precondition",
            "The current store product does not match the requested membership plan.",
        );
      }
      await applyNativeEntitlement({
        db,
        admin,
        uid: identity.uid,
        accountToken,
        entitlement,
        purchaseToken,
        reconciliationGeneration,
      });
      await finishBillingIntent({
        db,
        admin,
        uid: identity.uid,
        intentToken: purchaseIntentToken,
        status: "completed",
      });
      return {
        verified: true,
        provider: entitlement.provider,
        currentPlan: entitlement.planId,
        pendingPlan: nativeMembershipProduct(entitlement.pendingProductId)?.planId || "",
        expiresAtMillis: entitlement.expiresAtMillis,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Native membership purchase verification failed", {
        code: String(error && error.code || "").slice(0, 80),
      });
      throw new HttpsError(
          "internal",
          "The mobile store purchase could not be verified safely.",
      );
    }
  };

  const reconcileNativeMembershipSubscriptions = async ({
    startAfter = "",
    maxPages,
  } = {}) => {
    const readiness = await loadNativeBillingReadiness(db);
    if (!readiness.enabled) {
      return {
        checked: 0,
        updated: 0,
        failed: 0,
        pages: 0,
        complete: true,
        nextCursor: "",
      };
    }
    const loadPage = async ({startAfter: cursor, limit}) => {
      let query = db.collection("native_membership_provider_state")
          .where("active", "==", true)
          .orderBy(admin.firestore.FieldPath.documentId())
          .limit(limit);
      if (cursor) query = query.startAfter(cursor);
      const snapshot = await query.get();
      return snapshot.docs;
    };
    const reconcileDocument = async (document) => {
      const state = document.data();
      const uid = document.id;
      try {
        const accountToken = String(state.storeAccountToken || "");
        const reconciliationGeneration =
          await beginNativeMembershipReconciliation({db, admin, uid});
        let entitlement = null;
        let purchaseToken = "";
        if (state.provider === "app_store" && readiness.appleEnabled) {
          if (String(state.environment || "").toLowerCase() === "sandbox" &&
              !readiness.appleSandboxEnabled) {
            return {skipped: true};
          }
          if (String(state.environment || "").toLowerCase() === "sandbox" &&
              !await appleSandboxAccountAllowed(admin, uid)) {
            return {skipped: true};
          }
          entitlement = await appleReconciledEntitlement({
            originalTransactionId: String(state.originalTransactionId || ""),
            accountToken,
            environment: state.environment,
          });
        } else if (state.provider === "google_play" && readiness.googleEnabled) {
          purchaseToken = String(state.purchaseToken || "");
          const purchase = await googleSubscriptionPurchase(purchaseToken);
          entitlement = googleSubscriptionEntitlement(purchase, accountToken);
        } else {
          return {skipped: true};
        }
        if (!entitlement) {
          const cleared = await clearExpiredNativeEntitlement({
            db,
            admin,
            uid,
            providerState: state,
            reconciliationGeneration,
          });
          if (!cleared) return {skipped: true};
        } else {
          await applyNativeEntitlement({
            db,
            admin,
            uid,
            accountToken,
            entitlement,
            purchaseToken,
            reconciliationGeneration,
          });
        }
      } catch (error) {
        await document.ref.set({
          lastReconciliationErrorAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        console.error("Native membership reconciliation attempt failed", {
          provider: String(state.provider || "").slice(0, 30),
          code: String(error && error.code || "").slice(0, 80),
        });
        throw error;
      }
      return {skipped: false};
    };
    return reconcileNativeMembershipPages({
      loadPage,
      reconcileDocument,
      startAfter,
      pageSize: NATIVE_RECONCILIATION_LIMIT,
      ...(maxPages == null ? {} : {maxPages}),
    });
  };

  return {
    getNativeMembershipBillingStatus,
    preflightNativeMembershipPurchase,
    preflightNativeMembershipRestore,
    reconcileNativeMembershipSubscriptions,
    releaseNativeMembershipPurchaseIntent,
    resumeNativeMembershipPurchaseIntent,
    markNativeMembershipPurchasePending,
    verifyNativeMembershipPurchase,
  };
}

module.exports = {
  GOOGLE_ANDROID_PUBLISHER_SCOPE,
  NATIVE_RECONCILIATION_LIMIT,
  appleSandboxAccountAllowed,
  appleSandboxAllowedForCurrentAccount,
  appleSandboxAllowedForRequest,
  appleCurrentEntitlement,
  appleIapIssuerId,
  appleIapKeyId,
  appleIapPrivateKey,
  appleReconciledEntitlement,
  applyNativeEntitlement,
  beginNativeMembershipReconciliation,
  claimNativeMembershipPurchaseIntent,
  clearExpiredNativeEntitlement,
  createNativeMembershipBilling,
  ensureStoreAccountToken,
  googlePlayServiceAccountJson,
  nativeBillingReadiness,
  nativeMembershipSecretNames,
  nativeProviderCurrent,
  providerSubscriptionKey,
  requireNativeMembershipPurchaseIntent,
  resumableNativeMembershipIntent,
  stripeProviderBlocksNativePurchase,
  stripeMembershipBlocksNativePurchase,
};
