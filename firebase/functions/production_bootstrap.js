"use strict";

// Preserve the complete marketplace function surface and add the MFA-admin
// production-readiness control plane as a thin wrapper.
const coreExports = require("./bootstrap");
Object.assign(exports, coreExports);

const {onCall} = require("firebase-functions/v2/https");
const {createAdminRuntime} = require("./admin_runtime");
const {protectedCallableOptions} = require("./app_check_config");
const {
  createPaymentReadinessAdmin,
} = require("./payment_readiness_admin");
const {createMarketplaceFeeAdmin} = require("./marketplace_fee_admin");
const {
  createMarketplaceTaxCompliance,
} = require("./marketplace_tax_compliance");
const {
  createMarketplaceTaxClaimLink,
} = require("./marketplace_tax_claim_link");
const {
  createMarketplaceTaxRegistrationAdmin,
} = require("./marketplace_tax_registration_admin");
const {
  createMarketplaceTaxRecovery,
} = require("./marketplace_tax_recovery");
const {
  createMembershipPlanManagement,
} = require("./membership_plan_management");
const {stripeSecretKey} = require("./stripe_marketplace_commands");

const admin = createAdminRuntime();
const readinessAdmin = createPaymentReadinessAdmin(admin);
const marketplaceFeeAdmin = createMarketplaceFeeAdmin();
const marketplaceTaxCompliance = createMarketplaceTaxCompliance(admin);
const marketplaceTaxClaimLink = createMarketplaceTaxClaimLink(admin);
const marketplaceTaxRegistrationAdmin =
  createMarketplaceTaxRegistrationAdmin(admin);
const marketplaceTaxRecovery = createMarketplaceTaxRecovery(admin);
const membershipPlanManagement = createMembershipPlanManagement(admin);
const membershipStripeCallableOptions = Object.freeze({
  ...protectedCallableOptions,
  secrets: [stripeSecretKey.name],
});

exports.getPaymentProviderReadiness = onCall(
    protectedCallableOptions,
    readinessAdmin.getPaymentProviderReadiness,
);

exports.setPaymentProviderReadiness = onCall(
    protectedCallableOptions,
    readinessAdmin.setPaymentProviderReadiness,
);

exports.getMarketplaceFeeCatalog = onCall(
    protectedCallableOptions,
    marketplaceFeeAdmin.getMarketplaceFeeCatalog,
);

exports.getMarketplaceTaxProfile = onCall(
    protectedCallableOptions,
    marketplaceTaxCompliance.getMarketplaceTaxProfile,
);

exports.updateMarketplaceTaxProfile = onCall(
    protectedCallableOptions,
    marketplaceTaxCompliance.updateMarketplaceTaxProfile,
);

exports.submitMarketplaceTaxExemptionClaim = onCall(
    protectedCallableOptions,
    async (request) => {
      const result = await marketplaceTaxCompliance
          .submitMarketplaceTaxExemptionClaim(request);
      const transactionId = String(
          request.data && request.data.transactionId || "",
      ).trim();
      const claimId = String(result && result.claimId || "").trim();
      if (transactionId && claimId) {
        await marketplaceTaxClaimLink.attachMarketplaceTaxExemptionClaim({
          ...request,
          data: {transactionId, claimId},
        });
      }
      return result;
    },
);

exports.attachMarketplaceTaxExemptionClaim = onCall(
    protectedCallableOptions,
    marketplaceTaxClaimLink.attachMarketplaceTaxExemptionClaim,
);

exports.getMarketplaceTaxComplianceAdmin = onCall(
    protectedCallableOptions,
    marketplaceTaxCompliance.getMarketplaceTaxComplianceAdmin,
);

exports.reviewMarketplaceTaxExemptionClaim = onCall(
    protectedCallableOptions,
    marketplaceTaxCompliance.reviewMarketplaceTaxExemptionClaim,
);

exports.getMarketplaceTaxRegistrationAdmin = onCall(
    protectedCallableOptions,
    marketplaceTaxRegistrationAdmin.getMarketplaceTaxRegistrationAdmin,
);

exports.reviewMarketplaceTaxRegistration = onCall(
    protectedCallableOptions,
    marketplaceTaxRegistrationAdmin.reviewMarketplaceTaxRegistration,
);

exports.getMarketplaceTaxRecoveryAdmin = onCall(
    protectedCallableOptions,
    marketplaceTaxRecovery.getMarketplaceTaxRecoveryAdmin,
);

exports.createMarketplaceTaxRecoveryCase = onCall(
    protectedCallableOptions,
    marketplaceTaxRecovery.createMarketplaceTaxRecoveryCase,
);

exports.resolveMarketplaceTaxRecoveryCase = onCall(
    protectedCallableOptions,
    marketplaceTaxRecovery.resolveMarketplaceTaxRecoveryCase,
);

exports.getMembershipPlanStatus = onCall(
    protectedCallableOptions,
    membershipPlanManagement.getMembershipPlanStatus,
);

exports.changeMembershipPlan = onCall(
    membershipStripeCallableOptions,
    membershipPlanManagement.changeMembershipPlan,
);
