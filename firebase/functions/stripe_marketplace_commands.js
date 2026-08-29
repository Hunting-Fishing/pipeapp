"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {
  loadPhase1FeatureFlags,
  requirePhase1Feature,
} = require("./phase1_feature_flags");
const {stripeMarketplaceConfig} = require("./stripe_marketplace_config");

const STRIPE_SECRET_PRODUCTION_NAME = "STRIPE_SECRET_PRODUCTION";
const STRIPE_CONNECT_ACCOUNTS_API_VERSION =
  stripeMarketplaceConfig.connectAccountsApiVersion;
const stripeSecretKey = Object.freeze({
  name: STRIPE_SECRET_PRODUCTION_NAME,
  value() {
    const value = String(process.env[STRIPE_SECRET_PRODUCTION_NAME] || "").trim();
    if (!value) {
      throw new HttpsError(
          "failed-precondition",
          "Stripe production payment credentials are unavailable.",
      );
    }
    return value;
  },
});

const initialSellerCountries = new Set(["CA", "US"]);
const sellerSetupErrorMessages = Object.freeze({
  account_create_activation_required:
    "Pipe Buyer must finish Stripe Connect activation before seller payouts can be set up.",
  account_creation_liability_unacknowledged:
    "Pipe Buyer must acknowledge the Stripe Connect liability settings before seller payouts can be set up.",
  account_creation_requirement_collection_and_liability_unacknowledged:
    "Pipe Buyer must finish the Stripe Connect responsibility acknowledgements before seller payouts can be set up.",
  account_creation_requirement_collection_unacknowledged:
    "Pipe Buyer must finish the Stripe Connect requirement-collection setup before seller payouts can be set up.",
  connect_identity_not_verified:
    "Pipe Buyer's Stripe platform verification must be completed before seller payouts can be set up.",
  connect_profile_not_submitted:
    "Pipe Buyer must complete the Stripe Connect platform profile before seller payouts can be set up.",
  platform_registration_required:
    "Pipe Buyer must activate Stripe Connect before seller payouts can be set up.",
  cross_border_connected_account_creation_not_allowed:
    "Stripe does not currently allow this seller country for Pipe Buyer payouts.",
});

function requireAuth(request) {
  return requireAuthenticatedIdentity(request, {requirePhone: false}).uid;
}

function safeCountry(value) {
  const country = String(value || "CA").trim().toUpperCase();
  if (!initialSellerCountries.has(country)) {
    throw new HttpsError(
        "failed-precondition",
        "Seller payouts are currently prepared only for Canada and the United States.",
    );
  }
  return country;
}

function safePipeBuyerCallbackUrl(value, field) {
  let url;
  try {
    url = new URL(String(value || ""));
  } catch (_) {
    throw new HttpsError("failed-precondition", `${field} is not configured.`);
  }
  const host = url.hostname.toLowerCase();
  if (url.protocol !== "https:" ||
      !(host === "pipebuyer.com" || host.endsWith(".pipebuyer.com"))) {
    throw new HttpsError(
        "failed-precondition",
        `${field} must use an HTTPS pipebuyer.com address.`,
    );
  }
  return url.toString();
}

function sanitizeStripeSupportText(value, maxLength = 120) {
  const limit = Math.max(1, Math.min(Number(maxLength) || 120, 180));
  return String(value || "")
      .replace(/https?:\/\/\S+/gi, "[link]")
      .replace(
          /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi,
          "[redacted]",
      )
      .replace(/[\r\n\t]+/g, " ")
      .replace(/\s{2,}/g, " ")
      .trim()
      .slice(0, limit);
}

function sanitizeStripeSupportToken(value, maxLength = 120) {
  const limit = Math.max(1, Math.min(Number(maxLength) || 120, 180));
  return String(value || "")
      .trim()
      .replace(/[^A-Za-z0-9_.\-\[\]]+/g, "_")
      .slice(0, limit);
}

function stripeSellerSetupErrorMessage(stripeCode, diagnostics = {}) {
  const code = String(stripeCode || "").trim().toLowerCase().slice(0, 120);
  const knownMessage = sellerSetupErrorMessages[code];
  if (knownMessage) return knownMessage;
  if (code === "capability_not_available_without_other_capability") {
    const explanation = sanitizeStripeSupportText(
        diagnostics.stripeMessage,
        120,
    );
    const requestId = sanitizeStripeSupportToken(
        diagnostics.stripeRequestId,
        40,
    );
    const detail = explanation || code;
    return `Stripe capability dependency: ${detail}.` +
      (requestId ? ` Request ${requestId}.` : "");
  }
  if (code === "invalid_request_error") {
    const explanation = sanitizeStripeSupportText(
        diagnostics.stripeMessage,
        120,
    );
    const param = sanitizeStripeSupportToken(
        diagnostics.stripeParam,
        80,
    );
    const requestId = sanitizeStripeSupportToken(
        diagnostics.stripeRequestId,
        40,
    );
    return `Stripe rejected the seller payout setup: ${explanation || code}.` +
      (param ? ` Parameter ${param}.` : "") +
      (requestId ? ` Request ${requestId}.` : "");
  }
  if (code) {
    return `Stripe rejected the seller payout setup. Contact Pipe Buyer support with reference ${code}.`;
  }
  return "Stripe could not complete the seller payout setup. Try again or contact support.";
}

