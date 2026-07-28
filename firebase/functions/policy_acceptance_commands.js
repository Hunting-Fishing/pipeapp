"use strict";

const crypto = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {
  AdministratorAuthorizationError,
  requireAdministrator,
} = require("./administrator_authorization");
const {
  REQUIRED_POLICY_IDS,
  PolicyAcceptanceError,
  acceptanceFingerprint,
  assertCurrentPolicies,
  validateAcceptanceItems,
  validatePolicyPublication,
} = require("./policy_acceptance_policy");

function requiredRequestId(data) {
  const value = String(data && data.requestId || "").trim();
  if (!value || value.length > 180 || value.includes("/")) {
    throw new HttpsError("invalid-argument", "requestId is missing or invalid.");
  }
  return value;
}

function command(handler) {
  return async (request) => {
    try {
      return await handler(request);
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      if (error instanceof AccountSecurityError ||
          error instanceof AdministratorAuthorizationError ||
          error instanceof PolicyAcceptanceError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Policy acceptance command failed", error);
      throw new HttpsError("internal", "The policy action could not be completed.");
    }
  };
}

function receiptId(uid, commandName, requestId) {
  return crypto.createHash("sha256")
      .update(`${uid}|${commandName}|${requestId}`)
      .digest("hex");
}

function createPolicyAcceptanceCommands(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;

  const publishPolicyDocument = command(async (request) => {
    const administratorUid = requireAdministrator(request);
    await enforceUserRateLimit({db, admin, request, scope: "administration"});
    const requestId = requiredRequestId(request.data);
    const publication = validatePolicyPublication(request.data);
    const policyRef = db.collection("platform_policies")
        .doc(publication.policyId);
    const receiptRef = db.collection("policy_command_receipts")
        .doc(receiptId(administratorUid, "publishPolicyDocument", requestId));
    const eventRef = db.collection("policy_publication_events")
        .doc(`${publication.policyId}-${requestId}`);
    return db.runTransaction(async (transaction) => {
      const [receiptSnapshot, currentSnapshot] = await Promise.all([
        transaction.get(receiptRef),
        transaction.get(policyRef),
      ]);
      if (receiptSnapshot.exists) return receiptSnapshot.data().result;
      const revision = Number(currentSnapshot.data()?.revision || 0) + 1;
      const result = {
        policyId: publication.policyId,
        version: publication.version,
        revision,
      };
      transaction.set(policyRef, {
        policyId: publication.policyId,
        title: publication.title,
        version: publication.version,
        summary: publication.summary,
        documentUrl: publication.documentUrl,
        contentSha256: publication.contentSha256,
        effectiveAt: Timestamp.fromMillis(publication.effectiveAtMillis),
        status: "published",
        required: true,
        revision,
        publishedByUid: administratorUid,
        publishedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: false});
      transaction.create(eventRef, {
        policyId: publication.policyId,
        version: publication.version,
        contentSha256: publication.contentSha256,
        documentUrl: publication.documentUrl,
        effectiveAt: Timestamp.fromMillis(publication.effectiveAtMillis),
        approvalNote: publication.approvalNote,
        revision,
        actorUid: administratorUid,
        event: "published",
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.create(receiptRef, {
        actorUid: administratorUid,
        command: "publishPolicyDocument",
        result,
        createdAt: FieldValue.serverTimestamp(),
      });
      return result;
    });
  });

  const setPolicyEnforcement = command(async (request) => {
    const administratorUid = requireAdministrator(request);
    await enforceUserRateLimit({db, admin, request, scope: "administration"});
    const requestId = requiredRequestId(request.data);
    if (typeof request.data.enabled !== "boolean") {
      throw new HttpsError(
          "invalid-argument",
          "enabled must be an explicit boolean.",
      );
    }
    const approvalNote = String(request.data.approvalNote || "").trim();
    if (approvalNote.length < 20 || approvalNote.length > 1000) {
      throw new HttpsError(
          "invalid-argument",
          "Provide a 20-1000 character policy enforcement decision note.",
      );
    }
    const configRef = db.collection("platform_configuration")
        .doc("policy_enforcement");
    const receiptRef = db.collection("policy_command_receipts")
        .doc(receiptId(administratorUid, "setPolicyEnforcement", requestId));
    const eventRef = db.collection("policy_enforcement_events").doc(requestId);
    const policyRefs = REQUIRED_POLICY_IDS.map((id) =>
      db.collection("platform_policies").doc(id));
    return db.runTransaction(async (transaction) => {
      const [receiptSnapshot, configSnapshot] = await Promise.all([
        transaction.get(receiptRef),
        transaction.get(configRef),
      ]);
      if (receiptSnapshot.exists) return receiptSnapshot.data().result;
      const policies = [];
      if (request.data.enabled) {
        for (const ref of policyRefs) policies.push(await transaction.get(ref));
        if (policies.some((snapshot) =>
          !snapshot.exists || snapshot.data().status !== "published")) {
          throw new HttpsError(
              "failed-precondition",
              "Publish every required policy before enabling enforcement.",
          );
        }
      }
      const revision = Number(configSnapshot.data()?.revision || 0) + 1;
      const result = {enabled: request.data.enabled, revision};
      transaction.set(configRef, {
        enabled: request.data.enabled,
        requiredPolicyIds: REQUIRED_POLICY_IDS,
        revision,
        updatedByUid: administratorUid,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: false});
      transaction.create(eventRef, {
        event: request.data.enabled ? "enabled" : "disabled",
        enabled: request.data.enabled,
        approvalNote,
        revision,
        actorUid: administratorUid,
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.create(receiptRef, {
        actorUid: administratorUid,
        command: "setPolicyEnforcement",
        result,
        createdAt: FieldValue.serverTimestamp(),
      });
      return result;
    });
  });

  const acceptRequiredPolicies = command(async (request) => {
    const identity = requireAuthenticatedIdentity(request, {
      requireEmail: true,
      requirePhone: true,
    });
    await enforceUserRateLimit({db, admin, request, scope: "privacy"});
    const requestId = requiredRequestId(request.data);
    const accepted = validateAcceptanceItems(request.data.policies);
    const fingerprint = acceptanceFingerprint(accepted);
    const statusRef = db.collection("policy_acceptances").doc(identity.uid);
    const receiptRef = db.collection("policy_command_receipts")
        .doc(receiptId(identity.uid, "acceptRequiredPolicies", requestId));
    const eventRef = db.collection("policy_acceptance_events")
        .doc(`${identity.uid}-${requestId}`);
    const policyRefs = REQUIRED_POLICY_IDS.map((id) =>
      db.collection("platform_policies").doc(id));
    return db.runTransaction(async (transaction) => {
      const receiptSnapshot = await transaction.get(receiptRef);
      if (receiptSnapshot.exists) return receiptSnapshot.data().result;
      const policySnapshots = [];
      for (const ref of policyRefs) {
        policySnapshots.push(await transaction.get(ref));
      }
      const documents = {};
      for (const snapshot of policySnapshots) {
        if (snapshot.exists) documents[snapshot.id] = snapshot.data();
      }
      const current = assertCurrentPolicies(documents, accepted);
      const acceptedVersions = {};
      const acceptedHashes = {};
      for (const id of REQUIRED_POLICY_IDS) {
        acceptedVersions[id] = current[id].version;
        acceptedHashes[id] = current[id].contentSha256;
      }
      const result = {current: true, fingerprint, acceptedVersions};
      transaction.set(statusRef, {
        ownerUid: identity.uid,
        fingerprint,
        acceptedVersions,
        acceptedHashes,
        acceptedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: false});
      transaction.create(eventRef, {
        ownerUid: identity.uid,
        event: "required_policies_accepted",
        fingerprint,
        acceptedPolicyIds: REQUIRED_POLICY_IDS,
        acceptedVersions,
        acceptedHashes,
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.create(receiptRef, {
        actorUid: identity.uid,
        command: "acceptRequiredPolicies",
        result,
        createdAt: FieldValue.serverTimestamp(),
      });
      return result;
    });
  });

  const requireCurrentPolicies = (handler) => command(async (request) => {
    const configuration = await db.collection("platform_configuration")
        .doc("policy_enforcement").get();
    if (!configuration.exists || configuration.data().enabled !== true) {
      return handler(request);
    }
    const identity = requireAuthenticatedIdentity(request, {
      requireEmail: false,
      requirePhone: false,
    });
    const references = [
      db.collection("policy_acceptances").doc(identity.uid),
      ...REQUIRED_POLICY_IDS.map((id) =>
        db.collection("platform_policies").doc(id)),
    ];
    const [acceptanceSnapshot, ...policySnapshots] =
      await db.getAll(...references);
    if (!acceptanceSnapshot.exists) {
      throw new PolicyAcceptanceError(
          "failed-precondition",
          "Review and accept the current policies in Account > Settings before continuing.",
      );
    }
    const status = acceptanceSnapshot.data();
    const versions = status.acceptedVersions || {};
    const hashes = status.acceptedHashes || {};
    const accepted = {};
    for (const id of REQUIRED_POLICY_IDS) {
      accepted[id] = {
        version: String(versions[id] || ""),
        contentSha256: String(hashes[id] || ""),
      };
    }
    const policies = {};
    for (const snapshot of policySnapshots) {
      if (snapshot.exists) policies[snapshot.id] = snapshot.data();
    }
    try {
      assertCurrentPolicies(policies, accepted);
    } catch (_) {
      throw new PolicyAcceptanceError(
          "failed-precondition",
          "A required policy changed. Review and accept the current versions in Account > Settings.",
      );
    }
    return handler(request);
  });

  return {
    acceptRequiredPolicies,
    publishPolicyDocument,
    requireCurrentPolicies,
    setPolicyEnforcement,
  };
}

module.exports = {createPolicyAcceptanceCommands};
