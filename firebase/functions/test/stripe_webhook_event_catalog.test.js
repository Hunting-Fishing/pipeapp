"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  STRIPE_ACCOUNTS_V2_THIN_EVENTS,
  STRIPE_SNAPSHOT_WEBHOOK_EVENTS,
  STRIPE_WEBHOOK_EVENTS,
} = require("../stripe_webhook_event_catalog");

const requiredDispatchEvents = [
  "checkout.session.completed",
  "checkout.session.async_payment_succeeded",
  "checkout.session.async_payment_failed",
  "checkout.session.expired",
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
  assert.equal(
      new Set(STRIPE_ACCOUNTS_V2_THIN_EVENTS).size,
      STRIPE_ACCOUNTS_V2_THIN_EVENTS.length,
  );
  assert.equal(STRIPE_WEBHOOK_EVENTS, STRIPE_SNAPSHOT_WEBHOOK_EVENTS);
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

test("Accounts v2 readiness uses a separate thin-event destination catalog", () => {
  assert.deepEqual(STRIPE_ACCOUNTS_V2_THIN_EVENTS, [
    "v2.core.account.updated",
    "v2.core.account[configuration.recipient].capability_status_updated",
    "v2.core.account[configuration.recipient].updated",
    "v2.core.account[defaults].updated",
    "v2.core.account[future_requirements].updated",
    "v2.core.account[identity].updated",
    "v2.core.account[requirements].updated",
  ]);
  assert.equal(STRIPE_WEBHOOK_EVENTS.includes("account.updated"), false);
  for (const event of STRIPE_ACCOUNTS_V2_THIN_EVENTS) {
    assert.equal(STRIPE_WEBHOOK_EVENTS.includes(event), false, event);
  }
});
