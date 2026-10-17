"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  buildMarketplaceFeeClassificationRecord,
  createMarketplaceFeeAdmin,
  feeCatalog,
  publicFeeCatalog,
} = require("../marketplace_fee_admin");

const pipeListing = Object.freeze({
  sellerUid: "seller-1",
  revision: 4,
  category: "Pipe, Tubing & Materials",
  productType: "Tubing",
});

function fakeClassificationAdmin() {
  const documents = new Map([["public_listings/listing-1", pipeListing]]);
  let automaticId = 0;
  const db = {
    collection(collectionName) {
      return {
        doc(documentId) {
          const id = documentId || `automatic-${++automaticId}`;
          return {path: `${collectionName}/${id}`};
        },
      };
    },
    async runTransaction(handler) {
      return handler({
        async get(ref) {
          const exists = documents.has(ref.path);
          return {
            exists,
            data: () => exists ? documents.get(ref.path) : undefined,
          };
        },
        set(ref, values) {
          documents.set(ref.path, values);
        },
        create(ref, values) {
          assert.equal(documents.has(ref.path), false);
          documents.set(ref.path, values);
        },
      });
    },
  };
  const firestore = () => db;
  firestore.FieldValue = {serverTimestamp: () => "server-timestamp"};
  return {admin: {firestore}, documents};
}

function administratorRequest(data) {
  return {
    auth: {
      uid: "admin-1",
      token: {
        admin: true,
        role: "administrator",
        firebase: {sign_in_second_factor: "phone"},
      },
    },
    data,
  };
}

test("admin fee catalog exposes sale-only pipe fee rules", () => {
  const catalog = feeCatalog();
  assert.equal(catalog.scheduleRevision, "2026-10-16-sale-only-v4");
  assert.equal(catalog.feePayer, "seller");
  assert.equal(catalog.collectionTiming, "sale_payment");
  assert.equal(catalog.listingFeeByCurrency.USD.amount, 0);
  assert.equal(catalog.pipe.unitFeeByCurrency.CAD.amount, 1);
  assert.equal(catalog.pipe.percentageCap, 3);
  assert.equal(catalog.pipe.maximumFeeByCurrency.CAD.amount, 2500);
  assert.equal(catalog.pipe.unitFeeByCurrency.USD.amount, 1);
  assert.equal(catalog.pipe.maximumFeeByCurrency.USD.amount, 2500);
});

test("admin fee catalog exposes dispatch and affiliate pricing", () => {
  const catalog = feeCatalog();
  assert.equal(catalog.dispatch.monthly.amount, 25);
  assert.equal(catalog.dispatch.monthly.currency, "USD");
  assert.equal(catalog.dispatch.yearly.amount, 250);
  assert.equal(catalog.dispatch.yearly.currency, "USD");
  assert.equal(catalog.affiliate.sharePercent, 20);
});

test("admin fee catalog exposes progressive equipment brackets", () => {
  const catalog = feeCatalog();
  assert.equal(catalog.equipment.minimumFeeByCurrency.CAD.amount, 1);
  assert.equal(catalog.equipment.maximumFeeByCurrency.CAD.amount, 2500);
  assert.deepEqual(
      catalog.equipment.brackets.map((bracket) => bracket.feePercent),
      [3, 2.5, 2, 1.5, 1],
  );
});

test("public fee catalog exposes customer terms without provider secrets", () => {
  const catalog = publicFeeCatalog();
  assert.equal(catalog.scheduleRevision, "2026-10-16-sale-only-v4");
  assert.equal(catalog.feePayer, "seller");
  assert.equal(catalog.listingFeeByCurrency.USD.amount, 0);
  assert.equal(catalog.collectionTiming, "sale_payment");
  assert.equal(catalog.pipe.unitFeeByCurrency.USD.amount, 1);
  assert.equal(catalog.pipe.percentageCap, 3);
  assert.equal(catalog.equipment.maximumFeeByCurrency.USD.amount, 2500);
  assert.deepEqual(
      catalog.equipment.brackets.map((bracket) => bracket.feePercent),
      [3, 2.5, 2, 1.5, 1],
  );
  const serialized = JSON.stringify(catalog);
  assert.doesNotMatch(serialized, /stripe|priceId|productId|taxCode|affiliate/i);
});

test("admin decision builds an independent listing-bound pipe approval", () => {
  const record = buildMarketplaceFeeClassificationRecord({
    listingId: "listing-1",
    listing: pipeListing,
    feeClass: "pipe",
    administratorUid: "admin-1",
    reason: "Reviewed against the controlled pipe catalog.",
    decisionRevision: 1,
  });
  assert.equal(record.status, "approved");
  assert.equal(record.marketplaceFeeClass, "pipe");
  assert.equal(record.marketplaceFeeUnit, "item");
  assert.equal(record.marketplaceFeeClassSource, "administrator_approved_catalog");
  assert.equal(record.listingId, "listing-1");
  assert.equal(record.sellerUid, "seller-1");
  assert.equal(record.listingRevision, 4);
  assert.equal(record.category, pipeListing.category);
  assert.equal(record.productType, pipeListing.productType);
});

test("admin decision rejects a non-pipe catalog listing for pipe pricing", () => {
  assert.throws(() => buildMarketplaceFeeClassificationRecord({
    listingId: "listing-equipment-1",
    listing: {
      sellerUid: "seller-1",
      revision: 1,
      category: "Heavy Equipment",
      productType: "Excavator",
    },
    feeClass: "pipe",
    administratorUid: "admin-1",
    reason: "Requested pipe pricing after administrator review.",
    decisionRevision: 1,
  }), /canonical pipe catalog listing/);
});

test("admin equipment decision revokes any discounted pipe approval", () => {
  const record = buildMarketplaceFeeClassificationRecord({
    listingId: "listing-1",
    listing: pipeListing,
    feeClass: "equipment_asset",
    administratorUid: "admin-1",
    reason: "Pipe pricing approval was withdrawn after review.",
    decisionRevision: 2,
  });
  assert.equal(record.status, "revoked");
  assert.equal(record.marketplaceFeeClass, "equipment_asset");
  assert.equal(record.marketplaceFeeUnit, "sale_value");
  assert.equal(record.decisionRevision, 2);
});

test("MFA administrator callable stores the server-only approval", async () => {
  const fixture = fakeClassificationAdmin();
  const commands = createMarketplaceFeeAdmin(fixture.admin);
  const result = await commands.setMarketplaceListingFeeClassification(
      administratorRequest({
        listingId: "listing-1",
        feeClass: "pipe",
        reason: "Reviewed against the controlled pipe catalog.",
      }),
  );
  assert.equal(result.status, "approved");
  assert.equal(result.feeClass, "pipe");
  const stored = fixture.documents.get(
      "marketplace_fee_classifications/listing-1",
  );
  assert.equal(stored.decidedByUid, "admin-1");
  assert.equal(stored.listingRevision, 4);
  assert.equal(stored.decidedAt, "server-timestamp");
});

test("fee classification callable rejects an account without admin MFA", async () => {
  const fixture = fakeClassificationAdmin();
  const commands = createMarketplaceFeeAdmin(fixture.admin);
  await assert.rejects(
      commands.setMarketplaceListingFeeClassification({
        auth: {uid: "seller-1", token: {}},
        data: {
          listingId: "listing-1",
          feeClass: "pipe",
          reason: "Seller attempted to grant the discounted fee class.",
        },
      }),
      (error) => error && error.code === "permission-denied",
  );
  assert.equal(
      fixture.documents.has("marketplace_fee_classifications/listing-1"),
      false,
  );
});
