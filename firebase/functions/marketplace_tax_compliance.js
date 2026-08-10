"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {
  AdministratorAuthorizationError,
  requireAdministrator,
} = require("./administrator_authorization");
const {
  TAX_REGISTRATION_REVIEW_DAYS,
  effectiveVerificationStatus,
} = require("./marketplace_tax_registration_admin");

const TAX_POLICY_VERSION = "2026-08-10-ca-marketplace-tax-v1";
const TAX_RESPONSIBILITY_TERMS_VERSION = "2026-08-10-tax-responsibility-v1";
const VERIFICATION_STATUSES = new Set([
  "not_provided",
  "pending_verification",
  "verified",
  "invalid",
  "review_required",
]);
const SELLER_GST_STATUSES = new Set(["yes", "no", "pending"]);
const EXEMPTION_TYPES = Object.freeze({
  resale: Object.freeze({
    label: "Purchase for resale",
    recommendedEvidence: "Verified B.C. PST number or FIN 490",
  }),
  production_machinery_equipment: Object.freeze({
    label: "Production machinery and equipment",
    recommendedEvidence: "FIN 492",
  }),
  oil_gas_pme: Object.freeze({
    label: "Oil and gas qualifying production machinery and equipment",
    recommendedEvidence: "FIN 492 plus qualifying-use evidence",
  }),
  goods_shipped_out_of_bc: Object.freeze({
    label: "Goods shipped out of B.C.",
    recommendedEvidence: "Shipping records and, where applicable, FIN 464",
  }),
  other_documented: Object.freeze({
    label: "Other documented exemption",
    recommendedEvidence: "Applicable statutory certificate and supporting records",
  }),
});

const TAX_RESPONSIBILITY_SUMMARY =
  "Buyer and seller must provide complete and accurate tax, registration, " +
  "exemption, location, use, and transaction information. To the extent " +
  "permitted by law, the party whose false, incomplete, outdated, or " +
  "misleading information causes an under-collection is responsible for the " +
  "resulting tax, interest, penalties, assessments, recovery costs, and " +
  "reasonable professional fees, and must indemnify Pipe Buyer for those " +
  "amounts. This allocation does not remove or limit any statutory obligation " +
  "that applicable law imposes directly on Pipe Buyer.";

function cleanText(value, maxLength = 180) {
  const text = String(value == null ? "" : value).trim();
  if (text.length > maxLength) {
    throw new HttpsError("invalid-argument", "A tax profile field is too long.");
  }
  return text;
}

function normalizeCode(value, maxLength) {
  const text = cleanText(value, maxLength).toUpperCase();
  if (text && !/^[A-Z0-9-]+$/.test(text)) {
    throw new HttpsError("invalid-argument", "A jurisdiction code is invalid.");
  }
  return text;
}

function normalizeTaxNumber(value, maxLength = 40) {
  const text = cleanText(value, maxLength).toUpperCase();
  if (text && !/^[A-Z0-9 .-]+$/.test(text)) {
    throw new HttpsError("invalid-argument", "A tax registration number is invalid.");
  }
  return text;
}

function normalizeTaxProfileInput(data = {}) {
  const countryCode = normalizeCode(data.countryCode, 2);
  const regionCode = normalizeCode(data.regionCode, 12);
  const sellerNormalGstHstRegistered = cleanText(
      data.sellerNormalGstHstRegistered,
      12,
  ).toLowerCase();
  if (!countryCode || !regionCode) {
    throw new HttpsError(
        "invalid-argument",
        "Country and province/state are required for the tax profile.",
    );
  }
  if (!SELLER_GST_STATUSES.has(sellerNormalGstHstRegistered)) {
    throw new HttpsError(
        "invalid-argument",
        "Select whether the seller is registered under the normal GST/HST regime.",
    );
  }
  if (data.taxResponsibilityAcknowledged !== true) {
    throw new HttpsError(
        "failed-precondition",
        "Accept the tax information and responsibility terms before saving.",
    );
  }
  const legalBusinessName = cleanText(data.legalBusinessName, 180);
  if (!legalBusinessName) {
    throw new HttpsError("invalid-argument", "Legal business name is required.");
  }
  return {
    legalBusinessName,
    countryCode,
    regionCode,
    businessNumber: normalizeTaxNumber(data.businessNumber),
    gstHstNumber: normalizeTaxNumber(data.gstHstNumber),
    pstBcNumber: normalizeTaxNumber(data.pstBcNumber),
    sellerNormalGstHstRegistered,
    taxResponsibilityPolicyVersion: TAX_RESPONSIBILITY_TERMS_VERSION,
    taxPolicyVersion: TAX_POLICY_VERSION,
  };
}

