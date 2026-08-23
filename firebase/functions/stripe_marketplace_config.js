"use strict";

// Non-secret Stripe object identifiers created for Pipe Buyer. Secret keys and
// webhook signing secrets belong in Google Cloud Secret Manager only.
const stripeMarketplaceConfig = Object.freeze({
  // Production monetary requests and Accounts v2 use the same GA API family as
  // the live webhook endpoint. Do not switch production billing back to the
  // public-preview channel without an explicit reviewed Stripe dependency.
  apiVersion: "2026-06-24.dahlia",
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
      // Monthly and Yearly intentionally share one Stripe Product so the
      // Customer Portal can offer a tightly-scoped plan switch between only
      // these two reviewed prices.
      productId: "prod_V2WkE5D16GhGaD",
      priceId: "price_1U7bTCDkO07WMXyRvLkWVHHu",
      taxCode: "txcd_10103001",
      currency: "CAD",
      unitAmountMinor: 30000,
      billingInterval: "year",
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
  legacyProducts: Object.freeze({
    dispatchYearlyCadPreUnified: Object.freeze({
      productId: "prod_V2WsPl25y7Qe6A",
      priceId: "price_1U2XDVDkO07WMXyRS0eCYKCh",
      replacementProductId: "prod_V2WkE5D16GhGaD",
      replacementPriceId: "price_1U7bTCDkO07WMXyRvLkWVHHu",
      allowNewCheckout: false,
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
