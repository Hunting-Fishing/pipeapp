"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  buildPublicEntry,
  defaultCompanyWorkflow,
  isPublicationEligible,
  normalizedCompanyName,
  stringList,
} = require("../yellow_pages_policy");

function futureTimestamp(minutes = 60) {
  const millis = Date.now() + minutes * 60 * 1000;
  return {
    toMillis: () => millis,
    toDate: () => new Date(millis),
  };
}

test("new imported companies start private, unpaid, and unverified", () => {
  assert.deepEqual(defaultCompanyWorkflow(), {
    outreachStatus: "not_contacted",
    verificationStatus: "unverified",
    billingStatus: "unpaid",
    publicationStatus: "unpublished",
    doNotContact: false,
    nonExpiringPaid: false,
  });
});

test("publication requires verified + paid + published + current entitlement", () => {
  const base = {
    companyName: "North Test Energy Ltd.",
    verificationStatus: "verified",
    billingStatus: "paid",
    publicationStatus: "published",
    paidThrough: futureTimestamp(),
  };
  assert.equal(isPublicationEligible(base), true);
  assert.equal(isPublicationEligible({...base, verificationStatus: "unverified"}), false);
  assert.equal(isPublicationEligible({...base, billingStatus: "expired"}), false);
  assert.equal(isPublicationEligible({...base, publicationStatus: "pending"}), false);
  assert.equal(isPublicationEligible({...base, paidThrough: null}), false);
  assert.equal(isPublicationEligible({...base, paidThrough: {toMillis: () => Date.now() - 1}}), false);
  assert.equal(isPublicationEligible({...base, paidThrough: null, nonExpiringPaid: true}), true);
});

test("public projection is an allowlist and excludes private contact-center evidence", () => {
  const paidThrough = futureTimestamp();
  const privateCompany = {
    companyName: "North Test Energy Ltd.",
    website: "https://example.test",
    publicPhone: "+1 555 100 2000",
    publicEmail: "public@example.test",
    mainPhone: "+1 555 999 9999",
    generalEmail: "private@example.test",
    streetAddress: "Private yard address",
    doNotContact: true,
    doNotContactReason: "Requested no sales calls",
    assignedAgentUid: "employee-private-uid",
    paymentReference: "private-payment-reference",
    verificationReviewNote: "internal evidence",
    sourceReferences: [{sourceName: "private source"}],
    countryCode: "ca",
    regionCode: "AB",
    city: "Red Deer",
    categories: ["Pipe", "Pipe", "Inspection"],
    services: ["NDT"],
    description: "Industrial services",
    verificationStatus: "verified",
    billingStatus: "paid",
    publicationStatus: "published",
    paidThrough,
    publishedAt: paidThrough,
  };
  const publicEntry = buildPublicEntry(
      privateCompany,
      "company-1",
      "SERVER_TIMESTAMP",
  );
  assert.ok(publicEntry);
  assert.equal(publicEntry.companyName, "North Test Energy Ltd.");
  assert.equal(publicEntry.publicPhone, "+1 555 100 2000");
  assert.equal(publicEntry.publicEmail, "public@example.test");
  assert.deepEqual(publicEntry.categories, ["Pipe", "Inspection"]);

  for (const forbidden of [
    "mainPhone",
    "generalEmail",
    "streetAddress",
    "doNotContact",
    "doNotContactReason",
    "assignedAgentUid",
    "paymentReference",
    "verificationReviewNote",
    "sourceReferences",
  ]) {
    assert.equal(Object.hasOwn(publicEntry, forbidden), false, forbidden);
  }
});

test("company-name normalization and bounded list normalization are deterministic", () => {
  assert.equal(normalizedCompanyName("  ACME Pipe & Valve, Ltd.  "), "acme pipe valve ltd");
  assert.deepEqual(
      stringList(["Pipe", " pipe ", "Valves", "", null], 10, 20),
      ["Pipe", "Valves"],
  );
});
