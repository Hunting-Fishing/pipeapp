"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  NATIVE_PURCHASE_INTENT_TTL_MS,
  NATIVE_PURCHASE_PENDING_TTL_MS,
  NATIVE_RESTORE_INTENT_TTL_MS,
  billingIntentActive,
  billingIntentMatchesForVerification,
  claimBillingIntentInTransaction,
  failStripeCheckoutReservation,
  markBillingIntentPendingInTransaction,
  markBillingIntentVerifyingInTransaction,
  makeStripeCheckoutReservationRetryable,
  nativeBillingIntentCoordinationEnabled,
  stripeCheckoutStateOpen,
  validIntentToken,
} = require("../membership_billing_intent");

const admin = {
  firestore: {
    Timestamp: {fromMillis: (value) => ({toMillis: () => value})},
    FieldValue: {
      delete: () => "delete-field",
      serverTimestamp: () => "server-time",
    },
  },
};

function snapshot(data) {
  return {exists: Boolean(data), data: () => data};
}

function transactionRecorder() {
  const writes = [];
  return {
    writes,
    set(ref, value, options) {
      writes.push({ref, value, options});
    },
  };
}

test("billing intent coordination activates only with an enabled native store", () => {
  assert.equal(nativeBillingIntentCoordinationEnabled({}), false);
  assert.equal(nativeBillingIntentCoordinationEnabled({enabled: true}), false);
  assert.equal(nativeBillingIntentCoordinationEnabled({
    enabled: true,
    appleEnabled: true,
  }), true);
  assert.equal(nativeBillingIntentCoordinationEnabled({
    enabled: true,
    googleEnabled: true,
  }), true);
});

test("native preflight claims an opaque, bounded billing intent", () => {
  const transaction = transactionRecorder();
  const result = claimBillingIntentInTransaction({
    transaction,
    intentRef: "intent/user-1",
    intentSnapshot: snapshot(null),
    admin,
    uid: "user-1",
    channel: "app_store",
    platform: "ios",
    productId: "pipebuyer_dispatch_monthly",
    planId: "dispatch_monthly",
    nowMillis: 1_000,
    ttlMillis: NATIVE_PURCHASE_INTENT_TTL_MS,
  });
  assert.equal(validIntentToken(result.intentToken), true);
  assert.equal(result.expiresAtMillis, 1_000 + NATIVE_PURCHASE_INTENT_TTL_MS);
  assert.equal(transaction.writes.length, 1);
  assert.equal(transaction.writes[0].value.channel, "app_store");
  assert.equal(transaction.writes[0].value.status, "active");
});

test("a fresh intent clears replay metadata from the prior token", () => {
  const transaction = transactionRecorder();
  const completed = {
    ownerUid: "user-1",
    channel: "app_store",
    platform: "ios",
    productId: "pipebuyer_dispatch_monthly",
    planId: "dispatch_monthly",
    intentToken: "o".repeat(43),
    status: "completed",
    expiresAtMillis: 1_000,
    replayUntilMillis: 900_000,
    completedAt: "old-completion",
  };
  const result = claimBillingIntentInTransaction({
    transaction,
    intentRef: "intent/user-1",
    intentSnapshot: snapshot(completed),
    admin,
    uid: "user-1",
    channel: "app_store",
    platform: "ios",
    productId: "pipebuyer_dispatch_yearly",
    planId: "dispatch_yearly",
    nowMillis: 10_000,
    ttlMillis: NATIVE_PURCHASE_INTENT_TTL_MS,
  });
  assert.notEqual(result.intentToken, completed.intentToken);
  assert.equal(transaction.writes[0].value.replayUntilMillis, "delete-field");
  assert.equal(transaction.writes[0].value.replayUntil, "delete-field");
  assert.equal(transaction.writes[0].value.completedAt, "delete-field");
});

test("same target reuses its intent but a competing billing channel is blocked", () => {
  const current = {
    ownerUid: "user-1",
    channel: "app_store",
    platform: "ios",
    productId: "pipebuyer_dispatch_monthly",
    planId: "dispatch_monthly",
    intentToken: "a".repeat(43),
    status: "active",
    expiresAtMillis: 50_000,
  };
  const reused = claimBillingIntentInTransaction({
    transaction: transactionRecorder(),
    intentRef: "intent/user-1",
    intentSnapshot: snapshot(current),
    admin,
    uid: "user-1",
    channel: "app_store",
    platform: "ios",
    productId: "pipebuyer_dispatch_monthly",
    planId: "dispatch_monthly",
    nowMillis: 10_000,
    ttlMillis: NATIVE_PURCHASE_INTENT_TTL_MS,
  });
  assert.equal(reused.intentToken, current.intentToken);
  assert.equal(reused.reused, true);

  assert.throws(() => claimBillingIntentInTransaction({
    transaction: transactionRecorder(),
    intentRef: "intent/user-1",
    intentSnapshot: snapshot(current),
    admin,
    uid: "user-1",
    channel: "stripe",
    platform: "web",
    productId: "prod_dispatch",
    planId: "dispatch_monthly",
    nowMillis: 10_000,
    ttlMillis: NATIVE_PURCHASE_INTENT_TTL_MS,
  }), /Another membership billing attempt/);
});

