"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  stripeCheckoutRequestSnapshot,
  stripeFormRequest,
} = require("../stripe_checkout_commands");

async function rejectedRequest(
    status,
    stripeCode = "test_failure",
    stripeType = "",
) {
  const originalFetch = global.fetch;
  global.fetch = async () => ({
    ok: false,
    status,
    json: async () => ({error: {code: stripeCode, type: stripeType}}),
  });
  try {
    await stripeFormRequest({
      secretKey: "sk_test_placeholder",
      path: "/v1/checkout/sessions",
      fields: {mode: "subscription"},
      idempotencyKey: "test-attempt-1",
    });
    assert.fail("Expected Stripe request to fail");
  } catch (error) {
    return error;
  } finally {
    global.fetch = originalFetch;
  }
}

test("Stripe 4xx is classified as a definitive non-creation response", async () => {
  const error = await rejectedRequest(400);
  assert.equal(error.details.stripeRequestDefinitiveFailure, true);
  assert.equal(error.details.stripeHttpStatus, 400);
});

test("Stripe 5xx is classified as ambiguous for idempotent retry", async () => {
  const error = await rejectedRequest(500);
  assert.equal(error.details.stripeRequestDefinitiveFailure, false);
  assert.equal(error.details.stripeHttpStatus, 500);
});

test("Stripe 409 keeps the same idempotency attempt reserved", async () => {
  const error = await rejectedRequest(409);
  assert.equal(error.details.stripeRequestDefinitiveFailure, false);
  assert.equal(error.details.stripeHttpStatus, 409);
});

test("Stripe 400 idempotency errors remain ambiguous", async () => {
  const error = await rejectedRequest(400, "idempotency_error");
  assert.equal(error.details.stripeRequestDefinitiveFailure, false);
  assert.equal(error.details.stripeHttpStatus, 400);
  assert.equal(error.details.stripeCode, "idempotency_error");
  const typedError = await rejectedRequest(
      400,
      "parameter_mismatch",
      "idempotency_error",
  );
  assert.equal(typedError.details.stripeRequestDefinitiveFailure, false);
});

test("Stripe retry snapshots reject malformed or mutable request shapes", () => {
  const source = {mode: "subscription", "line_items[0][quantity]": 1};
  const snapshot = stripeCheckoutRequestSnapshot(source);
  source.mode = "payment";
  assert.deepEqual(snapshot, {
    mode: "subscription",
    "line_items[0][quantity]": 1,
  });
  assert.throws(() => stripeCheckoutRequestSnapshot({nested: {bad: true}}));
  assert.throws(() => stripeCheckoutRequestSnapshot({}));
});

test("network failure remains an unclassified ambiguous outcome", async () => {
  const originalFetch = global.fetch;
  global.fetch = async () => {
    throw new TypeError("network unavailable");
  };
  try {
    await assert.rejects(() => stripeFormRequest({
      secretKey: "sk_test_placeholder",
      path: "/v1/checkout/sessions",
      fields: {mode: "subscription"},
      idempotencyKey: "test-attempt-2",
    }), (error) => error instanceof TypeError && error.details === undefined);
  } finally {
    global.fetch = originalFetch;
  }
});
