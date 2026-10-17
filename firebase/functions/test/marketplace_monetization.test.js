"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  MARKETPLACE_FEE_CLASS_SOURCE,
  MARKETPLACE_FEE_CLASSIFICATION_REVISION,
} = require("../marketplace_fee_policy");
const {
  createMarketplaceMonetization,
} = require("../marketplace_monetization");

function fakeAdmin(initialDocuments) {
  const documents = new Map(Object.entries(initialDocuments));
  const db = {
    collection(collectionName) {
      return {
        doc(documentId) {
          return {path: `${collectionName}/${documentId}`};
        },
      };
    },
    async runTransaction(handler) {
      const transaction = {
        async get(ref) {
          const exists = documents.has(ref.path);
          return {
            exists,
            data: () => exists ? documents.get(ref.path) : undefined,
          };
        },
        update(ref, values) {
          documents.set(ref.path, {
            ...(documents.get(ref.path) || {}),
            ...values,
          });
        },
        create(ref, values) {
          assert.equal(documents.has(ref.path), false);
          documents.set(ref.path, values);
        },
      };
      return handler(transaction);
    },
  };
  const firestore = () => db;
  firestore.FieldValue = {serverTimestamp: () => "server-timestamp"};
  return {admin: {firestore}, documents};
}

function transactionDocuments(classification) {
  const listing = {
    sellerUid: "seller-1",
    revision: 2,
    category: "Pipe, Tubing & Materials",
    productType: "Tubing",
  };
  return {
    "marketplace_transactions/transaction-1": {
      listingId: "listing-1",
      sellerUid: "seller-1",
      agreedQuantity: 1000,
      agreedTotal: 40000,
      currency: "USD",
    },
    "public_listings/listing-1": listing,
    ...(classification ? {
      "marketplace_fee_classifications/listing-1": classification,
    } : {}),
  };
}

function approvedClassification(overrides = {}) {
  return {
    listingId: "listing-1",
    sellerUid: "seller-1",
    listingRevision: 2,
    category: "Pipe, Tubing & Materials",
    productType: "Tubing",
    status: "approved",
    marketplaceFeeClass: "pipe",
    marketplaceFeeUnit: "item",
    marketplaceFeeClassSource: MARKETPLACE_FEE_CLASS_SOURCE,
    marketplaceFeeClassificationRevision:
      MARKETPLACE_FEE_CLASSIFICATION_REVISION,
    decisionRevision: 1,
    decisionReason: "Reviewed against the controlled pipe catalog.",
    decidedByUid: "admin-1",
    decidedAt: "server-timestamp",
    ...overrides,
  };
}

async function snapshotFee(classification) {
  const fixture = fakeAdmin(transactionDocuments(classification));
  const monetization = createMarketplaceMonetization(fixture.admin);
  const fee = await monetization.snapshotAcceptedTransaction({
    transactionId: "transaction-1",
    transactionData:
      fixture.documents.get("marketplace_transactions/transaction-1"),
  });
  return {fee, documents: fixture.documents};
}

test("monetization defaults a seller-selected pipe listing to equipment", async () => {
  const result = await snapshotFee(null);
  assert.equal(result.fee.feeClass, "equipment_asset");
  assert.equal(
      result.fee.feeClassificationSource,
      "server_fail_closed_default",
  );
});

test("monetization uses a separate matching admin approval for pipe", async () => {
  const result = await snapshotFee(approvedClassification());
  assert.equal(result.fee.feeClass, "pipe");
  assert.equal(result.fee.marketplaceFeeMinor, 100000);
  assert.equal(result.fee.feeClassificationSource, MARKETPLACE_FEE_CLASS_SOURCE);
});

test("monetization rejects a stale admin approval after a listing edit", async () => {
  const result = await snapshotFee(approvedClassification({listingRevision: 1}));
  assert.equal(result.fee.feeClass, "equipment_asset");
  assert.equal(
      result.fee.feeClassificationSource,
      "server_fail_closed_default",
  );
});