test("verification fencing requires the exact active intent token", () => {
  const intent = {
    ownerUid: "user-1",
    channel: "app_store",
    platform: "ios",
    productId: "pipebuyer_dispatch_yearly",
    planId: "dispatch_yearly",
    intentToken: "b".repeat(43),
    status: "active",
    expiresAtMillis: 50_000,
  };
  const expected = {
    uid: "user-1",
    channel: "app_store",
    platform: "ios",
    productId: "pipebuyer_dispatch_yearly",
    planId: "dispatch_yearly",
    intentToken: intent.intentToken,
  };
  const transaction = transactionRecorder();
  markBillingIntentVerifyingInTransaction({
    transaction,
    intentRef: "intent/user-1",
    intentSnapshot: snapshot(intent),
    admin,
    expected,
    nowMillis: 10_000,
  });
  assert.equal(transaction.writes[0].value.status, "verifying");
  assert.throws(() => markBillingIntentVerifyingInTransaction({
    transaction: transactionRecorder(),
    intentRef: "intent/user-1",
    intentSnapshot: snapshot(intent),
    admin,
    expected: {...expected, intentToken: "c".repeat(43)},
    nowMillis: 10_000,
  }), /Start this membership purchase again/);
});

test("open Stripe checkout and expired intents are distinguished", () => {
  assert.equal(stripeCheckoutStateOpen({
    ownerUid: "user-1",
    status: "created",
    expiresAt: 20_000,
  }, "user-1", 10_000), true);
  assert.equal(stripeCheckoutStateOpen({
    ownerUid: "user-1",
    status: "created",
    expiresAt: 5_000,
  }, "user-1", 10_000), false);
  assert.equal(billingIntentActive({
    ownerUid: "user-1",
    status: "active",
    expiresAtMillis: 5_000,
  }, "user-1", 10_000), false);
});

test("pending Apple approval extends beyond 24 hours and blocks Stripe", () => {
  const nowMillis = 10_000;
  const intent = {
    ownerUid: "user-1",
    channel: "app_store",
    platform: "ios",
    productId: "pipebuyer_dispatch_monthly",
    planId: "dispatch_monthly",
    intentToken: "p".repeat(43),
    status: "active",
    expiresAtMillis: nowMillis + 60_000,
  };
  const transaction = transactionRecorder();
  const pending = markBillingIntentPendingInTransaction({
    transaction,
    intentRef: "intent/user-1",
    intentSnapshot: snapshot(intent),
    admin,
    expected: {
      uid: "user-1",
      channel: "app_store",
      platform: "ios",
      productId: "pipebuyer_dispatch_monthly",
      planId: "dispatch_monthly",
      intentToken: intent.intentToken,
    },
    nowMillis,
  });
  assert.equal(pending.status, "pending");
  assert.ok(pending.expiresAtMillis > nowMillis + (24 * 60 * 60 * 1000));
  assert.equal(
      pending.expiresAtMillis,
      nowMillis + NATIVE_PURCHASE_PENDING_TTL_MS,
  );
  assert.throws(() => claimBillingIntentInTransaction({
    transaction: transactionRecorder(),
    intentRef: "intent/user-1",
    intentSnapshot: snapshot(pending),
    admin,
    uid: "user-1",
    channel: "stripe",
    platform: "web",
    productId: "prod_dispatch",
    planId: "dispatch_monthly",
    nowMillis: nowMillis + (25 * 60 * 60 * 1000),
    ttlMillis: 24 * 60 * 60 * 1000,
  }), /Another membership billing attempt/);
});