function nextVerificationStatus(previousValue, nextValue, previousStatus) {
  const prior = String(previousValue || "").trim().toUpperCase();
  const next = String(nextValue || "").trim().toUpperCase();
  const status = VERIFICATION_STATUSES.has(String(previousStatus || "")) ?
    String(previousStatus) : "not_provided";
  if (!next) return "not_provided";
  if (next === prior && status === "verified") return "verified";
  return "pending_verification";
}

function sanitizeProfileForClient(profile = {}, nowMs = Date.now()) {
  return {
    legalBusinessName: String(profile.legalBusinessName || ""),
    countryCode: String(profile.countryCode || ""),
    regionCode: String(profile.regionCode || ""),
    businessNumber: String(profile.businessNumber || ""),
    businessNumberStatus: effectiveVerificationStatus(
        profile,
        "businessNumber",
        nowMs,
    ),
    businessNumberReviewDueAt: profile.businessNumberReviewDueAt || null,
    gstHstNumber: String(profile.gstHstNumber || ""),
    gstHstStatus: effectiveVerificationStatus(
        profile,
        "gstHstNumber",
        nowMs,
    ),
    gstHstNumberReviewDueAt: profile.gstHstNumberReviewDueAt || null,
    pstBcNumber: String(profile.pstBcNumber || ""),
    pstBcStatus: effectiveVerificationStatus(
        profile,
        "pstBcNumber",
        nowMs,
    ),
    pstBcNumberReviewDueAt: profile.pstBcNumberReviewDueAt || null,
    sellerNormalGstHstRegistered: String(
        profile.sellerNormalGstHstRegistered || "pending",
    ),
    taxComplianceHold: profile.taxComplianceHold === true,
    taxPolicyVersion: String(profile.taxPolicyVersion || TAX_POLICY_VERSION),
    taxResponsibilityPolicyVersion: String(
        profile.taxResponsibilityPolicyVersion || "",
    ),
    taxResponsibilityAcknowledgedAt:
      profile.taxResponsibilityAcknowledgedAt || null,
    updatedAt: profile.updatedAt || null,
  };
}

function normalizeExemptionClaim(data = {}) {
  const exemptionType = cleanText(data.exemptionType, 80);
  if (!Object.prototype.hasOwnProperty.call(EXEMPTION_TYPES, exemptionType)) {
    throw new HttpsError("invalid-argument", "The exemption type is not supported.");
  }
  const jurisdiction = normalizeCode(data.jurisdiction || "CA-BC", 12);
  if (jurisdiction !== "CA-BC") {
    throw new HttpsError(
        "failed-precondition",
        "Self-service exemption claims are currently limited to British Columbia.",
    );
  }
  if (data.claimAcknowledged !== true) {
    throw new HttpsError(
        "failed-precondition",
        "Certify the exemption claim before submitting it for review.",
    );
  }
  const certificateReference = cleanText(data.certificateReference, 180);
  const evidenceStoragePath = cleanText(data.evidenceStoragePath, 420);
  const intendedUse = cleanText(data.intendedUse, 1200);
  if (!intendedUse) {
    throw new HttpsError(
        "invalid-argument",
        "Describe how the goods will be used so the exemption can be reviewed.",
    );
  }
  if (evidenceStoragePath &&
      !/^business_documents\/[A-Za-z0-9_-]+\/[A-Za-z0-9._-]+$/.test(
          evidenceStoragePath,
      )) {
    throw new HttpsError("invalid-argument", "The exemption evidence path is invalid.");
  }
  return {
    exemptionType,
    jurisdiction,
    certificateReference,
    evidenceStoragePath,
    intendedUse,
    transactionId: cleanText(data.transactionId, 180),
    taxPolicyVersion: TAX_POLICY_VERSION,
    taxResponsibilityPolicyVersion: TAX_RESPONSIBILITY_TERMS_VERSION,
  };
}

