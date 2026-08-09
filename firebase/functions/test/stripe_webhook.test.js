"use strict";

const crypto = require("node:crypto");
const test = require("node:test");
const assert = require("node:assert/strict");
const {
  SIGNATURE_TOLERANCE_SECONDS,
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
