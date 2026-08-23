import assert from "node:assert/strict";
import {createRequire} from "node:module";

const require = createRequire(import.meta.url);
const {deleteApp, initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");

const projectId = process.env.GCLOUD_PROJECT ||
  process.env.GOOGLE_CLOUD_PROJECT ||
  "demo-pipe-buyer-integration";
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
let functionsHost = process.env.FUNCTIONS_EMULATOR_HOST;

if (!functionsHost && process.env.FIREBASE_EMULATOR_HUB) {
  const response = await fetch(
      `http://${process.env.FIREBASE_EMULATOR_HUB}/emulators`,
  );
  const emulators = await response.json();
  if (response.ok && emulators.functions) {
    functionsHost = `${emulators.functions.host}:${emulators.functions.port}`;
  }
}

if (!process.env.FIRESTORE_EMULATOR_HOST || !authHost || !functionsHost) {
  throw new Error(
      "P3 external-settlement integration must run inside Auth, Firestore, " +
      "and Functions emulators.",
  );
}

const now = Date.now();
const app = initializeApp(
    {projectId},
    `p3-external-settlement-integration-${now}`,
);
const auth = getAuth(app);
const db = getFirestore(app);

async function createVerifiedUser(label, phoneSuffix) {
  const email = `${label}-${now}@pipe.test`;
  const password = "Integration!234";
  const signupResponse = await fetch(
      `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp` +
      "?key=demo-emulator-key",
      {
        method: "POST",
        headers: {"content-type": "application/json"},
        body: JSON.stringify({email, password, returnSecureToken: true}),
      },
  );
  const signup = await signupResponse.json();
  if (!signupResponse.ok || !signup.localId) {
    throw new Error(`Auth emulator signup failed: ${JSON.stringify(signup)}`);
  }
  await auth.updateUser(signup.localId, {
    emailVerified: true,
    phoneNumber: `+1555555${phoneSuffix}`,
  });
  const signInResponse = await fetch(
      `http://${authHost}/identitytoolkit.googleapis.com/v1/` +
      "accounts:signInWithPassword?key=demo-emulator-key",
      {
        method: "POST",
        headers: {"content-type": "application/json"},
        body: JSON.stringify({email, password, returnSecureToken: true}),
      },
  );
  const signIn = await signInResponse.json();
  if (!signInResponse.ok || !signIn.idToken) {
    throw new Error(`Auth emulator sign-in failed: ${JSON.stringify(signIn)}`);
  }
  return {uid: signup.localId, token: signIn.idToken};
}

async function call(name, token, data) {
  const response = await fetch(
      `http://${functionsHost}/${projectId}/us-central1/${name}`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${token}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({data}),
      },
  );
  const payload = await response.json();
  if (!response.ok || payload.error) {
    throw new Error(
        `${name} failed (${response.status}): ${JSON.stringify(payload)}`,
    );
  }
  return payload.result;
}

async function expectCallableError(name, token, data, expectedStatus) {
  const response = await fetch(
      `http://${functionsHost}/${projectId}/us-central1/${name}`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${token}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({data}),
      },
  );
  const payload = await response.json();
  assert.equal(
      payload.error && payload.error.status,
      expectedStatus,
      `${name} expected ${expectedStatus}: ${JSON.stringify(payload)}`,
  );
  return payload.error;
}

