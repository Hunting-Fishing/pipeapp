"use strict";

// Non-secret Stripe object identifiers created for Pipe Buyer. Secret keys and
// webhook signing secrets belong in Google Cloud Secret Manager only.
const stripeMarketplaceConfig = Object.freeze({
  apiVersion: "2026-06-24.preview",
  accountCountry: "CA",
  products: Object.freeze({
    dispatchMonthlyCad: Object.freeze({
      productId: "prod_V2WkE5D16GhGaD",
      priceId: "price_1U2SYGDkO07WMXyRm6xbprUn",
      taxCode: "txcd_10103001",
    }),
    dispatchYearlyCad: Object.freeze({
      productId: "prod_V2WsPl25y7Qe6A",
      priceId: "price_1U2XDVDkO07WMXyRS0eCYKCh",
      taxCode: "txcd_10103001",
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
