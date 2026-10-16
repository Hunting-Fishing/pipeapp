"use strict";

const crypto = require("node:crypto");
const test = require("node:test");
const assert = require("node:assert/strict");
const {
  SIGNATURE_TOLERANCE_SECONDS,
  assertMarketplaceFeeCheckoutSessionIdentity,
  assertStripeCurrencyMatches,
  createStripeWebhookHandler,
  marketplaceCheckoutSessionIsActive,
  verifyStripeSignature,
} = require("../stripe_webhook");
const {
  createMarketplaceFinancialResolution,
} = require("../marketplace_financial_resolution");
const {
  createMarketplaceRefundWebhookGate,
} = require("../marketplace_refund_webhook_gate");
const {createMemoryAdmin} = require("./memory_firestore");

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

test("Stripe settlement currency is explicit, normalized, and exact", () => {
  assert.equal(assertStripeCurrencyMatches(" USD ", "usd", "Stripe"), "usd");
  assert.throws(
      () => assertStripeCurrencyMatches("", "usd", "Stripe"),
      /currency does not match/u,
  );
  assert.throws(
      () => assertStripeCurrencyMatches("cad", "usd", "Stripe"),
      /currency does not match/u,
  );
  assert.throws(
      () => assertStripeCurrencyMatches("usd", "", "Stripe"),
      /currency does not match/u,
  );
});

test("external fee webhook requires the active session and generation", () => {
  const sale = {
    paymentMethod: "external_settlement",
    settlementMode: "external_settlement",
    settlementGeneration: 7,
    stripeMarketplaceFeeSessionId: "cs_fee_current",
  };
  const session = {
    id: "cs_fee_current",
    metadata: {
      billingType: "marketplace_fee_only",
      pipeBuyerTransactionId: "transaction_1",
      pipeBuyerSettlementGeneration: "7",
    },
  };
  assert.deepEqual(assertMarketplaceFeeCheckoutSessionIdentity({
    sale,
    session,
    transactionId: "transaction_1",
  }), {
    sessionId: "cs_fee_current",
    settlementGeneration: 7,
    attemptId: null,
  });
  assert.throws(() => assertMarketplaceFeeCheckoutSessionIdentity({
    sale: {...sale, stripeMarketplaceFeeSessionId: "cs_fee_stale"},
    session,
    transactionId: "transaction_1",
  }));
  assert.throws(() => assertMarketplaceFeeCheckoutSessionIdentity({
    sale,
    session: {
      ...session,
      metadata: {
        ...session.metadata,
        pipeBuyerSettlementGeneration: "6",
      },
    },
    transactionId: "transaction_1",
  }));
});

test("fee webhook may bind the active reserved attempt before session storage", () => {
  const sale = {
    paymentMethod: "external_settlement",
    settlementMode: "external_settlement",
    settlementGeneration: 9,
    marketplaceFeeStatus: "checkout_creating",
    stripeMarketplaceFeeAttemptId: "fee_attempt_9",
    stripeMarketplaceFeeSettlementGeneration: 9,
    stripeMarketplaceFeeSessionId: null,
  };
  const session = {
    id: "cs_fee_race",
    metadata: {
      billingType: "marketplace_fee_only",
      pipeBuyerTransactionId: "transaction_9",
      pipeBuyerFeeCheckoutAttemptId: "fee_attempt_9",
      pipeBuyerSettlementGeneration: "9",
    },
  };
  assert.deepEqual(assertMarketplaceFeeCheckoutSessionIdentity({
    sale,
    session,
    transactionId: "transaction_9",
  }), {
    sessionId: "cs_fee_race",
    settlementGeneration: 9,
    attemptId: "fee_attempt_9",
  });
  assert.throws(() => assertMarketplaceFeeCheckoutSessionIdentity({
    sale,
    session: {
      ...session,
      metadata: {
        ...session.metadata,
        pipeBuyerFeeCheckoutAttemptId: "stale_attempt",
      },
    },
    transactionId: "transaction_9",
  }));
});

