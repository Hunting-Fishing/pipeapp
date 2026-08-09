"use strict";

// Keep the established function surface intact while layering the marketplace
// monetization foundation behind separate callables and safety gates.
const coreExports = require("./index");
Object.assign(exports, coreExports);

const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onCall, onRequest} = require("firebase-functions/v2/https");
const {createAdminRuntime} = require("./admin_runtime");
const {protectedCallableOptions} = require("./app_check_config");
const {createAffiliateCommands} = require("./affiliate_commands");
const {
  createStripeMarketplaceCommands,
  stripeSecretKey,
} = require("./stripe_marketplace_commands");
const {createStripeCheckoutCommands} = require("./stripe_checkout_commands");
const {
  createMarketplaceMonetization,
} = require("./marketplace_monetization");
const {
  createStripeWebhookHandler,
  stripeWebhookSecret,
} = require("./stripe_webhook");

const admin = createAdminRuntime();
const affiliateCommands = createAffiliateCommands(admin);
const stripeMarketplaceCommands = createStripeMarketplaceCommands(admin);
const stripeCheckoutCommands = createStripeCheckoutCommands(admin);
const marketplaceMonetization = createMarketplaceMonetization(admin);
const stripeWebhookHandler = createStripeWebhookHandler(admin);

exports.ensureAffiliateCode = onCall(
    protectedCallableOptions,
    affiliateCommands.ensureAffiliateCode,
);
exports.claimAffiliateReferral = onCall(
    protectedCallableOptions,
    affiliateCommands.claimAffiliateReferral,
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

exports.stripeMarketplaceWebhook = onRequest(
    {
      secrets: [stripeSecretKey, stripeWebhookSecret],
      cors: false,
    },
    stripeWebhookHandler,
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
