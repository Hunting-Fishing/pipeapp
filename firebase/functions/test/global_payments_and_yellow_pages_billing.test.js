"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {GLOBAL_COUNTRIES_LIST} = require("../yellow_pages_taxonomy");
const {
  STRIPE_CA_CONNECT_SELLER_COUNTRIES,
  STRIPE_SANCTIONED_COUNTRIES,
  appendCheckoutReturnParams,
  assertCountryPayableWithStripe,
  currencyExponent,
  extractCheckoutSettlementAmounts,
  fromStripeMinorUnits,
  isCountryBlockedForStripePayments,
  isStripeConnectSellerCountrySupported,
  toStripeMinorUnits,
} = require("../global_payment_policy");
const {
  invoiceYellowPagesPlan,
  resolveYellowPagesPriceSpec,
  subscriptionYellowPagesPlan,
  yellowPagesPlanForPriceId,
} = require("../yellow_pages_billing");
const {membershipPlanForPriceId} = require("../membership_plan_policy");
const {stripeMarketplaceConfig} = require("../stripe_marketplace_config");
const {calculateMarketplaceFeeSnapshot} = require("../marketplace_fee_policy");
const {normalizeTaxProfileInput} = require("../marketplace_tax_compliance");

test("197 Yellow Pages countries split cleanly into 6 sanctioned and 191 Stripe-payable countries", () => {
  assert.equal(GLOBAL_COUNTRIES_LIST.length, 197);
  const blocked = [];
  const payable = [];
  for (const country of GLOBAL_COUNTRIES_LIST) {
    if (isCountryBlockedForStripePayments(country.code)) {
      blocked.push(country.code);
      assert.throws(
          () => assertCountryPayableWithStripe(country.code),
          /unavailable for jurisdiction/i,
      );
    } else {
      payable.push(country.code);
      assert.equal(assertCountryPayableWithStripe(country.code), country.code);
    }
  }
  assert.deepEqual(blocked.sort(), [...STRIPE_SANCTIONED_COUNTRIES].sort());
  assert.equal(blocked.length, 6);
  assert.equal(payable.length, 191);

  // Occupied regions of Ukraine are blocked while non-occupied Ukraine remains payable.
  assert.equal(assertCountryPayableWithStripe("UA", "Kyiv"), "UA");
  assert.throws(
      () => assertCountryPayableWithStripe("UA", "Sevastopol, Crimea"),
      /unavailable for jurisdiction/i,
  );
});

test("Stripe Connect seller payout countries cover all 37 CA cross-border transfer countries", () => {
  assert.equal(STRIPE_CA_CONNECT_SELLER_COUNTRIES.length, 37);
  for (const code of ["CA", "US", "GB", "NO", "CH", "DE", "FR", "NL", "IT", "ES", "PL", "RO"]) {
    assert.equal(isStripeConnectSellerCountrySupported(code), true);
  }
  for (const code of ["SA", "QA", "GY", "RU", "IR"]) {
    assert.equal(isStripeConnectSellerCountrySupported(code), false);
  }
});

test("zero-decimal, two-decimal, and three-decimal currencies convert accurately for Stripe", () => {
  assert.equal(currencyExponent("JPY"), 0);
  assert.equal(toStripeMinorUnits(3750, "JPY"), 3750);
  assert.equal(fromStripeMinorUnits(3750, "JPY"), 3750);

  assert.equal(currencyExponent("USD"), 2);
  assert.equal(toStripeMinorUnits(29, "USD"), 2900);
  assert.equal(fromStripeMinorUnits(2900, "USD"), 29);

  assert.equal(currencyExponent("KWD"), 3);
  assert.equal(toStripeMinorUnits(12.34, "KWD"), 12340);
  assert.equal(toStripeMinorUnits(12.345, "KWD"), 12350); // Stripe 10-fils rounding
  assert.equal(fromStripeMinorUnits(12340, "KWD"), 12.34);

  const aedFee = calculateMarketplaceFeeSnapshot({
    listing: {productType: "Line Pipe"},
    agreedQuantity: 100,
    agreedTotal: 50000,
    currency: "AED",
  });
  assert.equal(aedFee.currency, "AED");
  assert.equal(aedFee.marketplaceFeeMinor, 37000);

  const jpyFee = calculateMarketplaceFeeSnapshot({
    listing: {productType: "Drill Pipe"},
    agreedQuantity: 50,
    agreedTotal: 1000000,
    currency: "JPY",
  });
  assert.equal(jpyFee.currency, "JPY");
  assert.equal(jpyFee.agreedTotalMinor, 1000000);
  assert.equal(jpyFee.marketplaceFeeMinor, 7500);
  assert.equal(jpyFee.marketplaceFee, 7500);
});