test("Checkout expiration identity rejects stale full and fee attempts", () => {
  const feeSale = {
    paymentMethod: "external_settlement",
    settlementMode: "external_settlement",
    settlementGeneration: 4,
    marketplaceFeeStatus: "checkout_created",
    stripeMarketplaceFeeAttemptId: "fee_attempt_current",
    stripeMarketplaceFeeSettlementGeneration: 4,
    stripeMarketplaceFeeSessionId: "cs_fee_current",
  };
  const staleFeeSession = {
    id: "cs_fee_stale",
    metadata: {
      billingType: "marketplace_fee_only",
      pipeBuyerTransactionId: "fee_transaction",
      pipeBuyerFeeCheckoutAttemptId: "fee_attempt_stale",
      pipeBuyerSettlementGeneration: "4",
    },
  };
  assert.equal(marketplaceCheckoutSessionIsActive({
    sale: feeSale,
    session: staleFeeSession,
    transactionId: "fee_transaction",
    feeOnly: true,
  }), false);

  const fullSale = {
    settlementMode: "stripe_checkout",
    settlementGeneration: 8,
    paymentProviderStatus: "checkout_created",
    stripeCheckoutAttemptId: "full_attempt_current",
    stripeCheckoutSessionId: "cs_full_current",
  };
  assert.equal(marketplaceCheckoutSessionIsActive({
    sale: fullSale,
    session: {
      id: "cs_full_stale",
      metadata: {
        pipeBuyerTransactionId: "full_transaction",
        pipeBuyerCheckoutAttemptId: "full_attempt_stale",
        pipeBuyerSettlementGeneration: "7",
      },
    },
    transactionId: "full_transaction",
    feeOnly: false,
  }), false);
});

async function deliverWebhook(handler, event, secret) {
  const rawBody = Buffer.from(JSON.stringify(event));
  const timestamp = Math.floor(Date.now() / 1000);
  const header = `t=${timestamp},v1=${signature(rawBody, secret, timestamp)}`;
  const result = {statusCode: null, body: null};
  await handler({
    rawBody,
    get: () => header,
  }, {
    status(code) {
      result.statusCode = code;
      return this;
    },
    send(body) {
      result.body = body;
      return this;
    },
  });
  return result;
}

test("expiration webhook fails only the active marketplace attempt", async () => {
  const secret = "whsec_expiration_test";
  const previousSecret = process.env.STRIPE_WEBHOOK_SECRET;
  process.env.STRIPE_WEBHOOK_SECRET = secret;
  try {
    const memory = createMemoryAdmin({
      "marketplace_transactions/fee_transaction": {
        paymentMethod: "external_settlement",
        settlementMode: "external_settlement",
        settlementGeneration: 4,
        marketplaceFeeStatus: "checkout_created",
        stripeMarketplaceFeeAttemptId: "fee_attempt_current",
        stripeMarketplaceFeeSettlementGeneration: 4,
        stripeMarketplaceFeeSessionId: "cs_fee_current",
      },
      "marketplace_transactions/full_transaction": {
        settlementMode: "stripe_checkout",
        settlementGeneration: 8,
        paymentProviderStatus: "checkout_created",
        stripeCheckoutAttemptId: "full_attempt_current",
        stripeCheckoutSessionId: "cs_full_current",
      },
    });
    const handler = createStripeWebhookHandler(memory.admin);
    const staleFeeResult = await deliverWebhook(handler, {
      id: "evt_fee_expired_stale",
      type: "checkout.session.expired",
      data: {object: {
        id: "cs_fee_stale",
        metadata: {
          billingType: "marketplace_fee_only",
          pipeBuyerTransactionId: "fee_transaction",
          pipeBuyerFeeCheckoutAttemptId: "fee_attempt_stale",
          pipeBuyerSettlementGeneration: "3",
        },
      }},
    }, secret);
    assert.equal(staleFeeResult.statusCode, 200);
    assert.equal(
        memory.read("marketplace_transactions/fee_transaction")
            .marketplaceFeeStatus,
        "checkout_created",
    );

    const activeFeeResult = await deliverWebhook(handler, {
      id: "evt_fee_expired_active",
      type: "checkout.session.expired",
      data: {object: {
        id: "cs_fee_current",
        metadata: {
          billingType: "marketplace_fee_only",
          pipeBuyerTransactionId: "fee_transaction",
          pipeBuyerFeeCheckoutAttemptId: "fee_attempt_current",
          pipeBuyerSettlementGeneration: "4",
        },
      }},
    }, secret);
    assert.equal(activeFeeResult.statusCode, 200);
    assert.equal(
        memory.read("marketplace_transactions/fee_transaction")
            .marketplaceFeeStatus,
        "payment_failed",
    );

    const staleFullResult = await deliverWebhook(handler, {
      id: "evt_full_expired_stale",
      type: "checkout.session.expired",
      data: {object: {
        id: "cs_full_stale",
        metadata: {
          pipeBuyerTransactionId: "full_transaction",
          pipeBuyerCheckoutAttemptId: "full_attempt_stale",
          pipeBuyerSettlementGeneration: "7",
        },
      }},
    }, secret);
    assert.equal(staleFullResult.statusCode, 200);
    assert.equal(
        memory.read("marketplace_transactions/full_transaction")
            .paymentProviderStatus,
        "checkout_created",
    );

    const activeFullResult = await deliverWebhook(handler, {
      id: "evt_full_expired_active",
      type: "checkout.session.expired",
      data: {object: {
        id: "cs_full_current",
        metadata: {
          pipeBuyerTransactionId: "full_transaction",
          pipeBuyerCheckoutAttemptId: "full_attempt_current",
          pipeBuyerSettlementGeneration: "8",
        },
      }},
    }, secret);
    assert.equal(activeFullResult.statusCode, 200);
    assert.equal(
        memory.read("marketplace_transactions/full_transaction")
            .paymentProviderStatus,
        "failed",
    );
  } finally {
    if (previousSecret == null) {
      delete process.env.STRIPE_WEBHOOK_SECRET;
    } else {
      process.env.STRIPE_WEBHOOK_SECRET = previousSecret;
    }
  }
});