function claimHasMinimumEvidence(claim, profile, nowMs = Date.now()) {
  if (!claim) return false;
  if (claim.exemptionType === "resale" && profile &&
      effectiveVerificationStatus(profile, "pstBcNumber", nowMs) === "verified" &&
      profile.pstBcNumber) {
    return true;
  }
  return Boolean(claim.evidenceStoragePath || claim.certificateReference);
}

function transactionTaxComplianceSnapshot({
  buyerProfile,
  sellerProfile,
  claim,
  nowMs = Date.now(),
}) {
  const blockers = [];
  if (!buyerProfile ||
      buyerProfile.taxResponsibilityPolicyVersion !== TAX_RESPONSIBILITY_TERMS_VERSION) {
    blockers.push("buyer_tax_terms_required");
  }
  if (!sellerProfile ||
      sellerProfile.taxResponsibilityPolicyVersion !== TAX_RESPONSIBILITY_TERMS_VERSION) {
    blockers.push("seller_tax_terms_required");
  }
  const buyerPstStatus = buyerProfile ?
    effectiveVerificationStatus(buyerProfile, "pstBcNumber", nowMs) :
    "not_provided";
  const sellerGstVerification = sellerProfile ?
    effectiveVerificationStatus(sellerProfile, "gstHstNumber", nowMs) :
    "not_provided";
  if (sellerProfile) {
    const gstStatus = String(sellerProfile.sellerNormalGstHstRegistered || "pending");
    if (gstStatus === "pending") blockers.push("seller_gst_status_required");
    if (gstStatus === "yes" && sellerGstVerification !== "verified") {
      blockers.push("seller_gst_number_verification_required");
    }
  }
  let exemption = null;
  let manualTaxReviewRequired = false;
  if (claim) {
    if (claim.status !== "approved") blockers.push("exemption_not_approved");
    if (!claimHasMinimumEvidence(claim, buyerProfile, nowMs)) {
      blockers.push("exemption_evidence_required");
    }
    manualTaxReviewRequired = true;
    exemption = {
      claimId: String(claim.id || ""),
      jurisdiction: String(claim.jurisdiction || ""),
      exemptionType: String(claim.exemptionType || ""),
      status: String(claim.status || ""),
      evidenceVerified: claim.evidenceVerified === true,
    };
  }
  return {
    taxPolicyVersion: TAX_POLICY_VERSION,
    taxResponsibilityPolicyVersion: TAX_RESPONSIBILITY_TERMS_VERSION,
    registrationReviewIntervalDays: TAX_REGISTRATION_REVIEW_DAYS,
    eligibleForAutomatedCheckout: blockers.length === 0 && !manualTaxReviewRequired,
    manualTaxReviewRequired,
    blockers,
    buyer: buyerProfile ? {
      profileRevision: Number(buyerProfile.revision || 0),
      countryCode: String(buyerProfile.countryCode || ""),
      regionCode: String(buyerProfile.regionCode || ""),
      pstBcStatus: buyerPstStatus,
    } : null,
    seller: sellerProfile ? {
      profileRevision: Number(sellerProfile.revision || 0),
      countryCode: String(sellerProfile.countryCode || ""),
      regionCode: String(sellerProfile.regionCode || ""),
      sellerNormalGstHstRegistered: String(
          sellerProfile.sellerNormalGstHstRegistered || "pending",
      ),
      gstHstStatus: sellerGstVerification,
    } : null,
    exemption,
  };
}

function asHttpsError(error, fallback) {
  if (error instanceof HttpsError) return error;
  if (error instanceof AccountSecurityError ||
      error instanceof AdministratorAuthorizationError) {
    return new HttpsError(error.code, error.message);
  }
  console.error(fallback, error);
  return new HttpsError("internal", fallback);
}

