"use strict";

const {HttpsError} = require("firebase-functions/v2/https");

const BASIS_POINTS = 10000;
const FULL_GMV_ECONOMICS_MODEL = "configured-cost-ceiling-v1";

function fail(message) {
  throw new HttpsError("failed-precondition", message);
}

function requiredPositiveInteger(value, field) {
  const number = Number(value);
  if (!Number.isSafeInteger(number) || number <= 0) {
    fail(`${field} is not configured.`);
  }
  return number;
}

function requiredNonNegativeInteger(value, field) {
  const number = Number(value);
  if (!Number.isSafeInteger(number) || number < 0) {
    fail(`${field} is not configured.`);
  }
  return number;
}

function approvedEconomicsConfiguration(readiness) {
  const safeReadiness = readiness && typeof readiness === "object" ?
    readiness : {};
  if (safeReadiness.stripeFullGmvEconomicsApproved !== true) {
    fail(
        "Full marketplace checkout is unavailable until its payment-rail " +
        "economics are approved. Use external settlement when offered.",
    );
  }

  const policyRevision = String(
      safeReadiness.stripeFullGmvEconomicsPolicyRevision || "",
  ).trim();
  if (!/^[A-Za-z0-9][A-Za-z0-9._:-]{2,119}$/.test(policyRevision)) {
    fail("The full marketplace checkout economics revision is not configured.");
  }
  const paymentMethodConfigurationId = String(
      safeReadiness.stripeFullGmvPaymentMethodConfigurationId || "",
  ).trim();
  if (!/^pmc_[A-Za-z0-9]+$/.test(paymentMethodConfigurationId)) {
    fail(
        "The approved full marketplace payment-method configuration is unavailable.",
    );
  }

  const maximumChargeMinor = requiredPositiveInteger(
      safeReadiness.stripeFullGmvMaximumChargeMinorUsd,
      "The approved full marketplace checkout limit",
  );
  const maximumProviderFeeBps = requiredPositiveInteger(
      safeReadiness.stripeFullGmvMaximumProviderFeeBps,
      "The approved payment-provider percentage cost ceiling",
  );
  if (maximumProviderFeeBps > BASIS_POINTS) {
    fail("The approved payment-provider percentage cost ceiling is invalid.");
  }
  const maximumProviderFeeFixedMinor = requiredNonNegativeInteger(
      safeReadiness.stripeFullGmvMaximumProviderFeeFixedMinorUsd,
      "The approved payment-provider fixed cost ceiling",
  );
  const maximumTaxUpliftBps = requiredNonNegativeInteger(
      safeReadiness.stripeFullGmvMaximumTaxUpliftBps,
      "The approved maximum checkout tax uplift",
  );
  if (maximumTaxUpliftBps > BASIS_POINTS ||
      (safeReadiness.stripeTaxReady === true && maximumTaxUpliftBps === 0)) {
    fail("The approved maximum checkout tax uplift is invalid.");
  }
  const minimumNetPlatformRevenueMinor = requiredPositiveInteger(
      safeReadiness.stripeFullGmvMinimumNetRevenueMinorUsd,
      "The approved minimum net platform revenue",
  );

  return Object.freeze({
    model: FULL_GMV_ECONOMICS_MODEL,
    policyRevision,
    paymentMethodConfigurationId,
    currency: "USD",
    maximumChargeMinor,
    maximumProviderFeeBps,
    maximumProviderFeeFixedMinor,
    maximumTaxUpliftBps,
    minimumNetPlatformRevenueMinor,
  });
}

function requireFullGmvCheckoutEconomics({readiness, feeSnapshot}) {
  const configuration = approvedEconomicsConfiguration(readiness);
  const safeFee = feeSnapshot && typeof feeSnapshot === "object" ?
    feeSnapshot : {};
  const currency = String(safeFee.currency || "").trim().toUpperCase();
  const chargeAmountMinor = Number(safeFee.agreedTotalMinor);
  const marketplaceFeeMinor = Number(safeFee.marketplaceFeeMinor);
  const affiliateCommissionMinor = Number(safeFee.affiliateCommissionMinor);
  if (currency !== configuration.currency ||
      !Number.isSafeInteger(chargeAmountMinor) || chargeAmountMinor <= 0 ||
      !Number.isSafeInteger(marketplaceFeeMinor) || marketplaceFeeMinor <= 0 ||
      marketplaceFeeMinor > chargeAmountMinor ||
      !Number.isSafeInteger(affiliateCommissionMinor) ||
      affiliateCommissionMinor < 0 ||
      affiliateCommissionMinor > marketplaceFeeMinor) {
    fail(
        "This transaction is not eligible for the approved full marketplace " +
        "checkout rail. Use external settlement when offered.",
    );
  }
  if (chargeAmountMinor > configuration.maximumChargeMinor) {
    fail(
        "This sale exceeds the approved full marketplace checkout limit. " +
        "Use external settlement when offered.",
    );
  }

  // The rate and fixed amount are explicit, administrator-approved upper
  // bounds for the payment methods in the attached Stripe configuration. They
  // are never inferred from public pricing or silently defaulted in code.
  const maximumTaxUpliftBpsApplied = readiness.stripeTaxReady === true ?
    configuration.maximumTaxUpliftBps : 0;
  const providerCostBaseMinor = Math.ceil(
      chargeAmountMinor *
      (BASIS_POINTS + maximumTaxUpliftBpsApplied) /
      BASIS_POINTS,
  );
  const configuredProviderCostCeilingMinor = Math.ceil(
      providerCostBaseMinor *
      configuration.maximumProviderFeeBps /
      BASIS_POINTS,
  ) + configuration.maximumProviderFeeFixedMinor;
  const requiredMarketplaceFeeMinor =
    configuredProviderCostCeilingMinor +
    configuration.minimumNetPlatformRevenueMinor;
  const retainedFeeBeforeProviderCostsMinor =
    marketplaceFeeMinor - affiliateCommissionMinor;
  if (!Number.isSafeInteger(configuredProviderCostCeilingMinor) ||
      !Number.isSafeInteger(requiredMarketplaceFeeMinor) ||
      !Number.isSafeInteger(retainedFeeBeforeProviderCostsMinor) ||
      retainedFeeBeforeProviderCostsMinor < requiredMarketplaceFeeMinor) {
    fail(
        "Full marketplace checkout is not economical for this sale under the " +
        "approved payment rail. Use external settlement when offered.",
    );
  }

  return Object.freeze({
    ...configuration,
    chargeAmountMinor,
    marketplaceFeeMinor,
    affiliateCommissionMinor,
    retainedFeeBeforeProviderCostsMinor,
    maximumTaxUpliftBpsApplied,
    providerCostBaseMinor,
    configuredProviderCostCeilingMinor,
    requiredMarketplaceFeeMinor,
    projectedMinimumNetPlatformRevenueMinor:
      retainedFeeBeforeProviderCostsMinor - configuredProviderCostCeilingMinor,
  });
}

module.exports = {
  BASIS_POINTS,
  FULL_GMV_ECONOMICS_MODEL,
  approvedEconomicsConfiguration,
  requireFullGmvCheckoutEconomics,
};
