"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  legacyMigrationBlockingReasons,
  migrationIdempotencyKey,
  migrationTransactionPatch,
  requireMigrationIdentity,
  saleUsesStripeSellerSettlement,
} = require("../stripe_provider_migration");

test("legacy migration idempotency is stable and environment-specific", () => {
  const sandbox = migrationIdempotencyKey(
      "seller-1",
      "acct_legacy_1",
      "sandbox",
  );
  assert.equal(
      sandbox,
      migrationIdempotencyKey("seller-1", "acct_legacy_1", "sandbox"),
  );
  assert.notEqual(
      sandbox,
      migrationIdempotencyKey("seller-1", "acct_legacy_1", "production"),
  );
});

test("only seller-settlement Stripe history is annotated", () => {
  assert.equal(saleUsesStripeSellerSettlement({}), false);
  assert.equal(saleUsesStripeSellerSettlement({
    paymentProvider: "stripe",
    settlementMode: "external_settlement",
    stripeMarketplaceFeeSessionId: "cs_fee_only",
  }), false);
  assert.equal(saleUsesStripeSellerSettlement({
    paymentProvider: "stripe",
    stripeChargeId: "ch_1",
  }), true);
  assert.deepEqual(migrationTransactionPatch({
    paymentProvider: "stripe",
    stripeChargeId: "ch_1",
    paymentProviderStatus: "paid",
    sellerPayoutStatus: "released",
  }, "acct_legacy_1", "sandbox"), {
    stripeMode: "sandbox",
    stripeSellerDestinationAccountId: "acct_legacy_1",
  });
});

test("historical transaction mode and destination conflicts fail closed", () => {
  assert.throws(() => migrationTransactionPatch({
    paymentProvider: "stripe",
    stripeChargeId: "ch_1",
    stripeMode: "production",
  }, "acct_legacy_1", "sandbox"), /different Stripe environment/u);
  assert.throws(() => migrationTransactionPatch({
    paymentProvider: "stripe",
    stripeChargeId: "ch_1",
    stripeMode: "sandbox",
    stripeSellerDestinationAccountId: "acct_other",
  }, "acct_legacy_1", "sandbox"), /different seller payout account/u);
});

test("unsettled, held, refund and dispute records block cutover", () => {
  assert.deepEqual(legacyMigrationBlockingReasons({
    paymentProvider: "stripe",
    paymentProviderStatus: "paid",
    stripeChargeId: "ch_1",
    sellerPayoutStatus: "released",
  }), []);
  assert.ok(legacyMigrationBlockingReasons({
    paymentProvider: "stripe",
    paymentProviderStatus: "paid",
    stripeChargeId: "ch_1",
    sellerPayoutStatus: "pending_release",
  }).includes("seller_proceeds_not_released"));
  assert.ok(legacyMigrationBlockingReasons({
    paymentProvider: "stripe",
    stripeChargeId: "ch_hold",
    financialHold: true,
  }).includes("financial_hold"));
  assert.ok(legacyMigrationBlockingReasons({
    paymentProvider: "stripe",
    stripeChargeId: "ch_refund",
    refundStatus: "pending",
  }).includes("refund_history_or_request"));
  assert.ok(legacyMigrationBlockingReasons({
    paymentProvider: "stripe",
    stripeChargeId: "ch_dispute",
    disputeStatus: "open",
  }).includes("dispute_history_or_case"));
});

test("migration identity binds both account IDs and both modes", () => {
  const provider = {legacyMigration: {
    uid: "seller-1",
    legacyAccountId: "acct_old",
    legacyMode: "sandbox",
    replacementAccountId: "acct_new",
    replacementMode: "sandbox",
  }};
  assert.equal(requireMigrationIdentity({
    provider,
    uid: "seller-1",
    legacyAccountId: "acct_old",
    replacementAccountId: "acct_new",
    mode: "sandbox",
  }), provider.legacyMigration);
  assert.throws(() => requireMigrationIdentity({
    provider,
    uid: "seller-1",
    legacyAccountId: "acct_old",
    replacementAccountId: "acct_new",
    mode: "production",
  }), /migration identity changed/u);
});
