"use strict";

// Keep the established function surface intact while layering the marketplace
// monetization foundation behind separate callables and safety gates.
const coreExports = require("./index");
Object.assign(exports, coreExports);

const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {HttpsError, onCall, onRequest} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {createAdminRuntime} = require("./admin_runtime");
const {protectedCallableOptions} = require("./app_check_config");
const {createAffiliateCommands} = require("./affiliate_commands");
const {createAffiliatePayouts} = require("./affiliate_payouts");
const {createMarketplaceCommands} = require("./marketplace_commands");
const {
  createPolicyAcceptanceCommands,
} = require("./policy_acceptance_commands");
const {
  cancellationRequiresFinancialResolution,
} = require("./marketplace_financial_guard");
const {
  createMarketplaceRefundWebhookGate,
} = require("./marketplace_refund_webhook_gate");
const {
  createStripeMarketplaceCommands,
  stripeSecretKey,
} = require("./stripe_marketplace_commands");
const {createStripeCheckoutCommands} = require("./stripe_checkout_commands");
const {
  createExternalSettlementCommands,
} = require("./external_settlement_commands");
const {
  createExternalSettlementReceiptCommands,
} = require("./external_settlement_receipt_commands");
const {
  createExternalSettlementReconciliationCommands,
} = require("./external_settlement_reconciliation_commands");
const {
  createDispatchSubscriptionCommands,
} = require("./dispatch_subscription_commands");
const {
  createDispatchSubscriptionStatusCommands,
} = require("./dispatch_subscription_status_commands");
const {
  createDispatchSubscriptionPortalCommands,
} = require("./dispatch_subscription_portal_commands");
const {
  createDispatchSubscriptionReconciliationCommands,
} = require("./dispatch_subscription_reconciliation_commands");
const {
  createDispatchSubscriptionAdminCommands,
} = require("./dispatch_subscription_admin_commands");
const {
  createDispatchSubscriptionLaunchReadinessCommands,
} = require("./dispatch_subscription_launch_readiness_commands");
const {
  createDispatchBillingPortalAdmin,
} = require("./dispatch_billing_portal_admin");
const {
  createDispatchBillingPortalVerificationCommands,
} = require("./dispatch_billing_portal_verification_commands");
const {
  createCanadaSmallSupplierThresholdCommands,
} = require("./canada_small_supplier_threshold_commands");
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
const marketplaceCommands = createMarketplaceCommands(admin);
const policyAcceptanceCommands = createPolicyAcceptanceCommands(admin);
const stripeMarketplaceCommands = createStripeMarketplaceCommands(admin);
const stripeCheckoutCommands = createStripeCheckoutCommands(admin);
const externalSettlementCommands = createExternalSettlementCommands(admin);
const externalSettlementReceiptCommands =
    createExternalSettlementReceiptCommands(admin);
const externalSettlementReconciliationCommands =
    createExternalSettlementReconciliationCommands(admin);
const dispatchSubscriptionCommands = createDispatchSubscriptionCommands(admin);
const dispatchSubscriptionStatusCommands =
    createDispatchSubscriptionStatusCommands(admin);
const dispatchSubscriptionPortalCommands =
    createDispatchSubscriptionPortalCommands(admin);
const dispatchSubscriptionReconciliationCommands =
    createDispatchSubscriptionReconciliationCommands(admin);
const dispatchSubscriptionAdminCommands =
    createDispatchSubscriptionAdminCommands(admin);
const dispatchSubscriptionLaunchReadinessCommands =
    createDispatchSubscriptionLaunchReadinessCommands(admin);
const dispatchBillingPortalAdmin = createDispatchBillingPortalAdmin(admin);
const dispatchBillingPortalVerificationCommands =
    createDispatchBillingPortalVerificationCommands(admin);
const canadaSmallSupplierThresholdCommands =
    createCanadaSmallSupplierThresholdCommands(admin);
const marketplaceMonetization = createMarketplaceMonetization(admin);
const marketplaceFinancialResolution = createMarketplaceFinancialResolution(admin);
const marketplaceRefundWebhookGate = createMarketplaceRefundWebhookGate(
    admin,
    marketplaceFinancialResolution,
);
const stripeDisputeResponse = createStripeDisputeResponse(admin);
const stripeWebhookHandler = createStripeWebhookHandler(admin, {
  marketplaceFinancialResolution: marketplaceRefundWebhookGate,
});