try {
  const [seller, buyer] = await Promise.all([
    createVerifiedUser("p3-seller", "2101"),
    createVerifiedUser("p3-buyer", "2102"),
  ]);

  await Promise.all([
    db.doc("platform_configuration/phase1_features").set({
      marketplace: true,
      wantedAds: true,
      offers: true,
      auctions: true,
      dispatch: true,
      paidFeatures: true,
      regulatedListings: false,
      revision: 1,
    }),
    db.doc("platform_configuration/payment_provider_readiness").set({
      stripeMode: "production",
      stripeCheckoutEnabled: false,
      stripeFeeBillingEnabled: true,
      stripeWebhookVerified: true,
      stripeTaxReady: true,
      stripeTaxRegistrationPending: false,
      stripeReconciliationReady: true,
      checkoutSuccessUrl: "https://pipebuyer.com/payments/success",
      checkoutCancelUrl: "https://pipebuyer.com/payments/cancel",
    }),
    db.doc(`users/${seller.uid}`).set({
      displayName: "P3 Integration Seller",
      accountVerified: true,
    }),
    db.doc(`users/${buyer.uid}`).set({
      displayName: "P3 Integration Buyer",
      accountVerified: true,
    }),
  ]);

  const transactionId = `p3-external-${now}`;
  await db.doc(`marketplace_transactions/${transactionId}`).set({
    buyerUid: buyer.uid,
    sellerUid: seller.uid,
    status: "pending_completion",
    currency: "CAD",
    marketplaceFeeStatus: "not_selected",
    marketplaceFeeSnapshot: {
      marketplaceFeeMinor: 2500,
      currency: "CAD",
      scheduleRevision: "integration-p3-v1",
      feeClass: "equipment",
    },
  });

  const sellerConfirmation = await call(
      "confirmExternalSettlement",
      seller.token,
      {transactionId},
  );
  assert.equal(sellerConfirmation.role, "seller");
  assert.equal(sellerConfirmation.sellerConfirmed, true);
  assert.equal(sellerConfirmation.buyerConfirmed, false);
  assert.equal(sellerConfirmation.fullyConfirmed, false);

  const onePartyFeeError = await expectCallableError(
      "createExternalSettlementFeeCheckout",
      seller.token,
      {transactionId},
      "FAILED_PRECONDITION",
  );
  assert.match(onePartyFeeError.message, /both parties/i);
  const onePartyState = (
    await db.doc(`marketplace_transactions/${transactionId}`).get()
  ).data();
  assert.equal(onePartyState.externalSettlementSellerConfirmed, true);
  assert.equal(onePartyState.externalSettlementBuyerConfirmed, false);
  assert.notEqual(onePartyState.marketplaceFeeStatus, "checkout_created");
  assert.equal(onePartyState.stripeMarketplaceFeeSessionId, undefined);

  const buyerConfirmation = await call(
      "confirmExternalSettlement",
      buyer.token,
      {transactionId},
  );
  assert.equal(buyerConfirmation.role, "buyer");
  assert.equal(buyerConfirmation.buyerConfirmed, true);
  assert.equal(buyerConfirmation.sellerConfirmed, true);
  assert.equal(buyerConfirmation.fullyConfirmed, true);

  const agreedState = (
    await db.doc(`marketplace_transactions/${transactionId}`).get()
  ).data();
  assert.equal(agreedState.externalSettlementBuyerConfirmed, true);
  assert.equal(agreedState.externalSettlementSellerConfirmed, true);
  assert.equal(agreedState.paymentMethod, "external_settlement");
  assert.equal(agreedState.paymentProvider, "external");
  assert.equal(agreedState.paymentProviderStatus, "external_agreed");
  assert.equal(agreedState.marketplaceFeeStatus, "pending_collection");

  const buyerFeeError = await expectCallableError(
      "createExternalSettlementFeeCheckout",
      buyer.token,
      {transactionId},
      "PERMISSION_DENIED",
  );
  assert.match(buyerFeeError.message, /seller/i);

  const stripeLockedTransactionId = `p3-stripe-locked-${now}`;
  await db.doc(`marketplace_transactions/${stripeLockedTransactionId}`).set({
    buyerUid: buyer.uid,
    sellerUid: seller.uid,
    status: "pending_payment",
    paymentMethod: "stripe_checkout",
    paymentProvider: "stripe",
    paymentProviderStatus: "checkout_created",
    stripeCheckoutSessionId: "cs_test_existing_marketplace_path",
  });
  const stripePathError = await expectCallableError(
      "confirmExternalSettlement",
      buyer.token,
      {transactionId: stripeLockedTransactionId},
      "FAILED_PRECONDITION",
  );
  assert.match(stripePathError.message, /Stripe marketplace payment/i);
  const stripeLockedState = (
    await db.doc(`marketplace_transactions/${stripeLockedTransactionId}`).get()
  ).data();
  assert.equal(stripeLockedState.externalSettlementBuyerConfirmed, undefined);
  assert.equal(stripeLockedState.paymentMethod, "stripe_checkout");

  console.log(
      "P3 external-settlement callable integration passed: " +
      "one-party fee gate, both-party agreement, seller-only fee authority, " +
      "and Stripe-path exclusivity.",
  );
} finally {
  await deleteApp(app);
}
