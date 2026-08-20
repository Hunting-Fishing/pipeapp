"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  validateDispatchQuoteBreakdown,
} = require("../dispatch_command_policy");

function breakdown(overrides = {}) {
  return {
    name: "GP to Dawson Creek",
    origin: "Grande Prairie",
    destination: "Dawson Creek",
    distanceKm: 100,
    deadheadKm: 0,
    mileageRate: 2,
    deadheadRate: 0,
    weightKg: 0,
    weightRate: 0,
    hours: 0,
    hourlyRate: 0,
    areaFee: 0,
    pilotCount: 0,
    pilotKmRate: 0,
    pilotHourlyRate: 0,
    pilotAreaFee: 0,
    permitFee: 0,
    baseFee: 50,
    surchargePercent: 10,
    taxPercent: 5,
    manualTotal: 0,
    manual: false,
    currency: "CAD",
    formulaVersion: 2,
    ...overrides,
  };
}

test("Dispatch quote v2 recalculates the submitted total on the server", () => {
  const result = validateDispatchQuoteBreakdown(
      {quoteBreakdown: breakdown(), currency: "CAD"},
      288.75,
  );
  assert.equal(result.currency, "CAD");
  assert.equal(result.quoteBreakdown.subtotal, 250);
  assert.equal(result.quoteBreakdown.surcharge, 25);
  assert.equal(result.quoteBreakdown.tax, 13.75);
  assert.equal(result.quoteBreakdown.total, 288.75);
});

test("Dispatch quote v2 rejects a client total that does not match the formula", () => {
  assert.throws(
      () => validateDispatchQuoteBreakdown(
          {quoteBreakdown: breakdown(), currency: "CAD"},
          999,
      ),
      (error) => error &&
        error.code === "failed-precondition" &&
        /server-calculated quote form/.test(error.message),
  );
});

test("Dispatch quote v2 keeps manual override auditable", () => {
  const result = validateDispatchQuoteBreakdown(
      {
        quoteBreakdown: breakdown({manual: true, manualTotal: 325}),
        currency: "USD",
      },
      325,
  );
  assert.equal(result.currency, "USD");
  assert.equal(result.quoteBreakdown.manual, true);
  assert.equal(result.quoteBreakdown.subtotal, 250);
  assert.equal(result.quoteBreakdown.total, 325);
});

test("Dispatch quote v2 rejects unsupported currency", () => {
  assert.throws(
      () => validateDispatchQuoteBreakdown(
          {quoteBreakdown: breakdown({currency: "EUR"}), currency: "EUR"},
          288.75,
      ),
      (error) => error && error.code === "invalid-argument",
  );
});