test("marketplace settlement rejects Checkout and PaymentIntent currency drift", async () => {
  const secret = "whsec_currency_test";
  const previousWebhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
  const previousStripeSecret = process.env.STRIPE_SECRET_PRODUCTION;
  const originalFetch = global.fetch;
  process.env.STRIPE_WEBHOOK_SECRET = secret;
  process.env.STRIPE_SECRET_PRODUCTION = "sk_test_currency";
  global.fetch = async (url) => {
    const paymentIntentId = decodeURIComponent(
        String(url).split("/payment_intents/")[1].split("?")[0],
    );
    return {
      ok: true,
      json: async () => ({
        id: paymentIntentId,
        status: "succeeded",
        currency: paymentIntentId.includes("currency_bad") ? "cad" : "usd",
        latest_charge: `ch_${paymentIntentId}`,
      }),
    };
  };
  try {
    const feeSale = (sessionId, attemptId) => ({
      currency: "USD",
      paymentMethod: "external_settlement",
      settlementMode: "external_settlement",
      settlementGeneration: 3,
      marketplaceFeeStatus: "checkout_created",
      stripeMarketplaceFeeAttemptId: attemptId,
      stripeMarketplaceFeeSettlementGeneration: 3,
      stripeMarketplaceFeeSessionId: sessionId,
      marketplaceFeeSnapshot: {
        currency: "USD",
        marketplaceFeeMinor: 100,
      },
    });
    const fullSale = (sessionId, attemptId) => ({
      currency: "USD",
      settlementMode: "stripe_checkout",
      settlementGeneration: 4,
      paymentProviderStatus: "checkout_created",
      stripeCheckoutAttemptId: attemptId,
      stripeCheckoutSessionId: sessionId,
      marketplaceFeeSnapshot: {
        currency: "USD",
        agreedTotalMinor: 1000,
        marketplaceFeeMinor: 100,
        sellerProceedsBeforeTaxMinor: 900,
      },
    });
    const memory = createMemoryAdmin({
      "marketplace_transactions/fee_session_bad":
        feeSale("cs_fee_session_bad", "fee_attempt_session_bad"),
      "marketplace_transactions/fee_intent_bad":
        feeSale("cs_fee_intent_bad", "fee_attempt_intent_bad"),
      "marketplace_transactions/full_session_bad":
        fullSale("cs_full_session_bad", "full_attempt_session_bad"),
      "marketplace_transactions/full_intent_bad":
        fullSale("cs_full_intent_bad", "full_attempt_intent_bad"),
    });
    const handler = createStripeWebhookHandler(memory.admin);
    const feeSession = ({transactionId, sessionId, attemptId, currency,
      paymentIntentId}) => ({
      id: sessionId,
      currency,
      payment_status: "paid",
      amount_subtotal: 100,
      amount_total: 100,
      total_details: {amount_tax: 0},
      payment_intent: paymentIntentId,
      metadata: {
        billingType: "marketplace_fee_only",
        pipeBuyerTransactionId: transactionId,
        pipeBuyerFeeCheckoutAttemptId: attemptId,
        pipeBuyerSettlementGeneration: "3",
      },
    });
    const fullSession = ({transactionId, sessionId, attemptId, currency,
      paymentIntentId}) => ({
      id: sessionId,
      currency,
      payment_status: "paid",
      amount_subtotal: 1000,
      amount_total: 1000,
      total_details: {amount_tax: 0},
      payment_intent: paymentIntentId,
      metadata: {
        pipeBuyerTransactionId: transactionId,
        pipeBuyerCheckoutAttemptId: attemptId,
        pipeBuyerSettlementGeneration: "4",
      },
    });
    const cases = [
      {
        eventId: "evt_fee_session_currency_bad",
        transactionId: "fee_session_bad",
        statusField: "marketplaceFeeStatus",
        expectedStatus: "checkout_created",
        session: feeSession({
          transactionId: "fee_session_bad",
          sessionId: "cs_fee_session_bad",
          attemptId: "fee_attempt_session_bad",
          currency: "cad",
          paymentIntentId: "pi_fee_session_not_retrieved",
        }),
      },
      {
        eventId: "evt_fee_intent_currency_bad",
        transactionId: "fee_intent_bad",
        statusField: "marketplaceFeeStatus",
        expectedStatus: "checkout_created",
        session: feeSession({
          transactionId: "fee_intent_bad",
          sessionId: "cs_fee_intent_bad",
          attemptId: "fee_attempt_intent_bad",
          currency: "usd",
          paymentIntentId: "pi_fee_currency_bad",
        }),
      },
      {
        eventId: "evt_full_session_currency_bad",
        transactionId: "full_session_bad",
        statusField: "paymentProviderStatus",
        expectedStatus: "checkout_created",
        session: fullSession({
          transactionId: "full_session_bad",
          sessionId: "cs_full_session_bad",
          attemptId: "full_attempt_session_bad",
          currency: "cad",
          paymentIntentId: "pi_full_session_not_retrieved",
        }),
      },
      {
        eventId: "evt_full_intent_currency_bad",
        transactionId: "full_intent_bad",
        statusField: "paymentProviderStatus",
        expectedStatus: "checkout_created",
        session: fullSession({
          transactionId: "full_intent_bad",
          sessionId: "cs_full_intent_bad",
          attemptId: "full_attempt_intent_bad",
          currency: "usd",
          paymentIntentId: "pi_full_currency_bad",
        }),
      },
    ];
    for (const testCase of cases) {
      const result = await deliverWebhook(handler, {
        id: testCase.eventId,
        type: "checkout.session.completed",
        data: {object: testCase.session},
      }, secret);
      assert.equal(result.statusCode, 500, testCase.eventId);
      assert.equal(
          memory.read(`marketplace_transactions/${testCase.transactionId}`)[
              testCase.statusField
          ],
          testCase.expectedStatus,
          testCase.eventId,
      );
    }
  } finally {
    global.fetch = originalFetch;
    if (previousWebhookSecret == null) {
      delete process.env.STRIPE_WEBHOOK_SECRET;
    } else {
      process.env.STRIPE_WEBHOOK_SECRET = previousWebhookSecret;
    }
    if (previousStripeSecret == null) {
      delete process.env.STRIPE_SECRET_PRODUCTION;
    } else {
      process.env.STRIPE_SECRET_PRODUCTION = previousStripeSecret;
    }
  }
});

