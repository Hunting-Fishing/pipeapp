"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  invoicePaymentIntentId,
  invoicePaymentsPath,
  objectId,
  paidInvoicePayments,
} = require("../dispatch_subscription_invoice_payment_policy");

test("builds the authoritative paid InvoicePayment query path", () => {
  assert.equal(
      invoicePaymentsPath("in_dispatch_1"),
      "/v1/invoice_payments?invoice=in_dispatch_1&status=paid&limit=100",
  );
});

test("reads PaymentIntent identity from current InvoicePayment shape", () => {
  assert.equal(invoicePaymentIntentId({
    payment: {
      type: "payment_intent",
      payment_intent: "pi_dispatch_1",
    },
  }), "pi_dispatch_1");
  assert.equal(invoicePaymentIntentId({
    payment: {
      type: "payment_intent",
      payment_intent: {id: "pi_dispatch_2"},
    },
  }), "pi_dispatch_2");
  assert.equal(invoicePaymentIntentId({
    payment: {type: "other"},
  }), "");
});

test("filters only paid InvoicePayments belonging to the requested invoice", () => {
  const payments = paidInvoicePayments({
    data: [
      {id: "inpay_1", status: "paid", invoice: "in_dispatch_1"},
      {id: "inpay_2", status: "open", invoice: "in_dispatch_1"},
      {id: "inpay_3", status: "paid", invoice: "in_other"},
    ],
  }, "in_dispatch_1");
  assert.deepEqual(payments.map((entry) => entry.id), ["inpay_1"]);
});

test("object identity accepts both string and expanded Stripe objects", () => {
  assert.equal(objectId("ch_1"), "ch_1");
  assert.equal(objectId({id: "ch_2"}), "ch_2");
  assert.equal(objectId(null), "");
});
