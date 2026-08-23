"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AdministratorAuthorizationError,
  requireAdministrator,
} = require("./administrator_authorization");
const {
  BASIS_POINTS,
  fromMinorUnits,
  launchMarketplaceFeeSchedule,
} = require("./marketplace_fee_policy");
const {
  AFFILIATE_REVENUE_POLICY_REVISION,
  DISPATCH_BILLING_COST_RESERVE_BPS,
} = require("./affiliate_revenue_policy");
const {stripeMarketplaceConfig} = require("./stripe_marketplace_config");

function moneyMap(minorByCurrency = {}) {
  return Object.fromEntries(
      Object.entries(minorByCurrency).map(([currency, minor]) => [
        currency,
        Object.freeze({
          minor: Number(minor),
          amount: fromMinorUnits(minor),
        }),
      ]),
  );
}

function feeCatalog() {
  const schedule = launchMarketplaceFeeSchedule;
  const products = stripeMarketplaceConfig.products;
  return {
    scheduleRevision: String(schedule.revision),
    feePayer: String(schedule.payer),
    affiliate: {
      shareBps: Number(schedule.affiliateShareBps),
      sharePercent: Number(
          (Number(schedule.affiliateShareBps) * 100 / BASIS_POINTS).toFixed(2),
      ),
      revenuePolicyRevision: AFFILIATE_REVENUE_POLICY_REVISION,
      commissionBasis: String(schedule.affiliateCommissionBasis),
      basisDescription:
        "5% of positive net eligible Pipe Buyer revenue after applicable " +
        "payment-provider costs, tax reserves, refunds, chargebacks, credits, " +
        "and other pass-through costs. Customer taxes and seller sale proceeds " +
        "are never affiliate revenue.",
      dispatchBillingCostReserveBps: DISPATCH_BILLING_COST_RESERVE_BPS,
      refundHoldDays: 30,
    },
    pipe: {
      unitFeeByCurrency: moneyMap(schedule.pipe.unitFeeMinorByCurrency),
      minimumFeeByCurrency: moneyMap(schedule.pipe.minimumFeeMinorByCurrency),
      maximumFeeByCurrency: moneyMap(schedule.pipe.maximumFeeMinorByCurrency),
      stripeProductId: products.pipeMarketplaceFeeCad.productId,
      stripePriceId: products.pipeMarketplaceFeeCad.priceId,
      stripeTaxCode: products.pipeMarketplaceFeeCad.taxCode,
    },
    equipment: {
      minimumFeeByCurrency: moneyMap(schedule.equipment.minimumFeeMinorByCurrency),
      tiers: schedule.equipment.tiers.map((tier) => ({
        upToExclusiveMinor: tier.upToExclusiveMinor,
        upToExclusive: tier.upToExclusiveMinor == null ? null :
          fromMinorUnits(tier.upToExclusiveMinor),
        feeBps: Number(tier.feeBps),
        feePercent: Number((Number(tier.feeBps) * 100 / BASIS_POINTS).toFixed(2)),
      })),
      stripeProductId: products.equipmentMarketplaceFee.productId,
      stripeTaxCode: products.equipmentMarketplaceFee.taxCode,
    },
    dispatch: {
      monthly: {
        currency: products.dispatchMonthlyCad.currency,
        amountMinor: products.dispatchMonthlyCad.unitAmountMinor,
        amount: fromMinorUnits(products.dispatchMonthlyCad.unitAmountMinor),
        interval: products.dispatchMonthlyCad.billingInterval,
        stripeProductId: products.dispatchMonthlyCad.productId,
        stripePriceId: products.dispatchMonthlyCad.priceId,
        stripeTaxCode: products.dispatchMonthlyCad.taxCode,
      },
      yearly: {
        currency: products.dispatchYearlyCad.currency,
        amountMinor: products.dispatchYearlyCad.unitAmountMinor,
        amount: fromMinorUnits(products.dispatchYearlyCad.unitAmountMinor),
        interval: products.dispatchYearlyCad.billingInterval,
        stripeProductId: products.dispatchYearlyCad.productId,
        stripePriceId: products.dispatchYearlyCad.priceId,
        stripeTaxCode: products.dispatchYearlyCad.taxCode,
      },
    },
    taxCodes: {
      defaultPhysicalGoods: stripeMarketplaceConfig.defaultPhysicalGoodsTaxCode,
      marketplaceService: products.pipeMarketplaceFeeCad.taxCode,
      dispatchSaas: products.dispatchMonthlyCad.taxCode,
    },
  };
}

function createMarketplaceFeeAdmin() {
  const getMarketplaceFeeCatalog = async (request) => {
    try {
      requireAdministrator(request);
      return feeCatalog();
    } catch (error) {
      if (error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Marketplace fee catalog failed", error);
      throw new HttpsError("internal", "The marketplace fee catalog is unavailable.");
    }
  };

  return {getMarketplaceFeeCatalog};
}

module.exports = {
  createMarketplaceFeeAdmin,
  feeCatalog,
  moneyMap,
};
