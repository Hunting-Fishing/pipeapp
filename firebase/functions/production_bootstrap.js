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

const readinessAdmin = createPaymentReadinessAdmin(createAdminRuntime());
const marketplaceFeeAdmin = createMarketplaceFeeAdmin();

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
