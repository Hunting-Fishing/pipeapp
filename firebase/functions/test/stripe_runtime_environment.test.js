"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  STRIPE_SECRET_PRODUCTION_NAME,
  STRIPE_SECRET_SANDBOX_NAME,
  assertStripeSecretMatchesMode,
  requireStripeProviderMode,
  requireStripeTransactionMode,
  stripeKeyMode,
  stripeSecretBindingForMode,
  stripeSecretNames,
  stripeSecretValueForMode,
} = require("../stripe_runtime_environment");

test("Stripe secret bindings are isolated by readiness mode", () => {
  assert.deepEqual(stripeSecretNames, [
    STRIPE_SECRET_PRODUCTION_NAME,
    STRIPE_SECRET_SANDBOX_NAME,
  ]);
  assert.equal(
      stripeSecretBindingForMode("production").name,
      STRIPE_SECRET_PRODUCTION_NAME,
  );
  assert.equal(
      stripeSecretBindingForMode("sandbox").name,
      STRIPE_SECRET_SANDBOX_NAME,
  );
  assert.throws(
      () => stripeSecretBindingForMode("disabled"),
      /explicit sandbox or production mode/u,
  );
});

test("Stripe key classes fail closed across environments", () => {
  assert.equal(stripeKeyMode("rk_live_example"), "production");
  assert.equal(stripeKeyMode("sk_test_example"), "sandbox");
  assert.equal(stripeKeyMode("not-a-key"), "unknown");
  assert.equal(
      assertStripeSecretMatchesMode("rk_live_example", "production"),
      "rk_live_example",
  );
  assert.equal(
      assertStripeSecretMatchesMode("rk_test_example", "sandbox"),
      "rk_test_example",
  );
  assert.throws(
      () => assertStripeSecretMatchesMode("sk_live_wrong", "sandbox"),
      /do not match/u,
  );
  assert.throws(
      () => assertStripeSecretMatchesMode("sk_test_wrong", "production"),
      /do not match/u,
  );
});

test("sandbox selection never reads the production binding", () => {
  const reads = [];
  const value = stripeSecretValueForMode("sandbox", {
    readSecret(name) {
      reads.push(name);
      return name === STRIPE_SECRET_SANDBOX_NAME ?
        "rk_test_sandbox" : "rk_live_production";
    },
  });
  assert.equal(value, "rk_test_sandbox");
  assert.deepEqual(reads, [STRIPE_SECRET_SANDBOX_NAME]);
});

test("provider and transaction modes must match the active readiness mode", () => {
  assert.equal(requireStripeProviderMode({mode: "sandbox"}, "sandbox"), "sandbox");
  assert.equal(
      requireStripeTransactionMode({stripeMode: "production"}, "production"),
      "production",
  );
  assert.throws(
      () => requireStripeProviderMode({mode: "production"}, "sandbox"),
      /different Stripe environment/u,
  );
  assert.throws(
      () => requireStripeTransactionMode({}, "sandbox"),
      /different Stripe environment/u,
  );
});
