"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  TAX_RESPONSIBILITY_TERMS_VERSION,
  claimHasMinimumEvidence,
  nextVerificationStatus,
  normalizeTaxProfileInput,
  transactionTaxComplianceSnapshot,
} = require("../marketplace_tax_compliance");

function timestamp(ms) {
  return {toMillis: () => ms};
}

test("changing a verified tax number returns it to pending verification", () => {
  assert.equal(nextVerificationStatus("PST-123", "PST-123", "verified"), "verified");
  assert.equal(
      nextVerificationStatus("PST-123", "PST-456", "verified"),
      "pending_verification",
  );
  assert.equal(nextVerificationStatus("", "", "verified"), "not_provided");
});

test("tax profile requires responsibility acknowledgement and seller GST status", () => {
  assert.throws(() => normalizeTaxProfileInput({
    legalBusinessName: "Example Energy Ltd.",
    countryCode: "CA",
    regionCode: "BC",
    sellerNormalGstHstRegistered: "yes",
    taxResponsibilityAcknowledged: false,
  }));

  const profile = normalizeTaxProfileInput({
    legalBusinessName: "Example Energy Ltd.",
    countryCode: "ca",
    regionCode: "bc",
    businessNumber: "123456789",
    gstHstNumber: "123456789 RT0001",
    pstBcNumber: "PST-1234-5678",
    sellerNormalGstHstRegistered: "yes",
    taxResponsibilityAcknowledged: true,
  });
  assert.equal(profile.countryCode, "CA");
  assert.equal(profile.regionCode, "BC");
  assert.equal(
      profile.taxResponsibilityPolicyVersion,
      TAX_RESPONSIBILITY_TERMS_VERSION,
  );
});

test("resale claim can rely only on a current verified BC PST number", () => {
  const now = Date.now();
  assert.equal(claimHasMinimumEvidence({exemptionType: "resale"}, {
    pstBcStatus: "verified",
    pstBcNumber: "PST-1234-5678",
    pstBcNumberReviewDueAt: timestamp(now + 60_000),
  }, now), true);
  assert.equal(claimHasMinimumEvidence({exemptionType: "resale"}, {
    pstBcStatus: "verified",
    pstBcNumber: "PST-1234-5678",
    pstBcNumberReviewDueAt: timestamp(now - 1),
  }, now), false);
});

test("unverified seller tax status blocks automated checkout", () => {
  const result = transactionTaxComplianceSnapshot({
    buyerProfile: {
      taxResponsibilityPolicyVersion: TAX_RESPONSIBILITY_TERMS_VERSION,
      revision: 2,
      countryCode: "CA",
      regionCode: "BC",
    },
    sellerProfile: {
      taxResponsibilityPolicyVersion: TAX_RESPONSIBILITY_TERMS_VERSION,
      revision: 3,
      countryCode: "CA",
      regionCode: "AB",
      sellerNormalGstHstRegistered: "yes",
      gstHstNumber: "123456789 RT0001",
      gstHstStatus: "pending_verification",
    },
    claim: null,
  });
  assert.equal(result.eligibleForAutomatedCheckout, false);
  assert.ok(result.blockers.includes("seller_gst_number_verification_required"));
});

test("expired seller GST verification blocks automated checkout", () => {
  const now = Date.now();
  const result = transactionTaxComplianceSnapshot({
    nowMs: now,
    buyerProfile: {
      taxResponsibilityPolicyVersion: TAX_RESPONSIBILITY_TERMS_VERSION,
      revision: 2,
      countryCode: "CA",
      regionCode: "BC",
    },
    sellerProfile: {
      taxResponsibilityPolicyVersion: TAX_RESPONSIBILITY_TERMS_VERSION,
      revision: 3,
      countryCode: "CA",
      regionCode: "AB",
      sellerNormalGstHstRegistered: "yes",
      gstHstNumber: "123456789 RT0001",
      gstHstStatus: "verified",
      gstHstNumberReviewDueAt: timestamp(now - 1),
    },
    claim: null,
  });
  assert.equal(result.eligibleForAutomatedCheckout, false);
  assert.equal(result.seller.gstHstStatus, "review_required");
  assert.ok(result.blockers.includes("seller_gst_number_verification_required"));
});

test("approved BC exemption still requires manual tax review", () => {
  const now = Date.now();
  const result = transactionTaxComplianceSnapshot({
    nowMs: now,
    buyerProfile: {
      taxResponsibilityPolicyVersion: TAX_RESPONSIBILITY_TERMS_VERSION,
      revision: 2,
      countryCode: "CA",
      regionCode: "BC",
      pstBcStatus: "verified",
      pstBcNumber: "PST-1234-5678",
      pstBcNumberReviewDueAt: timestamp(now + 60_000),
    },
    sellerProfile: {
      taxResponsibilityPolicyVersion: TAX_RESPONSIBILITY_TERMS_VERSION,
      revision: 3,
      countryCode: "CA",
      regionCode: "AB",
      sellerNormalGstHstRegistered: "no",
      gstHstStatus: "not_provided",
    },
    claim: {
      id: "claim-1",
      exemptionType: "resale",
      jurisdiction: "CA-BC",
      status: "approved",
      evidenceVerified: true,
    },
  });
  assert.equal(result.manualTaxReviewRequired, true);
  assert.equal(result.eligibleForAutomatedCheckout, false);
  assert.equal(result.blockers.length, 0);
});
