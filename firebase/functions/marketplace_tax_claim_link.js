"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {
  TAX_POLICY_VERSION,
  TAX_RESPONSIBILITY_TERMS_VERSION,
} = require("./marketplace_tax_compliance");

function identifier(value, label) {
  const result = String(value == null ? "" : value).trim();
  if (!result || result.length > 180 || result.includes("/")) {
    throw new HttpsError("invalid-argument", `${label} is invalid.`);
  }
  return result;
}

function createMarketplaceTaxClaimLink(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  const attachMarketplaceTaxExemptionClaim = async (request) => {
    try {
      const uid = requireAuthenticatedIdentity(
          request,
          {requirePhone: false},
      ).uid;
      const transactionId = identifier(
          request.data && request.data.transactionId,
          "The marketplace transaction",
      );
      const claimId = identifier(
          request.data && request.data.claimId,
          "The exemption claim",
      );
      const [saleSnapshot, claimSnapshot] = await Promise.all([
        db.collection("marketplace_transactions").doc(transactionId).get(),
        db.collection("marketplace_tax_exemption_claims").doc(claimId).get(),
      ]);
      if (!saleSnapshot.exists) {
        throw new HttpsError("not-found", "The marketplace transaction was not found.");
      }
      if (!claimSnapshot.exists) {
        throw new HttpsError("not-found", "The tax exemption claim was not found.");
      }
      const sale = saleSnapshot.data();
      const claim = claimSnapshot.data();
      if (String(sale.buyerUid || "") !== uid ||
          String(claim.buyerUid || "") !== uid) {
        throw new HttpsError(
            "permission-denied",
            "Only the buyer can attach their own exemption claim to their transaction.",
        );
      }
      if (["paid", "completed", "refunded", "cancelled"].includes(
          String(sale.status || ""),
      )) {
        throw new HttpsError(
            "failed-precondition",
            "Tax exemption claims cannot be attached after this transaction is finalized.",
        );
      }
      if (["rejected", "withdrawn"].includes(String(claim.status || ""))) {
        throw new HttpsError(
            "failed-precondition",
            "This exemption claim cannot be attached in its current status.",
        );
      }
      const batch = db.batch();
      batch.set(saleSnapshot.ref, {
        taxExemptionClaimId: claimId,
        taxReviewRequired: true,
        taxPolicyVersion: TAX_POLICY_VERSION,
        taxResponsibilityTermsVersion: TAX_RESPONSIBILITY_TERMS_VERSION,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      batch.set(claimSnapshot.ref, {
        transactionId,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      batch.set(db.collection("tax_compliance_events").doc(), {
        type: "exemption_claim_attached",
        actorUid: uid,
        ownerUid: uid,
        claimId,
        transactionId,
        createdAt: FieldValue.serverTimestamp(),
      });
      await batch.commit();
      return {
        transactionId,
        claimId,
        taxReviewRequired: true,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Tax exemption claim link failed", error);
      throw new HttpsError(
          "internal",
          "The tax exemption claim could not be attached to this transaction.",
      );
    }
  };

  return {attachMarketplaceTaxExemptionClaim};
}

module.exports = {
  createMarketplaceTaxClaimLink,
  identifier,
};
