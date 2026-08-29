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
const {loadProviderReadiness} = require("./stripe_marketplace_commands");
const {stripeMarketplaceConfig} = require("./stripe_marketplace_config");
const {taxCollectionStatus} = require("./pending_tax_policy");
const {requireVipSubscriptionReady} = require("./vip_subscription_commands");
const {currentPolicyAcceptanceStatus} = require("./policy_acceptance_status");

function vipPlanCatalogEntry(product) {
  const amountMinor = Number(product && product.unitAmountMinor || 0);
  return {
    currency: String(product && product.currency || "CAD").toUpperCase(),
    amountMinor,
    amount: Number((amountMinor / 100).toFixed(2)),
    interval: String(product && product.billingInterval || ""),
  };
}

function vipSubscriptionPlanCatalog() {
  return {
    monthly: vipPlanCatalogEntry(stripeMarketplaceConfig.products.vipMonthlyCad),
  };
}

function vipSubscriptionCheckoutReady(readiness, paidFeaturesEnabled) {
  if (paidFeaturesEnabled !== true) return false;
  try {
    requireVipSubscriptionReady(readiness);
    return true;
  } catch (_) {
    return false;
  }
}

function createVipSubscriptionCatalog(admin) {
  const db = admin.firestore();

  const getVipSubscriptionCatalog = async (request) => {
    try {
      const identity = requireAuthenticatedIdentity(request, {requirePhone: false});
      await enforceUserRateLimit({db, admin, request, scope: "account"});
      const flags = await loadPhase1FeatureFlags(db);
      requirePhase1Feature(flags, "marketplace");
      const [readinessSnapshot, policyStatus] = await Promise.all([
        db.collection("platform_configuration")
            .doc("payment_provider_readiness")
            .get(),
        currentPolicyAcceptanceStatus(db, identity.uid),
      ]);
      const data = readinessSnapshot.exists ? readinessSnapshot.data() : {};
      const readiness = {
        ...(await loadProviderReadiness(db)),
        stripeSubscriptionsEnabled: data.stripeSubscriptionsEnabled === true,
        stripeVipSubscriptionsEnabled: data.stripeVipSubscriptionsEnabled === true,
        stripeTaxRegistrationPending:
          data.stripeTaxRegistrationPending === true,
        stripeTaxPendingBillingApproved:
          data.stripeTaxPendingBillingApproved === true,
      };
      const providerCheckoutReady = vipSubscriptionCheckoutReady(
          readiness,
          flags.paidFeatures,
      );
      return {
        plans: vipSubscriptionPlanCatalog(),
        checkoutAvailable: providerCheckoutReady && policyStatus.current,
        providerCheckoutReady,
        policyEnforcementEnabled: policyStatus.enforcementEnabled,
        policyAcceptanceCurrent: policyStatus.current,
        policyAcceptanceRequired:
          policyStatus.enforcementEnabled && !policyStatus.current,
        taxCollectionStatus: taxCollectionStatus(readiness),
        pendingTaxBillingApproved:
          readiness.stripeTaxPendingBillingApproved === true,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Pipe Buyer VIP subscription catalog failed", error);
      throw new HttpsError(
          "internal",
          "Pipe Buyer VIP subscription pricing could not be loaded.",
      );
    }
  };

  return {getVipSubscriptionCatalog};
}

module.exports = {
  createVipSubscriptionCatalog,
  vipPlanCatalogEntry,
  vipSubscriptionCheckoutReady,
  vipSubscriptionPlanCatalog,
};
