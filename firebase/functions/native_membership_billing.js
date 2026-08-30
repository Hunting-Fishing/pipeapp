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
  GOOGLE_PACKAGE_NAME,
  NATIVE_MEMBERSHIP_PRODUCTS,
  appleStatusEntitlement,
  appleTransactionEntitlement,
  decodeJwsPayload,
  googleSubscriptionEntitlement,
  nativeMembershipProduct,
  normalizeNativePlatform,
} = require("./native_membership_policy");

const APPLE_PRODUCTION_BASE = "https://api.storekit.apple.com";
const APPLE_SANDBOX_BASE = "https://api.storekit-sandbox.apple.com";
const GOOGLE_ANDROID_PUBLISHER_SCOPE =
  "https://www.googleapis.com/auth/androidpublisher";
const NATIVE_RECONCILIATION_LIMIT = 200;
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

function appleAuthorizationToken() {
  const now = Math.floor(Date.now() / 1000);
  const header = {
    alg: "ES256",
    kid: appleIapKeyId.value(),
    typ: "JWT",
  };
  const payload = {
    iss: appleIapIssuerId.value(),
    iat: now,
    exp: now + (15 * 60),
    aud: "appstoreconnect-v1",
    bid: APPLE_BUNDLE_ID,
  };
  const signingInput = `${base64UrlJson(header)}.${base64UrlJson(payload)}`;
  const signature = crypto.sign(
      "sha256",
      Buffer.from(signingInput, "utf8"),
      {
        key: normalizePrivateKey(appleIapPrivateKey.value()),
        dsaEncoding: "ieee-p1363",
      },
  );
  return `${signingInput}.${signature.toString("base64url")}`;
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

async function appleRequestAtBase(baseUrl, path) {
  return fetchJson(`${baseUrl}${path}`, {
    headers: {
      Authorization: `Bearer ${appleAuthorizationToken()}`,
      Accept: "application/json",
    },
  });
}

async function appleRequestWithEnvironmentFallback(path) {
  const production = await appleRequestAtBase(APPLE_PRODUCTION_BASE, path);
  if (production.ok) {
    return {payload: production.payload, baseUrl: APPLE_PRODUCTION_BASE};
  }
  if (production.status !== 404) {
    throw new HttpsError(
        "failed-precondition",
        "Apple could not verify this subscription right now.",
    );
  }
  const sandbox = await appleRequestAtBase(APPLE_SANDBOX_BASE, path);
  if (!sandbox.ok) {
    throw new HttpsError(
        "failed-precondition",
        "Apple could not verify this subscription.",
    );
  }
  return {payload: sandbox.payload, baseUrl: APPLE_SANDBOX_BASE};
}

async function appleCurrentEntitlement({transactionId, accountToken}) {
  const transactionPath =
    `/inApps/v1/transactions/${encodeURIComponent(transactionId)}`;
  const transactionResponse =
    await appleRequestWithEnvironmentFallback(transactionPath);
  const transactionPayload = decodeJwsPayload(
      transactionResponse.payload && transactionResponse.payload.signedTransactionInfo,
  );
  const initial = appleTransactionEntitlement(transactionPayload, accountToken);
  if (!initial) {
    throw new HttpsError(
        "failed-precondition",
        "This App Store purchase does not belong to this Pipe Buyer account.",
    );
  }
  const statusPath =
    `/inApps/v1/subscriptions/${encodeURIComponent(initial.originalTransactionId)}`;
  const statusResponse = await appleRequestAtBase(
      transactionResponse.baseUrl,
      statusPath,
  );
  if (!statusResponse.ok) {
    throw new HttpsError(
        "failed-precondition",
        "Apple could not confirm the current subscription status.",
    );
  }
  const entitlement = appleStatusEntitlement(
      statusResponse.payload,
      accountToken,
  );
  if (!entitlement ||
      entitlement.originalTransactionId !== initial.originalTransactionId) {
    throw new HttpsError(
        "failed-precondition",
        "The App Store subscription is not currently entitled.",
    );
  }
  return entitlement;
}

async function appleReconciledEntitlement({originalTransactionId, accountToken, environment}) {
  const baseUrl = String(environment || "").toLowerCase() === "sandbox" ?
    APPLE_SANDBOX_BASE : APPLE_PRODUCTION_BASE;
  const path =
    `/inApps/v1/subscriptions/${encodeURIComponent(originalTransactionId)}`;
  const response = await appleRequestAtBase(baseUrl, path);
  if (!response.ok) {
    throw new Error(`apple_status_${response.status}`);
  }
  return appleStatusEntitlement(response.payload, accountToken);
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
    googleEnabled: config.enabled === true && config.googleEnabled === true,
  };
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
    if (/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
        .test(existing)) {
      return existing.toLowerCase();
    }
    const token = crypto.randomUUID().toLowerCase();
    transaction.set(ref, {
      ownerUid: uid,
      storeAccountToken: token,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
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
}) {
  const providerRef = db.collection("native_membership_provider_state").doc(uid);
  const dispatchRef = db.collection("dispatch_memberships").doc(uid);
  const vipRef = db.collection("vip_memberships").doc(uid);
  const userRef = db.collection("users").doc(uid);
  const transitionRef = db.collection("membership_plan_transitions").doc(uid);
  const Timestamp = admin.firestore.Timestamp;
  const FieldValue = admin.firestore.FieldValue;
  const end = Timestamp.fromMillis(entitlement.expiresAtMillis);
  const subscriptionKey = providerSubscriptionKey(entitlement, purchaseToken);

  await db.runTransaction(async (transaction) => {
    const [dispatchSnapshot, vipSnapshot, providerSnapshot] = await Promise.all([
      transaction.get(dispatchRef),
      transaction.get(vipRef),
      transaction.get(providerRef),
    ]);
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
  });
}

async function clearExpiredNativeEntitlement({db, admin, uid, providerState}) {
  const provider = String(providerState && providerState.provider || "");
  const planId = String(providerState && providerState.planId || "");
  const providerRef = db.collection("native_membership_provider_state").doc(uid);
  const dispatchRef = db.collection("dispatch_memberships").doc(uid);
  const vipRef = db.collection("vip_memberships").doc(uid);
  const userRef = db.collection("users").doc(uid);
  const FieldValue = admin.firestore.FieldValue;
  await db.runTransaction(async (transaction) => {
    const [dispatchSnapshot, vipSnapshot] = await Promise.all([
      transaction.get(dispatchRef),
      transaction.get(vipRef),
    ]);
    transaction.set(providerRef, {
      active: false,
      status: "expired",
      lastVerifiedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    if (planId.startsWith("dispatch_") && dispatchSnapshot.exists &&
        dispatchSnapshot.data().billingProvider === provider) {
      transaction.set(dispatchRef, {
        active: false,
        status: "expired",
        renewalStatus: "expired",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
    if (planId === "vip_monthly" && vipSnapshot.exists &&
        vipSnapshot.data().billingProvider === provider) {
      transaction.set(vipRef, {
        active: false,
        status: "expired",
        renewalStatus: "expired",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      transaction.set(userRef, {
        vipActive: false,
        vipStatus: "expired",
        vipUpdatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }
  });
}

function createNativeMembershipBilling(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  const getNativeMembershipBillingStatus = async (request) => {
    try {
      const identity = requireAuthenticatedIdentity(request, {requirePhone: false});
      await enforceUserRateLimit({db, admin, request, scope: "account"});
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
        googleEnabled: readiness.googleEnabled,
        bundleId: APPLE_BUNDLE_ID,
        packageName: GOOGLE_PACKAGE_NAME,
        productIds: Object.keys(NATIVE_MEMBERSHIP_PRODUCTS),
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

  const verifyNativeMembershipPurchase = async (request) => {
    try {
      const identity = requireAuthenticatedIdentity(request, {requirePhone: false});
      await enforceUserRateLimit({db, admin, request, scope: "account"});
      const platform = normalizeNativePlatform(request.data && request.data.platform);
      const product = nativeMembershipProduct(request.data && request.data.productId);
      if (!platform || !product) {
        throw new HttpsError("invalid-argument", "The mobile membership purchase is invalid.");
      }
      const readiness = await loadNativeBillingReadiness(db);
      if (!readiness.enabled ||
          (platform === "ios" && !readiness.appleEnabled) ||
          (platform === "android" && !readiness.googleEnabled)) {
        throw new HttpsError(
            "failed-precondition",
            "Mobile membership purchasing is not enabled yet.",
        );
      }
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
        entitlement = await appleCurrentEntitlement({
          transactionId: purchaseId,
          accountToken,
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

      const requestedProductMatches = entitlement.productId === product.productId ||
        entitlement.pendingProductId === product.productId;
      if (!requestedProductMatches) {
        throw new HttpsError(
            "failed-precondition",
            "The verified store product does not match the requested membership plan.",
        );
      }
      await applyNativeEntitlement({
        db,
        admin,
        uid: identity.uid,
        accountToken,
        entitlement,
        purchaseToken,
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

  const reconcileNativeMembershipSubscriptions = async () => {
    const readiness = await loadNativeBillingReadiness(db);
    if (!readiness.enabled) return {checked: 0, updated: 0, failed: 0};
    const snapshot = await db.collection("native_membership_provider_state")
        .where("active", "==", true)
        .limit(NATIVE_RECONCILIATION_LIMIT)
        .get();
    let updated = 0;
    let failed = 0;
    for (const document of snapshot.docs) {
      const state = document.data();
      const uid = document.id;
      try {
        const accountToken = String(state.storeAccountToken || "");
        let entitlement = null;
        let purchaseToken = "";
        if (state.provider === "app_store" && readiness.appleEnabled) {
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
          continue;
        }
        if (!entitlement) {
          await clearExpiredNativeEntitlement({db, admin, uid, providerState: state});
        } else {
          await applyNativeEntitlement({
            db,
            admin,
            uid,
            accountToken,
            entitlement,
            purchaseToken,
          });
        }
        updated += 1;
      } catch (error) {
        failed += 1;
        await document.ref.set({
          lastReconciliationErrorAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        console.error("Native membership reconciliation attempt failed", {
          provider: String(state.provider || "").slice(0, 30),
          code: String(error && error.code || "").slice(0, 80),
        });
      }
    }
    return {checked: snapshot.size, updated, failed};
  };

  return {
    getNativeMembershipBillingStatus,
    reconcileNativeMembershipSubscriptions,
    verifyNativeMembershipPurchase,
  };
}

module.exports = {
  APPLE_PRODUCTION_BASE,
  APPLE_SANDBOX_BASE,
  GOOGLE_ANDROID_PUBLISHER_SCOPE,
  NATIVE_RECONCILIATION_LIMIT,
  appleAuthorizationToken,
  appleIapIssuerId,
  appleIapKeyId,
  appleIapPrivateKey,
  createNativeMembershipBilling,
  googlePlayServiceAccountJson,
  nativeBillingReadiness,
  nativeMembershipSecretNames,
  nativeProviderCurrent,
  providerSubscriptionKey,
  stripeProviderBlocksNativePurchase,
};