function stripeFormBody(fields) {
  const form = new URLSearchParams();
  for (const [key, value] of Object.entries(fields || {})) {
    if (value == null) continue;
    form.append(key, String(value));
  }
  return form.toString();
}

async function stripeConnectRequest({
  secretKey,
  path,
  method = "POST",
  fields,
}) {
  const headers = {
    Authorization: `Bearer ${secretKey}`,
    "Stripe-Version": STRIPE_CONNECT_ACCOUNTS_API_VERSION,
  };
  const hasBody = fields != null && method !== "GET";
  if (hasBody) {
    headers["Content-Type"] = "application/x-www-form-urlencoded";
  }
  const response = await fetch(`https://api.stripe.com${path}`, {
    method,
    headers,
    ...(hasBody ? {body: stripeFormBody(fields)} : {}),
  });
  let payload = null;
  try {
    payload = await response.json();
  } catch (_) {
    payload = null;
  }
  if (!response.ok) {
    const stripeError = payload && payload.error || {};
    const stripeCode = sanitizeStripeSupportToken(
        stripeError.code || stripeError.type,
        120,
    ).toLowerCase();
    const stripeMessage = sanitizeStripeSupportText(stripeError.message, 120);
    const stripeParam = sanitizeStripeSupportToken(stripeError.param, 120);
    const stripeRequestId = sanitizeStripeSupportToken(
        response.headers.get("request-id"),
        120,
    );
    console.error("Stripe marketplace request failed", {
      path,
      status: response.status,
      stripeCode,
      stripeMessage,
      stripeParam,
      stripeRequestId,
    });
    throw new HttpsError(
        response.status === 429 ? "resource-exhausted" : "failed-precondition",
        stripeSellerSetupErrorMessage(stripeCode, {
          stripeMessage,
          stripeParam,
          stripeRequestId,
        }),
        {
          provider: "stripe",
          stripeCode: stripeCode || "unknown",
          stripeMessage: stripeMessage || null,
          stripeParam: stripeParam || null,
          stripeRequestId: stripeRequestId || null,
          httpStatus: response.status,
        },
    );
  }
  return payload || {};
}

async function loadProviderReadiness(db) {
  const snapshot = await db.collection("platform_configuration")
      .doc("payment_provider_readiness").get();
  const data = snapshot.exists ? snapshot.data() : {};
  return {
    stripeMode: String(data.stripeMode || "disabled"),
    stripeConnectOnboardingEnabled: data.stripeConnectOnboardingEnabled === true,
    stripeCheckoutEnabled: data.stripeCheckoutEnabled === true,
    stripeWebhookVerified: data.stripeWebhookVerified === true,
    stripeTaxReady: data.stripeTaxReady === true,
    marketplaceTaxCollectionDeferredApproved:
      data.marketplaceTaxCollectionDeferredApproved === true,
    stripeReconciliationReady: data.stripeReconciliationReady === true,
    connectReturnUrl: String(data.connectReturnUrl || ""),
    connectRefreshUrl: String(data.connectRefreshUrl || ""),
  };
}

function requireConnectOnboardingReady(readiness) {
  if (!readiness.stripeConnectOnboardingEnabled ||
      readiness.stripeMode !== "production") {
    throw new HttpsError(
        "failed-precondition",
        "Live Stripe seller payout onboarding is not enabled yet.",
    );
  }
}

function recipientTransferStatus(account) {
  return String(
      account && account.capabilities && account.capabilities.transfers ||
      "pending",
  );
}

function sellerPayoutReady(account) {
  return recipientTransferStatus(account) === "active" &&
    account && account.payouts_enabled === true;
}