test("completed purchase intent permits only bounded exact verification replay", () => {
  const nowMillis = 10_000;
  const intent = {
    ownerUid: "user-1",
    channel: "app_store",
    platform: "ios",
    productId: "pipebuyer_dispatch_monthly",
    planId: "dispatch_monthly",
    intentToken: "r".repeat(43),
    status: "completed",
    replayUntilMillis: nowMillis + (7 * 24 * 60 * 60 * 1000),
  };
  const expected = {
    uid: "user-1",
    channel: "app_store",
    platform: "ios",
    productId: "pipebuyer_dispatch_monthly",
    planId: "dispatch_monthly",
    intentToken: intent.intentToken,
  };
  assert.equal(
      billingIntentMatchesForVerification(intent, expected, nowMillis),
      true,
  );
  assert.equal(billingIntentMatchesForVerification(
      intent,
      {...expected, productId: "pipebuyer_dispatch_yearly"},
      nowMillis,
  ), false);
  assert.equal(billingIntentMatchesForVerification(
      intent,
      {...expected, intentToken: "x".repeat(43)},
      nowMillis,
  ), false);
  assert.equal(
      billingIntentMatchesForVerification(
          intent,
          expected,
          intent.replayUntilMillis + 1,
      ),
      false,
  );
  const transaction = transactionRecorder();
  markBillingIntentVerifyingInTransaction({
    transaction,
    intentRef: "intent/user-1",
    intentSnapshot: snapshot(intent),
    admin,
    expected,
    allowCompletedReplay: true,
    nowMillis,
  });
  assert.equal(transaction.writes[0].value.status, "verifying");
  const replayAfterCrash = {
    ...intent,
    status: "verifying",
    expiresAtMillis: nowMillis + (5 * 60 * 1000),
  };
  assert.equal(billingIntentMatchesForVerification(
      replayAfterCrash,
      expected,
      nowMillis + (6 * 60 * 1000),
  ), true);
});

test("restore intent uses a short non-charging settlement window", () => {
  assert.ok(NATIVE_RESTORE_INTENT_TTL_MS >= 60_000);
  assert.ok(NATIVE_RESTORE_INTENT_TTL_MS < NATIVE_PURCHASE_INTENT_TTL_MS);
});

test("definite Stripe failure releases only its exact attempt and intent", async () => {
  const stateRef = {collection: "checkout", id: "user-1"};
  const intentRef = {
    collection: "membership_billing_intents",
    id: "user-1",
  };
  const state = {
    ownerUid: "user-1",
    status: "creating",
    attemptNumber: 4,
  };
  const intent = {
    ownerUid: "user-1",
    channel: "stripe",
    intentToken: "s".repeat(43),
    status: "active",
  };
  const writes = [];
  const db = {
    collection(collection) {
      return {doc: (id) => ({collection, id})};
    },
    async runTransaction(callback) {
      return callback({
        async get(ref) {
          if (ref.collection === stateRef.collection) return snapshot(state);
          if (ref.collection === intentRef.collection) return snapshot(intent);
          return snapshot(null);
        },
        set(ref, value, options) {
          writes.push({ref, value, options});
        },
      });
    },
  };
  assert.equal(await failStripeCheckoutReservation({
    db,
    admin,
    uid: "user-1",
    stateRef,
    attemptNumber: 3,
    intentToken: intent.intentToken,
  }), false);
  assert.equal(writes.length, 0);
  assert.equal(await failStripeCheckoutReservation({
    db,
    admin,
    uid: "user-1",
    stateRef,
    attemptNumber: 4,
    intentToken: intent.intentToken,
  }), true);
  assert.equal(writes.length, 2);
  assert.equal(writes[0].value.status, "failed");
  assert.equal(writes[1].value.status, "released");
});

test("ambiguous Stripe failure keeps intent and reopens the same attempt", async () => {
  const stateRef = {collection: "checkout", id: "user-1"};
  const intent = {
    ownerUid: "user-1",
    channel: "stripe",
    intentToken: "t".repeat(43),
    status: "active",
  };
  const writes = [];
  const db = {
    collection(collection) {
      return {doc: (id) => ({collection, id})};
    },
    async runTransaction(callback) {
      return callback({
        async get(ref) {
          if (ref.collection === "checkout") {
            return snapshot({
              ownerUid: "user-1",
              status: "creating",
              attemptNumber: 9,
            });
          }
          if (ref.collection === "membership_billing_intents") {
            return snapshot(intent);
          }
          return snapshot(null);
        },
        set(ref, value, options) {
          writes.push({ref, value, options});
        },
      });
    },
  };
  assert.equal(await makeStripeCheckoutReservationRetryable({
    db,
    admin,
    uid: "user-1",
    stateRef,
    attemptNumber: 9,
    intentToken: intent.intentToken,
  }), true);
  assert.equal(writes.length, 1);
  assert.equal(writes[0].ref, stateRef);
  assert.equal(writes[0].value.status, undefined);
  assert.equal(writes[0].value.leaseExpiresAt.toMillis() <= Date.now(), true);
});
