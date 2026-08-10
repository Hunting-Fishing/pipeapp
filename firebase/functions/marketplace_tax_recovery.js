"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AdministratorAuthorizationError,
  requireAdministrator,
} = require("./administrator_authorization");
const {
  TAX_POLICY_VERSION,
  TAX_RESPONSIBILITY_TERMS_VERSION,
} = require("./marketplace_tax_compliance");

const RESPONSIBLE_PARTIES = new Set(["buyer", "seller", "both"]);
const TAX_TYPES = new Set([
  "gst_hst",
  "bc_pst",
  "qst",
  "pst_rst",
  "us_sales_tax",
  "vat",
  "other",
]);

function text(value, maxLength = 1200) {
  const result = String(value == null ? "" : value).trim();
  if (result.length > maxLength) {
    throw new HttpsError("invalid-argument", "The tax recovery field is too long.");
  }
  return result;
}

function positiveMinor(value) {
  const amount = Number(value);
  if (!Number.isSafeInteger(amount) || amount <= 0) {
    throw new HttpsError(
        "invalid-argument",
        "Tax recovery amount must be a positive integer in minor currency units.",
    );
  }
  return amount;
}

function normalizeCurrency(value) {
  const currency = text(value, 3).toUpperCase();
  if (!/^[A-Z]{3}$/.test(currency)) {
    throw new HttpsError("invalid-argument", "The tax recovery currency is invalid.");
  }
  return currency;
}

async function hasOpenObligation(db, uid) {
  const snapshot = await db.collection("marketplace_tax_recovery_obligations")
      .where("responsibleUid", "==", uid)
      .where("status", "==", "open")
      .limit(1)
      .get();
  return !snapshot.empty;
}

