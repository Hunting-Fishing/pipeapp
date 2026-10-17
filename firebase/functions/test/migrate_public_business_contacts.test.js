"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  EXPECTED_PROJECT_ID,
  PAGE_SIZE,
  SOURCE_COLLECTIONS,
  legacyContacts,
  migrationTarget,
  privateContactValues,
} = require("../scripts/migrate_public_business_contacts");

test("migration is bounded and scans both legacy public profile collections", () => {
  assert.ok(PAGE_SIZE <= 100);
  assert.deepEqual(SOURCE_COLLECTIONS, [
    "public_business_profiles",
    "public_seller_profiles",
  ]);
});

test("migration requires an exact project target and apply confirmation", () => {
  assert.throws(
      () => migrationTarget([], {}),
      /--project=flutter-flow-pipe/u,
  );
  const dryRun = migrationTarget([
    `--project=${EXPECTED_PROJECT_ID}`,
  ], {});
  assert.equal(dryRun.apply, false);
  assert.equal(dryRun.projectId, EXPECTED_PROJECT_ID);
  assert.match(dryRun.fingerprint, /^[a-f0-9]{16}$/u);
  assert.throws(
      () => migrationTarget([
        `--project=${EXPECTED_PROJECT_ID}`,
        "--apply",
      ], {}),
      /--confirm-project=flutter-flow-pipe/u,
  );
  assert.equal(migrationTarget([
    `--project=${EXPECTED_PROJECT_ID}`,
    `--confirm-project=${EXPECTED_PROJECT_ID}`,
    "--apply",
  ], {}).apply, true);
});

test("legacy contacts preserve both top-level and Dispatch website evidence", () => {
  assert.deepEqual(legacyContacts({
    publicPhone: "+1 780 555 1212",
    publicEmail: "seller@example.com",
    website: "https://seller.example",
    dispatchProfile: {website: "https://dispatch.example"},
  }), {
    phone: "+1 780 555 1212",
    email: "seller@example.com",
    website: "https://seller.example",
    profileWebsite: "https://seller.example",
    dispatchWebsite: "https://dispatch.example",
  });
});

test("migration does not overwrite an existing private contact", () => {
  const serverTimestamp = Symbol("serverTimestamp");
  const values = privateContactValues({
    uid: "seller-1",
    sourceCollection: "public_seller_profiles",
    contacts: {
      phone: "+1 780 555 1212",
      email: "legacy@example.com",
      website: "https://legacy.example",
      profileWebsite: "https://legacy.example",
      dispatchWebsite: "",
    },
    existing: {
      contactPhone: "+1 587 555 1212",
      contactEmail: "current@example.com",
      website: "https://current.example",
    },
    FieldValue: {serverTimestamp: () => serverTimestamp},
  });
  assert.equal(values.contactPhone, undefined);
  assert.equal(values.contactEmail, undefined);
  assert.equal(values.website, undefined);
  assert.equal(
      values.legacyPublicContacts.public_seller_profiles.publicEmail,
      "legacy@example.com",
  );
});