async function updateMarketplaceTransactionWithFinancialGuard(request) {
  const action = String(request.data && request.data.action || "").trim();
  const offerId = String(request.data && request.data.offerId || "").trim();
  if (action === "cancel" && offerId && !offerId.includes("/")) {
    const saleSnapshot = await admin.firestore()
        .collection("marketplace_transactions")
        .doc(offerId)
        .get();
    if (saleSnapshot.exists &&
        cancellationRequiresFinancialResolution(saleSnapshot.data())) {
      throw new HttpsError(
          "failed-precondition",
          "A paid Pipe Buyer transaction must be fully refunded before it can be cancelled.",
      );
    }
  }
  return marketplaceCommands.updateMarketplaceTransaction(request);
}

async function retryMarketplaceSellerRecoveryWithRefundGuard(request) {
  const caseId = String(request.data && request.data.caseId || "").trim();
  if (caseId && caseId.length <= 180 && !caseId.includes("/")) {
    const caseSnapshot = await admin.firestore()
        .collection("marketplace_financial_cases")
        .doc(caseId)
        .get();
    if (caseSnapshot.exists) {
      const financialCase = caseSnapshot.data();
      if (financialCase.type === "refund_request" &&
          ["blocked_seller_recovery", "refund_retry_required"].includes(
              String(financialCase.status || ""),
          )) {
        return marketplaceFinancialResolution.executeMarketplaceRefund(request);
      }
    }
  }
  return marketplaceFinancialResolution.retryMarketplaceSellerRecovery(request);
}

exports.updateMarketplaceTransaction = onCall(
    protectedCallableOptions,
    policyAcceptanceCommands.requireCurrentPolicies(
        updateMarketplaceTransactionWithFinancialGuard,
    ),
);

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
exports.getCanadaGstHstThresholdAssessment = onCall(
    protectedCallableOptions,
    canadaSmallSupplierThresholdCommands.getCanadaGstHstThresholdAssessment,
);
exports.setCanadaGstHstThresholdAssessment = onCall(
    protectedCallableOptions,
    canadaSmallSupplierThresholdCommands.setCanadaGstHstThresholdAssessment,
);
exports.getDispatchSubscriptionStatus = onCall(
    protectedCallableOptions,
    dispatchSubscriptionStatusCommands.getDispatchSubscriptionStatus,
);
exports.getDispatchSubscriptionReconciliationQueue = onCall(
    protectedCallableOptions,
    dispatchSubscriptionAdminCommands.getDispatchSubscriptionReconciliationQueue,
);
exports.getDispatchBillingPortalReadiness = onCall(
    protectedCallableOptions,
    dispatchBillingPortalAdmin.getDispatchBillingPortalReadiness,
);
exports.setDispatchBillingPortalReadiness = onCall(
    protectedCallableOptions,
    dispatchBillingPortalAdmin.setDispatchBillingPortalReadiness,
);

const stripeCallableOptions = Object.freeze({
  ...protectedCallableOptions,
  secrets: [stripeSecretKey.name],
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
exports.getExternalSettlementFeeReceipt = onCall(
    stripeCallableOptions,
    externalSettlementReceiptCommands.getExternalSettlementFeeReceipt,
);
exports.reconcileExternalSettlementFee = onCall(
    stripeCallableOptions,
    externalSettlementReconciliationCommands.reconcileExternalSettlementFee,
);
exports.createDispatchSubscriptionCheckout = onCall(
    stripeCallableOptions,
    dispatchSubscriptionCommands.createDispatchSubscriptionCheckout,
);
exports.createDispatchBillingPortalSession = onCall(
    stripeCallableOptions,
    dispatchSubscriptionPortalCommands.createDispatchBillingPortalSession,
);
exports.verifyDispatchBillingPortalConfiguration = onCall(
    stripeCallableOptions,
    dispatchBillingPortalVerificationCommands.verifyDispatchBillingPortalConfiguration,
);
exports.reconcileDispatchSubscriptionInvoice = onCall(
    stripeCallableOptions,
    dispatchSubscriptionReconciliationCommands.reconcileDispatchSubscriptionInvoice,
);
exports.verifyDispatchSubscriptionLifecycleWebhook = onCall(
    stripeCallableOptions,
    dispatchSubscriptionLaunchReadinessCommands.verifyDispatchSubscriptionLifecycleWebhook,
);
exports.executeMarketplaceRefund = onCall(
    stripeCallableOptions,
    marketplaceFinancialResolution.executeMarketplaceRefund,
);
exports.retryMarketplaceSellerRecovery = onCall(
    stripeCallableOptions,
    retryMarketplaceSellerRecoveryWithRefundGuard,
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
      secrets: [stripeSecretKey.name, stripeWebhookSecret.name],
      cors: false,
    },
    stripeWebhookHandler,
);
