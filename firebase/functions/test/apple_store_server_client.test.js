"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  APPLE_APP_ID,
  PINNED_APPLE_ROOT_CERTIFICATES,
  createAppleStoreServerEnvironment,
  fetchVerifiedAppleCurrentEntitlement,
  loadPinnedAppleRootCertificates,
  verifiedAppleStatusEntitlement,
  verifyAppleTransaction,
} = require("../apple_store_server_client");
const {APPLE_BUNDLE_ID} = require("../native_membership_policy");

const accountToken = "123e4567-e89b-42d3-a456-426614174000";

function fakeLibrary() {
  class FakeClient {
    constructor(...args) {
      this.args = args;
    }
  }
  class FakeVerifier {
    constructor(...args) {
      this.args = args;
    }
  }
  return {
    AppStoreServerAPIClient: FakeClient,
    SignedDataVerifier: FakeVerifier,
    Environment: {PRODUCTION: "Production", SANDBOX: "Sandbox"},
  };
}

function transaction(overrides = {}) {
  return {
    bundleId: APPLE_BUNDLE_ID,
    appAccountToken: accountToken,
    productId: "pipebuyer_dispatch_monthly",
    transactionId: "200000000000001",
    originalTransactionId: "200000000000000",
    expiresDate: Date.UTC(2026, 10, 1),
    environment: "Production",
    inAppOwnershipType: "PURCHASED",
    ...overrides,
  };
}

test("vendored Apple root certificates match pinned SHA-256 hashes", () => {
  const roots = loadPinnedAppleRootCertificates();
  assert.equal(roots.length, PINNED_APPLE_ROOT_CERTIFICATES.length);
  assert.ok(roots.every(Buffer.isBuffer));
});

test("Apple client factory pins the app ID only in production", () => {
  const library = fakeLibrary();
  const roots = [Buffer.from("root-one"), Buffer.from("root-two")];
  const production = createAppleStoreServerEnvironment({
    environment: "Production",
    privateKey: "private-key",
    keyId: "key-id",
    issuerId: "issuer-id",
    rootCertificates: roots,
    library,
  });
  const sandbox = createAppleStoreServerEnvironment({
    environment: "Sandbox",
    privateKey: "private-key",
    keyId: "key-id",
    issuerId: "issuer-id",
    rootCertificates: roots,
    library,
  });
  assert.deepEqual(production.apiClient.args, [
    "private-key", "key-id", "issuer-id", APPLE_BUNDLE_ID, "Production",
  ]);
  assert.equal(production.verifier.args.at(-1), APPLE_APP_ID);
  assert.equal(sandbox.verifier.args.at(-1), undefined);
});

test("verified transaction rejects account and Apple product mismatches", async () => {
  const verifier = {
    async verifyAndDecodeTransaction() {
      return transaction();
    },
  };
  const verified = await verifyAppleTransaction({
    verifier,
    signedTransactionInfo: "signed-transaction",
    expectedAccountToken: accountToken,
    expectedEnvironment: "Production",
  });
  assert.equal(verified.originalTransactionId, "200000000000000");
  await assert.rejects(() => verifyAppleTransaction({
    verifier,
    signedTransactionInfo: "signed-transaction",
    expectedAccountToken: "123e4567-e89b-42d3-a456-426614174999",
    expectedEnvironment: "Production",
  }), /did not match/);

  verifier.verifyAndDecodeTransaction = async () => transaction({
    productId: "pipebuyer_vip_monthly",
  });
  await assert.rejects(() => verifyAppleTransaction({
    verifier,
    signedTransactionInfo: "signed-transaction",
    expectedAccountToken: accountToken,
    expectedEnvironment: "Production",
  }), /did not match/);

  verifier.verifyAndDecodeTransaction = async () => transaction({
    inAppOwnershipType: undefined,
  });
  await assert.rejects(() => verifyAppleTransaction({
    verifier,
    signedTransactionInfo: "signed-transaction",
    expectedAccountToken: accountToken,
    expectedEnvironment: "Production",
  }), /did not match/);
});

