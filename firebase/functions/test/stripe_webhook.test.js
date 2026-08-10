"use strict";

const crypto = require("node:crypto");
const test = require("node:test");
const assert = require("node:assert/strict");
const {
  SIGNATURE_TOLERANCE_SECONDS,
  chargeEconomics,
  verifyStripeSignature,
} = require("../stripe_webhook");

function signature(body, secret, timestamp) {
  return crypto.createHmac("sha256", secret)
      .update(`${timestamp}.${body.toString("utf8")}`)
      .digest("hex");
}

test("accepts a valid Stripe v1 webhook signature", () => {
  const body = Buffer.from(JSON.stringify({id: "evt_test", type: "test"}));
  const secret = "whsec_test_secret";
  const timestamp = 2000000000;
  const header = `t=${timestamp},v1=${signature(body, secret, timestamp)}`;
  assert.equal(
      verifyStripeSignature(body, header, secret, timestamp + 30),
      true,
  );
});

test("rejects a webhook signed with the wrong secret", () => {
  const body = Buffer.from("{\"id\":\"evt_test\"}");
  const timestamp = 2000000000;
  const header = `t=${timestamp},v1=${signature(body, "wrong", timestamp)}`;
  assert.equal(
      verifyStripeSignature(body, header, "correct", timestamp),
      false,
  );
});

test("rejects stale webhook signatures", () => {
  const body = Buffer.from("{\"id\":\"evt_test\"}");
  const secret = "whsec_test_secret";
  const timestamp = 2000000000;
  const header = `t=${timestamp},v1=${signature(body, secret, timestamp)}`;
  assert.equal(
      verifyStripeSignature(
          body,
          header,
          secret,
          timestamp + SIGNATURE_TOLERANCE_SECONDS + 1,
      ),
      false,
  );
});

test("rejects a modified payload", () => {
  const original = Buffer.from("{\"id\":\"evt_original\"}");
  const modified = Buffer.from("{\"id\":\"evt_modified\"}");
  const secret = "whsec_test_secret";
  const timestamp = 2000000000;
  const header = `t=${timestamp},v1=${signature(original, secret, timestamp)}`;
  assert.equal(
      verifyStripeSignature(modified, header, secret, timestamp),
      false,
  );
});

test("reads actual Stripe provider fee from expanded balance transaction", () => {
  const economics = chargeEconomics({
    latest_charge: {
      id: "ch_live_example",
      balance_transaction: {
        id: "txn_live_example",
        fee: 2930,
        net: 97070,
        currency: "cad",
      },
    },
  }, "CAD");
  assert.equal(economics.chargeId, "ch_live_example");
  assert.equal(economics.balanceTransactionId, "txn_live_example");
  assert.equal(economics.providerFeeMinor, 2930);
  assert.equal(economics.netChargeImpactMinor, 97070);
  assert.equal(economics.currency, "CAD");
});

test("fails closed when Stripe settlement currency does not match", () => {
  assert.throws(() => chargeEconomics({
    latest_charge: {
      id: "ch_live_example",
      balance_transaction: {
        id: "txn_live_example",
        fee: 2930,
        net: 97070,
        currency: "usd",
      },
    },
  }, "CAD"), /financial review/);
});

test("fails closed when Stripe provider fee details are unavailable", () => {
  assert.throws(() => chargeEconomics({
    latest_charge: {
      id: "ch_live_example",
      balance_transaction: "txn_not_expanded",
    },
  }, "CAD"), /fee details are unavailable/);
});
