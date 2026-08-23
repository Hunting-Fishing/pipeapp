"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  dispatchSubscriptionInvoiceReconciliationState,
} = require("../dispatch_subscription_reconciliation_policy");
const {stripeMarketplaceConfig} = require("../stripe_marketplace_config");

function stored(overrides = {}) {
  return {
    invoiceId: "in_dispatch_1",
    subscriptionId: "sub_dispatch_1",
    uid: "user-1",
    plan: "monthly",
    stripePriceId: stripeMarketplaceConfig.products.dispatchMonthlyCad.priceId,
    currency: "CAD",
    commissionBaseMinor: 2500,
    amountPaidMinor: 2500,
    taxMinor: 0,
    sourceChargeId: "",
    status: "paid",
    ...overrides,
  };
}

function invoice(overrides = {}) {
  const priceId = String(
      overrides.priceId || stripeMarketplaceConfig.products.dispatchMonthlyCad.priceId,
  );
  return {
    id: "in_dispatch_1",
    status: "paid",
    amount_paid: 2500,
    total: 2500,
    total_excluding_tax: 2500,
    currency: "cad",
    lines: {
      data: [{
        quantity: 1,
        pricing: {
          price_details: {
            price: priceId,
            product: stripeMarketplaceConfig.products.dispatchMonthlyCad.productId,
          },
        },
      }],
    },
    parent: {
      subscription_details: {
        subscription: "sub_dispatch_1",
        metadata: {
          billingType: "dispatch_subscription",
          pipeBuyerUid: "user-1",
          dispatchPlan: "monthly",
        },
      },
    },
    ...overrides,
  };
}

function invoicePayment(overrides = {}) {
  return {
    id: "inpay_dispatch_1",
    status: "paid",
    invoice: "in_dispatch_1",
    amount_paid: 2500,
    currency: "cad",
    payment: {
      type: "payment_intent",
      payment_intent: "pi_dispatch_1",
    },
    ...overrides,
  };
}

function paymentIntent(overrides = {}) {
  return {
    id: "pi_dispatch_1",
    status: "succeeded",
    amount_received: 2500,
    latest_charge: "ch_dispatch_1",
    ...overrides,
  };
}

function charge(overrides = {}) {
  return {
    id: "ch_dispatch_1",
    paid: true,
    amount: 2500,
    currency: "cad",
    balance_transaction: "txn_dispatch_1",
    ...overrides,
  };
}

function balance(overrides = {}) {
  return {
    id: "txn_dispatch_1",
    amount: 2500,
    fee: 103,
    net: 2397,
    currency: "cad",
    ...overrides,
  };
}

test("positive Dispatch invoice balances InvoicePayment PaymentIntent Charge and Balance Transaction", () => {
  const result = dispatchSubscriptionInvoiceReconciliationState({
    stored: stored(),
    invoice: invoice(),
    invoicePayment: invoicePayment(),
    paymentIntent: paymentIntent(),
    charge: charge(),
    balanceTransaction: balance(),
  });
  assert.equal(result.balanced, true);
  assert.deepEqual(result.failedChecks, []);
  assert.equal(result.providerPlan, "monthly");
  assert.equal(
      result.providerStripePriceId,
      stripeMarketplaceConfig.products.dispatchMonthlyCad.priceId,
  );
  assert.equal(result.stripeInvoicePaymentId, "inpay_dispatch_1");
  assert.equal(result.stripePaymentIntentId, "pi_dispatch_1");
  assert.equal(result.stripeChargeId, "ch_dispatch_1");
  assert.equal(result.providerGrossMinor, 2500);
  assert.equal(result.providerFeeMinor, 103);
  assert.equal(result.providerNetMinor, 2397);
  assert.equal(result.providerDifferenceMinor, 0);
});

test("yearly invoice remains balanced when Checkout metadata still says monthly", () => {
  const yearlyPrice = stripeMarketplaceConfig.products.dispatchYearlyCad.priceId;
  const result = dispatchSubscriptionInvoiceReconciliationState({
    stored: stored({plan: "yearly", stripePriceId: yearlyPrice}),
    invoice: invoice({priceId: yearlyPrice}),
    invoicePayment: invoicePayment(),
    paymentIntent: paymentIntent(),
    charge: charge(),
    balanceTransaction: balance(),
  });
  assert.equal(result.balanced, true);
  assert.equal(result.providerPlan, "yearly");
  assert.equal(result.providerStripePriceId, yearlyPrice);
});

