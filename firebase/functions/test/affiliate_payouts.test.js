"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {createAffiliatePayouts} = require("../affiliate_payouts");

function adminWithReadiness(readiness) {
  function firestore() {
    return {
      collection(name) {
        if (name !== "platform_configuration") {
          throw new Error(`Unexpected collection access: ${name}`);
        }
        return {
          doc(id) {
            assert.equal(id, "payment_provider_readiness");
            return {
              async get() {
                return {
                  exists: true,
                  data: () => readiness,
                };
              },
            };
          },
        };
      },
    };
  }
  firestore.FieldValue = {};
  firestore.Timestamp = {
    now: () => ({toMillis: () => Date.now()}),
  };
  return {firestore};
}

test("affiliate payout executor remains off when economics are not approved", async () => {
  const payouts = createAffiliatePayouts(adminWithReadiness({
    affiliatePayoutsEnabled: true,
    affiliatePayoutEconomicsReady: false,
    stripeMode: "production",
  }));
  assert.deepEqual(await payouts.payoutReadiness(), {
    enabled: true,
    economicsReady: false,
    stripeMode: "production",
  });
  assert.deepEqual(await payouts.processEligibleAffiliatePayouts(), {
    enabled: false,
    economicsReady: false,
    processed: 0,
  });
});

test("affiliate economics approval alone does not enable payouts", async () => {
  const payouts = createAffiliatePayouts(adminWithReadiness({
    affiliatePayoutsEnabled: false,
    affiliatePayoutEconomicsReady: true,
    stripeMode: "production",
  }));
  assert.deepEqual(await payouts.processEligibleAffiliatePayouts(), {
    enabled: false,
    economicsReady: true,
    processed: 0,
  });
});
