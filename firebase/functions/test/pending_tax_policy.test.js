"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  automaticTaxEnabled,
  provisionalTaxReserveMinor,
  taxBillingPrepared,
  taxCollectionStatus,
} = require("../pending_tax_policy");

test("registered tax status enables Stripe automatic tax and billing", () => {
  const readiness = {stripeTaxReady: true};
  assert.equal(taxCollectionStatus(readiness), "registered");
  assert.equal(taxBillingPrepared(readiness), true);
  assert.equal(automaticTaxEnabled(readiness), true);
  assert.equal(provisionalTaxReserveMinor(10000, "registered"), 0);
});

test("pending registration alone does not authorize billing", () => {
  const readiness = {stripeTaxRegistrationPending: true};
  assert.equal(taxCollectionStatus(readiness), "registration_pending");
  assert.equal(taxBillingPrepared(readiness), false);
  assert.equal(automaticTaxEnabled(readiness), false);
  assert.equal(provisionalTaxReserveMinor(10000, "registration_pending"), 1500);
});

test("separately approved pending registration can authorize billing without automatic tax", () => {
  const readiness = {
    stripeTaxRegistrationPending: true,
    stripeTaxPendingBillingApproved: true,
  };
  assert.equal(taxCollectionStatus(readiness), "registration_pending");
  assert.equal(taxBillingPrepared(readiness), true);
  assert.equal(automaticTaxEnabled(readiness), false);
});

test("reserve rounds upward by a cent when required", () => {
  assert.equal(provisionalTaxReserveMinor(101, "registration_pending"), 16);
});

test("no tax state creates no reserve or billing authority", () => {
  assert.equal(taxCollectionStatus({}), "not_ready");
  assert.equal(taxBillingPrepared({}), false);
  assert.equal(automaticTaxEnabled({}), false);
  assert.equal(provisionalTaxReserveMinor(10000, "not_ready"), 0);
});
