"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  createDispatchSubscriptionState,
  dispatchMetadata,
} = require("../dispatch_subscription_state");

const FieldValue = {serverTimestamp: () => "server-time"};

function fakeAdmin(initial = {}) {
  const docs = new Map(Object.entries(initial));
  function ref(path) {
    return {path};
  }
  const db = {
    docs,
    collection(name) {
      return {doc: (id) => ref(`${name}/${id}`)};
    },
    async runTransaction(callback) {
      const writes = [];
      const transaction = {
        async get(documentRef) {
          const value = docs.get(documentRef.path);
          return {exists: value != null, data: () => value};
        },
        set(documentRef, value, options) {
          writes.push({documentRef, value, options});
        },
      };
      const result = await callback(transaction);
      for (const write of writes) {
        const current = docs.get(write.documentRef.path) || {};
        docs.set(
            write.documentRef.path,
            write.options && write.options.merge ?
              {...current, ...write.value} : write.value,
        );
      }
      return result;
    },
  };
  function firestore() {
    return db;
  }
  firestore.FieldValue = FieldValue;
  return {admin: {firestore}, db};
}

const stripeConfig = {apiVersion: "2026-06-24.dahlia"};

function subscription(overrides = {}) {
  return {
    id: "sub_dispatch",
    status: "active",
    customer: "cus_dispatch",
    metadata: {
      billingType: "dispatch_subscription",
      pipeBuyerUid: "user-1",
      dispatchPlan: "monthly",
      taxCollectionStatus: "registered",
    },
    ...overrides,
  };
}

function invoice(overrides = {}) {
  return {
    id: "in_dispatch",
    subscription: "sub_dispatch",
    customer: "cus_dispatch",
    amount_paid: 2500,
    currency: "cad",
    parent: {
      subscription_details: {
        subscription: "sub_dispatch",
        metadata: subscription().metadata,
      },
    },
    ...overrides,
  };
}

test("only Dispatch subscription metadata is accepted", () => {
  assert.equal(dispatchMetadata({metadata: {billingType: "other"}}), null);
  assert.equal(dispatchMetadata(subscription()).uid, "user-1");
});

test("Checkout completion creates processing state but does not grant entitlement", async () => {
  const {admin, db} = fakeAdmin();
  const state = createDispatchSubscriptionState(admin, stripeConfig);
  const result = await state.handleCheckoutSession({
    id: "cs_dispatch",
    customer: "cus_dispatch",
    subscription: "sub_dispatch",
    metadata: subscription().metadata,
  });
  assert.equal(result.action, "processing");
  const stored = db.docs.get("dispatch_subscriptions/user-1");
  assert.equal(stored.status, "processing");
  assert.equal(stored.entitlementActive, false);
  assert.equal(stored.stripeSubscriptionId, "sub_dispatch");
});

test("late Checkout completion cannot downgrade invoice-paid active state", async () => {
  const {admin, db} = fakeAdmin({
    "dispatch_subscriptions/user-1": {
      status: "active",
      entitlementActive: true,
      stripeSubscriptionId: "sub_dispatch",
    },
  });
  const state = createDispatchSubscriptionState(admin, stripeConfig);
  const result = await state.handleCheckoutSession({
    id: "cs_late",
    subscription: "sub_dispatch",
    metadata: subscription().metadata,
  });
  assert.equal(result.action, "preserve_active");
  assert.equal(db.docs.get("dispatch_subscriptions/user-1").status, "active");
});

test("invoice.paid is authoritative for activating Dispatch entitlement", async () => {
  const {admin, db} = fakeAdmin({
    "dispatch_subscriptions/user-1": {
      status: "processing",
      entitlementActive: false,
      stripeSubscriptionId: "sub_dispatch",
    },
  });
  const state = createDispatchSubscriptionState(admin, stripeConfig);
  const result = await state.handleInvoicePaid(invoice(), "sk_test");
  assert.equal(result.action, "activated");
  const stored = db.docs.get("dispatch_subscriptions/user-1");
  assert.equal(stored.entitlementActive, true);
  assert.equal(stored.billingStatus, "paid");
  assert.equal(stored.lastPaidInvoiceId, "in_dispatch");
});

test("failed invoice in past_due state flags payment issue without arbitrary access cutoff", async () => {
  const {admin, db} = fakeAdmin({
    "dispatch_subscriptions/user-1": {
      status: "active",
      entitlementActive: true,
      stripeSubscriptionId: "sub_dispatch",
    },
  });
  const state = createDispatchSubscriptionState(admin, stripeConfig, {
    retrieveSubscription: async () => subscription({status: "past_due"}),
  });
  const result = await state.handleInvoicePaymentFailed(invoice(), "sk_test");
  assert.equal(result.action, "payment_failed");
  const stored = db.docs.get("dispatch_subscriptions/user-1");
  assert.equal(stored.status, "past_due");
  assert.equal(stored.entitlementActive, true);
  assert.equal(stored.paymentIssue, true);
});

test("unpaid subscription revokes entitlement", async () => {
  const {admin, db} = fakeAdmin({
    "dispatch_subscriptions/user-1": {
      status: "past_due",
      entitlementActive: true,
      stripeSubscriptionId: "sub_dispatch",
    },
  });
  const state = createDispatchSubscriptionState(admin, stripeConfig);
  await state.handleSubscriptionEvent(
      subscription({status: "unpaid"}),
      "customer.subscription.updated",
  );
  const stored = db.docs.get("dispatch_subscriptions/user-1");
  assert.equal(stored.entitlementActive, false);
  assert.equal(stored.status, "unpaid");
});

test("subscription deletion revokes entitlement", async () => {
  const {admin, db} = fakeAdmin({
    "dispatch_subscriptions/user-1": {
      status: "active",
      entitlementActive: true,
      stripeSubscriptionId: "sub_dispatch",
    },
  });
  const state = createDispatchSubscriptionState(admin, stripeConfig);
  await state.handleSubscriptionEvent(
      subscription({status: "active"}),
      "customer.subscription.deleted",
  );
  const stored = db.docs.get("dispatch_subscriptions/user-1");
  assert.equal(stored.entitlementActive, false);
  assert.equal(stored.status, "canceled");
});

test("different paid subscription is quarantined instead of silently replacing active subscription", async () => {
  const {admin, db} = fakeAdmin({
    "dispatch_subscriptions/user-1": {
      status: "active",
      entitlementActive: true,
      stripeSubscriptionId: "sub_expected",
    },
  });
  const state = createDispatchSubscriptionState(admin, stripeConfig, {
    retrieveSubscription: async () => subscription({id: "sub_unexpected"}),
  });
  const conflictInvoice = invoice({
    subscription: "sub_unexpected",
    parent: {
      subscription_details: {
        subscription: "sub_unexpected",
        metadata: null,
      },
    },
  });
  const result = await state.handleInvoicePaid(conflictInvoice, "sk_test");
  assert.equal(result.action, "review");
  const stored = db.docs.get("dispatch_subscriptions/user-1");
  assert.equal(stored.stripeSubscriptionId, "sub_expected");
  assert.equal(stored.reviewRequired, true);
  assert.equal(stored.conflictingStripeSubscriptionId, "sub_unexpected");
});
