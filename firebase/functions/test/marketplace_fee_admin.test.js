"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {feeCatalog} = require("../marketplace_fee_admin");

test("admin fee catalog exposes strict pipe fee rules", () => {
  const catalog = feeCatalog();
  assert.equal(catalog.scheduleRevision, "2026-08-10-launch-v3");
  assert.equal(catalog.feePayer, "seller");
  assert.equal(catalog.pipe.unitFeeByCurrency.CAD.amount, 1);
  assert.equal(catalog.pipe.minimumFeeByCurrency.CAD.amount, 25);
  assert.equal(catalog.pipe.maximumFeeByCurrency.CAD.amount, 5000);
  assert.equal(catalog.pipe.unitFeeByCurrency.USD.amount, 1);
  assert.equal(catalog.pipe.minimumFeeByCurrency.USD.amount, 25);
  assert.equal(catalog.pipe.maximumFeeByCurrency.USD.amount, 5000);
});

test("admin fee catalog exposes dispatch and affiliate pricing", () => {
  const catalog = feeCatalog();
  assert.equal(catalog.dispatch.monthly.amount, 25);
  assert.equal(catalog.dispatch.monthly.currency, "CAD");
  assert.equal(catalog.dispatch.yearly.amount, 300);
  assert.equal(catalog.dispatch.yearly.currency, "CAD");
  assert.equal(catalog.affiliate.sharePercent, 5);
  assert.equal(catalog.affiliate.shareBps, 500);
  assert.equal(
      catalog.affiliate.commissionBasis,
      "positive_net_eligible_pipe_buyer_revenue",
  );
  assert.match(catalog.affiliate.basisDescription, /payment-provider costs/);
});

test("admin fee catalog exposes equipment tiers", () => {
  const catalog = feeCatalog();
  assert.equal(catalog.equipment.minimumFeeByCurrency.CAD.amount, 25);
  assert.deepEqual(
      catalog.equipment.tiers.map((tier) => tier.feePercent),
      [5, 3, 2, 1],
  );
});
