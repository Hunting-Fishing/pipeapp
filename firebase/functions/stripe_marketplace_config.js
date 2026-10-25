"use strict";

// Non-secret Stripe object identifiers created for Pipe Buyer. Secret keys and
// webhook signing secrets belong in Google Cloud Secret Manager only.
const stripeMarketplaceConfig = Object.freeze({
  apiVersion: "2026-06-24.preview",
  // Seller payout accounts use stable Connect v1. Accounts v2 preview is not
  // compatible with Pipe Buyer's separate-charges-and-transfers architecture;
  // Stripe documents that Express/controller accounts on v1 support that flow.
  connectAccountsApiVersion: "2026-06-24.dahlia",
  accountCountry: "CA",
  products: Object.freeze({
    dispatchMonthlyCad: Object.freeze({
      productId: "prod_V2WkE5D16GhGaD",
      priceId: "price_1U2SYGDkO07WMXyRm6xbprUn",
      taxCode: "txcd_10103001",
      currency: "CAD",
      unitAmountMinor: 2500,
      billingInterval: "month",
    }),
    dispatchYearlyCad: Object.freeze({
      productId: "prod_V2WkE5D16GhGaD",
      priceId: "price_1U7bTCDkO07WMXyRvLkWVHHu",
      taxCode: "txcd_10103001",
      currency: "CAD",
      unitAmountMinor: 30000,
      billingInterval: "year",
    }),
    dispatchMonthlyUsd: Object.freeze({
      productId: "prod_V2WkE5D16GhGaD",
      priceId: "price_1UReXRDkO07WMXyRFyrSKpR4",
      taxCode: "txcd_10103001",
      currency: "USD",
      unitAmountMinor: 2500,
      billingInterval: "month",
    }),
    dispatchYearlyUsd: Object.freeze({
      productId: "prod_V2WkE5D16GhGaD",
      priceId: "price_1UReYXDkO07WMXyRwonGROt3",
      taxCode: "txcd_10103001",
      currency: "USD",
      unitAmountMinor: 25000,
      billingInterval: "year",
    }),
    vipMonthlyCad: Object.freeze({
      productId: "prod_VA12LaMiaCMRqZ",
      priceId: "price_1U9h0tDkO07WMXyRgdzAmm43",
      taxCode: "txcd_10103001",
      currency: "CAD",
      unitAmountMinor: 10000,
      billingInterval: "month",
    }),
    yellowPagesVerifiedProMonthly: Object.freeze({
      productId: "prod_VVVAOWhj7vX0Kv",
      priceId: "price_1UUUAEDkO07WMXyRjMfSl8kr",
      taxCode: "txcd_10103001",
      currency: "USD",
      unitAmountMinor: 2900,
      cadUnitAmountMinor: 2900,
      billingInterval: "month",
      directoryTier: "paid_verified",
      planCode: "yp_paid_verified_monthly",
    }),
    yellowPagesVerifiedProYearly: Object.freeze({
      productId: "prod_VVVAOWhj7vX0Kv",
      priceId: "price_1UUUAEDkO07WMXyR35GIupwZ",
      taxCode: "txcd_10103001",
      currency: "USD",
      unitAmountMinor: 28800,
      cadUnitAmountMinor: 28800,
      billingInterval: "year",
      directoryTier: "paid_verified",
      planCode: "yp_paid_verified_yearly",
    }),
    yellowPagesFeaturedMonthly: Object.freeze({
      productId: "prod_VVVAGpj5u1kObj",
      priceId: "price_1UUUAEDkO07WMXyRtkm6GWgD",
      taxCode: "txcd_10103001",
      currency: "USD",
      unitAmountMinor: 7900,
      cadUnitAmountMinor: 7900,
      billingInterval: "month",
      directoryTier: "featured_platinum",
      planCode: "yp_featured_platinum_monthly",
    }),
    yellowPagesFeaturedYearly: Object.freeze({
      productId: "prod_VVVAGpj5u1kObj",
      priceId: "price_1UUUAFDkO07WMXyRoF54HylB",
      taxCode: "txcd_10103001",
      currency: "USD",
      unitAmountMinor: 78000,
      cadUnitAmountMinor: 78000,
      billingInterval: "year",
      directoryTier: "featured_platinum",
      planCode: "yp_featured_platinum_yearly",
    }),
    pipeMarketplaceFeeCad: Object.freeze({
      productId: "prod_V2cTDvqWIPAZEm",
      priceId: "price_1U2XEPDkO07WMXyRJciY3faj",
      taxCode: "txcd_10000000",
    }),
    equipmentMarketplaceFee: Object.freeze({
      productId: "prod_V2cTrDBcQDhMKq",
      taxCode: "txcd_10000000",
    }),
  }),
  coupons: Object.freeze({
    oneYearFree: "PIPEBUYER_FREE_1Y",
    fiveYearsFree: "PIPEBUYER_FREE_5Y",
  }),
  // Underlying marketplace inventory is physical by default. Specific listing
  // categories can override this server-side when a more precise Stripe tax
  // code has been reviewed and assigned.
  defaultPhysicalGoodsTaxCode: "txcd_99999999",
});

module.exports = {stripeMarketplaceConfig};