function marketplaceCheckoutFixture({feeOnly}) {
  const transactionId = feeOnly ? "fee-race" : "sale-race";
  const sessionId = feeOnly ? "cs_fee_race" : "cs_sale_race";
  const paymentIntentId = feeOnly ? "pi_fee_race" : "pi_sale_race";
  const chargeId = feeOnly ? "ch_FeeRace1" : "ch_SaleRace1";
  const attemptId = feeOnly ? "fee_attempt_race" : "sale_attempt_race";
  const sale = feeOnly ? {
    currency: "USD",
    listingId: "listing-fee-race",
    buyerUid: "buyer-1",
    sellerUid: "seller-1",
    paymentMethod: "external_settlement",
    settlementMode: "external_settlement",
    settlementGeneration: 1,
    marketplaceFeeStatus: "checkout_created",
    stripeMarketplaceFeeAttemptId: attemptId,
    stripeMarketplaceFeeSettlementGeneration: 1,
    stripeMarketplaceFeeSessionId: sessionId,
    marketplaceFeeSnapshot: {
      currency: "USD",
      marketplaceFeeMinor: 1000,
    },
    financialEpoch: 1,
    financialHold: false,
  } : {
    currency: "USD",
    listingId: "listing-sale-race",
    buyerUid: "buyer-1",
    sellerUid: "seller-1",
    settlementMode: "stripe_checkout",
    settlementGeneration: 1,
    paymentProviderStatus: "checkout_created",
    stripeCheckoutAttemptId: attemptId,
    stripeCheckoutSessionId: sessionId,
    marketplaceFeeSnapshot: {
      currency: "USD",
      agreedTotalMinor: 10000,
      marketplaceFeeMinor: 500,
      sellerProceedsBeforeTaxMinor: 9500,
    },
    financialEpoch: 1,
    financialHold: false,
  };
  const session = {
    id: sessionId,
    currency: "usd",
    payment_status: "paid",
    amount_subtotal: feeOnly ? 1000 : 10000,
    amount_total: feeOnly ? 1000 : 10000,
    total_details: {amount_tax: 0},
    payment_intent: paymentIntentId,
    metadata: {
      ...(feeOnly ? {billingType: "marketplace_fee_only"} : {}),
      pipeBuyerTransactionId: transactionId,
      ...(feeOnly ? {
        pipeBuyerFeeCheckoutAttemptId: attemptId,
      } : {
        pipeBuyerCheckoutAttemptId: attemptId,
      }),
      pipeBuyerSettlementGeneration: "1",
    },
  };
  return {transactionId, sessionId, paymentIntentId, chargeId, sale, session};
}

