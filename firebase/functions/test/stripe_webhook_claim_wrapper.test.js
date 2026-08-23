"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  applyExternalFeeNonSuccessEvent,
  claimStripeWebhookEvent,
  createClaimedStripeWebhookHandler,
} = require("../stripe_webhook_claim_wrapper");

class FakeTimestamp {
  constructor(millis) {
    this._millis = millis;
  }
  toMillis() {
    return this._millis;
  }
  static fromMillis(millis) {
    return new FakeTimestamp(millis);
  }
}

const FakeFieldValue = {
  serverTimestamp() {
    return "server-time";
  },
};

function fakeDb(initial = {}) {
  const docs = new Map(Object.entries(initial));
  const makeRef = (path) => ({
    path,
    async set(value, options) {
      const current = docs.get(path) || {};
      docs.set(path, options && options.merge ? {...current, ...value} : value);
    },
  });
  return {
    docs,
    collection(name) {
      return {
        doc(id) {
          return makeRef(`${name}/${id}`);
        },
      };
    },
    async runTransaction(callback) {
      const writes = [];
      const transaction = {
        async get(documentRef) {
          const value = docs.get(documentRef.path);
          return {
            exists: value != null,
            data: () => value,
          };
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

function requestFor(event) {
  return {
    rawBody: Buffer.from(JSON.stringify(event)),
    get: () => "signature",
  };
}

function feeEvent({
  id = "evt_fee",
  type = "checkout.session.async_payment_failed",
  sessionId = "cs_1",
  attempt = 1,
  paymentStatus = "unpaid",
} = {}) {
  return {
    id,
    type,
    data: {
      object: {
        id: sessionId,
        payment_status: paymentStatus,
        metadata: {
          billingType: "marketplace_fee_only",
          checkoutAttempt: String(attempt),
          pipeBuyerTransactionId: "txn_fee",
        },
      },
    },
  };
}

test("claim writes processing lease and increments attempts", async () => {
  const db = fakeDb({
    "stripe_webhook_events/evt_1": {status: "failed", attempts: 2},
  });
  const eventRef = db.collection("stripe_webhook_events").doc("evt_1");
  const decision = await claimStripeWebhookEvent({
    db,
    eventRef,
    event: {id: "evt_1", type: "checkout.session.completed"},
    Timestamp: FakeTimestamp,
    nowMillis: 1000,
  });
  assert.equal(decision.action, "claim");
  assert.equal(decision.attempt, 3);
  const stored = db.docs.get("stripe_webhook_events/evt_1");
  assert.equal(stored.status, "processing");
  assert.equal(stored.attempts, 3);
  assert.equal(stored.processingStartedAt.toMillis(), 1000);
  assert.ok(stored.processingLeaseExpiresAt.toMillis() > 1000);
});

test("wrapper allows only the first in-flight delivery to invoke inner handler", async () => {
  const db = fakeDb();
  let innerCalls = 0;
  const admin = {
    firestore() {
      return db;
    },
  };
  admin.firestore.Timestamp = FakeTimestamp;
  admin.firestore.FieldValue = FakeFieldValue;
  const handler = createClaimedStripeWebhookHandler(admin, {
    verifySignature: () => true,
    secretProvider: () => "secret",
    nowProvider: () => 5000,
    innerHandler: async (_request, response) => {
      innerCalls += 1;
      response.status(200).send("OK");
    },
  });
  const event = {id: "evt_dup", type: "customer.created"};
  const first = responseRecorder();
  await handler(requestFor(event), first);
  assert.equal(first.statusCode, 200);
  assert.equal(innerCalls, 1);

  const second = responseRecorder();
  await handler(requestFor(event), second);
  assert.equal(second.statusCode, 200);
  assert.equal(second.body, "Already processing");
  assert.equal(innerCalls, 1);
});

test("processed event bypasses inner handler", async () => {
  const db = fakeDb({
    "stripe_webhook_events/evt_done": {status: "processed", attempts: 1},
  });
  let innerCalls = 0;
  const admin = {firestore: () => db};
  admin.firestore.Timestamp = FakeTimestamp;
  admin.firestore.FieldValue = FakeFieldValue;
  const handler = createClaimedStripeWebhookHandler(admin, {
    verifySignature: () => true,
    secretProvider: () => "secret",
    nowProvider: () => 5000,
    innerHandler: async () => {
      innerCalls += 1;
    },
  });
  const response = responseRecorder();
  await handler(
      requestFor({id: "evt_done", type: "customer.created"}),
      response,
  );
  assert.equal(response.statusCode, 200);
  assert.equal(response.body, "Already processed");
  assert.equal(innerCalls, 0);
});

test("invalid signature never claims event", async () => {
  const db = fakeDb();
  const admin = {firestore: () => db};
  admin.firestore.Timestamp = FakeTimestamp;
  admin.firestore.FieldValue = FakeFieldValue;
  const handler = createClaimedStripeWebhookHandler(admin, {
    verifySignature: () => false,
    secretProvider: () => "secret",
    innerHandler: async () => assert.fail("inner handler should not run"),
  });
  const response = responseRecorder();
  await handler(
      requestFor({id: "evt_bad", type: "customer.created"}),
      response,
  );
  assert.equal(response.statusCode, 400);
  assert.equal(db.docs.size, 0);
});

test("late failed fee webhook cannot downgrade collected state", async () => {
  const db = fakeDb({
    "marketplace_transactions/txn_fee": {
      marketplaceFeeStatus: "collected",
      stripeMarketplaceFeeSessionId: "cs_1",
      marketplaceFeeCheckoutAttempt: 1,
    },
  });
  const result = await applyExternalFeeNonSuccessEvent({
    db,
    event: feeEvent(),
    FieldValue: FakeFieldValue,
  });
  assert.equal(result.action, "ignore");
  assert.equal(result.reason, "already_collected");
  assert.equal(
      db.docs.get("marketplace_transactions/txn_fee").marketplaceFeeStatus,
      "collected",
  );
});

test("newer attempt processing webhook can arrive before callable persistence", async () => {
  const db = fakeDb({
    "marketplace_transactions/txn_fee": {
      marketplaceFeeStatus: "payment_failed",
      stripeMarketplaceFeeSessionId: "cs_old",
      marketplaceFeeCheckoutAttempt: 1,
    },
  });
  const result = await applyExternalFeeNonSuccessEvent({
    db,
    event: feeEvent({
      type: "checkout.session.completed",
      sessionId: "cs_new",
      attempt: 2,
    }),
    FieldValue: FakeFieldValue,
  });
  assert.equal(result.action, "apply");
  const stored = db.docs.get("marketplace_transactions/txn_fee");
  assert.equal(stored.marketplaceFeeStatus, "processing");
  assert.equal(stored.stripeMarketplaceFeeSessionId, "cs_new");
  assert.equal(stored.marketplaceFeeCheckoutAttempt, 2);
});

test("same-attempt session conflict is flagged without changing fee state", async () => {
  const db = fakeDb({
    "marketplace_transactions/txn_fee": {
      marketplaceFeeStatus: "checkout_created",
      stripeMarketplaceFeeSessionId: "cs_expected",
      marketplaceFeeCheckoutAttempt: 2,
    },
  });
  const result = await applyExternalFeeNonSuccessEvent({
    db,
    event: feeEvent({sessionId: "cs_unexpected", attempt: 2}),
    FieldValue: FakeFieldValue,
  });
  assert.equal(result.action, "review");
  const stored = db.docs.get("marketplace_transactions/txn_fee");
  assert.equal(stored.marketplaceFeeStatus, "checkout_created");
  assert.equal(stored.marketplaceFeeOperationalReviewRequired, true);
  assert.equal(stored.marketplaceFeeOperationalReviewReason, "session_conflict");
});

test("wrapper intercepts fee failure and marks claimed event processed", async () => {
  const db = fakeDb({
    "marketplace_transactions/txn_fee": {
      marketplaceFeeStatus: "processing",
      stripeMarketplaceFeeSessionId: "cs_1",
      marketplaceFeeCheckoutAttempt: 1,
    },
  });
  let innerCalls = 0;
  const admin = {firestore: () => db};
  admin.firestore.Timestamp = FakeTimestamp;
  admin.firestore.FieldValue = FakeFieldValue;
  const handler = createClaimedStripeWebhookHandler(admin, {
    verifySignature: () => true,
    secretProvider: () => "secret",
    nowProvider: () => 1000,
    innerHandler: async () => {
      innerCalls += 1;
    },
  });
  const response = responseRecorder();
  await handler(requestFor(feeEvent()), response);
  assert.equal(response.statusCode, 200);
  assert.equal(innerCalls, 0);
  assert.equal(
      db.docs.get("marketplace_transactions/txn_fee").marketplaceFeeStatus,
      "payment_failed",
  );
  const eventRecord = db.docs.get("stripe_webhook_events/evt_fee");
  assert.equal(eventRecord.status, "processed");
  assert.equal(eventRecord.guardedFeeTransitionAction, "apply");
});
