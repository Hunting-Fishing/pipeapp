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

function stripeSellerSetupErrorMessage(stripeCode) {
  const code = String(stripeCode || "").trim().toLowerCase().slice(0, 120);
  const knownMessage = sellerSetupErrorMessages[code];
  if (knownMessage) return knownMessage;
  if (code) {
    return `Stripe rejected the seller payout setup. Contact Pipe Buyer support with reference ${code}.`;
  }
  return "Stripe could not complete the seller payout setup. Try again or contact support.";
}

async function stripeRequest({secretKey, path, method = "POST", body, query}) {
  const url = new URL(`https://api.stripe.com${path}`);
  for (const [key, value] of Object.entries(query || {})) {
    if (Array.isArray(value)) {
      for (const item of value) url.searchParams.append(`${key}[]`, String(item));
    } else if (value != null) {
      url.searchParams.set(key, String(value));
    }
  }
  const response = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${secretKey}`,
      "Content-Type": "application/json",
      "Stripe-Version": STRIPE_CONNECT_ACCOUNTS_API_VERSION,
    },
    ...(body == null ? {} : {body: JSON.stringify(body)}),
  });
  let payload = null;
  try {
    payload = await response.json();
  } catch (_) {
    payload = null;
  }
  if (!response.ok) {
    const stripeCode = String(
        payload && payload.error && (payload.error.code || payload.error.type) || "",
    ).slice(0, 120);
    const stripeRequestId = String(response.headers.get("request-id") || "")
        .slice(0, 120);
    console.error("Stripe marketplace request failed", {
      path,
      status: response.status,
      stripeCode,
      stripeRequestId,
    });
    throw new HttpsError(
        response.status === 429 ? "resource-exhausted" : "failed-precondition",
        stripeSellerSetupErrorMessage(stripeCode),
        {
          provider: "stripe",
          stripeCode: stripeCode || "unknown",
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
      account && account.configuration && account.configuration.recipient &&
      account.configuration.recipient.capabilities &&
      account.configuration.recipient.capabilities.stripe_balance &&
      account.configuration.recipient.capabilities.stripe_balance
          .stripe_transfers &&
      account.configuration.recipient.capabilities.stripe_balance
          .stripe_transfers.status || "pending",
  );
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
    const [userSnapshot, businessSnapshot] = await Promise.all([
      db.collection("users").doc(uid).get(),
      db.collection("public_business_profiles").doc(uid).get(),
    ]);
    const user = userSnapshot.data() || {};
    const business = businessSnapshot.data() || {};
    const displayName = String(
        user.accountType === "business" ?
          business.publicName || user.businessName || "Pipe Buyer seller" :
          user.display_name || user.displayName || user.fullName || "Pipe Buyer seller",
    ).trim().slice(0, 200);
    const contactEmail = String(
        request.auth && request.auth.token && request.auth.token.email || "",
    ).trim().slice(0, 320);
    if (!contactEmail) {
      throw new HttpsError(
          "failed-precondition",
          "Add and verify an email address before setting up seller payouts.",
      );
    }

    const account = await stripeRequest({
      secretKey: stripeSecretKey.value(),
      path: "/v2/core/accounts",
      body: {
        contact_email: contactEmail,
        display_name: displayName,
        defaults: {
          responsibilities: {
            fees_collector: "application",
            losses_collector: "application",
          },
        },
        dashboard: "express",
        identity: {country: country.toLowerCase()},
        configuration: {
          recipient: {
            capabilities: {
              stripe_balance: {
                stripe_transfers: {requested: true},
              },
            },
          },
        },
        include: [
          "configuration.recipient",
          "identity",
          "requirements",
        ],
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
      feesCollector: "application",
      lossesCollector: "application",
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
      const accountLink = await stripeRequest({
        secretKey: stripeSecretKey.value(),
        path: "/v2/core/account_links",
        body: {
          account: seller.accountId,
          use_case: {
            type: "account_onboarding",
            account_onboarding: {
              configurations: ["recipient"],
              return_url: returnUrl,
              refresh_url: refreshUrl,
              collection_options: {
                future_requirements: "include",
              },
            },
          },
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
      const account = await stripeRequest({
        secretKey: stripeSecretKey.value(),
        path: `/v2/core/accounts/${encodeURIComponent(accountId)}`,
        method: "GET",
        query: {
          include: [
            "configuration.recipient",
            "identity",
            "requirements",
          ],
        },
      });
      const transferStatus = recipientTransferStatus(account);
      const onboardingStatus = transferStatus === "active" ? "payout_ready" : "pending";
      await providerRef.set({
        transferStatus,
        onboardingStatus,
        lastStripeStatusCheckAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return {
        accountId,
        transferStatus,
        payoutReady: transferStatus === "active",
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
  safePipeBuyerCallbackUrl,
  stripeSellerSetupErrorMessage,
  stripeSecretKey,
};
