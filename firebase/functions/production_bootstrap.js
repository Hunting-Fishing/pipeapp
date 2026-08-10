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
  createMarketplaceTaxRegistrationAdmin,
} = require("./marketplace_tax_registration_admin");

const admin = createAdminRuntime();
const readinessAdmin = createPaymentReadinessAdmin(admin);
const marketplaceFeeAdmin = createMarketplaceFeeAdmin();
const marketplaceTaxCompliance = createMarketplaceTaxCompliance(admin);
const marketplaceTaxRegistrationAdmin =
  createMarketplaceTaxRegistrationAdmin(admin);

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
    marketplaceTaxCompliance.submitMarketplaceTaxExemptionClaim,
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
