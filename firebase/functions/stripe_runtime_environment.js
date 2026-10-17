"use strict";

const {HttpsError} = require("firebase-functions/v2/https");

const STRIPE_SECRET_PRODUCTION_NAME = "STRIPE_SECRET_PRODUCTION";
const STRIPE_SECRET_SANDBOX_NAME = "STRIPE_SECRET_SANDBOX";
const ACTIVE_STRIPE_MODES = new Set(["sandbox", "production"]);

function stripeEnvironmentError(message) {
  return new HttpsError("failed-precondition", message);
}

function normalizeActiveStripeMode(value) {
  const mode = String(value || "").trim().toLowerCase();
  if (!ACTIVE_STRIPE_MODES.has(mode)) {
    throw stripeEnvironmentError(
        "Stripe money movement requires an explicit sandbox or production mode.",
    );
  }
  return mode;
}

function createSecretBinding(name, mode) {
  return Object.freeze({
    name,
    mode,
    value() {
      const value = String(process.env[name] || "").trim();
      if (!value) {
        throw stripeEnvironmentError(
            `Stripe ${mode} payment credentials are unavailable.`,
        );
      }
      return value;
    },
  });
}

const stripeProductionSecret = createSecretBinding(
    STRIPE_SECRET_PRODUCTION_NAME,
    "production",
);
const stripeSandboxSecret = createSecretBinding(
    STRIPE_SECRET_SANDBOX_NAME,
    "sandbox",
);
const stripeSecretBindings = Object.freeze({
  production: stripeProductionSecret,
  sandbox: stripeSandboxSecret,
});
const stripeSecretNames = Object.freeze([
  STRIPE_SECRET_PRODUCTION_NAME,
  STRIPE_SECRET_SANDBOX_NAME,
]);

function stripeKeyMode(value) {
  const key = String(value || "").trim();
  if (/^(?:sk|rk)_live_/u.test(key)) return "production";
  if (/^(?:sk|rk)_test_/u.test(key)) return "sandbox";
  return "unknown";
}

function assertStripeSecretMatchesMode(secretValue, expectedMode) {
  const mode = normalizeActiveStripeMode(expectedMode);
  if (stripeKeyMode(secretValue) !== mode) {
    throw stripeEnvironmentError(
        `Stripe ${mode} credentials do not match the selected payment mode.`,
    );
  }
  return String(secretValue).trim();
}

function stripeSecretBindingForMode(mode) {
  return stripeSecretBindings[normalizeActiveStripeMode(mode)];
}

function stripeSecretValueForMode(mode, options = {}) {
  const activeMode = normalizeActiveStripeMode(mode);
  const binding = stripeSecretBindingForMode(activeMode);
  const readSecret = typeof options.readSecret === "function" ?
    options.readSecret : () => binding.value();
  return assertStripeSecretMatchesMode(readSecret(binding.name), activeMode);
}

function requireStoredStripeMode({expectedMode, storedMode, subject}) {
  const expected = normalizeActiveStripeMode(expectedMode);
  const actual = String(storedMode || "").trim().toLowerCase();
  if (actual !== expected) {
    throw stripeEnvironmentError(
        `${String(subject || "Stripe record")} belongs to a different Stripe environment.`,
    );
  }
  return expected;
}

function requireStripeProviderMode(provider, expectedMode) {
  const record = provider && typeof provider === "object" ? provider : {};
  return requireStoredStripeMode({
    expectedMode,
    storedMode: record.mode,
    subject: "Seller payout account",
  });
}

function requireStripeTransactionMode(transaction, expectedMode) {
  const record = transaction && typeof transaction === "object" ?
    transaction : {};
  return requireStoredStripeMode({
    expectedMode,
    storedMode: record.stripeMode,
    subject: "Marketplace transaction",
  });
}

module.exports = {
  ACTIVE_STRIPE_MODES,
  STRIPE_SECRET_PRODUCTION_NAME,
  STRIPE_SECRET_SANDBOX_NAME,
  assertStripeSecretMatchesMode,
  normalizeActiveStripeMode,
  requireStoredStripeMode,
  requireStripeProviderMode,
  requireStripeTransactionMode,
  stripeKeyMode,
  stripeProductionSecret,
  stripeSandboxSecret,
  stripeSecretBindingForMode,
  stripeSecretBindings,
  stripeSecretNames,
  stripeSecretValueForMode,
};
