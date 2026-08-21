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
const {
  loadProviderReadiness,
} = require("./stripe_marketplace_commands");
const {stripeMarketplaceConfig} = require("./stripe_marketplace_config");
const {
  taxCollectionStatus,
} = require("./pending_tax_policy");
const {
  requireSubscriptionReady,
} = require("./dispatch_subscription_commands");

function planCatalogEntry(product) {
  const amountMinor = Number(product && product.unitAmountMinor || 0);
  return {
    currency: String(product && product.currency || "CAD").toUpperCase(),
    amountMinor,
    amount: Number((amountMinor / 100).toFixed(2)),
    interval: String(product && product.billingInterval || ""),
  };
}

function dispatchSubscriptionPlanCatalog() {
  return {
    monthly: planCatalogEntry(
        stripeMarketplaceConfig.products.dispatchMonthlyCad,
    ),
    yearly: planCatalogEntry(
        stripeMarketplaceConfig.products.dispatchYearlyCad,
    ),
  };
}

function subscriptionCheckoutReady(readiness, paidFeaturesEnabled) {
  if (paidFeaturesEnabled !== true) return false;
  try {
    requireSubscriptionReady(readiness);
    return true;
  } catch (_) {
    return false;
  }
}

function createDispatchSubscriptionCatalog(admin) {
  const db = admin.firestore();

  const getDispatchSubscriptionCatalog = async (request) => {
    try {
      requireAuthenticatedIdentity(request, {requirePhone: false});
      await enforceUserRateLimit({db, admin, request, scope: "account"});
      const flags = await loadPhase1FeatureFlags(db);
      requirePhase1Feature(flags, "dispatch");
      const readinessSnapshot = await db.collection("platform_configuration")
          .doc("payment_provider_readiness")
          .get();
      const readinessData = readinessSnapshot.exists ? readinessSnapshot.data() : {};
      const readiness = {
        ...(await loadProviderReadiness(db)),
        stripeSubscriptionsEnabled: readinessData.stripeSubscriptionsEnabled === true,
        stripeTaxRegistrationPending:
          readinessData.stripeTaxRegistrationPending === true,
      };
      return {
        plans: dispatchSubscriptionPlanCatalog(),
        checkoutAvailable: subscriptionCheckoutReady(
            readiness,
            flags.paidFeatures,
        ),
        taxCollectionStatus: taxCollectionStatus(readiness),
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Dispatch subscription catalog failed", error);
      throw new HttpsError(
          "internal",
          "Dispatch subscription pricing could not be loaded.",
      );
    }
  };

  return {getDispatchSubscriptionCatalog};
}

module.exports = {
  createDispatchSubscriptionCatalog,
  dispatchSubscriptionPlanCatalog,
  planCatalogEntry,
  subscriptionCheckoutReady,
};