function createMarketplaceTaxCompliance(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  const getMarketplaceTaxProfile = async (request) => {
    try {
      const uid = requireAuthenticatedIdentity(
          request,
          {requirePhone: false},
      ).uid;
      const snapshot = await db.collection("business_tax_profiles").doc(uid).get();
      return {
        profile: sanitizeProfileForClient(snapshot.exists ? snapshot.data() : {}),
        taxPolicyVersion: TAX_POLICY_VERSION,
        responsibilityTermsVersion: TAX_RESPONSIBILITY_TERMS_VERSION,
        registrationReviewIntervalDays: TAX_REGISTRATION_REVIEW_DAYS,
        responsibilitySummary: TAX_RESPONSIBILITY_SUMMARY,
        exemptionTypes: Object.entries(EXEMPTION_TYPES).map(([value, config]) => ({
          value,
          label: config.label,
          recommendedEvidence: config.recommendedEvidence,
        })),
      };
    } catch (error) {
      throw asHttpsError(error, "The business tax profile is unavailable.");
    }
  };

  const updateMarketplaceTaxProfile = async (request) => {
    try {
      const uid = requireAuthenticatedIdentity(
          request,
          {requirePhone: false},
      ).uid;
      const next = normalizeTaxProfileInput(request.data || {});
      const ref = db.collection("business_tax_profiles").doc(uid);
      const priorSnapshot = await ref.get();
      const prior = priorSnapshot.exists ? priorSnapshot.data() : {};
      const revision = Math.max(0, Number(prior.revision || 0)) + 1;
      const businessNumberStatus = nextVerificationStatus(
          prior.businessNumber,
          next.businessNumber,
          prior.businessNumberStatus,
      );
      const gstHstStatus = nextVerificationStatus(
          prior.gstHstNumber,
          next.gstHstNumber,
          prior.gstHstStatus,
      );
      const pstBcStatus = nextVerificationStatus(
          prior.pstBcNumber,
          next.pstBcNumber,
          prior.pstBcStatus,
      );
      const values = {
        ...next,
        ownerUid: uid,
        revision,
        businessNumberStatus,
        gstHstStatus,
        pstBcStatus,
        ...(businessNumberStatus === "verified" ? {} : {
          businessNumberReviewDueAt: FieldValue.delete(),
        }),
        ...(gstHstStatus === "verified" ? {} : {
          gstHstNumberReviewDueAt: FieldValue.delete(),
        }),
        ...(pstBcStatus === "verified" ? {} : {
          pstBcNumberReviewDueAt: FieldValue.delete(),
        }),
        taxResponsibilityAcknowledgedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        ...(priorSnapshot.exists ? {} : {createdAt: FieldValue.serverTimestamp()}),
      };
      await ref.set(values, {merge: true});
      await db.collection("tax_compliance_events").add({
        type: "tax_profile_attested",
        actorUid: uid,
        ownerUid: uid,
        profileRevision: revision,
        taxPolicyVersion: TAX_POLICY_VERSION,
        responsibilityTermsVersion: TAX_RESPONSIBILITY_TERMS_VERSION,
        createdAt: FieldValue.serverTimestamp(),
      });
      return {
        saved: true,
        revision,
        verification: {
          businessNumberStatus: sanitizeProfileForClient(values).businessNumberStatus,
          gstHstStatus: sanitizeProfileForClient(values).gstHstStatus,
          pstBcStatus: sanitizeProfileForClient(values).pstBcStatus,
        },
      };
    } catch (error) {
      throw asHttpsError(error, "The business tax profile could not be saved.");
    }
  };

  const submitMarketplaceTaxExemptionClaim = async (request) => {
    try {
      const uid = requireAuthenticatedIdentity(
          request,
          {requirePhone: false},
      ).uid;
      const profileSnapshot = await db.collection("business_tax_profiles")
          .doc(uid).get();
      if (!profileSnapshot.exists ||
          profileSnapshot.data().taxResponsibilityPolicyVersion !==
            TAX_RESPONSIBILITY_TERMS_VERSION) {
        throw new HttpsError(
            "failed-precondition",
            "Save and attest your business tax profile before claiming an exemption.",
        );
      }
      const claim = normalizeExemptionClaim(request.data || {});
      if (claim.evidenceStoragePath &&
          !claim.evidenceStoragePath.startsWith(`business_documents/${uid}/`)) {
        throw new HttpsError(
            "permission-denied",
            "Exemption evidence must belong to the signed-in account.",
        );
      }
      const ref = db.collection("marketplace_tax_exemption_claims").doc();
      await ref.set({
        ...claim,
        ownerUid: uid,
        buyerUid: uid,
        status: "pending_review",
        evidenceVerified: false,
        claimAcknowledgedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      await db.collection("tax_compliance_events").add({
        type: "exemption_claim_submitted",
        actorUid: uid,
        ownerUid: uid,
        claimId: ref.id,
        jurisdiction: claim.jurisdiction,
        exemptionType: claim.exemptionType,
        createdAt: FieldValue.serverTimestamp(),
      });
      return {claimId: ref.id, status: "pending_review"};
    } catch (error) {
      throw asHttpsError(error, "The tax exemption claim could not be submitted.");
    }
  };

  const getMarketplaceTaxComplianceAdmin = async (request) => {
    try {
      requireAdministrator(request);
      const [profiles, claims] = await Promise.all([
        db.collection("business_tax_profiles").limit(250).get(),
        db.collection("marketplace_tax_exemption_claims")
            .orderBy("createdAt", "desc").limit(250).get(),
      ]);
      const nowMs = Date.now();
      const profileRows = profiles.docs.map((doc) => ({id: doc.id, ...doc.data()}));
      const claimRows = claims.docs.map((doc) => ({id: doc.id, ...doc.data()}));
      return {
        taxPolicyVersion: TAX_POLICY_VERSION,
        responsibilityTermsVersion: TAX_RESPONSIBILITY_TERMS_VERSION,
        registrationReviewIntervalDays: TAX_REGISTRATION_REVIEW_DAYS,
        counts: {
          profiles: profileRows.length,
          pstPending: profileRows.filter((row) => {
            const status = effectiveVerificationStatus(row, "pstBcNumber", nowMs);
            return status === "pending_verification" || status === "review_required";
          }).length,
          pstVerified: profileRows.filter((row) =>
            effectiveVerificationStatus(row, "pstBcNumber", nowMs) === "verified").length,
          gstPending: profileRows.filter((row) => {
            const status = effectiveVerificationStatus(row, "gstHstNumber", nowMs);
            return status === "pending_verification" || status === "review_required";
          }).length,
          gstVerified: profileRows.filter((row) =>
            effectiveVerificationStatus(row, "gstHstNumber", nowMs) === "verified").length,
          exemptionPending: claimRows.filter((row) =>
            row.status === "pending_review" || row.status === "needs_info").length,
          exemptionApproved: claimRows.filter((row) => row.status === "approved").length,
          exemptionRejected: claimRows.filter((row) => row.status === "rejected").length,
        },
        pendingClaims: claimRows
            .filter((row) => row.status === "pending_review" || row.status === "needs_info")
            .slice(0, 50)
            .map((row) => ({
              id: row.id,
              buyerUid: String(row.buyerUid || ""),
              jurisdiction: String(row.jurisdiction || ""),
              exemptionType: String(row.exemptionType || ""),
              certificateReference: String(row.certificateReference || ""),
              evidenceStoragePath: String(row.evidenceStoragePath || ""),
              intendedUse: String(row.intendedUse || ""),
              status: String(row.status || "pending_review"),
              transactionId: String(row.transactionId || ""),
            })),
      };
    } catch (error) {
      throw asHttpsError(error, "The tax compliance queue is unavailable.");
    }
  };

  const reviewMarketplaceTaxExemptionClaim = async (request) => {
    try {
      const adminUid = requireAdministrator(request);
      const claimId = cleanText(request.data && request.data.claimId, 180);
      const status = cleanText(request.data && request.data.status, 30);
      const reviewNote = cleanText(request.data && request.data.reviewNote, 1200);
      const evidenceVerified = request.data && request.data.evidenceVerified === true;
      if (!claimId || claimId.includes("/")) {
        throw new HttpsError("invalid-argument", "The exemption claim is invalid.");
      }
      if (!new Set(["approved", "rejected", "needs_info"]).has(status)) {
        throw new HttpsError("invalid-argument", "Select a valid review decision.");
      }
      if (reviewNote.length < 4) {
        throw new HttpsError("invalid-argument", "Record the reason for the review decision.");
      }
      const ref = db.collection("marketplace_tax_exemption_claims").doc(claimId);
      const snapshot = await ref.get();
      if (!snapshot.exists) {
        throw new HttpsError("not-found", "The exemption claim was not found.");
      }
      const claim = {id: snapshot.id, ...snapshot.data()};
      const profileSnapshot = await db.collection("business_tax_profiles")
          .doc(String(claim.buyerUid || "")).get();
      const profile = profileSnapshot.exists ? profileSnapshot.data() : null;
      if (status === "approved") {
        if (!evidenceVerified || !claimHasMinimumEvidence(claim, profile)) {
          throw new HttpsError(
              "failed-precondition",
              "Approval requires verified exemption evidence or a current verified B.C. PST number where permitted.",
          );
        }
      }
      await ref.set({
        status,
        evidenceVerified: status === "approved" ? true : evidenceVerified,
        reviewNote,
        reviewedBy: adminUid,
        reviewedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      await db.collection("tax_compliance_events").add({
        type: "exemption_claim_reviewed",
        actorUid: adminUid,
        ownerUid: String(claim.buyerUid || ""),
        claimId,
        decision: status,
        evidenceVerified: status === "approved" ? true : evidenceVerified,
        createdAt: FieldValue.serverTimestamp(),
      });
      return {claimId, status};
    } catch (error) {
      throw asHttpsError(error, "The exemption review could not be saved.");
    }
  };

  const evaluateTransactionTaxCompliance = async (sale) => {
    const buyerUid = String(sale && sale.buyerUid || "");
    const sellerUid = String(sale && sale.sellerUid || "");
    const claimId = String(sale && sale.taxExemptionClaimId || "");
    const [buyerSnapshot, sellerSnapshot, claimSnapshot] = await Promise.all([
      buyerUid ? db.collection("business_tax_profiles").doc(buyerUid).get() : null,
      sellerUid ? db.collection("business_tax_profiles").doc(sellerUid).get() : null,
      claimId ? db.collection("marketplace_tax_exemption_claims").doc(claimId).get() : null,
    ]);
    const buyerProfile = buyerSnapshot && buyerSnapshot.exists ? buyerSnapshot.data() : null;
    const sellerProfile = sellerSnapshot && sellerSnapshot.exists ? sellerSnapshot.data() : null;
    let claim = null;
    if (claimSnapshot && claimSnapshot.exists) {
      const data = claimSnapshot.data();
      if (String(data.buyerUid || "") !== buyerUid) {
        throw new HttpsError(
            "permission-denied",
            "The exemption claim does not belong to this buyer.",
        );
      }
      claim = {id: claimSnapshot.id, ...data};
    }
    return transactionTaxComplianceSnapshot({buyerProfile, sellerProfile, claim});
  };

  return {
    evaluateTransactionTaxCompliance,
    getMarketplaceTaxComplianceAdmin,
    getMarketplaceTaxProfile,
    reviewMarketplaceTaxExemptionClaim,
    submitMarketplaceTaxExemptionClaim,
    updateMarketplaceTaxProfile,
  };
}

module.exports = {
  EXEMPTION_TYPES,
  TAX_POLICY_VERSION,
  TAX_RESPONSIBILITY_SUMMARY,
  TAX_RESPONSIBILITY_TERMS_VERSION,
  claimHasMinimumEvidence,
  createMarketplaceTaxCompliance,
  nextVerificationStatus,
  normalizeExemptionClaim,
  normalizeTaxProfileInput,
  sanitizeProfileForClient,
  transactionTaxComplianceSnapshot,
};
