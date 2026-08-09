"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  evidenceHash,
  normalizeEvidence,
} = require("../stripe_dispute_response");
const {
  isStripeDisputeId,
} = require("../marketplace_stripe_financial_api");
const {
  disputeOutcome,
} = require("../marketplace_financial_resolution");

test("Stripe dispute identifiers use the current du_ object prefix", () => {
  assert.equal(isStripeDisputeId("du_1MtJUT2eZvKYlo2CNaw2HvEv"), true);
  assert.equal(isStripeDisputeId("dp_legacy"), false);
  assert.equal(isStripeDisputeId("ch_123"), false);
});

test("terminal dispute outcomes remain terminal across later events", () => {
  assert.equal(disputeOutcome("won"), "won");
  assert.equal(disputeOutcome("lost"), "lost");
  assert.equal(disputeOutcome("warning_closed"), "warning_closed");
  assert.equal(disputeOutcome("under_review"), "open");
});

test("physical-goods dispute evidence accepts text and Stripe file IDs", () => {
  const evidence = normalizeEvidence({
    product_description: "500 joints of 4.5 inch inspected casing",
    shipping_tracking_number: "LOAD-8821",
    shipping_documentation: "file_ABC123",
  });
  assert.deepEqual(Object.keys(evidence).sort(), [
    "product_description",
    "shipping_documentation",
    "shipping_tracking_number",
  ]);
  assert.equal(evidenceHash(evidence).length, 64);
});

test("unsupported or non-Stripe evidence files are rejected", () => {
  assert.throws(
      () => normalizeEvidence({shipping_documentation: "https://example.com/proof.pdf"}),
      /Stripe dispute-evidence file ID/u,
  );
  assert.throws(
      () => normalizeEvidence({bank_password: "nope"}),
      /not approved/u,
  );
});
