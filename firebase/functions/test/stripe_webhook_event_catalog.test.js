"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {STRIPE_WEBHOOK_EVENTS} = require("../stripe_webhook_event_catalog");

const requiredDispatchEvents = [
  "checkout.session.completed",
  "checkout.session.async_payment_succeeded",
  "checkout.session.async_payment_failed",
  "invoice.paid",
  "invoice.payment_failed",
  "customer.subscription.created",
  "customer.subscription.updated",
  "customer.subscription.deleted",
  "customer.subscription.paused",
  "customer.subscription.resumed",
];

const requiredFinancialEvents = [
  "charge.refunded",
  "refund.created",
  "refund.updated",
  "refund.failed",
  "charge.dispute.created",
  "charge.dispute.updated",
  "charge.dispute.closed",
  "charge.dispute.funds_withdrawn",
  "charge.dispute.funds_reinstated",
];

test("Stripe webhook catalog has no duplicate event subscriptions", () => {
  assert.equal(new Set(STRIPE_WEBHOOK_EVENTS).size, STRIPE_WEBHOOK_EVENTS.length);
});

test("Stripe webhook catalog includes the complete Dispatch Billing lifecycle", () => {
  for (const event of requiredDispatchEvents) {
    assert.equal(STRIPE_WEBHOOK_EVENTS.includes(event), true, event);
  }
});

test("Stripe webhook catalog preserves refund and dispute event coverage", () => {
  for (const event of requiredFinancialEvents) {
    assert.equal(STRIPE_WEBHOOK_EVENTS.includes(event), true, event);
  }
});
