"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  automaticTaxEnabled,
  provisionalTaxReserveMinor,
  taxCollectionStatus,
} = require("../pending_tax_policy");

test("registered tax status enables Stripe automatic tax", () => {
  const readiness = {stripeTaxReady: true};
  assert.equal(taxCollectionStatus(readiness), "registered");
  assert.equal(automaticTaxEnabled(readiness), true);
  assert.equal(provisionalTaxReserveMinor(10000, "registered"), 0);
});

test("pending registration disables automatic tax and reserves fifteen percent", () => {
  const readiness = {stripeTaxRegistrationPending: true};
  assert.equal(taxCollectionStatus(readiness), "registration_pending");
  assert.equal(automaticTaxEnabled(readiness), false);
  assert.equal(provisionalTaxReserveMinor(10000, "registration_pending"), 1500);
});

test("reserve rounds upward by a cent when required", () => {
  assert.equal(provisionalTaxReserveMinor(101, "registration_pending"), 16);
});

test("no tax state creates no reserve", () => {
  assert.equal(taxCollectionStatus({}), "not_ready");
  assert.equal(automaticTaxEnabled({}), false);
  assert.equal(provisionalTaxReserveMinor(10000, "not_ready"), 0);
});
