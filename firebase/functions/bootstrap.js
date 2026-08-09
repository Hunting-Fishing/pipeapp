"use strict";

// Keep the established function surface intact while layering the marketplace
// monetization foundation behind separate callables and safety gates.
const coreExports = require("./index");
Object.assign(exports, coreExports);

const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onCall, onRequest} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {createAdminRuntime} = require("./admin_runtime");
const {protectedCallableOptions} = require("./app_check_config");
const {createAffiliateCommands} = require("./affiliate_commands");
const {createAffiliatePayouts} = require("./affiliate_payouts");
const {
  createStripeMarketplaceCommands,
  stripeSecretKey,
} = require("./stripe_marketplace_commands");
const {createStripeCheckoutCommands} = require("./stripe_checkout_commands");
const {
  createExternalSettlementCommands,
} = require("./external_settlement_commands");
const {
  createDispatchSubscriptionCommands,
} = require("./dispatch_subscription_commands");
const {
  createMarketplaceMonetization,
} = require("./marketplace_monetization");
const {
  createMarketplaceFinancialResolution,
} = require("./marketplace_financial_resolution");
const {createStripeDisputeResponse} = require("./stripe_dispute_response");
const {
  createStripeWebhookHandler,
  stripeWebhookSecret,
} = require("./stripe_webhook");

const admin = createAdminRuntime();
const affiliateCommands = createAffiliateCommands(admin);
const affiliatePayouts = createAffiliatePayouts(admin);
const stripeMarketplaceCommands = createStripeMarketplaceCommands(admin);
const stripeCheckoutCommands = createStripeCheckoutCommands(admin);
const externalSettlementCommands = createExternalSettlementCommands(admin);
const dispatchSubscriptionCommands = createDispatchSubscriptionCommands(admin);
const marketplaceMonetization = createMarketplaceMonetization(admin);
const marketplaceFinancialResolution = createMarketplaceFinancialResolution(admin);
const stripeDisputeResponse = createStripeDisputeResponse(admin);
const stripeWebhookHandler = createStripeWebhookHandler(admin, {
  marketplaceFinancialResolution,
});

exports.ensureAffiliateCode = onCall(
    protectedCallableOptions,
    affiliateCommands.ensureAffiliateCode,
);
exports.claimAffiliateReferral = onCall(
    protectedCallableOptions,
    affiliateCommands.claimAffiliateReferral,
);
exports.confirmExternalSettlement = onCall(
    protectedCallableOptions,
    externalSettlementCommands.confirmExternalSettlement,
);
exports.requestMarketplaceRefund = onCall(
    protectedCallableOptions,
    marketplaceFinancialResolution.requestMarketplaceRefund,
);
exports.cancelMarketplaceRefundRequest = onCall(
    protectedCallableOptions,
    marketplaceFinancialResolution.cancelMarketplaceRefundRequest,
);

const stripeCallableOptions = Object.freeze({
  ...protectedCallableOptions,
  secrets: [stripeSecretKey],
});

exports.ensureStripeSellerAccount = onCall(
    stripeCallableOptions,
    stripeMarketplaceCommands.ensureStripeSellerAccount,
);
exports.createStripeSellerOnboardingLink = onCall(
    stripeCallableOptions,
    stripeMarketplaceCommands.createStripeSellerOnboardingLink,
);
exports.refreshStripeSellerStatus = onCall(
    stripeCallableOptions,
    stripeMarketplaceCommands.refreshStripeSellerStatus,
);
exports.createMarketplaceCheckout = onCall(
    stripeCallableOptions,
    stripeCheckoutCommands.createMarketplaceCheckout,
);
exports.createExternalSettlementFeeCheckout = onCall(
    stripeCallableOptions,
    externalSettlementCommands.createExternalSettlementFeeCheckout,
);
exports.createDispatchSubscriptionCheckout = onCall(
    stripeCallableOptions,
    dispatchSubscriptionCommands.createDispatchSubscriptionCheckout,
);
exports.executeMarketplaceRefund = onCall(
    stripeCallableOptions,
    marketplaceFinancialResolution.executeMarketplaceRefund,
);
exports.retryMarketplaceSellerRecovery = onCall(
    stripeCallableOptions,
    marketplaceFinancialResolution.retryMarketplaceSellerRecovery,
);
exports.stageMarketplaceDisputeEvidence = onCall(
    stripeCallableOptions,
    stripeDisputeResponse.stageMarketplaceDisputeEvidence,
);
exports.submitMarketplaceDisputeEvidence = onCall(
    stripeCallableOptions,
    stripeDisputeResponse.submitMarketplaceDisputeEvidence,
);
exports.acceptMarketplaceDispute = onCall(
    stripeCallableOptions,
    stripeDisputeResponse.acceptMarketplaceDispute,
);

exports.stripeMarketplaceWebhook = onRequest(
    {
      secrets: [stripeSecretKey, stripeWebhookSecret],
      cors: false,
    },
    stripeWebhookHandler,
);

exports.processEligibleAffiliatePayouts = onSchedule(
    {
      schedule: "every day 06:15",
      timeZone: "America/Vancouver",
      secrets: [stripeSecretKey],
    },
    affiliatePayouts.processEligibleAffiliatePayouts,
);

exports.onMarketplaceTransactionCreatedMonetization = onDocumentCreated(
    {
      document: "marketplace_transactions/{transactionId}",
      retry: true,
    },
    async (event) => marketplaceMonetization.snapshotAcceptedTransaction({
      transactionId: event.params.transactionId,
      transactionData: event.data && event.data.data(),
    }),
);
