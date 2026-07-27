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
  SupportPolicyError,
  assertSupportTransition,
  validateSupportCaseInput,
  validateSupportReply,
  validateSupportResponse,
} = require("./support_policy");

function requiredId(data, fieldName) {
  const value = String(data && data[fieldName] || "").trim();
  if (!value || value.length > 180 || value.includes("/")) {
    throw new HttpsError(
        "invalid-argument",
        `${fieldName} is missing or invalid.`,
    );
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
          error instanceof SupportPolicyError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Support command failed", error);
      throw new HttpsError(
          "internal",
          "The support action could not be completed.",
      );
    }
  };
}

function receiptId(actorUid, commandName, requestId) {
  return crypto.createHash("sha256")
      .update(`${actorUid}|${commandName}|${requestId}`)
      .digest("hex");
}

function createSupportCommands(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;

  function receiptReference(actorUid, commandName, requestId) {
    return db.collection("support_command_receipts")
        .doc(receiptId(actorUid, commandName, requestId));
  }

  function eventReference(caseId, requestId) {
    return db.collection("support_case_events").doc(`${caseId}-${requestId}`);
  }

  async function notifyAdministrators(
      caseId,
      subject,
      priority,
      eventId = "submitted",
  ) {
    const administrators = await db.collection("administrator_roles")
        .where("active", "==", true).get();
    if (administrators.empty) {
      console.warn(`Support case ${caseId} has no active administrator`);
      return;
    }
    const batch = db.batch();
    for (const role of administrators.docs) {
      batch.set(
          db.collection("users").doc(role.id).collection("notifications")
              .doc(`support-${caseId}-${eventId}`),
          {
            recipientUid: role.id,
            type: "support_case_submitted",
            title: priority === "urgent" ?
              "Urgent support case" : "New support case",
            message: subject,
            supportCaseId: caseId,
            priority,
            read: false,
            createdAt: FieldValue.serverTimestamp(),
          },
          {merge: false},
      );
    }
    await batch.commit();
  }

  const createSupportCase = command(async (request) => {
    const identity = requireAuthenticatedIdentity(request, {
      requireEmail: false,
      requirePhone: false,
    });
    await enforceUserRateLimit({db, admin, request, scope: "support"});
    const caseId = requiredId(request.data, "requestId");
    const input = validateSupportCaseInput(request.data);
    const caseRef = db.collection("support_cases").doc(caseId);
    const receiptRef = receiptReference(
        identity.uid,
        "createSupportCase",
        caseId,
    );
    const result = await db.runTransaction(async (transaction) => {
      const [receiptSnapshot, caseSnapshot] = await Promise.all([
        transaction.get(receiptRef),
        transaction.get(caseRef),
      ]);
      if (receiptSnapshot.exists) return receiptSnapshot.data().result;
      if (caseSnapshot.exists) {
        throw new HttpsError(
            "already-exists",
            "This support request has already been submitted.",
        );
      }
      const responseDue = Timestamp.fromMillis(
          Date.now() + input.firstResponseHours * 60 * 60 * 1000,
      );
      const created = {caseId, status: "open", priority: input.priority};
      transaction.create(caseRef, {
        ownerUid: identity.uid,
        category: input.category,
        subject: input.subject,
        description: input.description,
        priority: input.priority,
        firstResponseHours: input.firstResponseHours,
        firstResponseDueAt: responseDue,
        status: "open",
        ...(input.relatedType ? {relatedType: input.relatedType} : {}),
        ...(input.relatedId ? {relatedId: input.relatedId} : {}),
        revision: 1,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.create(eventReference(caseId, caseId), {
        caseId,
        ownerUid: identity.uid,
        event: "submitted",
        status: "open",
        message: input.description,
        actorUid: identity.uid,
        actorRole: "customer",
        revision: 1,
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.create(receiptRef, {
        actorUid: identity.uid,
        command: "createSupportCase",
        result: created,
        createdAt: FieldValue.serverTimestamp(),
      });
      return created;
    });
    await notifyAdministrators(caseId, input.subject, input.priority);
    return result;
  });

  const replySupportCase = command(async (request) => {
    const identity = requireAuthenticatedIdentity(request, {
      requireEmail: false,
      requirePhone: false,
    });
    await enforceUserRateLimit({db, admin, request, scope: "support"});
    const caseId = requiredId(request.data, "caseId");
    const requestId = requiredId(request.data, "requestId");
    const {message} = validateSupportReply(request.data);
    const caseRef = db.collection("support_cases").doc(caseId);
    const receiptRef = receiptReference(
        identity.uid,
        "replySupportCase",
        requestId,
    );
    const result = await db.runTransaction(async (transaction) => {
      const [receiptSnapshot, caseSnapshot] = await Promise.all([
        transaction.get(receiptRef),
        transaction.get(caseRef),
      ]);
      if (receiptSnapshot.exists) return receiptSnapshot.data().result;
      if (!caseSnapshot.exists || caseSnapshot.data().ownerUid !== identity.uid) {
        throw new HttpsError("not-found", "This support case is unavailable.");
      }
      const supportCase = caseSnapshot.data();
      if (supportCase.status === "resolved") {
        throw new HttpsError(
            "failed-precondition",
            "Reopen this resolved case before adding a reply.",
        );
      }
      const revision = Number(supportCase.revision || 1) + 1;
      const status = supportCase.status === "waiting_customer" ?
        "in_review" : supportCase.status;
      const updated = {caseId, status, revision};
      transaction.update(caseRef, {
        status,
        revision,
        lastCustomerMessage: message,
        lastCustomerReplyAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.create(eventReference(caseId, requestId), {
        caseId,
        ownerUid: identity.uid,
        event: "customer_reply",
        status,
        message,
        actorUid: identity.uid,
        actorRole: "customer",
        revision,
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.create(receiptRef, {
        actorUid: identity.uid,
        command: "replySupportCase",
        result: updated,
        createdAt: FieldValue.serverTimestamp(),
      });
      return updated;
    });
    await notifyAdministrators(
        caseId,
        "Customer replied to a support case",
        "normal",
        requestId,
    );
    return result;
  });

  const updateSupportCase = command(async (request) => {
    const administratorUid = requireAdministrator(request);
    await enforceUserRateLimit({
      db,
      admin,
      request,
      scope: "administration",
    });
    const caseId = requiredId(request.data, "caseId");
    const requestId = requiredId(request.data, "requestId");
    const {action, message} = validateSupportResponse(request.data);
    const caseRef = db.collection("support_cases").doc(caseId);
    const receiptRef = receiptReference(
        administratorUid,
        "updateSupportCase",
        requestId,
    );
    return db.runTransaction(async (transaction) => {
      const [receiptSnapshot, caseSnapshot] = await Promise.all([
        transaction.get(receiptRef),
        transaction.get(caseRef),
      ]);
      if (receiptSnapshot.exists) return receiptSnapshot.data().result;
      if (!caseSnapshot.exists) {
        throw new HttpsError("not-found", "This support case is unavailable.");
      }
      const supportCase = caseSnapshot.data();
      const status = assertSupportTransition(supportCase.status, action);
      const revision = Number(supportCase.revision || 1) + 1;
      const updated = {caseId, status, revision};
      transaction.update(caseRef, {
        status,
        revision,
        assignedAdministratorUid: administratorUid,
        lastAdministratorMessage: message,
        lastAdministratorResponseAt: FieldValue.serverTimestamp(),
        ...(supportCase.firstRespondedAt ? {} :
          {firstRespondedAt: FieldValue.serverTimestamp()}),
        ...(action === "resolve" ?
          {resolvedAt: FieldValue.serverTimestamp()} : {}),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.create(eventReference(caseId, requestId), {
        caseId,
        ownerUid: supportCase.ownerUid,
        event: action,
        status,
        message,
        actorUid: administratorUid,
        actorRole: "administrator",
        revision,
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.set(
          db.collection("users").doc(supportCase.ownerUid)
              .collection("notifications")
              .doc(`support-${caseId}-${revision}`),
          {
            recipientUid: supportCase.ownerUid,
            type: "support_case_updated",
            title: action === "resolve" ?
              "Support case resolved" : "Support case updated",
            message,
            supportCaseId: caseId,
            status,
            read: false,
            createdAt: FieldValue.serverTimestamp(),
          },
      );
      transaction.create(receiptRef, {
        actorUid: administratorUid,
        command: "updateSupportCase",
        result: updated,
        createdAt: FieldValue.serverTimestamp(),
      });
      return updated;
    });
  });

  return {createSupportCase, replySupportCase, updateSupportCase};
}

module.exports = {createSupportCommands};