test("fee refund arriving between Charge lookup and binding is replayed before collection", async () => {
  const secret = "whsec_fee_binding_race";
  const previousWebhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
  process.env.STRIPE_WEBHOOK_SECRET = secret;
  try {
    const fixture = marketplaceCheckoutFixture({feeOnly: true});
    const memory = createMemoryAdmin({
      [`marketplace_transactions/${fixture.transactionId}`]: fixture.sale,
      [`affiliate_commission_ledger/marketplace_${fixture.transactionId}`]: {
        transactionId: fixture.transactionId,
        referrerUid: "affiliate-1",
        currency: "USD",
        commissionMinor: 200,
        status: "pending_platform_fee_payment",
      },
    });
    const financial = createMarketplaceFinancialResolution(memory.admin);
    const gate = createMarketplaceRefundWebhookGate(memory.admin, financial);
    let handler;
    let injected = false;
    handler = createStripeWebhookHandler(memory.admin, {
      marketplaceFinancialResolution: gate,
      stripeSecret: () => "sk_test_binding_race",
      retrievePaymentIntent: async () => ({
        id: fixture.paymentIntentId,
        status: "succeeded",
        currency: "usd",
        latest_charge: {
          id: fixture.chargeId,
          amount: 1000,
          amount_refunded: 0,
          refunded: false,
          disputed: false,
          currency: "usd",
        },
      }),
      afterMarketplaceChargeLookup: async ({billingType}) => {
        if (injected || billingType !== "marketplace_fee_only") return;
        injected = true;
        const result = await deliverWebhook(handler, {
          id: "evt_fee_refund_before_binding",
          type: "charge.refunded",
          created: 200,
          data: {object: {
            id: fixture.chargeId,
            amount: 1000,
            amount_refunded: 1000,
            refunded: true,
            currency: "usd",
            payment_intent: fixture.paymentIntentId,
            metadata: {pipeBuyerTransactionId: fixture.transactionId},
          }},
        }, secret);
        assert.equal(result.statusCode, 500);
      },
    });
    const result = await deliverWebhook(handler, {
      id: "evt_fee_checkout_binding_race",
      type: "checkout.session.completed",
      data: {object: fixture.session},
    }, secret);
    assert.equal(result.statusCode, 200);
    const sale = memory.read(
        `marketplace_transactions/${fixture.transactionId}`,
    );
    const ledger = memory.read(
        `affiliate_commission_ledger/marketplace_${fixture.transactionId}`,
    );
    const unresolved = memory.read(
        "marketplace_unresolved_stripe_events/evt_fee_refund_before_binding",
    );
    assert.equal(sale.marketplaceFeeStatus, "refunded");
    assert.equal(sale.marketplaceFeeRefundedMinor, 1000);
    assert.equal(sale.financialHold, true);
    assert.equal(ledger.status, "void_refunded");
    assert.notEqual(unresolved.status, "pending_marketplace_match");
  } finally {
    if (previousWebhookSecret == null) {
      delete process.env.STRIPE_WEBHOOK_SECRET;
    } else {
      process.env.STRIPE_WEBHOOK_SECRET = previousWebhookSecret;
    }
  }
});

