"use strict";

const STRIPE_SNAPSHOT_WEBHOOK_EVENTS = Object.freeze([
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
  "charge.refunded",
  "refund.created",
  "refund.updated",
  "refund.failed",
  "charge.dispute.created",
  "charge.dispute.updated",
  "charge.dispute.closed",
  "charge.dispute.funds_withdrawn",
  "charge.dispute.funds_reinstated",
]);

// Accounts v2 emits unversioned thin events. Configure these on a separate
// thin-format event destination; the v1 payment lifecycle above remains on its
// existing snapshot-format webhook endpoint.
const STRIPE_ACCOUNTS_V2_THIN_EVENTS = Object.freeze([
  "v2.core.account.updated",
  "v2.core.account[configuration.recipient].capability_status_updated",
  "v2.core.account[configuration.recipient].updated",
  "v2.core.account[defaults].updated",
  "v2.core.account[future_requirements].updated",
  "v2.core.account[identity].updated",
  "v2.core.account[requirements].updated",
]);

// Backward-compatible name used by the existing v1 webhook bootstrap workflow.
const STRIPE_WEBHOOK_EVENTS = STRIPE_SNAPSHOT_WEBHOOK_EVENTS;

module.exports = {
  STRIPE_ACCOUNTS_V2_THIN_EVENTS,
  STRIPE_SNAPSHOT_WEBHOOK_EVENTS,
  STRIPE_WEBHOOK_EVENTS,
};