test("Adaptive Pricing currency_conversion preserves settlement subtotal for webhook verification", () => {
  const convertedSession = {
    currency: "eur",
    amount_subtotal: 18450,
    amount_total: 21955,
    total_details: {amount_tax: 3505},
    currency_conversion: {
      source_currency: "cad",
      amount_subtotal: 25000,
      amount_total: 29750,
      fx_rate: "0.7380",
    },
  };
  const extracted = extractCheckoutSettlementAmounts(convertedSession);
  assert.equal(extracted.adaptivePricingApplied, true);
  assert.equal(extracted.settlementCurrency, "CAD");
  assert.equal(extracted.settlementSubtotalMinor, 25000);
  assert.equal(extracted.settlementTotalMinor, 29750);
  assert.equal(extracted.settlementTaxMinor, 4750);
  assert.equal(extracted.presentmentCurrency, "EUR");
  assert.equal(extracted.presentmentSubtotalMinor, 18450);
});

test("Oilfield Directory Stripe Products & Prices resolve cleanly and stay decoupled from Dispatch/VIP ladder", () => {
  const proMonthly = resolveYellowPagesPriceSpec("paid_verified", "monthly");
  const proYearly = resolveYellowPagesPriceSpec("paid_verified", "yearly");
  const featMonthly = resolveYellowPagesPriceSpec("featured_platinum", "monthly");
  const featYearly = resolveYellowPagesPriceSpec("featured_platinum", "yearly");

  assert.equal(proMonthly.priceId, "price_1UUUAEDkO07WMXyRjMfSl8kr");
  assert.equal(proYearly.priceId, "price_1UUUAEDkO07WMXyR35GIupwZ");
  assert.equal(featMonthly.priceId, "price_1UUUAEDkO07WMXyRtkm6GWgD");
  assert.equal(featYearly.priceId, "price_1UUUAFDkO07WMXyRoF54HylB");

  for (const spec of [proMonthly, proYearly, featMonthly, featYearly]) {
    const plan = yellowPagesPlanForPriceId(spec.priceId);
    assert.ok(plan);
    assert.equal(plan.directoryTier, spec.directoryTier);
    // Must NOT collide with user-level Dispatch/VIP membership ladder!
    assert.equal(membershipPlanForPriceId(spec.priceId), null);
  }

  // USD Dispatch prices resolve to Dispatch membership plans
  assert.equal(
      membershipPlanForPriceId(
          stripeMarketplaceConfig.products.dispatchMonthlyUsd.priceId,
      ).id,
      "dispatch_monthly",
  );
  assert.equal(
      membershipPlanForPriceId(
          stripeMarketplaceConfig.products.dispatchYearlyUsd.priceId,
      ).id,
      "dispatch_yearly",
  );

  // Invoice & subscription matching for Yellow Pages
  const matchedInvoice = invoiceYellowPagesPlan({
    lines: {
      data: [{
        amount: 28800,
        pricing: {price_details: {price: proYearly.priceId}},
      }],
    },
  });
  assert.equal(matchedInvoice.plan.directoryTier, "paid_verified");
  assert.equal(matchedInvoice.plan.billingInterval, "yearly");

  const matchedSub = subscriptionYellowPagesPlan({
    items: {data: [{id: "si_yp1", price: {id: featYearly.priceId}}]},
  });
  assert.equal(matchedSub.directoryTier, "featured_platinum");
  assert.equal(matchedSub.billingInterval, "yearly");
});

test("international tax profiles support unitary countries and non-Canadian GST defaults", () => {
  const sgProfile = normalizeTaxProfileInput({
    legalBusinessName: "Marina Offshore Tubulars Pte Ltd",
    countryCode: "sg",
    regionCode: "",
    businessNumber: "202012345G",
    taxResponsibilityAcknowledged: true,
  });
  assert.equal(sgProfile.countryCode, "SG");
  assert.equal(sgProfile.regionCode, "NA");
  assert.equal(sgProfile.sellerNormalGstHstRegistered, "no");

  const url = appendCheckoutReturnParams("https://www.pipebuyer.com/?payment=success", {
    flow: "yellow_pages",
    requestId: "req_123",
  });
  assert.equal(
      url,
      "https://www.pipebuyer.com/?payment=success&flow=yellow_pages&requestId=req_123",
  );
});