test("sale dispute arriving between Charge lookup and binding blocks seller payout", async () => {
  const secret = "whsec_sale_binding_race";
  const previousWebhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
  process.env.STRIPE_WEBHOOK_SECRET = secret;
  try {
    const fixture = marketplaceCheckoutFixture({feeOnly: false});
    const memory = createMemoryAdmin({
      [`marketplace_transactions/${fixture.transactionId}`]: fixture.sale,
      [`affiliate_commission_ledger/marketplace_${fixture.transactionId}`]: {
        transactionId: fixture.transactionId,
        referrerUid: "affiliate-1",
        currency: "USD",
        commissionMinor: 100,
        status: "pending_platform_fee_payment",
      },
      "platform_configuration/payment_provider_readiness": {
        marketplaceDisputeAutomationEnabled: false,
      },
    });
    const financial = createMarketplaceFinancialResolution(memory.admin);
    const gate = createMarketplaceRefundWebhookGate(memory.admin, financial);
    let handler;
    let injected = false;
    handler = createStripeWebhookHandler(memory.admin, {
      marketplaceFinancialResolution: gate,
      stripeSecret: () => "sk_test_binding_race",
      retrievePaymentIntent: async () => ({
        id: fixture.paymentIntentId,
        status: "succeeded",
        currency: "usd",
        latest_charge: {
          id: fixture.chargeId,
          amount: 10000,
          amount_refunded: 0,
          refunded: false,
          disputed: false,
          currency: "usd",
        },
      }),
      afterMarketplaceChargeLookup: async ({billingType}) => {
        if (injected || billingType !== "marketplace_sale") return;
        injected = true;
        const result = await deliverWebhook(handler, {
          id: "evt_sale_dispute_before_binding",
          type: "charge.dispute.created",
          created: 300,
          data: {object: {
            id: "du_SaleBindingRace1",
            charge: fixture.chargeId,
            amount: 10000,
            currency: "usd",
            reason: "fraudulent",
            status: "under_review",
            metadata: {pipeBuyerTransactionId: fixture.transactionId},
            evidence_details: {submission_count: 0},
          }},
        }, secret);
        assert.equal(result.statusCode, 500);
      },
    });
    const result = await deliverWebhook(handler, {
      id: "evt_sale_checkout_binding_race",
      type: "checkout.session.completed",
      data: {object: fixture.session},
    }, secret);
    assert.equal(result.statusCode, 200);
    const sale = memory.read(
        `marketplace_transactions/${fixture.transactionId}`,
    );
    const ledger = memory.read(
        `affiliate_commission_ledger/marketplace_${fixture.transactionId}`,
    );
    assert.equal(sale.paymentProviderStatus, "paid");
    assert.equal(sale.financialStatus, "disputed");
    assert.equal(sale.financialHold, true);
    assert.equal(sale.sellerPayoutStatus, "blocked_financial_hold");
    assert.notEqual(ledger.status, "pending_refund_window");
  } finally {
    if (previousWebhookSecret == null) {
      delete process.env.STRIPE_WEBHOOK_SECRET;
    } else {
      process.env.STRIPE_WEBHOOK_SECRET = previousWebhookSecret;
    }
  }
});
