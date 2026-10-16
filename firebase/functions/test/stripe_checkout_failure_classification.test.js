"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  assertMarketplaceCheckoutSessionIdentity,
  hasExternalSettlementState,
  marketplaceCheckoutAttemptId,
  marketplaceCheckoutIdempotencyKey,
  marketplaceCheckoutReservationFromSale,
  marketplaceExecutionCurrency,
  sameStripeCheckoutRequestSnapshot,
  stripeCheckoutRequestSnapshot,
  stripeCheckoutSessionState,
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

test("marketplace checkout attempts have stable isolated idempotency keys", () => {
  const first = marketplaceCheckoutAttemptId("transaction_1", 1, 1);
  const retry = marketplaceCheckoutAttemptId("transaction_1", 1, 1);
  const next = marketplaceCheckoutAttemptId("transaction_1", 1, 2);
  assert.equal(first, retry);
  assert.notEqual(first, next);
  assert.equal(
      marketplaceCheckoutIdempotencyKey(first),
      `pipebuyer-checkout-${first}`,
  );
});

test("marketplace monetary execution requires explicit CAD or USD", () => {
  assert.equal(
      marketplaceExecutionCurrency({currency: "USD"}, {currency: "USD"}),
      "usd",
  );
  assert.equal(marketplaceExecutionCurrency({}, {currency: "CAD"}), "cad");
  assert.throws(() => marketplaceExecutionCurrency({}, {}), /no supported currency/u);
  assert.throws(
      () => marketplaceExecutionCurrency(
          {currency: "USD"},
          {currency: "CAD"},
      ),
      /do not match/u,
  );
  assert.throws(
      () => marketplaceExecutionCurrency({currency: "EUR"}, {}),
      /no supported currency/u,
  );
});

test("stored Checkout sessions distinguish reusable and expired URLs", () => {
  assert.deepEqual(stripeCheckoutSessionState({
    status: "open",
    url: "https://checkout.stripe.com/c/pay/test",
  }), {
    state: "open",
    checkoutUrl: "https://checkout.stripe.com/c/pay/test",
  });
  assert.deepEqual(stripeCheckoutSessionState({status: "expired"}), {
    state: "expired",
    checkoutUrl: null,
  });
  assert.deepEqual(stripeCheckoutSessionState({
    status: "complete",
    url: "https://checkout.stripe.com/c/pay/test",
  }), {
    state: "pending",
    checkoutUrl: null,
  });
});

test("reserved checkout resumes only its immutable request and generation", () => {
  const attemptId = marketplaceCheckoutAttemptId("transaction_1", 1, 1);
  const fields = stripeCheckoutRequestSnapshot({
    mode: "payment",
    "metadata[pipeBuyerCheckoutAttemptId]": attemptId,
  });
  const reservation = marketplaceCheckoutReservationFromSale({
    settlementMode: "stripe_checkout",
    settlementGeneration: 4,
    stripeCheckoutAttemptId: attemptId,
    stripeCheckoutAttemptNumber: 1,
    stripeCheckoutIdempotencyKey: marketplaceCheckoutIdempotencyKey(attemptId),
    stripeCheckoutRequestSnapshot: fields,
  });
  assert.equal(reservation.attemptId, attemptId);
  assert.equal(reservation.settlementGeneration, 4);
  assert.equal(sameStripeCheckoutRequestSnapshot(reservation.fields, fields), true);
  assert.equal(sameStripeCheckoutRequestSnapshot(
      reservation.fields,
      {...fields, mode: "subscription"},
  ), false);
  assert.throws(() => marketplaceCheckoutReservationFromSale({
    settlementMode: "stripe_checkout",
    settlementGeneration: 5,
    stripeCheckoutAttemptId: attemptId,
    stripeCheckoutAttemptNumber: 1,
    stripeCheckoutIdempotencyKey: "different",
    stripeCheckoutRequestSnapshot: fields,
  }));
});

test("marketplace checkout session must match active attempt and generation", () => {
  const attemptId = marketplaceCheckoutAttemptId("transaction_1", 1, 1);
  const sale = {
    settlementMode: "stripe_checkout",
    settlementGeneration: 3,
    stripeCheckoutAttemptId: attemptId,
  };
  const session = {
    id: "cs_current",
    metadata: {
      pipeBuyerTransactionId: "transaction_1",
      pipeBuyerCheckoutAttemptId: attemptId,
      pipeBuyerSettlementGeneration: "3",
    },
  };
  assert.deepEqual(assertMarketplaceCheckoutSessionIdentity({
    sale,
    session,
    transactionId: "transaction_1",
  }), {sessionId: "cs_current", attemptId});
  assert.throws(() => assertMarketplaceCheckoutSessionIdentity({
    sale,
    session: {
      ...session,
      metadata: {
        ...session.metadata,
        pipeBuyerSettlementGeneration: "2",
      },
    },
    transactionId: "transaction_1",
  }));
  assert.throws(() => assertMarketplaceCheckoutSessionIdentity({
    sale: {...sale, stripeCheckoutSessionId: "cs_other"},
    session,
    transactionId: "transaction_1",
  }));
  assert.throws(() => assertMarketplaceCheckoutSessionIdentity({
    sale: {...sale, status: "cancelled"},
    session,
    transactionId: "transaction_1",
  }));
});

test("legacy checkout identity requires the exact stored Stripe session", () => {
  const session = {
    id: "cs_legacy",
    metadata: {pipeBuyerTransactionId: "transaction_legacy"},
  };
  assert.doesNotThrow(() => assertMarketplaceCheckoutSessionIdentity({
    sale: {stripeCheckoutSessionId: "cs_legacy"},
    session,
    transactionId: "transaction_legacy",
  }));
  assert.throws(() => assertMarketplaceCheckoutSessionIdentity({
    sale: {stripeCheckoutSessionId: "cs_different"},
    session,
    transactionId: "transaction_legacy",
  }));
});

test("full checkout rejects every external settlement marker", () => {
  for (const sale of [
    {settlementMode: "external_settlement"},
    {paymentMethod: "external_settlement"},
    {paymentProvider: "external"},
    {paymentProviderStatus: "external_agreed"},
    {externalSettlementBuyerConfirmed: true},
    {externalSettlementSellerConfirmed: true},
    {externalSettlementAgreedAt: "timestamp"},
  ]) {
    assert.equal(hasExternalSettlementState(sale), true);
  }
  assert.equal(hasExternalSettlementState({
    settlementMode: "stripe_checkout",
    paymentProviderStatus: "checkout_creating",
  }), false);
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
