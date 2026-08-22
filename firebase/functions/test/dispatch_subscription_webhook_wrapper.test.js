"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  createDispatchSubscriptionWebhookWrapper,
} = require("../dispatch_subscription_webhook_wrapper");

const FieldValue = {serverTimestamp: () => "server-time"};

function fakeAdmin() {
  const docs = new Map();
  const db = {
    docs,
    collection(name) {
      return {
        doc(id) {
          const path = `${name}/${id}`;
          return {
            path,
            async set(value, options) {
              const current = docs.get(path) || {};
              docs.set(path, options && options.merge ?
                {...current, ...value} : value);
            },
          };
        },
      };
    },
  };
  function firestore() {
    return db;
  }
  firestore.FieldValue = FieldValue;
  return {admin: {firestore}, db};
}

function responseRecorder() {
  return {
    statusCode: null,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    send(body) {
      this.body = body;
      return this;
    },
  };
}

function request(event) {
  return {rawBody: Buffer.from(JSON.stringify(event))};
}

function event(type, object) {
  return {id: `evt_${type.replaceAll(".", "_")}`, type, data: {object}};
}

const dispatchMetadata = {
  billingType: "dispatch_subscription",
  pipeBuyerUid: "user-1",
  dispatchPlan: "monthly",
};

test("Dispatch Checkout lifecycle is applied before inner financial webhook", async () => {
  const {admin} = fakeAdmin();
  const order = [];
  const wrapper = createDispatchSubscriptionWebhookWrapper(admin, {
    secretProvider: () => "sk_test",
    dispatchState: {
      async handleCheckoutSession() {
        order.push("state");
      },
    },
    innerHandler: async (_request, response) => {
      order.push("inner");
      response.status(200).send("OK");
    },
  });
  const response = responseRecorder();
  await wrapper(request(event("checkout.session.completed", {
    id: "cs_dispatch",
    metadata: dispatchMetadata,
  })), response);
  assert.deepEqual(order, ["state", "inner"]);
  assert.equal(response.statusCode, 200);
});

test("invoice.paid updates entitlement state and then preserves existing monetization handler", async () => {
  const {admin} = fakeAdmin();
  let paidCalls = 0;
  let innerCalls = 0;
  const wrapper = createDispatchSubscriptionWebhookWrapper(admin, {
    secretProvider: () => "sk_test",
    dispatchState: {
      async handleInvoicePaid(_invoice, secret) {
        paidCalls += 1;
        assert.equal(secret, "sk_test");
      },
    },
    innerHandler: async (_request, response) => {
      innerCalls += 1;
      response.status(200).send("OK");
    },
  });
  const response = responseRecorder();
  await wrapper(request(event("invoice.paid", {id: "in_paid"})), response);
  assert.equal(paidCalls, 1);
  assert.equal(innerCalls, 1);
});

test("invoice.payment_failed is handled even though legacy core has no lifecycle action", async () => {
  const {admin} = fakeAdmin();
  let failedCalls = 0;
  const wrapper = createDispatchSubscriptionWebhookWrapper(admin, {
    secretProvider: () => "sk_test",
    dispatchState: {
      async handleInvoicePaymentFailed() {
        failedCalls += 1;
      },
    },
    innerHandler: async (_request, response) => response.status(200).send("OK"),
  });
  const response = responseRecorder();
  await wrapper(request(event("invoice.payment_failed", {id: "in_failed"})), response);
  assert.equal(failedCalls, 1);
  assert.equal(response.statusCode, 200);
});

test("subscription deletion reaches authoritative lifecycle state writer", async () => {
  const {admin} = fakeAdmin();
  let receivedType = "";
  const wrapper = createDispatchSubscriptionWebhookWrapper(admin, {
    dispatchState: {
      async handleSubscriptionEvent(_subscription, type) {
        receivedType = type;
      },
    },
    innerHandler: async (_request, response) => response.status(200).send("OK"),
  });
  const response = responseRecorder();
  await wrapper(request(event("customer.subscription.deleted", {
    id: "sub_deleted",
    metadata: dispatchMetadata,
  })), response);
  assert.equal(receivedType, "customer.subscription.deleted");
});

test("state failure marks webhook event failed and does not call inner handler", async () => {
  const {admin, db} = fakeAdmin();
  let innerCalls = 0;
  const wrapper = createDispatchSubscriptionWebhookWrapper(admin, {
    secretProvider: () => "sk_test",
    dispatchState: {
      async handleInvoicePaid() {
        throw new Error("state failure");
      },
    },
    innerHandler: async () => {
      innerCalls += 1;
    },
  });
  const webhookEvent = event("invoice.paid", {id: "in_fail_state"});
  const response = responseRecorder();
  await wrapper(request(webhookEvent), response);
  assert.equal(innerCalls, 0);
  assert.equal(response.statusCode, 500);
  const stored = db.docs.get(`stripe_webhook_events/${webhookEvent.id}`);
  assert.equal(stored.status, "failed");
  assert.equal(stored.failureScope, "dispatch_subscription_state");
});
