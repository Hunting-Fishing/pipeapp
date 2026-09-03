"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {
  AccountSecurityError,
  requireAuthenticatedIdentity,
} = require("./account_security");
const {enforceUserRateLimit} = require("./abuse_rate_limit");
const {CommandPolicyError} = require("./marketplace_command_policy");
const {
  FeatureFlagError,
  loadPhase1FeatureFlags,
  requirePhase1Feature,
} = require("./phase1_feature_flags");
const {
  validateDispatchRequestAttachmentReferences,
  validateDispatchRequestUploadInput,
  validateUploadedDispatchAttachment,
} = require("./dispatch_request_attachment_policy");

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
          error instanceof CommandPolicyError ||
          error instanceof FeatureFlagError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error("Dispatch request attachment command failed", error);
      throw new HttpsError(
          "internal",
          "The Dispatch request attachment action could not be completed.",
      );
    }
  };
}

function createDispatchRequestAttachmentCommands(admin) {
  const db = admin.firestore();
  const FieldValue = admin.firestore.FieldValue;
  const Timestamp = admin.firestore.Timestamp;

  const secured = (handler) => command(async (request) => {
    const identity = requireAuthenticatedIdentity(request);
    const flags = await loadPhase1FeatureFlags(db);
    requirePhase1Feature(flags, "dispatch");
    await enforceUserRateLimit({db, admin, request, scope: "media"});
    return handler(request, identity);
  });

  const authorizeDispatchRequestUpload = secured(
      async (request, {uid}) => {
        const authorizationId = requiredId(request.data, "requestId");
        const input = validateDispatchRequestUploadInput(request.data || {});
        const jobRef = db.collection("dispatch_jobs").doc(input.jobId);
        const jobSnapshot = await jobRef.get();
        if (jobSnapshot.exists) {
          const job = jobSnapshot.data() || {};
          if (job.createdByUid !== uid ||
              !["draft", "open"].includes(String(job.status || ""))) {
            throw new HttpsError(
                "permission-denied",
                "Only the owner of an editable Dispatch request can attach files.",
            );
          }
        }

        const storagePath =
          `dispatch_request_attachments/${input.jobId}/${uid}/${authorizationId}`;
        const reference = db.collection("media_upload_authorizations")
            .doc(authorizationId);
        const expiresAt = Timestamp.fromMillis(Date.now() + 15 * 60 * 1000);
        return db.runTransaction(async (transaction) => {
          const existing = await transaction.get(reference);
          if (existing.exists) {
            const current = existing.data();
            if (current.ownerUid !== uid ||
                current.purpose !== "dispatch_request_attachment" ||
                current.targetId !== input.jobId ||
                current.storagePath !== storagePath ||
                current.contentType !== input.contentType ||
                current.sizeBytes !== input.sizeBytes) {
              throw new HttpsError(
                  "already-exists",
                  "This upload request is already used for another file.",
              );
            }
            return {
              authorizationId,
              storagePath,
              expiresAtMillis: current.expiresAt.toMillis(),
            };
          }
          transaction.create(reference, {
            ownerUid: uid,
            purpose: "dispatch_request_attachment",
            targetId: input.jobId,
            storagePath,
            contentType: input.contentType,
            sizeBytes: input.sizeBytes,
            originalName: input.originalName,
            status: "authorized",
            expiresAt,
            createdAt: FieldValue.serverTimestamp(),
          });
          return {
            authorizationId,
            storagePath,
            expiresAtMillis: expiresAt.toMillis(),
          };
        });
      },
  );

  async function finalizeDispatchRequestAttachments({
    uid,
    jobId,
    attachments,
  }) {
    const submitted = validateDispatchRequestAttachmentReferences(attachments);
    const requestedAuthorizationIds =
      submitted.map((attachment) => attachment.authorizationId);
    const jobRef = db.collection("dispatch_jobs").doc(jobId);
    const privateRef = db.collection("dispatch_job_private").doc(jobId);

    await db.runTransaction(async (transaction) => {
      const [jobSnapshot, privateSnapshot] = await Promise.all([
        transaction.get(jobRef),
        transaction.get(privateRef),
      ]);
      if (!jobSnapshot.exists || !privateSnapshot.exists ||
          jobSnapshot.data().createdByUid !== uid ||
          privateSnapshot.data().createdByUid !== uid) {
        throw new HttpsError(
            "permission-denied",
            "This Dispatch request is unavailable for attachments.",
        );
      }
      const job = jobSnapshot.data() || {};
      const privateJob = privateSnapshot.data() || {};
      if (Array.isArray(privateJob.requestAttachmentAuthorizationIds)) {
        const existing = privateJob.requestAttachmentAuthorizationIds.map(String);
        const same = existing.length === requestedAuthorizationIds.length &&
          existing.every((value, index) =>
            value === requestedAuthorizationIds[index]);
        if (!same) {
          throw new HttpsError(
              "already-exists",
              "This Dispatch request was already finalized with different attachments.",
          );
        }
        return;
      }
      if (!["draft", "open"].includes(String(job.status || ""))) {
        throw new HttpsError(
            "failed-precondition",
            "Attachments can only be finalized while the Dispatch request is editable.",
        );
      }

      const authorizationSnapshots = [];
      for (const attachment of submitted) {
        authorizationSnapshots.push(await transaction.get(
            db.collection("media_upload_authorizations")
                .doc(attachment.authorizationId),
        ));
      }
      const finalized = [];
      for (let index = 0; index < submitted.length; index += 1) {
        const submittedAttachment = submitted[index];
        const snapshot = authorizationSnapshots[index];
        const authorization = snapshot.exists ? snapshot.data() : null;
        const value = validateUploadedDispatchAttachment(
            authorization,
            {
              uid,
              jobId,
              submittedUrl: submittedAttachment.url,
              nowMillis: Date.now(),
            },
        );
        finalized.push({
          ...value,
          authorizationId: submittedAttachment.authorizationId,
          name: submittedAttachment.name || value.name,
        });
      }

      transaction.set(privateRef, {
        requestAttachments: finalized,
        requestAttachmentAuthorizationIds: requestedAuthorizationIds,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      transaction.set(privateRef.collection("revisions").doc("1"), {
        requestAttachments: finalized,
        requestAttachmentAuthorizationIds: requestedAuthorizationIds,
      }, {merge: true});
      transaction.set(jobRef, {
        attachmentCount: finalized.length,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      transaction.set(jobRef.collection("revisions").doc("1"), {
        attachmentCount: finalized.length,
      }, {merge: true});
      for (const snapshot of authorizationSnapshots) {
        transaction.update(snapshot.ref, {
          status: "consumed",
          consumedBy: "dispatch_request",
          consumedAt: FieldValue.serverTimestamp(),
        });
      }
    });
  }

  return {
    authorizeDispatchRequestUpload,
    finalizeDispatchRequestAttachments,
  };
}

module.exports = {createDispatchRequestAttachmentCommands};
