"use strict";

const {
  dispatchBillingPortalRuntimeDecision,
} = require("./dispatch_subscription_portal_runtime_gate");
const {
  canadaSmallSupplierReadinessDecision,
} = require("./canada_small_supplier_readiness_guard");
const {taxBillingPrepared} = require("./pending_tax_policy");

function dispatchSubscriptionFeatureReady(features = {}) {
  return features.dispatch === true && features.paidFeatures === true;
}

function dispatchSubscriptionTaxReady(readiness = {}, assessment = null) {
  if (readiness.canadaGstHstSmallSupplier === true) {
    return canadaSmallSupplierReadinessDecision(
        readiness,
        assessment,
    ).authorized === true;
  }
  return taxBillingPrepared(readiness);
}

function dispatchSubscriptionStoredReadiness(
    readiness = {},
    portal = {},
    assessment = null,
    features = {},
) {
  const featureFlagsReady = dispatchSubscriptionFeatureReady(features);
  const productionModeReady = readiness.stripeMode === "production";
  const portalReady =
    dispatchBillingPortalRuntimeDecision(portal).ready === true;
  const coreWebhookReady = readiness.stripeWebhookVerified === true;
  const lifecycleWebhookReady =
    readiness.stripeSubscriptionLifecycleWebhookVerified === true;
  const recoveryReady =
    readiness.stripeSubscriptionRecoveryVerified === true;
  const reconciliationReady = readiness.stripeReconciliationReady === true;
  const taxReady = dispatchSubscriptionTaxReady(readiness, assessment);
  const subscriptionsEnabled = readiness.stripeSubscriptionsEnabled === true;

  const prerequisiteStates = Object.freeze([
    featureFlagsReady,
    productionModeReady,
    portalReady,
    coreWebhookReady,
    lifecycleWebhookReady,
    recoveryReady,
    reconciliationReady,
    taxReady,
  ]);
  const readyCount = prerequisiteStates.filter(Boolean).length;
  const prerequisitesReady = readyCount === prerequisiteStates.length;

  return Object.freeze({
    featureFlagsReady,
    dispatchFeatureEnabled: features.dispatch === true,
    paidFeaturesEnabled: features.paidFeatures === true,
    productionModeReady,
    portalReady,
    coreWebhookReady,
    lifecycleWebhookReady,
    recoveryReady,
    reconciliationReady,
    taxReady,
    subscriptionsEnabled,
    readyCount,
    prerequisiteCount: prerequisiteStates.length,
    prerequisitesReady,
    publicBillingAvailable: prerequisitesReady && subscriptionsEnabled,
  });
}

module.exports = {
  dispatchSubscriptionFeatureReady,
  dispatchSubscriptionStoredReadiness,
  dispatchSubscriptionTaxReady,
};