test("stored and provider amount mismatch can never report balanced", () => {
  const result = dispatchSubscriptionInvoiceReconciliationState({
    stored: stored(),
    invoice: invoice({amount_paid: 2400, total: 2400, total_excluding_tax: 2400}),
    invoicePayment: invoicePayment({amount_paid: 2400}),
    paymentIntent: paymentIntent({amount_received: 2400}),
    charge: charge({amount: 2400}),
    balanceTransaction: balance({amount: 2400, net: 2297}),
  });
  assert.equal(result.balanced, false);
  assert.ok(result.failedChecks.includes("amountPaidMatches"));
  assert.ok(result.failedChecks.includes("commissionBaseMatches"));
  assert.equal(result.invoiceDifferenceMinor, -100);
});

test("wrong Dispatch subscription metadata is quarantined as mismatch", () => {
  const result = dispatchSubscriptionInvoiceReconciliationState({
    stored: stored(),
    invoice: invoice({
      parent: {
        subscription_details: {
          subscription: "sub_dispatch_1",
          metadata: {
            billingType: "other",
            pipeBuyerUid: "user-1",
            dispatchPlan: "monthly",
          },
        },
      },
    }),
    invoicePayment: invoicePayment(),
    paymentIntent: paymentIntent(),
    charge: charge(),
    balanceTransaction: balance(),
  });
  assert.equal(result.balanced, false);
  assert.ok(result.failedChecks.includes("billingTypeMatches"));
});

test("wrong invoice Price is never balanced even when metadata plan matches", () => {
  const result = dispatchSubscriptionInvoiceReconciliationState({
    stored: stored(),
    invoice: invoice({
      priceId: stripeMarketplaceConfig.products.dispatchYearlyCad.priceId,
    }),
    invoicePayment: invoicePayment(),
    paymentIntent: paymentIntent(),
    charge: charge(),
    balanceTransaction: balance(),
  });
  assert.equal(result.balanced, false);
  assert.ok(result.failedChecks.includes("planMatches"));
  assert.ok(result.failedChecks.includes("stripePriceMatches"));
});

test("wrong InvoicePayment PaymentIntent link is never balanced", () => {
  const result = dispatchSubscriptionInvoiceReconciliationState({
    stored: stored(),
    invoice: invoice(),
    invoicePayment: invoicePayment({
      payment: {
        type: "payment_intent",
        payment_intent: "pi_other",
      },
    }),
    paymentIntent: paymentIntent(),
    charge: charge(),
    balanceTransaction: balance(),
  });
  assert.equal(result.balanced, false);
  assert.ok(result.failedChecks.includes("paymentIntentIdMatches"));
});

test("100 percent discount invoice reconciles only when no provider payment evidence exists", () => {
  const result = dispatchSubscriptionInvoiceReconciliationState({
    stored: stored({
      commissionBaseMinor: 0,
      amountPaidMinor: 0,
      taxMinor: 0,
      sourceChargeId: null,
    }),
    invoice: invoice({
      amount_paid: 0,
      total: 0,
      total_excluding_tax: 0,
    }),
  });
  assert.equal(result.balanced, true);
  assert.equal(result.zeroAmount, true);
  assert.equal(result.providerGrossMinor, 0);
  assert.equal(result.providerFeeMinor, 0);
  assert.equal(result.providerNetMinor, 0);
  assert.equal(result.stripeInvoicePaymentId, "");
  assert.equal(result.stripePaymentIntentId, "");
  assert.equal(result.stripeChargeId, "");
});

test("zero-dollar invoice mismatches if Stripe unexpectedly reports paid payment evidence", () => {
  const result = dispatchSubscriptionInvoiceReconciliationState({
    stored: stored({
      commissionBaseMinor: 0,
      amountPaidMinor: 0,
      taxMinor: 0,
      sourceChargeId: null,
    }),
    invoice: invoice({
      amount_paid: 0,
      total: 0,
      total_excluding_tax: 0,
    }),
    invoicePayment: invoicePayment({amount_paid: 0}),
  });
  assert.equal(result.balanced, false);
  assert.ok(result.failedChecks.includes("zeroAmountProviderPaymentAbsent"));
});
