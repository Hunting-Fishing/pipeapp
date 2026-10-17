"use strict";

const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");

const checkoutSource = fs.readFileSync(
    path.join(__dirname, "..", "stripe_checkout_commands.js"),
    "utf8",
);
const webhookSource = fs.readFileSync(
    path.join(__dirname, "..", "stripe_webhook.js"),
    "utf8",
);
const externalSettlementSource = fs.readFileSync(
    path.join(__dirname, "..", "external_settlement_commands.js"),
    "utf8",
);

test("marketplace checkout reserves before any Stripe session creation", () => {
  const reservationWrite = checkoutSource.indexOf(
      "paymentProviderStatus: \"checkout_creating\"",
  );
  const stripeCreation = checkoutSource.indexOf(
      "session = await stripeFormRequest",
      reservationWrite,
  );
  assert.ok(reservationWrite > 0);
  assert.ok(stripeCreation > reservationWrite);
  assert.match(checkoutSource, /stripeCheckoutRequestSnapshot: fields/);
  assert.match(checkoutSource, /stripeCheckoutIdempotencyKey: idempotencyKey/);
  assert.match(checkoutSource, /settlementGeneration/);
});

test("marketplace checkout finalization compares the active reservation", () => {
  assert.match(
      checkoutSource,
      /currentStatus !== "checkout_creating"[\s\S]*stripeCheckoutAttemptId/,
  );
  assert.match(
      checkoutSource,
      /sameStripeCheckoutRequestSnapshot\([\s\S]*reservation\.fields/,
  );
  assert.match(
      checkoutSource,
      /stripeRequestDefinitiveFailure === true[\s\S]*"failed"/,
  );
});

test("marketplace webhooks bind under hold, replay, refetch, and CAS final state", () => {
  assert.match(webhookSource, /assertMarketplaceCheckoutSessionIdentity/);
  assert.match(webhookSource, /assertMarketplaceFeeCheckoutSessionIdentity/);
  assert.match(
      webhookSource,
      /db\.runTransaction\([\s\S]*paymentProviderStatus: "settlement_reconciling"[\s\S]*financialHold: true/,
  );
  assert.match(
      webhookSource,
      /stripeSettlementReconciliationId: reconciliationId/,
  );
  assert.match(
      webhookSource,
      /resolveUnmatchedFinancialEvents\(chargeId, transactionId\)[\s\S]*refreshedPaymentIntent = await readPaymentIntent/,
  );
  assert.match(
      webhookSource,
      /currentData\.stripeSettlementReconciliationId !== reconciliationId[\s\S]*const paymentProviderStatus = [\s\S]*firestoreTransaction\.set\(transactionRef, \{[\s\S]*paymentProviderStatus,[\s\S]*sellerPayoutStatus: financialHold/,
  );
});

test("fee checkout probes stored sessions and atomically replaces only expiry", () => {
  const retrieval = externalSettlementSource.indexOf(
      "path: `/v1/checkout/sessions/${encodeURIComponent(",
  );
  const replacement = externalSettlementSource.indexOf(
      "stripeMarketplaceFeeExpiredSessionId:",
      retrieval,
  );
  const creation = externalSettlementSource.indexOf(
      "session = await stripeFormRequest",
      replacement,
  );
  assert.ok(retrieval > 0);
  assert.ok(replacement > retrieval);
  assert.ok(creation > replacement);
  assert.match(
      externalSettlementSource,
      /externalFeeCheckoutMatchesReservation\([\s\S]*expiredReservation/,
  );
  assert.match(
      externalSettlementSource,
      /replacementAttemptId[\s\S]*marketplaceFeeStatus: "checkout_creating"/,
  );
});

