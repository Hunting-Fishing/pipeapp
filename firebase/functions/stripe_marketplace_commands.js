"use strict";

const crypto = require("node:crypto");
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
const {
  STRIPE_SECRET_PRODUCTION_NAME,
  normalizeActiveStripeMode,
  requireStripeProviderMode,
  stripeProductionSecret,
  stripeSecretValueForMode,
} = require("./stripe_runtime_environment");

const STRIPE_CONNECT_ACCOUNTS_API_VERSION =
  stripeMarketplaceConfig.connectAccountsApiVersion;
const STRIPE_CONNECT_ACCOUNT_OBJECT =
  stripeMarketplaceConfig.connectAccountObject;
const STRIPE_CONNECT_ACCOUNT_API_FAMILY = "v2";
const stripeSecretKey = stripeProductionSecret;

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
  accounts_v2_access_blocked:
    "Pipe Buyer must enable Stripe Accounts v2 before seller payouts can be set up.",
  non_connect_platform_accounts_v2_access_blocked:
    "Pipe Buyer must finish Stripe Connect activation for Accounts v2 before seller payouts can be set up.",
  v1_account_instead_of_v2_account:
    "This seller payout account uses Stripe's legacy account model and must be migrated before marketplace payments can continue.",
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
  query,
  idempotencyKey,
  stripeContext,
}) {
  const requestUrl = new URL(`https://api.stripe.com${path}`);
  for (const [key, value] of Object.entries(query || {})) {
    if (Array.isArray(value)) {
      value.forEach((item, index) => {
        requestUrl.searchParams.append(`${key}[${index}]`, String(item));
      });
    } else if (value != null) {
      requestUrl.searchParams.append(key, String(value));
    }
  }
  const accountsV2Request = requestUrl.pathname.startsWith("/v2/");
  const headers = {
    Authorization: `Bearer ${secretKey}`,
    "Stripe-Version": STRIPE_CONNECT_ACCOUNTS_API_VERSION,
    ...(idempotencyKey ? {"Idempotency-Key": idempotencyKey} : {}),
    ...(stripeContext ? {"Stripe-Context": stripeContext} : {}),
  };
  const hasBody = fields != null && method !== "GET";
  if (hasBody) {
    headers["Content-Type"] = accountsV2Request ?
      "application/json" : "application/x-www-form-urlencoded";
  }
  const response = await fetch(requestUrl, {
    method,
    headers,
    ...(hasBody ? {
      body: accountsV2Request ?
        JSON.stringify(fields) : stripeFormBody(fields),
    } : {}),
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
      path: requestUrl.pathname,
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

function stripeSellerAccountIdempotencyKey(uid) {
  const identity = String(uid || "").trim();
  if (!identity || identity.length > 180 || identity.includes("/")) {
    throw new HttpsError(
        "invalid-argument",
        "The seller payout identity is invalid.",
    );
  }
  const digest = crypto.createHash("sha256")
      .update(`pipebuyer-stripe-recipient-v2:${identity}`)
      .digest("hex");
  return `pipebuyer-recipient-v2-${digest}`;
}

function stripeV2RecipientAccountPayload({contactEmail, country, uid}) {
  return {
    contact_email: String(contactEmail || "").trim().slice(0, 320),
    dashboard: "express",
    identity: {
      country: safeCountry(country).toLowerCase(),
    },
    configuration: {
      recipient: {
        capabilities: {
          stripe_balance: {
            stripe_transfers: {requested: true},
          },
        },
      },
    },
    defaults: {
      responsibilities: {
        fees_collector: "application",
        losses_collector: "application",
      },
    },
    metadata: {
      pipeBuyerUid: String(uid || "").trim().slice(0, 180),
      pipeBuyerPurpose: "marketplace_recipient",
    },
    include: [
      "configuration.recipient",
      "defaults",
      "identity",
      "requirements",
    ],
  };
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
    stripeFullGmvEconomicsApproved:
      data.stripeFullGmvEconomicsApproved === true,
    stripeFullGmvEconomicsPolicyRevision: String(
        data.stripeFullGmvEconomicsPolicyRevision || "",
    ),
    stripeFullGmvPaymentMethodConfigurationId: String(
        data.stripeFullGmvPaymentMethodConfigurationId || "",
    ),
    stripeFullGmvMaximumChargeMinorUsd: Number(
        data.stripeFullGmvMaximumChargeMinorUsd || 0,
    ),
    stripeFullGmvMaximumProviderFeeBps: Number(
        data.stripeFullGmvMaximumProviderFeeBps || 0,
    ),
    stripeFullGmvMaximumProviderFeeFixedMinorUsd: Number(
        data.stripeFullGmvMaximumProviderFeeFixedMinorUsd || 0,
    ),
    stripeFullGmvMaximumTaxUpliftBps: Number(
        data.stripeFullGmvMaximumTaxUpliftBps || 0,
    ),
    stripeFullGmvMinimumNetRevenueMinorUsd: Number(
        data.stripeFullGmvMinimumNetRevenueMinorUsd || 0,
    ),
    connectReturnUrl: String(data.connectReturnUrl || ""),
    connectRefreshUrl: String(data.connectRefreshUrl || ""),
  };
}

function requireConnectOnboardingReady(readiness) {
  if (!readiness.stripeConnectOnboardingEnabled) {
    throw new HttpsError(
        "failed-precondition",
        "Stripe seller payout onboarding is not enabled yet.",
    );
  }
  normalizeActiveStripeMode(readiness.stripeMode);
}

function recipientTransferStatus(account) {
  return String(account && account.configuration &&
    account.configuration.recipient &&
    account.configuration.recipient.capabilities &&
    account.configuration.recipient.capabilities.stripe_balance &&
    account.configuration.recipient.capabilities.stripe_balance
        .stripe_transfers &&
    account.configuration.recipient.capabilities.stripe_balance
        .stripe_transfers.status || "pending");
}

function recipientPayoutStatus(account) {
  return String(account && account.configuration &&
    account.configuration.recipient &&
    account.configuration.recipient.capabilities &&
    account.configuration.recipient.capabilities.stripe_balance &&
    account.configuration.recipient.capabilities.stripe_balance.payouts &&
    account.configuration.recipient.capabilities.stripe_balance
        .payouts.status || "pending");
}

function stripeAccountMode(account) {
  if (account && account.livemode === true) return "production";
  if (account && account.livemode === false) return "sandbox";
  return "unknown";
}

function recipientAccountReadiness(account) {
  const safeAccount = account && typeof account === "object" ? account : {};
  const responsibilities = safeAccount.defaults &&
    safeAccount.defaults.responsibilities || {};
  const appliedConfigurations = Array.isArray(
      safeAccount.applied_configurations,
  ) ? safeAccount.applied_configurations : [];
  const transferStatus = recipientTransferStatus(safeAccount);
  const payoutStatus = recipientPayoutStatus(safeAccount);
  const accountMode = stripeAccountMode(safeAccount);
  const recipientConfigurationReady =
    safeAccount.object === STRIPE_CONNECT_ACCOUNT_OBJECT &&
    appliedConfigurations.includes("recipient") &&
    safeAccount.dashboard === "express" &&
    responsibilities.fees_collector === "application" &&
    responsibilities.losses_collector === "application";
  return {
    accountObject: String(safeAccount.object || ""),
    dashboard: String(safeAccount.dashboard || ""),
    feesCollector: String(responsibilities.fees_collector || ""),
    lossesCollector: String(responsibilities.losses_collector || ""),
    appliedConfigurations,
    accountMode,
    transferStatus,
    payoutStatus,
    recipientConfigurationReady,
    payoutReady: recipientConfigurationReady &&
      transferStatus === "active" &&
      payoutStatus === "active",
  };
}

function sellerPayoutReady(account) {
  return recipientAccountReadiness(account).payoutReady;
}

function providerUsesAccountsV2(provider) {
  const safeProvider = provider && typeof provider === "object" ? provider : {};
  return safeProvider.connectAccountApiVersion ===
      STRIPE_CONNECT_ACCOUNT_API_FAMILY &&
    safeProvider.connectAccountObject === STRIPE_CONNECT_ACCOUNT_OBJECT;
}

async function refreshStripeRecipientAccountStatus({
  providerRef,
  providerData,
  FieldValue,
  secretKey,
  expectedMode,
  stripeContext,
  requestFn = stripeConnectRequest,
}) {
  const provider = providerData && typeof providerData === "object" ?
    providerData : {};
  const accountId = String(provider.stripeAccountId || "").trim();
  if (!accountId.startsWith("acct_")) {
    throw new HttpsError(
        "failed-precondition",
        "Set up seller payouts before checking payout status.",
    );
  }
  if (!providerUsesAccountsV2(provider)) {
    throw new HttpsError(
        "failed-precondition",
        "This seller payout account uses Stripe's legacy account model and must be migrated before marketplace payments can continue.",
    );
  }
  const account = await requestFn({
    secretKey,
    path: `/v2/core/accounts/${encodeURIComponent(accountId)}`,
    method: "GET",
    query: {
      include: [
        "configuration.recipient",
        "defaults",
        "requirements",
      ],
    },
    ...(stripeContext ? {stripeContext} : {}),
  });
  if (String(account.id || "") !== accountId) {
    throw new HttpsError(
        "failed-precondition",
        "Stripe returned a different seller payout account.",
    );
  }
  const accountMode = stripeAccountMode(account);
  if (expectedMode && accountMode !== String(expectedMode)) {
    throw new HttpsError(
        "failed-precondition",
        "Stripe returned a seller payout account from a different environment.",
    );
  }
  const readiness = recipientAccountReadiness(account);
  const statusCheckId = crypto.randomUUID();
  await providerRef.set({
    connectAccountApiVersion: STRIPE_CONNECT_ACCOUNT_API_FAMILY,
    connectAccountObject: readiness.accountObject,
    dashboard: readiness.dashboard,
    feesCollector: readiness.feesCollector,
    lossesCollector: readiness.lossesCollector,
    appliedConfigurations: readiness.appliedConfigurations,
    transferStatus: readiness.transferStatus,
    payoutStatus: readiness.payoutStatus,
    recipientConfigurationReady: readiness.recipientConfigurationReady,
    payoutReady: readiness.payoutReady,
    onboardingStatus: readiness.payoutReady ? "payout_ready" : "pending",
    migrationRequired: false,
    lastStripeStatusCheckId: statusCheckId,
    lastStripeStatusCheckAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  return {
    accountId,
    statusCheckId,
    ...readiness,
  };
}

function createStripeMarketplaceCommands(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  async function ensureStripeSellerAccountInternal(request, uid, readiness) {
    const providerRef = db.collection("payment_provider_accounts").doc(uid);
    const existing = await providerRef.get();
    if (existing.exists && existing.data().stripeAccountId) {
      const existingData = existing.data();
      if (!providerUsesAccountsV2(existingData)) {
        await providerRef.set({
          migrationRequired: true,
          recipientConfigurationReady: false,
          payoutReady: false,
          transferStatus: "legacy_migration_required",
          payoutStatus: "legacy_migration_required",
          onboardingStatus: "migration_required",
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        throw new HttpsError(
            "failed-precondition",
            "This seller payout account uses Stripe's legacy account model and must be migrated before marketplace payments can continue.",
        );
      }
      requireStripeProviderMode(existingData, readiness.stripeMode);
      return {
        accountId: String(existingData.stripeAccountId),
        country: String(existingData.country || "CA"),
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
      secretKey: stripeSecretValueForMode(readiness.stripeMode),
      path: "/v2/core/accounts",
      fields: stripeV2RecipientAccountPayload({contactEmail, country, uid}),
      idempotencyKey: stripeSellerAccountIdempotencyKey(uid),
    });
    const accountId = String(account.id || "").trim();
    if (!accountId.startsWith("acct_")) {
      throw new HttpsError(
          "internal",
          "Stripe returned an invalid seller account identifier.",
      );
    }
    const accountReadiness = recipientAccountReadiness(account);
    if (accountReadiness.accountMode !== readiness.stripeMode) {
      throw new HttpsError(
          "failed-precondition",
          "Stripe returned a seller payout account from a different environment.",
      );
    }
    if (!accountReadiness.recipientConfigurationReady) {
      throw new HttpsError(
          "failed-precondition",
          "Stripe did not apply the required recipient, Express dashboard, fee collection, and negative balance liability configuration.",
      );
    }
    await providerRef.create({
      uid,
      provider: "stripe",
      stripeAccountId: accountId,
      accountPurpose: "marketplace_recipient",
      country,
      mode: readiness.stripeMode,
      connectAccountApiVersion: STRIPE_CONNECT_ACCOUNT_API_FAMILY,
      connectAccountObject: accountReadiness.accountObject,
      dashboard: accountReadiness.dashboard,
      feesCollector: accountReadiness.feesCollector,
      lossesCollector: accountReadiness.lossesCollector,
      appliedConfigurations: accountReadiness.appliedConfigurations,
      capabilityConfigurationSource: "accounts_v2_recipient",
      transferStatus: accountReadiness.transferStatus,
      payoutStatus: accountReadiness.payoutStatus,
      recipientConfigurationReady:
        accountReadiness.recipientConfigurationReady,
      payoutReady: accountReadiness.payoutReady,
      migrationRequired: false,
      onboardingStatus: accountReadiness.payoutReady ?
        "payout_ready" : "created",
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
        secretKey: stripeSecretValueForMode(readiness.stripeMode),
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
      requireStripeProviderMode(providerSnapshot.data(), readiness.stripeMode);
      const status = await refreshStripeRecipientAccountStatus({
        providerRef,
        providerData: providerSnapshot.data(),
        FieldValue,
        secretKey: stripeSecretValueForMode(readiness.stripeMode),
        expectedMode: readiness.stripeMode,
      });
      return {
        accountId,
        transferStatus: status.transferStatus,
        payoutStatus: status.payoutStatus,
        payoutReady: status.payoutReady,
        recipientConfigurationReady: status.recipientConfigurationReady,
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
  STRIPE_CONNECT_ACCOUNT_API_FAMILY,
  STRIPE_CONNECT_ACCOUNT_OBJECT,
  STRIPE_CONNECT_ACCOUNTS_API_VERSION,
  STRIPE_SECRET_PRODUCTION_NAME,
  createStripeMarketplaceCommands,
  loadProviderReadiness,
  providerUsesAccountsV2,
  recipientAccountReadiness,
  recipientPayoutStatus,
  recipientTransferStatus,
  refreshStripeRecipientAccountStatus,
  safePipeBuyerCallbackUrl,
  sanitizeStripeSupportText,
  sellerPayoutReady,
  stripeAccountMode,
  stripeConnectRequest,
  stripeFormBody,
  stripeSellerAccountIdempotencyKey,
  stripeSellerSetupErrorMessage,
  stripeSecretKey,
  stripeV2RecipientAccountPayload,
};