function createMarketplaceTaxRecovery(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;

  const createMarketplaceTaxRecoveryCase = async (request) => {
    try {
      const adminUid = requireAdministrator(request);
      const transactionId = text(request.data && request.data.transactionId, 180);
      const responsibleParty = text(
          request.data && request.data.responsibleParty,
          20,
      ).toLowerCase();
      const taxType = text(request.data && request.data.taxType, 40).toLowerCase();
      const currency = normalizeCurrency(request.data && request.data.currency);
      const amountMinor = positiveMinor(request.data && request.data.amountMinor);
      const reason = text(request.data && request.data.reason, 1600);
      const authorityReference = text(
          request.data && request.data.authorityReference,
          300,
      );
      if (!transactionId || transactionId.includes("/")) {
        throw new HttpsError("invalid-argument", "A marketplace transaction is required.");
      }
      if (!RESPONSIBLE_PARTIES.has(responsibleParty)) {
        throw new HttpsError("invalid-argument", "Select buyer, seller, or both.");
      }
      if (!TAX_TYPES.has(taxType)) {
        throw new HttpsError("invalid-argument", "Select a supported tax type.");
      }
      if (reason.length < 12) {
        throw new HttpsError(
            "invalid-argument",
            "Record why the tax recovery obligation is being created.",
        );
      }
      const saleSnapshot = await db.collection("marketplace_transactions")
          .doc(transactionId).get();
      if (!saleSnapshot.exists) {
        throw new HttpsError("not-found", "The marketplace transaction was not found.");
      }
      const sale = saleSnapshot.data();
      const buyerUid = text(sale.buyerUid, 180);
      const sellerUid = text(sale.sellerUid, 180);
      const responsible = responsibleParty === "both" ?
        [{role: "buyer", uid: buyerUid}, {role: "seller", uid: sellerUid}] :
        [{
          role: responsibleParty,
          uid: responsibleParty === "buyer" ? buyerUid : sellerUid,
        }];
      if (responsible.some((entry) => !entry.uid)) {
        throw new HttpsError(
            "failed-precondition",
            "The transaction does not contain the responsible account identifiers.",
        );
      }

      const caseRef = db.collection("marketplace_tax_recovery_cases").doc();
      const batch = db.batch();
      batch.set(caseRef, {
        transactionId,
        buyerUid,
        sellerUid,
        responsibleParty,
        taxType,
        currency,
        amountMinor,
        reason,
        authorityReference,
        status: "open",
        taxPolicyVersion: TAX_POLICY_VERSION,
        responsibilityTermsVersion: TAX_RESPONSIBILITY_TERMS_VERSION,
        createdBy: adminUid,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      for (const entry of responsible) {
        const obligationRef = db.collection("marketplace_tax_recovery_obligations").doc();
        batch.set(obligationRef, {
          caseId: caseRef.id,
          transactionId,
          responsibleUid: entry.uid,
          responsibleRole: entry.role,
          currency,
          amountMinor,
          status: "open",
          taxType,
          reason,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        batch.set(db.collection("business_tax_profiles").doc(entry.uid), {
          taxComplianceHold: true,
          taxComplianceHoldReason: "open_tax_recovery_obligation",
          taxComplianceHoldUpdatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        if (entry.role === "seller") {
          batch.set(db.collection("payment_provider_accounts").doc(entry.uid), {
            sellerPayoutHold: true,
            sellerPayoutHoldReason: "tax_recovery_obligation",
            sellerPayoutHoldUpdatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
        }
      }
      batch.set(db.collection("marketplace_transactions").doc(transactionId), {
        taxRecoveryOpen: true,
        taxRecoveryCaseIds: FieldValue.arrayUnion(caseRef.id),
        taxReviewRequired: true,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      batch.set(db.collection("tax_compliance_events").doc(), {
        type: "tax_recovery_case_created",
        actorUid: adminUid,
        caseId: caseRef.id,
        transactionId,
        responsibleParty,
        taxType,
        currency,
        amountMinor,
        createdAt: FieldValue.serverTimestamp(),
      });
      await batch.commit();
      return {caseId: caseRef.id, status: "open"};
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Tax recovery case creation failed", error);
      throw new HttpsError("internal", "The tax recovery case could not be created.");
    }
  };

  const resolveMarketplaceTaxRecoveryCase = async (request) => {
    try {
      const adminUid = requireAdministrator(request);
      const caseId = text(request.data && request.data.caseId, 180);
      const resolution = text(request.data && request.data.resolution, 1600);
      if (!caseId || caseId.includes("/") || resolution.length < 8) {
        throw new HttpsError(
            "invalid-argument",
            "A valid tax recovery case and resolution note are required.",
        );
      }
      const caseRef = db.collection("marketplace_tax_recovery_cases").doc(caseId);
      const caseSnapshot = await caseRef.get();
      if (!caseSnapshot.exists) {
        throw new HttpsError("not-found", "The tax recovery case was not found.");
      }
      const recoveryCase = caseSnapshot.data();
      if (recoveryCase.status !== "open") {
        return {caseId, status: String(recoveryCase.status || "resolved")};
      }
      const obligations = await db.collection("marketplace_tax_recovery_obligations")
          .where("caseId", "==", caseId).get();
      const affected = new Map();
      const batch = db.batch();
      for (const doc of obligations.docs) {
        const obligation = doc.data();
        affected.set(String(obligation.responsibleUid || ""),
            String(obligation.responsibleRole || ""));
        batch.set(doc.ref, {
          status: "resolved",
          resolution,
          resolvedBy: adminUid,
          resolvedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
      batch.set(caseRef, {
        status: "resolved",
        resolution,
        resolvedBy: adminUid,
        resolvedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      batch.set(db.collection("tax_compliance_events").doc(), {
        type: "tax_recovery_case_resolved",
        actorUid: adminUid,
        caseId,
        transactionId: String(recoveryCase.transactionId || ""),
        createdAt: FieldValue.serverTimestamp(),
      });
      await batch.commit();

      for (const [uid, role] of affected.entries()) {
        if (!uid || await hasOpenObligation(db, uid)) continue;
        await db.collection("business_tax_profiles").doc(uid).set({
          taxComplianceHold: false,
          taxComplianceHoldReason: FieldValue.delete(),
          taxComplianceHoldUpdatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        if (role === "seller") {
          const providerRef = db.collection("payment_provider_accounts").doc(uid);
          const providerSnapshot = await providerRef.get();
          const provider = providerSnapshot.exists ? providerSnapshot.data() : {};
          if (provider.sellerPayoutHoldReason === "tax_recovery_obligation") {
            await providerRef.set({
              sellerPayoutHold: false,
              sellerPayoutHoldReason: FieldValue.delete(),
              sellerPayoutHoldUpdatedAt: FieldValue.serverTimestamp(),
            }, {merge: true});
          }
        }
      }
      const remainingForTransaction = await db
          .collection("marketplace_tax_recovery_cases")
          .where("transactionId", "==", String(recoveryCase.transactionId || ""))
          .where("status", "==", "open")
          .limit(1)
          .get();
      if (remainingForTransaction.empty) {
        await db.collection("marketplace_transactions")
            .doc(String(recoveryCase.transactionId || "")).set({
              taxRecoveryOpen: false,
              updatedAt: FieldValue.serverTimestamp(),
            }, {merge: true});
      }
      return {caseId, status: "resolved"};
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AdministratorAuthorizationError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Tax recovery resolution failed", error);
      throw new HttpsError("internal", "The tax recovery case could not be resolved.");
    }
  };

  return {
    createMarketplaceTaxRecoveryCase,
    resolveMarketplaceTaxRecoveryCase,
  };
}

module.exports = {
  RESPONSIBLE_PARTIES,
  TAX_TYPES,
  createMarketplaceTaxRecovery,
  hasOpenObligation,
};