function createStripeMarketplaceCommands(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  async function ensureStripeSellerAccountInternal(request, uid, readiness) {
    const providerRef = db.collection("payment_provider_accounts").doc(uid);
    const existing = await providerRef.get();
    if (existing.exists && existing.data().stripeAccountId) {
      return {
        accountId: String(existing.data().stripeAccountId),
        country: String(existing.data().country || "CA"),
        created: false,
      };
    }

    const flags = await loadPhase1FeatureFlags(db);
    requirePhase1Feature(flags, "marketplace");
    const country = safeCountry(request.data && request.data.country);
    const contactEmail = String(
        request.auth && request.auth.token && request.auth.token.email || "",
    ).trim().slice(0, 320);
    if (!contactEmail) {
      throw new HttpsError(
          "failed-precondition",
          "Add and verify an email address before setting up seller payouts.",
      );
    }

    const account = await stripeConnectRequest({
      secretKey: stripeSecretKey.value(),
      path: "/v1/accounts",
      fields: {
        email: contactEmail,
        country,
        type: "express",
      },
    });
    const accountId = String(account.id || "").trim();
    if (!accountId.startsWith("acct_")) {
      throw new HttpsError(
          "internal",
          "Stripe returned an invalid seller account identifier.",
      );
    }
    await providerRef.create({
      uid,
      provider: "stripe",
      stripeAccountId: accountId,
      accountPurpose: "marketplace_recipient",
      country,
      mode: readiness.stripeMode,
      dashboard: "express",
      capabilityConfigurationSource: "stripe_connect_configuration",
      transferStatus: recipientTransferStatus(account),
      onboardingStatus: "created",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return {accountId, country, created: true};
  }

  const ensureStripeSellerAccount = async (request) => {
    try {
      const uid = requireAuth(request);
      await enforceUserRateLimit({db, admin, request, scope: "account"});
      const readiness = await loadProviderReadiness(db);
      requireConnectOnboardingReady(readiness);
      return await ensureStripeSellerAccountInternal(request, uid, readiness);
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Stripe seller account setup failed", error);
      throw new HttpsError(
          "internal",
          "Seller payout setup could not be completed.",
      );
    }
  };

  const createStripeSellerOnboardingLink = async (request) => {
    try {
      const uid = requireAuth(request);
      await enforceUserRateLimit({db, admin, request, scope: "account"});
      const readiness = await loadProviderReadiness(db);
      requireConnectOnboardingReady(readiness);
      const seller = await ensureStripeSellerAccountInternal(
          request,
          uid,
          readiness,
      );
      const returnUrl = safePipeBuyerCallbackUrl(
          readiness.connectReturnUrl,
          "Stripe Connect return URL",
      );
      const refreshUrl = safePipeBuyerCallbackUrl(
          readiness.connectRefreshUrl,
          "Stripe Connect refresh URL",
      );
      const accountLink = await stripeConnectRequest({
        secretKey: stripeSecretKey.value(),
        path: "/v1/account_links",
        fields: {
          account: seller.accountId,
          refresh_url: refreshUrl,
          return_url: returnUrl,
          type: "account_onboarding",
          "collection_options[fields]": "eventually_due",
          "collection_options[future_requirements]": "include",
        },
      });
      const url = String(accountLink.url || "");
      if (!url.startsWith("https://")) {
        throw new HttpsError("internal", "Stripe did not return an onboarding link.");
      }
      await db.collection("payment_provider_accounts").doc(uid).set({
        onboardingStatus: "link_created",
        onboardingLinkExpiresAt: accountLink.expires_at || null,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      // Account links are single-use and grant access to private onboarding data.
      // Return the URL only to this authenticated caller; never persist the URL.
      return {
        accountId: seller.accountId,
        onboardingUrl: url,
        expiresAt: accountLink.expires_at || null,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Stripe seller onboarding link failed", error);
      throw new HttpsError(
          "internal",
          "Seller payout onboarding could not be started.",
      );
    }
  };

  const refreshStripeSellerStatus = async (request) => {
    try {
      const uid = requireAuth(request);
      await enforceUserRateLimit({db, admin, request, scope: "account"});
      const readiness = await loadProviderReadiness(db);
      requireConnectOnboardingReady(readiness);
      const providerRef = db.collection("payment_provider_accounts").doc(uid);
      const providerSnapshot = await providerRef.get();
      if (!providerSnapshot.exists || !providerSnapshot.data().stripeAccountId) {
        throw new HttpsError(
            "failed-precondition",
            "Set up seller payouts before checking payout status.",
        );
      }
      const accountId = String(providerSnapshot.data().stripeAccountId);
      const account = await stripeConnectRequest({
        secretKey: stripeSecretKey.value(),
        path: `/v1/accounts/${encodeURIComponent(accountId)}`,
        method: "GET",
      });
      const transferStatus = recipientTransferStatus(account);
      const payoutReady = sellerPayoutReady(account);
      const onboardingStatus = payoutReady ? "payout_ready" : "pending";
      await providerRef.set({
        transferStatus,
        onboardingStatus,
        payoutsEnabled: account.payouts_enabled === true,
        detailsSubmitted: account.details_submitted === true,
        lastStripeStatusCheckAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {
        accountId,
        transferStatus,
        payoutReady,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Stripe seller status refresh failed", error);
      throw new HttpsError(
          "internal",
          "Seller payout status could not be refreshed.",
      );
    }
  };

  return {
    createStripeSellerOnboardingLink,
    ensureStripeSellerAccount,
    refreshStripeSellerStatus,
  };
}

module.exports = {
  STRIPE_CONNECT_ACCOUNTS_API_VERSION,
  STRIPE_SECRET_PRODUCTION_NAME,
  createStripeMarketplaceCommands,
  loadProviderReadiness,
  recipientTransferStatus,
  safePipeBuyerCallbackUrl,
  sanitizeStripeSupportText,
  sellerPayoutReady,
  stripeFormBody,
  stripeSellerSetupErrorMessage,
  stripeSecretKey,
};