test("verified Apple status selects the latest current Dispatch entitlement", async () => {
  const now = Date.UTC(2026, 9, 16);
  const transactions = new Map([
    ["older", transaction({expiresDate: now + 3600000})],
    ["newer", transaction({
      productId: "pipebuyer_dispatch_yearly",
      transactionId: "200000000000002",
      expiresDate: now + 7200000,
    })],
  ]);
  const verifier = {
    async verifyAndDecodeTransaction(value) {
      return transactions.get(value);
    },
    async verifyAndDecodeRenewalInfo(value) {
      assert.equal(value, "renewal");
      return {
        environment: "Production",
        originalTransactionId: "200000000000000",
        autoRenewStatus: 1,
        autoRenewProductId: "pipebuyer_dispatch_monthly",
      };
    },
  };
  const entitlement = await verifiedAppleStatusEntitlement({
    statusResponse: {
      environment: "Production",
      bundleId: APPLE_BUNDLE_ID,
      appAppleId: APPLE_APP_ID,
      data: [{
        lastTransactions: [
          {status: 1, signedTransactionInfo: "older", signedRenewalInfo: "renewal"},
          {status: 1, signedTransactionInfo: "newer", signedRenewalInfo: "renewal"},
        ],
      }],
    },
    verifier,
    expectedAccountToken: accountToken,
    expectedEnvironment: "Production",
    expectedOriginalTransactionId: "200000000000000",
    nowMillis: now,
  });
  assert.equal(entitlement.planId, "dispatch_yearly");
  assert.equal(entitlement.pendingProductId, "pipebuyer_dispatch_monthly");
  assert.equal(entitlement.autoRenewEnabled, true);
});

test("ordinary same-product auto-renewal is not reported as a pending change", async () => {
  const now = Date.UTC(2026, 9, 16);
  const verifier = {
    async verifyAndDecodeTransaction() {
      return transaction({expiresDate: now + 3_600_000});
    },
    async verifyAndDecodeRenewalInfo() {
      return {
        environment: "Production",
        originalTransactionId: "200000000000000",
        autoRenewStatus: 1,
        autoRenewProductId: "pipebuyer_dispatch_monthly",
      };
    },
  };
  const entitlement = await verifiedAppleStatusEntitlement({
    statusResponse: {
      environment: "Production",
      bundleId: APPLE_BUNDLE_ID,
      appAppleId: APPLE_APP_ID,
      data: [{
        lastTransactions: [{
          status: 1,
          signedTransactionInfo: "current",
          signedRenewalInfo: "renewal",
        }],
      }],
    },
    verifier,
    expectedAccountToken: accountToken,
    expectedEnvironment: "Production",
    expectedOriginalTransactionId: "200000000000000",
    nowMillis: now,
  });
  assert.equal(entitlement.productId, "pipebuyer_dispatch_monthly");
  assert.equal(entitlement.pendingProductId, "");
});

test("verified Apple grace-period status uses signed renewal grace expiry", async () => {
  const now = Date.UTC(2026, 9, 16);
  const verifier = {
    async verifyAndDecodeTransaction() {
      return transaction({expiresDate: now - 1000});
    },
    async verifyAndDecodeRenewalInfo() {
      return {
        environment: "Production",
        originalTransactionId: "200000000000000",
        gracePeriodExpiresDate: now + 3600000,
      };
    },
  };
  const entitlement = await verifiedAppleStatusEntitlement({
    statusResponse: {
      environment: "Production",
      bundleId: APPLE_BUNDLE_ID,
      appAppleId: APPLE_APP_ID,
      data: [{lastTransactions: [{
        status: 4,
        signedTransactionInfo: "transaction",
        signedRenewalInfo: "renewal",
      }]}],
    },
    verifier,
    expectedAccountToken: accountToken,
    expectedEnvironment: "Production",
    nowMillis: now,
  });
  assert.equal(entitlement.status, "grace_period");
  assert.equal(entitlement.expiresAtMillis, now + 3600000);
});

test("current entitlement verifies transaction and status JWS values", async () => {
  const now = Date.UTC(2026, 9, 16);
  const calls = [];
  const apiClient = {
    async getTransactionInfo(transactionId) {
      calls.push(["transaction", transactionId]);
      return {signedTransactionInfo: "initial"};
    },
    async getAllSubscriptionStatuses(originalTransactionId) {
      calls.push(["status", originalTransactionId]);
      return {
        environment: "Sandbox",
        bundleId: APPLE_BUNDLE_ID,
        data: [{lastTransactions: [{
          status: 1,
          originalTransactionId,
          signedTransactionInfo: "latest",
        }]}],
      };
    },
  };
  const verifier = {
    async verifyAndDecodeTransaction(value) {
      return transaction({
        transactionId: value === "initial" ?
          "200000000000001" : "200000000000002",
        expiresDate: now + 3600000,
        environment: "Sandbox",
      });
    },
    async verifyAndDecodeRenewalInfo() {
      throw new Error("renewal verifier should not be called");
    },
  };
  const entitlement = await fetchVerifiedAppleCurrentEntitlement({
    apiClient,
    verifier,
    transactionId: "200000000000001",
    expectedAccountToken: accountToken,
    expectedEnvironment: "Sandbox",
    nowMillis: now,
  });
  assert.equal(entitlement.transactionId, "200000000000002");
  assert.deepEqual(calls, [
    ["transaction", "200000000000001"],
    ["status", "200000000000000"],
  ]);
});
