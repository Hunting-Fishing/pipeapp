"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  dispatchPlanForPriceId,
  dispatchSubscriptionCatalogAssessment,
} = require("../dispatch_subscription_catalog_policy");
const {stripeMarketplaceConfig} = require("../stripe_marketplace_config");

function subscription({priceId, productId, quantity = 1, itemCount = 1} = {}) {
  const price = priceId || stripeMarketplaceConfig.products.dispatchMonthlyCad.priceId;
  const product = productId || stripeMarketplaceConfig.products.dispatchMonthlyCad.productId;
  return {
    items: {
      data: Array.from({length: itemCount}, () => ({
        quantity,
        price: {id: price, product},
      })),
    },
  };
}

test("canonical Dispatch prices map to monthly and yearly", () => {
  assert.equal(
      dispatchPlanForPriceId(
          stripeMarketplaceConfig.products.dispatchMonthlyCad.priceId,
      ),
      "monthly",
  );
  assert.equal(
      dispatchPlanForPriceId(
          stripeMarketplaceConfig.products.dispatchYearlyCad.priceId,
      ),
      "yearly",
  );
  assert.equal(dispatchPlanForPriceId("price_unknown"), "");
});

test("single quantity-one canonical subscription item is accepted", () => {
  const monthly = dispatchSubscriptionCatalogAssessment(subscription());
  assert.equal(monthly.ready, true);
  assert.equal(monthly.plan, "monthly");
  assert.equal(monthly.quantity, 1);

  const yearly = dispatchSubscriptionCatalogAssessment(subscription({
    priceId: stripeMarketplaceConfig.products.dispatchYearlyCad.priceId,
  }));
  assert.equal(yearly.ready, true);
  assert.equal(yearly.plan, "yearly");
});

test("unknown price, wrong product, quantity change, or multiple items fail closed", () => {
  assert.deepEqual(
      dispatchSubscriptionCatalogAssessment(subscription({
        priceId: "price_unknown",
      })).failedChecks,
      ["dispatch_price"],
  );
  assert.ok(
      dispatchSubscriptionCatalogAssessment(subscription({
        productId: "prod_unknown",
      })).failedChecks.includes("dispatch_product"),
  );
  assert.ok(
      dispatchSubscriptionCatalogAssessment(subscription({quantity: 2}))
          .failedChecks.includes("subscription_quantity"),
  );
  assert.ok(
      dispatchSubscriptionCatalogAssessment(subscription({itemCount: 2}))
          .failedChecks.includes("subscription_item_count"),
  );
});
